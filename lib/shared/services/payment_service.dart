import 'package:dio/dio.dart';
import '../mock/payments_mock.dart';
import '../models/payment_link.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';

export '../models/payment_link.dart';

class PaymentUnauthorizedException implements Exception {}
class PaymentNetworkException implements Exception {}
class PaymentNotFoundException implements Exception {}

/// Réponse serveur inexploitable. Aucune donnée de démonstration n'est
/// substituée : l'écran doit afficher une erreur explicite plutôt que de faire
/// croire à des transactions réelles.
class PaymentServerException implements Exception {
  final int statusCode;
  const PaymentServerException(this.statusCode);
}

abstract class PaymentService {
  /// GET /api/v1.2/payment-links/organizations/{org_id}
  Future<List<PaymentLink>> getPaymentLinks({
    String? status,
    String? paymentStatus,
    String? provider,
    int limit = 50,
    int offset = 0,
  });

  /// POST /api/v1.2/payment-links/organizations/{org_id}/product
  Future<PaymentLink> createPaymentLink({
    required String catalogItemId,
    String? provider,
    int expiresInHours = 24,
    String? customerPhone,
    String? customerName,
    String? threadId,
  });

  /// GET /api/v1.2/payment-links/organizations/{org_id}/{payment_link_id}
  Future<PaymentLink> getPaymentLinkDetail(String paymentLinkId);

  /// GET /api/v1.2/payment-links/organizations/{org_id}/summary
  Future<Map<String, dynamic>> getPaymentSummary({
    String? startDate,
    String? endDate,
  });

  /// POST /api/v1.2/payment-links/organizations/{org_id}/{payment_link_id}/cancel
  Future<void> cancelPaymentLink(String paymentLinkId);
}

class HttpPaymentService implements PaymentService {
  String get _orgId => SessionService.organizationId ?? '';
  String get _base => '/payment-links/organizations/$_orgId';

  List<PaymentLink> _parseList(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map && data['items'] is List) {
      items = data['items'] as List;
    } else if (data is Map && data['data'] is List) {
      items = data['data'] as List;
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentLink.fromJson)
        .toList();
  }

  PaymentLink _parseSingle(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) return PaymentLink.fromJson(data['data'] as Map<String, dynamic>);
      return PaymentLink.fromJson(data);
    }
    throw FormatException('Unexpected response format');
  }

  @override
  Future<List<PaymentLink>> getPaymentLinks({
    String? status,
    String? paymentStatus,
    String? provider,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'offset': offset};
      if (status != null) params['status'] = status;
      if (paymentStatus != null) params['payment_status'] = paymentStatus;
      if (provider != null) params['provider'] = provider;

      final resp = await ApiClient.dio.get(_base, queryParameters: params);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      if (resp.statusCode != 200) {
        throw PaymentServerException(resp.statusCode ?? 0);
      }
      return _parseList(resp.data);
    } on PaymentUnauthorizedException {
      rethrow;
    } on PaymentServerException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<PaymentLink> createPaymentLink({
    required String catalogItemId,
    String? provider,
    int expiresInHours = 24,
    String? customerPhone,
    String? customerName,
    String? threadId,
  }) async {
    try {
      final body = <String, dynamic>{
        'catalog_item_id': catalogItemId,
        'expires_in_hours': expiresInHours,
      };
      if (provider != null) body['provider'] = provider;
      if (customerPhone != null && customerPhone.isNotEmpty) body['customer_phone'] = customerPhone;
      if (customerName != null && customerName.isNotEmpty) body['customer_name'] = customerName;
      if (threadId != null) body['thread_id'] = threadId;

      final resp = await ApiClient.dio.post('$_base/product', data: body);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      return _parseSingle(resp.data);
    } on PaymentUnauthorizedException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<PaymentLink> getPaymentLinkDetail(String paymentLinkId) async {
    try {
      final resp = await ApiClient.dio.get('$_base/$paymentLinkId');
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      if (resp.statusCode == 404) throw PaymentNotFoundException();
      return _parseSingle(resp.data);
    } on PaymentUnauthorizedException {
      rethrow;
    } on PaymentNotFoundException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<Map<String, dynamic>> getPaymentSummary({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final resp = await ApiClient.dio.get('$_base/summary', queryParameters: params);
      if (resp.statusCode == 401) throw PaymentUnauthorizedException();
      final data = resp.data;
      return data is Map<String, dynamic> ? data : {};
    } on PaymentUnauthorizedException {
      rethrow;
    } on DioException {
      throw PaymentNetworkException();
    }
  }

  @override
  Future<void> cancelPaymentLink(String paymentLinkId) async {
    try {
      final resp = await ApiClient.dio.post('$_base/$paymentLinkId/cancel');
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
}

class MockPaymentService implements PaymentService {
  final _links = List<PaymentLink>.from(mockPaymentLinks);

  @override
  Future<List<PaymentLink>> getPaymentLinks({
    String? status,
    String? paymentStatus,
    String? provider,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var result = List<PaymentLink>.from(_links);
    if (status != null) result = result.where((l) => l.status == status).toList();
    if (provider != null) result = result.where((l) => l.provider == provider).toList();
    return result;
  }

  @override
  Future<PaymentLink> createPaymentLink({
    required String catalogItemId,
    String? provider,
    int expiresInHours = 24,
    String? customerPhone,
    String? customerName,
    String? threadId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final link = PaymentLink(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      checkoutUrl: 'https://pay.esignal.ci/l/pay_${DateTime.now().millisecondsSinceEpoch}',
      provider: provider ?? 'wave',
      amount: '0',
      currency: 'XOF',
      description: customerName ?? 'Nouveau lien',
      expiresAt: DateTime.now().add(Duration(hours: expiresInHours)).toIso8601String(),
      status: 'created',
      catalogItemId: catalogItemId,
      threadId: threadId,
    );
    _links.add(link);
    return link;
  }

  @override
  Future<PaymentLink> getPaymentLinkDetail(String paymentLinkId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _links.firstWhere((l) => l.id == paymentLinkId, orElse: () => _links.first);
  }

  @override
  Future<Map<String, dynamic>> getPaymentSummary({String? startDate, String? endDate}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'total': _links.length, 'paid': _links.where((l) => l.status == 'paid').length};
  }

  @override
  Future<void> cancelPaymentLink(String paymentLinkId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _links.indexWhere((l) => l.id == paymentLinkId);
    if (index == -1) return;
    final old = _links[index];
    _links[index] = PaymentLink(
      id: old.id, checkoutUrl: old.checkoutUrl, provider: old.provider,
      amount: old.amount, currency: old.currency, description: old.description,
      expiresAt: old.expiresAt, status: 'expired',
      catalogItemId: old.catalogItemId, threadId: old.threadId,
    );
  }
}

final paymentService = HttpPaymentService();
