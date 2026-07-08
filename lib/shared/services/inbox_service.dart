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

  /// POST /api/v1.2/inbox/threads/:id/messages
  Future<void> sendMessage(String threadId, String content);

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
    if (orgId == null) return List.from(mockThreads);

    try {
      final params = <String, dynamic>{'organization_id': orgId, 'limit': 50, 'offset': 0};
      if (channelFilter != null) params['channel'] = channelFilter;
      if (unreadOnly == true) params['status'] = 'unread';

      final resp = await ApiClient.dio.get('/inbox/threads', queryParameters: params);

      if (resp.statusCode == 200) {
        final data = resp.data;
        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data['data'] is List) {
          items = data['data'] as List;
        } else if (data is Map && data['threads'] is List) {
          items = data['threads'] as List;
        } else {
          return List.from(mockThreads);
        }
        return items.map((e) => Thread.fromJson(e as Map<String, dynamic>)).toList();
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

  @override
  Future<void> sendMessage(String threadId, String content) async {
    await Future.delayed(const Duration(milliseconds: 250));
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
    return MessagesResult(messages: all);
  }

  @override
  Future<void> sendMessage(String threadId, String content) async {
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
