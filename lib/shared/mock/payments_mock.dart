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

  const PaymentLink({
    required this.id,
    required this.contactName,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.paymentMethod,
  });
}

enum PaymentMethod { wave, orangeMoney }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.wave:       return 'Wave';
      case PaymentMethod.orangeMoney: return 'Orange Money';
    }
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
