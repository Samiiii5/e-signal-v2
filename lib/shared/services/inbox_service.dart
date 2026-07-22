import 'package:dio/dio.dart';
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

// ── Contrat ────────────────────────────────────────────────────────────────

abstract class InboxService {
  /// GET /api/v1.2/inbox/threads?organization_id=&channel=&limit=&offset=
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly});

  /// GET /api/v1.2/inbox/threads/:id/messages?organization_id=&limit=&before_id=
  Future<MessagesResult> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  });

  /// POST /api/v1.2/inbox/{provider}/messages
  Future<void> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String content,
  });

  /// POST /api/v1.2/inbox/{provider}/messages (type: "carousel")
  Future<void> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<String> catalogItemIds,
  });

  /// POST /api/v1.2/inbox/threads/:id/read
  Future<void> markAsRead(String threadId);

  /// POST /api/threads/:id/payment-links
  Future<Message> createPaymentLink(String threadId, String amount, String provider);
}

// ── HTTP ───────────────────────────────────────────────────────────────────

class HttpInboxService implements InboxService {
  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionTimeout;

  @override
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly}) async {
    final orgId = SessionService.organizationId;
    // ignore: avoid_print
    print('=== GET THREADS appelé ===');
    // ignore: avoid_print
    print('=== ORG ID utilisé : ${SessionService.organizationId} ===');
    if (orgId == null) return List.from(mockThreads);

    try {
      final params = <String, dynamic>{'organization_id': orgId, 'limit': 50, 'offset': 0};
      if (channelFilter != null) params['channel'] = channelFilter;
      if (unreadOnly == true) params['status'] = 'unread';

      final resp = await ApiClient.dio.get('/inbox/threads', queryParameters: params);
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
          return List.from(mockThreads);
        }
        final threads = items.map((e) => Thread.fromJson(e as Map<String, dynamic>)).toList();
        // ignore: avoid_print
        print('=== THREADS PARSÉS : ${threads.length} ===');
        // ignore: avoid_print
        print('=== PREMIER THREAD : ${threads.isNotEmpty ? threads.first.contactName : "vide"} ===');
        return threads;
      } else if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else {
        return List.from(mockThreads);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const InboxNetworkException();
      return List.from(mockThreads);
    }
  }

  @override
  Future<MessagesResult> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) {
      return MessagesResult(messages: List.from(mockMessagesThread001));
    }

    try {
      final params = <String, dynamic>{'organization_id': orgId, 'limit': limit};
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
        return MessagesResult(messages: List.from(mockMessagesThread001));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const InboxNetworkException();
      return MessagesResult(messages: List.from(mockMessagesThread001));
    }
  }

  /// POST /api/v1.2/inbox/{provider}/messages
  @override
  Future<void> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String content,
  }) async {
    final orgId = SessionService.organizationId;
    // Fallback sur 'whatsapp' si le channel est vide pour éviter /inbox//messages
    final resolvedProvider = provider.isNotEmpty ? provider : 'whatsapp';
    final body = <String, dynamic>{
      'thread_id': threadId,
      'body_text': content,
      'type': 'text',
      if (orgId != null) 'organization_id': orgId,
      if (integrationAccountId != null) 'integration_account_id': integrationAccountId,
    };
    // ignore: avoid_print
    print('=== SEND MESSAGE → POST /inbox/$resolvedProvider/messages ===');
    // ignore: avoid_print
    print('=== BODY : $body ===');
    try {
      final resp = await ApiClient.dio.post(
        '/inbox/$resolvedProvider/messages',
        data: body,
      );
      // ignore: avoid_print
      print('=== SEND MESSAGE status : ${resp.statusCode} ===');
      // ignore: avoid_print
      print('=== SEND MESSAGE response : ${resp.data} ===');
      if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else if (resp.statusCode! < 200 || resp.statusCode! >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print('=== SEND MESSAGE DioException : ${e.type} — ${e.message} ===');
      if (_isNetworkError(e)) throw const InboxNetworkException();
      rethrow;
    }
  }

  /// POST /api/v1.2/inbox/{provider}/messages (type: "carousel")
  @override
  Future<void> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<String> catalogItemIds,
  }) async {
    try {
      final resp = await ApiClient.dio.post(
        '/inbox/$provider/messages',
        data: {
          'thread_id': threadId,
          'type': 'carousel',
          'integration_account_id': integrationAccountId,
          'catalog_item_ids': catalogItemIds,
        },
      );
      if (resp.statusCode == 401) {
        throw const InboxUnauthorizedException();
      } else if (resp.statusCode! < 200 || resp.statusCode! >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const InboxNetworkException();
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String threadId) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return;
    try {
      await ApiClient.dio.post(
        '/inbox/threads/$threadId/read',
        queryParameters: {'organization_id': orgId},
      );
    } catch (_) {
      // Non-bloquant — ignorer les erreurs
    }
  }

  @override
  Future<Message> createPaymentLink(String threadId, String amount, String provider) async {
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

  @override
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = List<Thread>.from(mockThreads);
    if (channelFilter != null) results = results.where((t) => t.channel == channelFilter).toList();
    if (unreadOnly == true) results = results.where((t) => t.unreadCount > 0).toList();
    return results;
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
  Future<void> sendMessage({
    required String threadId,
    required String provider,
    String? integrationAccountId,
    required String content,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> sendCarousel({
    required String threadId,
    required String provider,
    required String integrationAccountId,
    required List<String> catalogItemIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> markAsRead(String threadId) async {}

  @override
  Future<Message> createPaymentLink(String threadId, String amount, String provider) async {
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
