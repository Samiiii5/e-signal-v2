import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';
import '../mock/threads_mock.dart';
import '../mock/messages_mock.dart';

// ── Réponse paginée des messages ───────────────────────────────────────────

class MessagesResult {
  final List<Message> messages;
  final bool hasMore;
  final String? nextBeforeId;

  const MessagesResult({
    required this.messages,
    this.hasMore = false,
    this.nextBeforeId,
  });
}

// ── Exceptions internes ────────────────────────────────────────────────────

class InboxUnauthorizedException implements Exception {
  const InboxUnauthorizedException();
}

class InboxNetworkException implements Exception {
  const InboxNetworkException();
}

class InboxForbiddenException implements Exception {
  const InboxForbiddenException();
}

/// Réponse serveur inexploitable (code non-2xx, format inattendu, ou
/// organization_id absent de la session). Aucune donnée de démonstration n'est
/// substituée : l'écran doit afficher une erreur explicite plutôt que de faire
/// croire à des conversations réelles.
class InboxServerException implements Exception {
  final int statusCode;
  const InboxServerException(this.statusCode);
}

/// Le téléversement d'un média a échoué autrement que par un code HTTP :
/// fichier absent de l'appareil, ou réponse serveur sans URL exploitable.
class InboxMediaUploadException implements Exception {
  final String message;
  const InboxMediaUploadException(this.message);

  @override
  String toString() => message;
}

// ── Contrat ────────────────────────────────────────────────────────────────

abstract class InboxService {
  /// GET /api/v1.2/inbox/threads?organization_id=&channel=&limit=&offset=
  Future<List<Thread>> getThreads({
    String? channelFilter,
    bool? unreadOnly,
    int limit = 50,
    int offset = 0,
  });

  /// GET /api/v1.2/inbox/threads/:id/messages?organization_id=&limit=&before_id=
  Future<MessagesResult> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  });

  // ── Cache (Stale-While-Revalidate) ────────────────────────────────────────

  /// Threads actuellement en cache, ou null si aucun cache valide.
  List<Thread>? get cachedThreads;

  /// Invalide le cache des threads.
  void invalidateThreadsCache();

  /// Messages en cache pour un thread, ou null si absent/expiré.
  List<Message>? cachedMessages(String threadId);

  /// Invalide le cache des messages d'un thread.
  void invalidateMessagesCache(String threadId);

  /// Ajoute un message au cache existant d'un thread (ex: reçu via WebSocket).
  void addMessageToCache(String threadId, Message message);

  /// Met à jour le dernier message d'un thread dans le cache (appelé depuis WebSocket).
  void updateThreadLastMessage(
    String threadId,
    String lastMessage,
    DateTime lastAt,
  );

  /// POST multipart/form-data (champ `file`) sur l'endpoint de téléversement.
  ///
  /// Téléverse un fichier local et retourne l'URL publique renvoyée par le
  /// serveur. Indispensable avant [sendMessage] pour les types image / audio /
  /// vidéo / document : `media_url` doit être une URL téléchargeable depuis
  /// l'extérieur (Meta/WhatsApp va la chercher), jamais un chemin local.
  ///
  /// Réponse attendue : `{"media_url": "https://..."}` — les clés `url`,
  /// `file_url`, `public_url` et `location` sont également acceptées.
  ///
  /// Endpoint : `POST /api/v1.2/media/upload`, avec `organization_id`.
  ///
  /// Lève [InboxMediaUploadException] si le fichier est introuvable, si aucun
  /// endpoint n'existe, ou si la réponse ne contient aucune URL.
  Future<String> uploadMedia(String filePath);

  /// POST /api/v1.2/inbox/{provider}/messages
  /// Retourne le message_id du serveur, ou null si absent de la réponse.
  Future<String?> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String
    type, // "text", "image", "audio", "video", "document", "location"
    String? content, // pour type text et location
    String? mediaUrl, // pour type image, audio, video, document
  });

  /// POST /api/v1.2/inbox/{provider}/messages (type: "carousel")
  /// Retourne le message_id du serveur, ou null si absent de la réponse.
  Future<String?> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<Map<String, dynamic>> catalogItemIds,
  });

  /// POST /api/v1.2/inbox/messenger/sender-action
  /// Signale au contact que le commercial est en train d'écrire.
  /// Non critique : les erreurs sont ignorées silencieusement.
  Future<void> sendTypingAction(String threadId, bool isTyping);

  /// POST /api/v1.2/inbox/threads/:id/read
  Future<void> markAsRead(String threadId);

  /// POST /api/threads/:id/payment-links
  Future<Message> createPaymentLink(
    String threadId,
    String amount,
    String provider,
  );
}

