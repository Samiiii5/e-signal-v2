import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';

class CommentsUnauthorizedException implements Exception {
  const CommentsUnauthorizedException();
}

class CommentsNetworkException implements Exception {
  const CommentsNetworkException();
}

class CommentsUnavailableException implements Exception {
  const CommentsUnavailableException();
}

class CommentsServerException implements Exception {
  final int statusCode;
  const CommentsServerException(this.statusCode);
}

class CommentsService {
  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionTimeout;

  /// GET /api/v1.2/comments/organizations/{org_id}/posts
  Future<List<Map<String, dynamic>>> getPosts({
    String? channel,
    int limit = 20,
    String? cursor,
  }) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return [];

    try {
      final resp = await ApiClient.dio.get(
        '/comments/organizations/$orgId/posts',
        queryParameters: {
          if (channel != null) 'channel': channel,
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        final raw = (data is Map ? data['items'] ?? data['data'] ?? [] : data) as List? ?? [];
        return List<Map<String, dynamic>>.from(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      } else if (resp.statusCode == 401) {
        throw const CommentsUnauthorizedException();
      } else if (resp.statusCode == 502 || resp.statusCode == 503) {
        throw const CommentsUnavailableException();
      }
      return [];
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const CommentsNetworkException();
      return [];
    }
  }

  /// GET /api/v1.2/comments/organizations/{org_id}
  Future<List<Map<String, dynamic>>> getComments({
    String? postId,
    String? channel,
    String? status,
    int limit = 30,
    String? cursor,
  }) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return [];

    try {
      final resp = await ApiClient.dio.get(
        '/comments/organizations/$orgId',
        queryParameters: {
          if (postId != null) 'post_id': postId,
          if (channel != null) 'channel': channel,
          if (status != null) 'status': status,
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        final raw = (data is Map ? data['items'] ?? data['data'] ?? [] : data) as List? ?? [];
        return List<Map<String, dynamic>>.from(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      } else if (resp.statusCode == 401) {
        throw const CommentsUnauthorizedException();
      } else if (resp.statusCode == 502 || resp.statusCode == 503) {
        throw const CommentsUnavailableException();
      }
      return [];
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const CommentsNetworkException();
      return [];
    }
  }

  /// POST /api/v1.2/comments/{comment_id}/reply
  Future<void> replyToComment({
    required String commentId,
    required String message,
    required String provider,
  }) async {
    // ApiClient accepte tous les codes HTTP (validateStatus) — sans cette
    // vérification, un 401/422/500 remonterait comme un succès.
    final resp = await ApiClient.dio.post(
      '/comments/$commentId/reply',
      data: {'message': message, 'provider': provider},
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw CommentsServerException(resp.statusCode ?? 0);
    }
  }

  /// POST /api/v1.2/comments/{comment_id}/like
  Future<void> likeComment({
    required String commentId,
    required String provider,
  }) async {
    final resp = await ApiClient.dio.post(
      '/comments/$commentId/like',
      queryParameters: {'provider': provider},
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw CommentsServerException(resp.statusCode ?? 0);
    }
  }

  /// PATCH /api/v1.2/comments/{comment_id}/status
  Future<void> updateCommentStatus({
    required String commentId,
    required String status,
  }) async {
    final resp = await ApiClient.dio.patch(
      '/comments/$commentId/status',
      data: {'status': status},
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw CommentsServerException(resp.statusCode ?? 0);
    }
  }
}

final commentsService = CommentsService();
