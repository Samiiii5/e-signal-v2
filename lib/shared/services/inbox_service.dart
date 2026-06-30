import '../mock/threads_mock.dart';
import '../mock/messages_mock.dart';

abstract class InboxService {
  /// GET /api/threads?channel=&unread=
  /// [channelFilter] : filtre par canal ("whatsapp", "facebook", "sms", "tiktok", "email")
  /// [unreadOnly]    : si true, retourne uniquement les threads avec unreadCount > 0
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly});

  /// GET /api/threads/:id/messages?page=&limit=20
  /// Les messages sont retournés du plus ancien au plus récent.
  Future<List<Message>> getMessages(String threadId, {int page = 1});

  /// POST /api/threads/:id/messages
  /// [content] : texte du message à envoyer
  Future<void> sendMessage(String threadId, String content);

  /// POST /api/threads/:id/payment-links
  /// Génère un lien de paiement Wave ou Orange Money dans la conversation.
  /// [amount]   : montant en FCFA (ex: "25000")
  /// [provider] : "wave" ou "orange_money"
  Future<Message> createPaymentLink(String threadId, String amount, String provider);
}

/// Implémentation mock — à remplacer par un appel HTTP réel en Sprint 3.
class MockInboxService implements InboxService {
  final Map<String, List<Message>> _extraMessages = {};
  final Map<String, (String, DateTime)> _threadPreviews = {};

  /// Injecte un message dans la conversation et met à jour l'aperçu du thread.
  void addMessage(String threadId, Message msg) {
    _extraMessages.putIfAbsent(threadId, () => []).add(msg);
    _threadPreviews[threadId] = (msg.content, msg.sentAt);
  }

  @override
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = mockThreads.map((t) {
      if (_threadPreviews.containsKey(t.id)) {
        final (msg, at) = _threadPreviews[t.id]!;
        return t.copyWith(lastMessage: msg, lastMessageAt: at);
      }
      return t;
    }).toList();

    if (channelFilter != null) {
      final ch = Channel.values.firstWhere(
        (c) => c.name == channelFilter,
        orElse: () => Channel.whatsapp,
      );
      results = results.where((t) => t.channel == ch).toList();
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
    // En production : POST /api/threads/:id/messages {content}
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

final inboxService = MockInboxService();