// ── HTTP ───────────────────────────────────────────────────────────────────

class HttpInboxService implements InboxService {
  // ── Cache (Stale-While-Revalidate) ────────────────────────────────────────

  // Cache threads
  List<Thread>? _cachedThreads;
  DateTime? _threadsCachedAt;
  static const _threadsCacheDuration = Duration(minutes: 3);

  // Cache messages par thread
  final Map<String, List<Message>> _messagesCache = {};
  final Map<String, DateTime> _messagesCachedAt = {};
  static const _messagesCacheDuration = Duration(minutes: 2);

  // Cache produits
  List<Map<String, dynamic>>? _cachedProducts;
  DateTime? _productsCachedAt;
  static const _productsCacheDuration = Duration(minutes: 5);

  @override
  List<Thread>? get cachedThreads => _cachedThreads;

  @override
  void invalidateThreadsCache() {
    _cachedThreads = null;
    _threadsCachedAt = null;
    debugPrint('=== Cache threads invalidé ===');
  }

  @override
  List<Message>? cachedMessages(String threadId) {
    final cachedAt = _messagesCachedAt[threadId];
    final cached = _messagesCache[threadId];
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > _messagesCacheDuration) {
      return null;
    }
    return cached;
  }

  @override
  void invalidateMessagesCache(String threadId) {
    _messagesCache.remove(threadId);
    _messagesCachedAt.remove(threadId);
    debugPrint('=== Cache messages $threadId invalidé ===');
  }

  @override
  void addMessageToCache(String threadId, Message message) {
    if (_messagesCache.containsKey(threadId)) {
      _messagesCache[threadId]!.add(message);
      debugPrint('=== Message ajouté au cache $threadId ===');
    }
  }

  @override
  void updateThreadLastMessage(
    String threadId,
    String lastMessage,
    DateTime lastAt,
  ) {
    if (_cachedThreads == null) return;
    final idx = _cachedThreads!.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;

    final old = _cachedThreads![idx];
    _cachedThreads![idx] = old.copyWith(
      lastMessage: lastMessage,
      lastMessageAt: lastAt.toIso8601String(),
      unreadCount: old.unreadCount + 1,
    );

    // Remonter ce thread en haut de la liste
    final updated = _cachedThreads!.removeAt(idx);
    _cachedThreads!.insert(0, updated);

    debugPrint('=== Cache thread $threadId mis à jour : $lastMessage ===');
  }

  /// Produits en cache, ou null si absent/expiré.
  List<Map<String, dynamic>>? get cachedProducts {
    if (_cachedProducts == null || _productsCachedAt == null) return null;
    if (DateTime.now().difference(_productsCachedAt!) >
        _productsCacheDuration) {
      return null;
    }
    return _cachedProducts;
  }

  /// Invalide le cache des produits.
  void invalidateProductsCache() {
    _cachedProducts = null;
    _productsCachedAt = null;
    debugPrint('=== Cache produits invalidé ===');
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionTimeout;

  @override
  Future<List<Thread>> getThreads({
    String? channelFilter,
    bool? unreadOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    // Le cache ne s'applique qu'à la première page de la liste complète
    // (sans filtre) — les pages suivantes sont toujours demandées au serveur.
    final useCache =
        channelFilter == null && unreadOnly != true && offset == 0;
    if (useCache &&
        _cachedThreads != null &&
        _threadsCachedAt != null &&
        DateTime.now().difference(_threadsCachedAt!) < _threadsCacheDuration) {
      debugPrint('=== THREADS depuis cache ===');
      return _cachedThreads!;
    }
    final threads = await _fetchThreads(
      channelFilter: channelFilter,
      unreadOnly: unreadOnly,
      limit: limit,
      offset: offset,
    );
    if (useCache) {
      _cachedThreads = threads;
      _threadsCachedAt = DateTime.now();
      debugPrint('=== THREADS depuis API → mis en cache ===');
    }
    return threads;
  }

  /// Méthode privée qui fait le vrai appel API.
  Future<List<Thread>> _fetchThreads({
    String? channelFilter,
    bool? unreadOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    final orgId = SessionService.organizationId;
    // ignore: avoid_print
    print('=== GET THREADS appelé ===');
    // ignore: avoid_print
    print('=== ORG ID utilisé : ${SessionService.organizationId} ===');
    if (orgId == null) throw const InboxServerException(0);

    try {
      final params = <String, dynamic>{
        'organization_id': orgId,
        'limit': limit,
        'offset': offset,
      };
      if (channelFilter != null) params['channel'] = channelFilter;
      if (unreadOnly == true) params['status'] = 'unread';

      final resp = await ApiClient.dio.get(
        '/inbox/threads',
        queryParameters: params,
      );
      // ignore: avoid_print
      print('=== RÉPONSE API : ${resp.data} ===');

      if (resp.statusCode == 200) {
        final data = resp.data;
        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data['items'] is List) {
          items = data['items'] as List;
        } else if (data is Map && data['data'] is List) {
          items = data['data'] as List;
        } else if (data is Map && data['threads'] is List) {
          items = data['threads'] as List;
        } else {
          throw InboxServerException(resp.statusCode ?? 0);
        }
        final threads = items
            .map((e) => Thread.fromJson(e as Map<String, dynamic>))
            .toList();
        // ignore: avoid_print
        print('=== THREADS PARSÉS : ${threads.length} ===');
        // ignore: avoid_print
        print(
          '=== PREMIER THREAD : ${threads.isNotEmpty ? threads.first.contactName : "vide"} ===',
        );
        return threads;
      } else if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else {
        throw InboxServerException(resp.statusCode ?? 0);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const InboxNetworkException();
      throw InboxServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<MessagesResult> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  }) async {
    // Cache seulement pour le premier chargement (pas pour la pagination beforeId).
    if (beforeId == null) {
      final cached = cachedMessages(threadId);
      if (cached != null) {
        debugPrint('=== MESSAGES $threadId depuis cache ===');
        return MessagesResult(
          messages: cached,
          hasMore: false,
          nextBeforeId: null,
        );
      }
    }
    final result = await _fetchMessages(
      threadId,
      limit: limit,
      beforeId: beforeId,
    );
    if (beforeId == null) {
      _messagesCache[threadId] = result.messages;
      _messagesCachedAt[threadId] = DateTime.now();
      debugPrint('=== MESSAGES $threadId depuis API → mis en cache ===');
    }
    return result;
  }

  /// Méthode privée qui fait le vrai appel API.
  Future<MessagesResult> _fetchMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) throw const InboxServerException(0);

    try {
      final params = <String, dynamic>{
        'organization_id': orgId,
        'limit': limit,
      };
      if (beforeId != null) params['before_id'] = beforeId;

      final resp = await ApiClient.dio.get(
        '/inbox/threads/$threadId/messages',
        queryParameters: params,
      );

      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        final rawMsgs = data['messages'] as List<dynamic>? ?? [];
        final messages = rawMsgs
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
        return MessagesResult(
          messages: messages,
          hasMore: data['has_more'] as bool? ?? false,
          nextBeforeId: data['next_before_id']?.toString(),
        );
      } else if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else if (resp.statusCode == 403) {
        throw const InboxForbiddenException();
      } else {
        throw InboxServerException(resp.statusCode ?? 0);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const InboxNetworkException();
      throw InboxServerException(e.response?.statusCode ?? 0);
    }
  }

  /// POST /api/v1.2/media/upload — « Uploader un fichier via le serveur »
  /// (section `media` de la doc Swagger). L'alternative
  /// `POST /media/upload-url` (URL pré-signée pour upload direct) éviterait de
  /// faire transiter le fichier par le serveur, mais impose un aller-retour de
  /// plus ; à envisager si les envois deviennent lourds.
  static const _mediaUploadPath = '/media/upload';

  /// Préfixe des fichiers stockés, si le serveur ne renvoie qu'une clé.
  /// GET /api/v1.2/media/file/{key}
  static const _mediaFilePath = '/media/file';

  /// POST multipart/form-data sur /media/upload
  @override
  Future<String> uploadMedia(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const InboxMediaUploadException(
        'Fichier introuvable sur l\'appareil',
      );
    }

    final orgId = SessionService.organizationId;
    if (orgId == null || orgId.isEmpty) {
      throw const InboxMediaUploadException(
        'Organisation inconnue — reconnectez-vous',
      );
    }

    final fileName = filePath.split(Platform.pathSeparator).last;
    // `organization_id` est passé en query ET en champ de formulaire : les
    // routes de l'API l'attendent en query, mais certaines routes multipart le
    // lisent dans le formulaire. Le champ en trop est ignoré côté serveur.
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'organization_id': orgId,
    });

    debugPrint(
      '=== uploadMedia url: $_mediaUploadPath fichier: $fileName '
      '(${file.lengthSync()} octets) ===',
    );

    // ApiClient accepte tous les codes HTTP (validateStatus) — on vérifie donc
    // le statut nous-mêmes. Les échecs sont traduits ici plutôt que renvoyés
    // bruts : un 404 sur le téléversement signifie « endpoint absent », pas
    // « conversation introuvable » comme pour l'envoi d'un message.
    final resp = await ApiClient.dio.post(
      _mediaUploadPath,
      data: formData,
      queryParameters: {'organization_id': orgId},
    );
    debugPrint(
      '=== uploadMedia response (${resp.statusCode}): ${resp.data} ===',
    );
    final status = resp.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw InboxMediaUploadException(_uploadErrorMessage(status, resp.data));
    }

    final url = _extractMediaUrl(resp.data);
    if (url == null || url.isEmpty) {
      throw const InboxMediaUploadException(
        'Le serveur n\'a pas renvoyé l\'URL du fichier',
      );
    }
    return url;
  }

  static String _uploadErrorMessage(int? status, dynamic body) {
    final detail = body is Map ? (body['detail'] ?? body['message'] ?? '') : '';
    return switch (status) {
      404 || 405 => 'Téléversement refusé par le serveur : endpoint absent',
      401 => 'Session expirée, reconnectez-vous',
      403 => 'Téléversement non autorisé pour ce compte',
      413 => 'Photo trop volumineuse',
      415 => 'Format de photo non pris en charge',
      422 => 'Photo rejetée par le serveur : $detail',
      429 => 'Trop d\'envois, patientez un instant',
      500 || 502 || 503 => 'Serveur indisponible, réessayez plus tard',
      _ => 'Échec du téléversement de la photo (erreur $status)',
    };
  }

  /// L'URL peut être nommée différemment selon le backend, et se trouver à la
  /// racine ou sous `data`. On accepte les clés usuelles plutôt que d'échouer
  /// sur un simple écart de nommage. Si le serveur ne renvoie qu'une clé de
  /// stockage, on la transforme en URL via /media/file/{key} — c'est cette
  /// URL que Meta ira télécharger.
  static String? _extractMediaUrl(dynamic body) {
    if (body is! Map) return null;
    for (final name in const [
      'media_url',
      'url',
      'file_url',
      'public_url',
      'location',
    ]) {
      final value = body[name];
      if (value is String && value.isNotEmpty) return value;
    }
    for (final name in const ['key', 'file_key', 'object_key']) {
      final value = body[name];
      if (value is String && value.isNotEmpty) {
        return '${ApiClient.baseUrl}$_mediaFilePath/$value';
      }
    }
    return _extractMediaUrl(body['data']);
  }

  /// POST /api/v1.2/inbox/{provider}/messages
  /// Retourne le message_id du serveur, ou null si absent de la réponse.
  @override
  Future<String?> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String type,
    String? content,
    String? mediaUrl,
  }) async {
    // Aucun repli silencieux : deviner 'whatsapp' enverrait le message sur le
    // mauvais fournisseur (ex. conversation Messenger) sans que rien ne le
    // signale. Mieux vaut une erreur explicite.
    if (provider.isEmpty) {
      throw ArgumentError(
        'Provider manquant : impossible d\'envoyer le message sans canal défini',
      );
    }

    final Map<String, dynamic> data = {'thread_id': threadId, 'type': type};
    if (content != null && content.isNotEmpty) {
      data['body_text'] = content;
    }
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      data['media_url'] = mediaUrl;
    }
    if (integrationAccountId != null && integrationAccountId.isNotEmpty) {
      data['integration_account_id'] = integrationAccountId;
    }

    debugPrint('=== sendMessage url: /inbox/$provider/messages ===');
    debugPrint('=== sendMessage body: $data ===');

    // ApiClient accepte tous les codes HTTP sans exception (validateStatus) —
    // on doit donc lever nous-mêmes une DioException sur un statut non-2xx
    // pour que l'appelant (_send() dans chat_screen.dart) puisse distinguer
    // les codes d'erreur (401/403/404/422/429/500/502...).
    final resp = await ApiClient.dio.post(
      '/inbox/$provider/messages',
      data: data,
    );
    debugPrint('=== sendMessage response: ${resp.data} ===');
    if (resp.statusCode == null ||
        resp.statusCode! < 200 ||
        resp.statusCode! >= 300) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
      );
    }

    final responseData = resp.data;
    if (responseData is Map) {
      final msgId = responseData['message_id']?.toString();
      debugPrint('=== sendMessage message_id serveur: $msgId ===');
      return msgId;
    }
    return null;
  }

  /// POST /api/v1.2/inbox/{provider}/messages (type: "carousel")
  @override
  Future<String?> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<Map<String, dynamic>> catalogItemIds,
  }) async {
    // Même règle que sendMessage : pas de repli silencieux sur 'whatsapp'.
    if (provider.isEmpty) {
      throw ArgumentError(
        'Provider manquant : impossible d\'envoyer le message sans canal défini',
      );
    }

    // Une seule clé de type — 'type' est celle utilisée par sendMessage() pour
    // tous les autres formats de message.
    final body = <String, dynamic>{
      'thread_id': threadId,
      'type': 'carousel',
      'integration_account_id': integrationAccountId,
      'carousel': {'items': catalogItemIds},
      'body_text': '📦 Catalogue',
    };
    debugPrint('=== CAROUSEL envoyé : /inbox/$provider/messages ===');
    debugPrint('=== CAROUSEL body : $body ===');
    try {
      final resp = await ApiClient.dio.post(
        '/inbox/$provider/messages',
        data: body,
      );
      debugPrint('=== CAROUSEL response status: ${resp.statusCode} ===');
      debugPrint('=== CAROUSEL response data: ${resp.data} ===');
      if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else if (resp.statusCode == null ||
          resp.statusCode! < 200 ||
          resp.statusCode! >= 300) {
        throw Exception('HTTP ${resp.statusCode} - ${resp.data}');
      }

      // Retourner le vrai message_id du serveur
      final responseData = resp.data;
      if (responseData is Map) {
        final msgId = responseData['message_id']?.toString();
        debugPrint('=== CAROUSEL message_id serveur: $msgId ===');
        return msgId;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('=== CAROUSEL DioException: ${e.type} - ${e.message} ===');
      debugPrint('=== CAROUSEL DioException response: ${e.response?.data} ===');
      if (_isNetworkError(e)) throw const InboxNetworkException();
      rethrow;
    }
  }

  @override
  Future<void> sendTypingAction(String threadId, bool isTyping) async {
    try {
      await ApiClient.dio.post(
        '/inbox/messenger/sender-action',
        data: {
          'thread_id': threadId,
          'action': isTyping ? 'typing_on' : 'typing_off',
        },
      );
    } catch (e) {
      // Purement cosmétique côté contact — ne jamais gêner la saisie.
      debugPrint('=== sendTypingAction error: $e ===');
    }
  }

  @override
  Future<void> markAsRead(String threadId) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return;
    try {
      final resp = await ApiClient.dio.post(
        '/inbox/threads/$threadId/read',
        queryParameters: {'organization_id': orgId},
      );
      if (resp.statusCode == null ||
          resp.statusCode! < 200 ||
          resp.statusCode! >= 300) {
        debugPrint(
          '=== markAsRead échec HTTP ${resp.statusCode} : ${resp.data} ===',
        );
      }
    } catch (e) {
      // Non-bloquant pour l'utilisateur, mais tracé pour le diagnostic.
      debugPrint('=== markAsRead error: $e ===');
    }
  }

  @override
  Future<Message> createPaymentLink(
    String threadId,
    String amount,
    String provider,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      direction: 'OUT',
      bodyText: 'Lien de paiement $provider — $amount FCFA',
      messageType: 'PAYMENT_LINK',
      sentAt: DateTime.now().toIso8601String(),
      paymentAmount: amount,
      paymentCurrency: 'FCFA',
      paymentStatus: PaymentStatus.created,
      paymentProvider: provider,
    );
  }
}

