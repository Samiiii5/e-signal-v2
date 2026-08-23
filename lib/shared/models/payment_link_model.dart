import 'package:flutter/foundation.dart';

/// Lien de paiement rattaché à un message de conversation.
///
/// Distinct de [PaymentLink] (`payment_link.dart`), qui modélise la réponse de
/// `GET /payment-links/organizations/{id}` pour l'écran Paiements. Celui-ci
/// modélise l'objet **imbriqué dans un message** renvoyé par
/// `GET /inbox/threads/{id}/messages`.
///
/// Le parsing est volontairement tolérant : la structure exacte renvoyée par le
/// serveur n'étant pas figée, chaque champ accepte plusieurs noms possibles.
class PaymentLinkModel {
  final String id;
  final String description;
  final double amount;
  final String currency;
  final String status;
  final String? url;

  const PaymentLinkModel({
    this.id = '',
    this.description = '',
    this.amount = 0.0,
    this.currency = 'XOF',
    this.status = 'pending',
    this.url,
  });

  /// Vrai si le lien peut être ouvert dans un navigateur.
  bool get hasUrl => url != null && url!.trim().isNotEmpty;

  /// Vrai si aucun champ exploitable n'a pu être extrait — l'appelant doit
  /// alors afficher un repli plutôt qu'une bulle vide.
  bool get isEmpty =>
      description.isEmpty && amount == 0.0 && !hasUrl && id.isEmpty;

  /// Trace lisible pour le diagnostic (sans ce toString, un debugPrint
  /// afficherait « Instance of 'PaymentLinkModel' »).
  @override
  String toString() =>
      'PaymentLinkModel(id: $id, description: $description, '
      'amount: $amount, currency: $currency, status: $status, url: $url)';

  /// Vrai si le paiement est déjà réglé — le bouton n'a alors plus de sens.
  bool get isPaid {
    final s = status.toLowerCase();
    return s == 'paid' || s == 'completed' || s == 'success';
  }

  /// Clés du message pouvant contenir l'objet lien de paiement.
  static const _objectKeys = [
    'payment_link',
    'paymentLink',
    'payment',
    'payment_link_data',
  ];

  /// Extrait l'objet lien de paiement d'un message JSON, ou null s'il est absent.
  ///
  /// Deux formes sont acceptées :
  /// - objet imbriqué : `{"payment_link": {"amount": …}}`
  /// - champs à plat sur le message : `{"payment_amount": …, "payment_status": …}`
  static PaymentLinkModel? fromMessageJson(Map<String, dynamic> json) {
    for (final key in _objectKeys) {
      final raw = json[key];
      if (raw is Map) {
        // Trace décisive : la structure réelle renvoyée par le serveur.
        debugPrint('=== payment_link brut (clé "$key") : $raw ===');
        return PaymentLinkModel.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    // Repli : champs préfixés directement sur le message.
    final flat = json['payment_amount'] ?? json['payment_status'];
    if (flat != null) {
      debugPrint('=== payment_link à plat sur le message : $json ===');
      return PaymentLinkModel(
        id: _str(json['payment_link_id'] ?? json['payment_id']),
        description: _str(json['body_text'] ?? json['description']),
        amount: _num(json['payment_amount']),
        currency: _str(json['payment_currency'], fallback: 'XOF'),
        status: _str(json['payment_status'], fallback: 'pending'),
        url: _nullableStr(
          json['payment_url'] ??
              json['checkout_url'] ??
              json['payment_link_url'],
        ),
      );
    }
    // Aucun objet ni champ de paiement : on trace les clés disponibles pour
    // pouvoir ajouter la bonne variante si le serveur en emploie une autre.
    final type = (json['message_type'] ?? '').toString().toUpperCase();
    if (type.contains('PAYMENT')) {
      debugPrint(
        '=== message_type "$type" sans objet de paiement reconnu. '
        'Clés présentes : ${json.keys.toList()} ===',
      );
    }
    return null;
  }

  factory PaymentLinkModel.fromJson(Map<String, dynamic> json) {
    return PaymentLinkModel(
      id: _str(json['id'] ?? json['payment_link_id'] ?? json['link_id']),
      // Variantes de libellé : description, title, name, label
      description: _str(
        json['description'] ??
            json['title'] ??
            json['name'] ??
            json['label'] ??
            json['catalog_item_name'],
      ),
      // Variantes de montant : amount, price, total, value
      amount: _num(
        json['amount'] ?? json['price'] ?? json['total'] ?? json['value'],
      ),
      currency: _str(
        json['currency'] ?? json['currency_code'],
        fallback: 'XOF',
      ),
      // Variantes de statut : status, payment_status, state — repli 'pending'
      status: _str(
        json['status'] ?? json['payment_status'] ?? json['state'],
        fallback: 'pending',
      ),
      // Variantes d'URL : url, checkout_url, payment_url, link, short_url
      url: _nullableStr(
        json['url'] ??
            json['checkout_url'] ??
            json['payment_url'] ??
            json['link'] ??
            json['short_url'],
      ),
    );
  }

  /// Chaîne non nulle, avec repli.
  static String _str(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Chaîne nullable — conserve null plutôt que de renvoyer une chaîne vide,
  /// pour que [hasUrl] puisse désactiver le bouton.
  static String? _nullableStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Nombre tolérant : accepte 25000, 25000.0 et "25000.00".
  static double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(' ', '')) ?? 0.0;
  }

  /// Montant formaté avec séparateur de milliers : 25000.0 → « 25 000 ».
  String get formattedAmount {
    final s = amount.truncate().abs().toString();
    final buf = StringBuffer(amount < 0 ? '-' : '');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
