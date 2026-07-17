import 'package:dio/dio.dart';
import '../mock/messages_mock.dart' show PaymentStatus;
import '../mock/payments_mock.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';

class PaymentUnauthorizedException implements Exception {}
class PaymentNetworkException implements Exception {}
class PaymentNotFoundException implements Exception {}

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
  Future<List<PaymentLink>> getPaymentLinks();

  /// GET /api/payment-links/:id
  Future<PaymentLink> getPaymentLinkDetail(String id);

  /// POST /api/payment-links
  Future<PaymentLink> createPaymentLink(CreatePaymentLinkDto dto);

  /// DELETE /api/payment-links/:id
  Future<void> cancelPaymentLink(String id);

  /// PATCH /api/payment-links/:id/status
  Future<void> updatePaymentStatus(String id, String status);
}

class HttpPaymentService implements PaymentService {
  Map<String, dynamic> get _orgParam {
    final orgId = SessionService.organizationId;
    return orgId != null ? {'organization_id': orgId} : {};
  }

  @override
  Future<List<PaymentLink>> getPaymentLinks() async {
    try {
      final resp = await ApiClient.dio.get('/payment-links', queryParameters: _orgParam);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      final data = resp.data;
      List items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is Map && data['data'] is List) {
        items = data['data'] as List;
      } else {
        return List.from(mockPaymentLinks)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(PaymentLink.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on PaymentUnauthorizedException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<PaymentLink> getPaymentLinkDetail(String id) async {
    try {
      final resp = await ApiClient.dio.get('/payment-links/$id', queryParameters: _orgParam);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      if (resp.statusCode == 404) throw PaymentNotFoundException();
      final data = resp.data;
      final raw = data is Map && data['data'] is Map ? data['data'] as Map<String, dynamic> : data as Map<String, dynamic>;
      return PaymentLink.fromJson(raw);
    } on PaymentUnauthorizedException {
      rethrow;
    } on PaymentNotFoundException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<PaymentLink> createPaymentLink(CreatePaymentLinkDto dto) async {
    try {
      final provider = _methodToProvider(dto.paymentMethod);
      final resp = await ApiClient.dio.post('/payment-links', data: {
        'contact_name': dto.contactName,
        'description': dto.description,
        'amount': dto.amount.toString(),
        'provider': provider,
        ..._orgParam,
      });
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      final data = resp.data;
      final raw = data is Map && data['data'] is Map ? data['data'] as Map<String, dynamic> : data as Map<String, dynamic>;
      return PaymentLink.fromJson(raw);
    } on PaymentUnauthorizedException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<void> cancelPaymentLink(String id) async {
    try {
      final resp = await ApiClient.dio.delete('/payment-links/$id', queryParameters: _orgParam);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      if (resp.statusCode == 404) throw PaymentNotFoundException();
    } on PaymentUnauthorizedException {
      rethrow;
    } on PaymentNotFoundException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<void> updatePaymentStatus(String id, String status) async {
    try {
      final resp = await ApiClient.dio.patch('/payment-links/$id/status', data: {'status': status});
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
    } on PaymentUnauthorizedException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  String _methodToProvider(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.wave:        return 'wave';
      case PaymentMethod.orangeMoney: return 'orange_money';
      case PaymentMethod.cinetPay:    return 'cinetpay';
      case PaymentMethod.moovMoney:   return 'moov_money';
      case PaymentMethod.mtnMoney:    return 'mtn_money';
      case PaymentMethod.djamo:       return 'djamo';
    }
  }
}

class MockPaymentService implements PaymentService {
  final _links = List<PaymentLink>.from(mockPaymentLinks);

  @override
  Future<List<PaymentLink>> getPaymentLinks() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_links)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<PaymentLink> getPaymentLinkDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _links.firstWhere((l) => l.id == id, orElse: () => _links.first);
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
  Future<void> cancelPaymentLink(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _links.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final old = _links[index];
    _links[index] = PaymentLink(
      id: old.id, contactName: old.contactName, description: old.description,
      amount: old.amount, status: PaymentStatus.expired,
      createdAt: old.createdAt, expiresAt: old.expiresAt, paymentMethod: old.paymentMethod,
    );
  }

  @override
  Future<void> updatePaymentStatus(String id, String status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final parsed = PaymentStatus.values.firstWhere((s) => s.name == status, orElse: () => PaymentStatus.pending);
    final index = _links.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final old = _links[index];
    _links[index] = PaymentLink(
      id: old.id, contactName: old.contactName, description: old.description,
      amount: old.amount, status: parsed,
      createdAt: old.createdAt, expiresAt: old.expiresAt, paymentMethod: old.paymentMethod,
    );
  }
}

final paymentService = HttpPaymentService();