// ── Mock ───────────────────────────────────────────────────────────────────

class MockInboxService implements InboxService {
  final Map<String, List<Message>> _extraMessages = {};

  void addMessage(String threadId, Message msg) {
    _extraMessages.putIfAbsent(threadId, () => []).add(msg);
  }

  // Pas de cache pour le mock — toujours les données en mémoire directement.
  @override
  List<Thread>? get cachedThreads => null;

  @override
  void invalidateThreadsCache() {}

  @override
  List<Message>? cachedMessages(String threadId) => null;

  @override
  void invalidateMessagesCache(String threadId) {}

  @override
  void addMessageToCache(String threadId, Message message) {}

  @override
  void updateThreadLastMessage(
    String threadId,
    String lastMessage,
    DateTime lastAt,
  ) {}

  @override
  Future<List<Thread>> getThreads({
    String? channelFilter,
    bool? unreadOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = List<Thread>.from(mockThreads);
    if (channelFilter != null) {
      results = results.where((t) => t.channel == channelFilter).toList();
    }
    if (unreadOnly == true) {
      results = results.where((t) => t.unreadCount > 0).toList();
    }
    // Pagination : même contrat que l'implémentation HTTP.
    if (offset >= results.length) return <Thread>[];
    return results.sublist(
      offset,
      (offset + limit).clamp(0, results.length),
    );
  }

  @override
  Future<MessagesResult> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final base = threadId == 'thread_001'
        ? List<Message>.from(mockMessagesThread001)
        : <Message>[];
    final all = [...base, ...(_extraMessages[threadId] ?? [])];
    return MessagesResult(messages: List<Message>.from(all));
  }

  @override
  Future<String> uploadMedia(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'https://picsum.photos/seed/${filePath.hashCode}/600/400';
  }

  @override
  Future<String?> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String type,
    String? content,
    String? mediaUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return null;
  }

  @override
  Future<String?> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<Map<String, dynamic>> catalogItemIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return null;
  }

  @override
  Future<void> sendTypingAction(String threadId, bool isTyping) async {}

  @override
  Future<void> markAsRead(String threadId) async {}

  @override
  Future<Message> createPaymentLink(
    String threadId,
    String amount,
    String provider,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Message(
      id: 'msg_generated_${DateTime.now().millisecondsSinceEpoch}',
      direction: 'OUT',
      bodyText: 'Lien de paiement $provider — $amount FCFA',
      messageType: 'PAYMENT_LINK',
      sentAt: DateTime.now().toIso8601String(),
      paymentAmount: amount,
      paymentCurrency: 'FCFA',
      paymentStatus: PaymentStatus.created,
      paymentProvider: provider,
    );
  }
}

final InboxService inboxService = HttpInboxService();
