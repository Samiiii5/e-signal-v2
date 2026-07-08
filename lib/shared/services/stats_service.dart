import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';
import '../models/dashboard_model.dart';

class StatsUnauthorizedException implements Exception {
  const StatsUnauthorizedException();
}

class StatsUnavailableException implements Exception {
  const StatsUnavailableException();
}

class StatsNetworkException implements Exception {
  const StatsNetworkException();
}

class StatsService {
  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionTimeout;

  Future<DashboardData> getDashboard({String? period}) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) throw Exception('organization_id manquant');

    try {
      final params = <String, dynamic>{};
      if (period != null) params['period'] = period;

      final resp = await ApiClient.dio.get(
        '/analytics/organizations/$orgId/dashboard',
        queryParameters: params.isEmpty ? null : params,
      );

      if (resp.statusCode == 200) {
        return DashboardData.fromJson(resp.data as Map<String, dynamic>);
      } else if (resp.statusCode == 401) {
        throw const StatsUnauthorizedException();
      } else if (resp.statusCode == 503 || resp.statusCode == 502) {
        throw const StatsUnavailableException();
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const StatsNetworkException();
      rethrow;
    }
  }
}

final statsService = StatsService();
