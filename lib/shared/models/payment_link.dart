class PaymentLink {
  final String id;
  final String checkoutUrl;
  final String provider;
  final String amount;
  final String currency;
  final String description;
  final String expiresAt;
  final String status;
  final String? paymentStatus;
  final String? openedAt;
  final String? catalogItemId;
  final String? catalogItemName;
  final String? threadId;
  final bool orderCardSent;

  const PaymentLink({
    required this.id,
    required this.checkoutUrl,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.description,
    required this.expiresAt,
    required this.status,
    this.paymentStatus,
    this.openedAt,
    this.catalogItemId,
    this.catalogItemName,
    this.threadId,
    this.orderCardSent = false,
  });

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    return PaymentLink(
      id:              (json['id'] ?? '').toString(),
      checkoutUrl:     (json['checkout_url'] ?? '').toString(),
      provider:        (json['provider'] ?? '').toString(),
      amount:          (json['amount'] ?? '0').toString(),
      currency:        (json['currency'] ?? 'XOF').toString(),
      description:     (json['description'] ?? '').toString(),
      expiresAt:       (json['expires_at'] ?? '').toString(),
      status:          (json['status'] ?? 'created').toString().toLowerCase(),
      paymentStatus:   json['payment_status']?.toString(),
      openedAt:        json['opened_at']?.toString(),
      catalogItemId:   json['catalog_item_id']?.toString(),
      catalogItemName: json['catalog_item_name']?.toString(),
      threadId:        json['thread_id']?.toString(),
      orderCardSent:   json['order_card_sent'] as bool? ?? false,
    );
  }

  /// Montant en entier (pour affichage formaté).
  int get amountInt => int.tryParse(amount) ?? 0;

  /// Date d'expiration parsée (null si invalide).
  DateTime? get expiresAtDate => DateTime.tryParse(expiresAt);
}
