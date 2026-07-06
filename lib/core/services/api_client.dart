import 'package:dio/dio.dart';
import 'navigation_service.dart';
import 'session_service.dart';

/// Client HTTP centralisé.
/// - Injecte automatiquement `Authorization: Bearer` sur chaque requête.
/// - Gère le refresh silencieux sur 401 ; déconnecte si le refresh échoue.
class ApiClient {
  static const baseUrl = 'https://ws.score360.africa/api/v1.2';

  static late final Dio _dio;
  static late final Dio _refreshDio; // Pas d'intercepteurs → évite la récursion.

  static Dio get dio => _dio;

  static void init() {
    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionService.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isRetry = error.requestOptions.extra['_retry'] == true;
          if (error.response?.statusCode == 401 && !isRetry) {
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
                // Rejoue la requête originale avec le nouveau token.
                final opts = error.requestOptions;
                opts.extra['_retry'] = true;
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
          handler.next(error);
        },
      ),
    );
  }
}
