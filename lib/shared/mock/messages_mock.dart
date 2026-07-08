// Statut de livraison (UI uniquement — animation envoi)
enum MessageStatus { sent, delivered, read }

// Statut d'un lien de paiement (UI uniquement)
enum PaymentStatus { created, pending, paid, expired }

// Type de message (UI uniquement — backward compat)
enum MessageType { text, paymentLink, location, orderTracking, image }

class Message {
  final String id;
  final String direction;     // 'IN' (reçu) | 'OUT' (envoyé)
  final String? bodyText;
  final String messageType;   // 'TEXT' | 'IMAGE' | 'PAYMENT_LINK' | 'LOCATION' | 'ORDER_TRACKING'
  final String? mediaUrl;
  final String? mediaMimeType;
  final String status;        // 'sent' | 'delivered' | 'read'
  final String sentAt;        // ISO 8601
  final String? deliveredAt;
  final String? readAt;

  // Champs paiement (messages créés localement, absents de l'API)
  final String? paymentAmount;
  final String? paymentCurrency;
  final PaymentStatus? paymentStatus;
  final String? paymentProvider;

  const Message({
    required this.id,
    required this.direction,
    this.bodyText,
    this.messageType = 'TEXT',
    this.mediaUrl,
    this.mediaMimeType,
    this.status = 'sent',
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.paymentAmount,
    this.paymentCurrency,
    this.paymentStatus,
    this.paymentProvider,
  });

  // ── Backward-compat getters ─────────────────────────────────────────────────

  bool get isMe => direction == 'OUT';
  bool get isFromContact => direction == 'IN';
  String get content => bodyText ?? '';

  DateTime get sentAtDt => DateTime.tryParse(sentAt)?.toLocal() ?? DateTime.now();

  MessageType get type => switch (messageType.toUpperCase()) {
    'PAYMENT_LINK'   => MessageType.paymentLink,
    'IMAGE'          => MessageType.image,
    'LOCATION'       => MessageType.location,
    'ORDER_TRACKING' => MessageType.orderTracking,
    _                => MessageType.text,
  };

  MessageStatus? get initialStatus => switch (status.toLowerCase()) {
    'read'      => MessageStatus.read,
    'delivered' => MessageStatus.delivered,
    'sent'      => MessageStatus.sent,
    _           => null,
  };

  // ── Factory API ─────────────────────────────────────────────────────────────

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? '').toString(),
      direction: (json['direction'] ?? 'IN').toString(),
      bodyText: json['body_text']?.toString(),
      messageType: (json['message_type'] ?? 'TEXT').toString(),
      mediaUrl: json['media_url']?.toString(),
      mediaMimeType: json['media_mime_type']?.toString(),
      status: (json['status'] ?? 'sent').toString(),
      sentAt: (json['sent_at'] ?? '').toString(),
      deliveredAt: json['delivered_at']?.toString(),
      readAt: json['read_at']?.toString(),
    );
  }
}

// ── Données mock — thread_001 (Awa N'Guessan) ──────────────────────────────

final mockMessagesThread001 = <Message>[
  Message(
    id: 'msg_001',
    direction: 'IN',
    bodyText: "Bonjour, est-ce que vous avez encore le sac en cuir marron ?",
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 45)).toIso8601String(),
  ),
  Message(
    id: 'msg_002',
    direction: 'OUT',
    bodyText: 'Bonjour Awa 👋 Oui, il est encore disponible !',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 40)).toIso8601String(),
  ),
  Message(
    id: 'msg_003',
    direction: 'IN',
    bodyText: 'Super ! Il coûte combien ?',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 38)).toIso8601String(),
  ),
  Message(
    id: 'msg_004',
    direction: 'OUT',
    bodyText: 'Il est à 25 000 FCFA. Livraison gratuite à Abidjan pour toute commande ce mois-ci.',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 35)).toIso8601String(),
  ),
  Message(
    id: 'msg_005',
    direction: 'IN',
    bodyText: 'Waouh top ! Je peux payer par Wave ?',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)).toIso8601String(),
  ),
  Message(
    id: 'msg_006',
    direction: 'OUT',
    bodyText: 'Bien sûr ! Je vous génère un lien de paiement maintenant.',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 28)).toIso8601String(),
  ),
  Message(
    id: 'msg_007',
    direction: 'OUT',
    bodyText: 'Voici votre lien de paiement Wave pour le sac en cuir marron.',
    messageType: 'PAYMENT_LINK',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 27)).toIso8601String(),
    paymentAmount: '15000',
    paymentCurrency: 'FCFA',
    paymentStatus: PaymentStatus.paid,
    paymentProvider: 'wave',
  ),
  Message(
    id: 'msg_008',
    direction: 'IN',
    bodyText: 'Je viens de recevoir le lien 😊',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 20)).toIso8601String(),
  ),
  Message(
    id: 'msg_009',
    direction: 'IN',
    bodyText: "J'essaie de payer...",
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)).toIso8601String(),
  ),
  Message(
    id: 'msg_010',
    direction: 'OUT',
    bodyText: 'Prenez votre temps, le lien est valable 24h.',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 12)).toIso8601String(),
  ),
  Message(
    id: 'msg_011',
    direction: 'IN',
    bodyText: "Voilà c'est fait ! J'ai payé 🎉",
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 5)).toIso8601String(),
  ),
  Message(
    id: 'msg_012',
    direction: 'OUT',
    bodyText: 'Paiement reçu ✅ Merci Awa ! Votre commande est confirmée.',
    status: 'read',
    sentAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 3)).toIso8601String(),
  ),
  Message(
    id: 'msg_013',
    direction: 'IN',
    bodyText: 'La livraison se fait dans combien de temps ?',
    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)).toIso8601String(),
  ),
  Message(
    id: 'msg_014',
    direction: 'OUT',
    bodyText: 'Sous 24-48h ouvrées. Notre livreur vous contactera avant de passer.',
    status: 'delivered',
    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)).toIso8601String(),
  ),
  Message(
    id: 'msg_015',
    direction: 'IN',
    bodyText: 'Merci pour le lien, j\'ai payé 🙏',
    sentAt: DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
  ),
];
