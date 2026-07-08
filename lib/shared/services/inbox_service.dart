import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';
import '../mock/threads_mock.dart';
import '../mock/messages_mock.dart';

abstract class InboxService {
  /// GET /api/v1.2/inbox/threads?organization_id=&channel=&status=&limit=&offset=
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly});

  /// GET /api/threads/:id/messages?page=&limit=20
  Future<List<Message>> getMessages(String threadId, {int page = 1});

  /// POST /api/threads/:id/messages
  Future<void> sendMessage(String threadId, String content);

  /// POST /api/threads/:id/payment-links
  Future<Message> createPaymentLink(String threadId, String amount, String provider);
}

/// Implémentation HTTP réelle.
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
      final params = <String, dynamic>{'organization_id': orgId};
      if (channelFilter != null) params['channel'] = channelFilter;
      if (unreadOnly == true) params['status'] = 'unread';
      params['limit'] = 50;
      params['offset'] = 0;

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
        throw const _UnauthorizedException();
      } else {
        return List.from(mockThreads);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const _NetworkException();
      return List.from(mockThreads);
    }
  }

  @override
  Future<List<Message>> getMessages(String threadId, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return <Message>[];
  }

  @override
  Future<void> sendMessage(String threadId, String content) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<Message> createPaymentLink(String threadId, String amount, String provider) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      threadId: threadId,
      content: 'Lien de paiement $provider — $amount FCFA',
      isFromContact: false,
      sentAt: DateTime.now(),
      type: MessageType.paymentLink,
      paymentAmount: amount,
      paymentCurrency: 'FCFA',
      paymentStatus: PaymentStatus.created,
      paymentProvider: provider,
    );
  }
}

/// Implémentation mock — fallback ou tests.
class MockInboxService implements InboxService {
  final Map<String, List<Message>> _extraMessages = {};

  void addMessage(String threadId, Message msg) {
    _extraMessages.putIfAbsent(threadId, () => []).add(msg);
  }

  @override
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = List<Thread>.from(mockThreads);

    if (channelFilter != null) {
      results = results.where((t) => t.channel == channelFilter).toList();
    }
    if (unreadOnly == true) {
      results = results.where((t) => t.unreadCount > 0).toList();
    }
    return results;
  }

  @override
  Future<List<Message>> getMessages(String threadId, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final base = threadId == 'thread_001'
        ? List<Message>.from(mockMessagesThread001)
        : <Message>[];
    return [...base, ...(_extraMessages[threadId] ?? [])];
  }

  @override
  Future<void> sendMessage(String threadId, String content) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<Message> createPaymentLink(String threadId, String amount, String provider) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Message(
      id: 'msg_generated_${DateTime.now().millisecondsSinceEpoch}',
      threadId: threadId,
      content: 'Lien de paiement $provider — $amount FCFA',
      isFromContact: false,
      sentAt: DateTime.now(),
      type: MessageType.paymentLink,
      paymentAmount: amount,
      paymentCurrency: 'FCFA',
      paymentStatus: PaymentStatus.created,
      paymentProvider: provider,
    );
  }
}

class _UnauthorizedException implements Exception {
  const _UnauthorizedException();
}

class _NetworkException implements Exception {
  const _NetworkException();
}

final InboxService inboxService = HttpInboxService();
