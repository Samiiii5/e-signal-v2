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
  @override
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = List<Thread>.from(mockThreads);

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
    // Seule thread_001 a des messages mockés pour l'instant
    if (threadId == 'thread_001') return List.from(mockMessagesThread001);
    return [];
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
