import '../mock/messages_mock.dart' show PaymentStatus;
import '../mock/payments_mock.dart';

class CreatePaymentLinkDto {
  final String contactName;
  final String description;
  final int amount; // en FCFA
  final PaymentMethod paymentMethod;

  const CreatePaymentLinkDto({
    required this.contactName,
    required this.description,
    required this.amount,
    required this.paymentMethod,
  });
}

abstract class PaymentService {
  /// GET /api/payment-links
  /// Retourne tous les liens de paiement du commerçant, du plus récent au plus ancien.
  Future<List<PaymentLink>> getPaymentLinks();

  /// POST /api/payment-links
  /// Crée un nouveau lien de paiement Wave ou Orange Money.
  /// Retourne le lien créé avec son statut initial [PaymentStatus.created].
  Future<PaymentLink> createPaymentLink(CreatePaymentLinkDto dto);

  /// PATCH /api/payment-links/:id/status
  /// [status] : "created" | "pending" | "paid" | "expired"
  /// Utilisé en interne par le webhook de paiement ou manuellement.
  Future<void> updatePaymentStatus(String id, String status);
}

/// Implémentation mock — à remplacer par un appel HTTP en Sprint 3.
class MockPaymentService implements PaymentService {
  final _links = List<PaymentLink>.from(mockPaymentLinks);

  @override
  Future<List<PaymentLink>> getPaymentLinks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_links)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<PaymentLink> createPaymentLink(CreatePaymentLinkDto dto) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final link = PaymentLink(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      contactName: dto.contactName,
      description: dto.description,
      amount: dto.amount,
      status: PaymentStatus.created,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      paymentMethod: dto.paymentMethod,
    );
    _links.add(link);
    return link;
  }

  @override
  Future<void> updatePaymentStatus(String id, String status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final parsed = PaymentStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => PaymentStatus.pending,
    );
    final index = _links.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final old = _links[index];
    _links[index] = PaymentLink(
      id: old.id,
      contactName: old.contactName,
      description: old.description,
      amount: old.amount,
      status: parsed,
      createdAt: old.createdAt,
      expiresAt: old.expiresAt,
      paymentMethod: old.paymentMethod,
    );
  }
}

final paymentService = MockPaymentService();
