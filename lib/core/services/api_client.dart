import 'package:dio/dio.dart';
import 'navigation_service.dart';
import 'session_service.dart';

/// Client HTTP centralisé.
///
/// Stratégie validateStatus → Dio ne lève JAMAIS d'exception pour les codes
/// HTTP (4xx, 5xx). Le code retour est vérifié explicitement dans chaque
/// méthode de service. Cela évite toute ambiguïté sur la propagation des
/// DioException à travers les intercepteurs async.
///
/// Les DioException résiduelles (timeout, pas de réseau…) sont toujours
/// levées par Dio et doivent être interceptées par les services.
class ApiClient {
  static const baseUrl = 'https://ws.score360.africa/api/v1.2';

  static late final Dio _dio;
  static late final Dio _refreshDio;

  static Dio get dio => _dio;

  static void init() {
    // Instance dédiée au refresh — pas d'intercepteurs pour éviter la récursion.
    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null, // accepte tout
    ));

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null, // accepte tout — pas d'exception HTTP
    ));

    // Intercepteur 1 — injecte le Bearer token dans chaque requête.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionService.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    // Intercepteur 2 — refresh silencieux sur 401.
    // Déclenché dans onResponse (pas onError) car validateStatus accepte les 4xx.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) async {
          final isRetry = response.requestOptions.extra['_retry'] == true;

          if (response.statusCode == 401 && !isRetry) {
            final refreshToken = SessionService.refreshToken;

            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final resp = await _refreshDio.post(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );
                final data = resp.data as Map<String, dynamic>;
                await SessionService.updateTokens(
                  accessToken: data['access_token'] as String? ?? '',
                  refreshToken: data['refresh_token'] as String? ?? '',
                  expiresAt: data['expires_at'] as String? ?? '',
                  refreshTokenExpiresAt:
                      data['refresh_token_expires_at'] as String? ?? '',
                );
                final opts = response.requestOptions;
                opts.extra['_retry'] = true;
                opts.headers['Authorization'] =
                    'Bearer ${SessionService.accessToken}';
                final retryResp = await _dio.fetch(opts);
                return handler.resolve(retryResp);
              } catch (_) {
                await SessionService.logout();
                NavigationService.onSessionExpired?.call();
              }
            } else {
              await SessionService.logout();
              NavigationService.onSessionExpired?.call();
            }
          }

          handler.next(response);
        },
      ),
    );
  }
}
