// Type d'un message dans la conversation
enum MessageType { text, paymentLink, location, orderTracking, image }

// Statut d'un lien de paiement
enum PaymentStatus { created, pending, paid, expired }

class Message {
  final String id;
  final String threadId;
  final String content;
  final bool isFromContact; // false = envoyé par le commerçant
  final DateTime sentAt;
  final MessageType type;

  // Champs spécifiques aux liens de paiement (type == paymentLink)
  final String? paymentAmount;
  final String? paymentCurrency;
  final PaymentStatus? paymentStatus;
  final String? paymentProvider; // "wave" | "orange_money"

  // Champ spécifique aux images (type == image)
  final String? imagePath;

  const Message({
    required this.id,
    required this.threadId,
    required this.content,
    required this.isFromContact,
    required this.sentAt,
    this.type = MessageType.text,
    this.paymentAmount,
    this.paymentCurrency,
    this.paymentStatus,
    this.paymentProvider,
    this.imagePath,
  });
}

// 15 messages pour la conversation Awa N'Guessan (thread_001)
final mockMessagesThread001 = <Message>[
  Message(
    id: 'msg_001',
    threadId: 'thread_001',
    content: 'Bonjour, est-ce que vous avez encore le sac en cuir marron ?',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 45)),
  ),
  Message(
    id: 'msg_002',
    threadId: 'thread_001',
    content: 'Bonjour Awa 👋 Oui, il est encore disponible !',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 40)),
  ),
  Message(
    id: 'msg_003',
    threadId: 'thread_001',
    content: 'Super ! Il coûte combien ?',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 38)),
  ),
  Message(
    id: 'msg_004',
    threadId: 'thread_001',
    content: 'Il est à 25 000 FCFA. Livraison gratuite à Abidjan pour toute commande ce mois-ci.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 35)),
  ),
  Message(
    id: 'msg_005',
    threadId: 'thread_001',
    content: 'Waouh top ! Je peux payer par Wave ?',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)),
  ),
  Message(
    id: 'msg_006',
    threadId: 'thread_001',
    content: 'Bien sûr ! Je vous génère un lien de paiement maintenant.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 28)),
  ),
  // Lien de paiement Wave
  Message(
    id: 'msg_007',
    threadId: 'thread_001',
    content: 'Voici votre lien de paiement Wave pour le sac en cuir marron.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 27)),
    type: MessageType.paymentLink,
    paymentAmount: '15000',
    paymentCurrency: 'FCFA',
    paymentStatus: PaymentStatus.paid,
    paymentProvider: 'wave',
  ),
  Message(
    id: 'msg_008',
    threadId: 'thread_001',
    content: 'Je viens de recevoir le lien 😊',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 20)),
  ),
  Message(
    id: 'msg_009',
    threadId: 'thread_001',
    content: 'J\'essaie de payer...',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
  ),
  Message(
    id: 'msg_010',
    threadId: 'thread_001',
    content: 'Prenez votre temps, le lien est valable 24h.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 12)),
  ),
  Message(
    id: 'msg_011',
    threadId: 'thread_001',
    content: 'Voilà c\'est fait ! J\'ai payé 🎉',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 5)),
  ),
  Message(
    id: 'msg_012',
    threadId: 'thread_001',
    content: 'Paiement reçu ✅ Merci Awa ! Votre commande est confirmée.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 3)),
  ),
  Message(
    id: 'msg_013',
    threadId: 'thread_001',
    content: 'La livraison se fait dans combien de temps ?',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
  ),
  Message(
    id: 'msg_014',
    threadId: 'thread_001',
    content: 'Sous 24-48h ouvrées. Notre livreur vous contactera avant de passer.',
    isFromContact: false,
    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
  ),
  Message(
    id: 'msg_015',
    threadId: 'thread_001',
    content: 'Merci pour le lien, j\'ai payé 🙏',
    isFromContact: true,
    sentAt: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
];
