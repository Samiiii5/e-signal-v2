import '../mock/messages_mock.dart' show PaymentStatus;

class PaymentLink {
  final String id;
  final String contactName;
  final String description;
  final int amount; // en FCFA
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final PaymentMethod paymentMethod;

  // Champs optionnels renvoyés par l'API (absents dans les données mockées)
  final String? checkoutUrl;
  final String? currency;
  final bool orderCardSent;
  final String? catalogItemId;
  final String? threadId;

  const PaymentLink({
    required this.id,
    required this.contactName,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.paymentMethod,
    this.checkoutUrl,
    this.currency,
    this.orderCardSent = false,
    this.catalogItemId,
    this.threadId,
  });

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    int parsedAmount = 0;
    final rawAmount = json['amount'];
    if (rawAmount is int) parsedAmount = rawAmount;
    else if (rawAmount is double) parsedAmount = rawAmount.toInt();
    else if (rawAmount is String) parsedAmount = int.tryParse(rawAmount) ?? 0;

    final rawStatus = (json['status'] ?? '').toString().toLowerCase();
    final status = PaymentStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => PaymentStatus.created,
    );

    final rawProvider = (json['provider'] ?? json['payment_method'] ?? '').toString().toLowerCase();
    final paymentMethod = _providerToMethod(rawProvider);

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return PaymentLink(
      id: (json['id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? json['contactName'] ?? 'Inconnu').toString(),
      description: (json['description'] ?? '').toString(),
      amount: parsedAmount,
      status: status,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      expiresAt: parseDate(json['expires_at'] ?? json['expiresAt']),
      paymentMethod: paymentMethod,
      checkoutUrl: json['checkout_url']?.toString(),
      currency: json['currency']?.toString(),
      orderCardSent: json['order_card_sent'] as bool? ?? false,
      catalogItemId: json['catalog_item_id']?.toString(),
      threadId: json['thread_id']?.toString(),
    );
  }

  static PaymentMethod _providerToMethod(String provider) {
    switch (provider) {
      case 'wave':         return PaymentMethod.wave;
      case 'orange_money': return PaymentMethod.orangeMoney;
      case 'cinetpay':     return PaymentMethod.cinetPay;
      case 'moov_money':   return PaymentMethod.moovMoney;
      case 'mtn_money':    return PaymentMethod.mtnMoney;
      case 'djamo':        return PaymentMethod.djamo;
      default:             return PaymentMethod.wave;
    }
  }
}

enum PaymentMethod { wave, orangeMoney, cinetPay, moovMoney, mtnMoney, djamo }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.wave:        return 'Wave';
      case PaymentMethod.orangeMoney: return 'Orange Money';
      case PaymentMethod.cinetPay:    return 'CinetPay';
      case PaymentMethod.moovMoney:   return 'Moov Money';
      case PaymentMethod.mtnMoney:    return 'MTN Money';
      case PaymentMethod.djamo:       return 'Djamo';
    }
  }

  static PaymentMethod fromLabel(String label) {
    return PaymentMethod.values.firstWhere(
      (m) => m.label == label,
      orElse: () => PaymentMethod.wave,
    );
  }
}

final mockPaymentLinks = <PaymentLink>[
  PaymentLink(
    id: 'pay_001',
    contactName: 'Awa N\'Guessan',
    description: 'Sac en cuir marron',
    amount: 25000,
    status: PaymentStatus.paid,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    expiresAt: DateTime.now().add(const Duration(hours: 21)),
    paymentMethod: PaymentMethod.wave,
  ),
  PaymentLink(
    id: 'pay_002',
    contactName: 'Kofi Mensah',
    description: 'Commande lot de 5 pagnes',
    amount: 75000,
    status: PaymentStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
    expiresAt: DateTime.now().add(const Duration(hours: 22, minutes: 40)),
    paymentMethod: PaymentMethod.orangeMoney,
  ),
  PaymentLink(
    id: 'pay_003',
    contactName: 'Fatou Diallo',
    description: 'Robe ankara taille M',
    amount: 15000,
    status: PaymentStatus.created,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    expiresAt: DateTime.now().add(const Duration(hours: 23, minutes: 30)),
    paymentMethod: PaymentMethod.wave,
  ),
  PaymentLink(
    id: 'pay_004',
    contactName: 'Jean-Baptiste Aka',
    description: 'Devis 50 unités — acompte 30%',
    amount: 150000,
    status: PaymentStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    expiresAt: DateTime.now().add(const Duration(hours: 19)),
    paymentMethod: PaymentMethod.orangeMoney,
  ),
  PaymentLink(
    id: 'pay_005',
    contactName: 'Binta Coulibaly',
    description: 'Bracelet argent + gravure',
    amount: 8500,
    status: PaymentStatus.expired,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    paymentMethod: PaymentMethod.wave,
  ),
  PaymentLink(
    id: 'pay_006',
    contactName: 'Moussa Traoré',
    description: 'Chaussures cuir modèle bleu',
    amount: 32000,
    status: PaymentStatus.paid,
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
    paymentMethod: PaymentMethod.wave,
  ),
  PaymentLink(
    id: 'pay_007',
    contactName: 'Aminata Koné',
    description: 'Offre duo — 2 robes TikTok promo',
    amount: 45000,
    status: PaymentStatus.created,
    createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
    expiresAt: DateTime.now().add(const Duration(hours: 21, minutes: 15)),
    paymentMethod: PaymentMethod.orangeMoney,
  ),
  PaymentLink(
    id: 'pay_008',
    contactName: 'Rose Yao',
    description: 'Frais de livraison express Abidjan',
    amount: 5000,
    status: PaymentStatus.expired,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    expiresAt: DateTime.now().subtract(const Duration(days: 2)),
    paymentMethod: PaymentMethod.wave,
  ),
];
