import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';

/// Catalogue produits et comptes intégrés — utilisés pour l'envoi de
/// carousels produits dans le chat (voir InboxService.sendCarousel).
class CatalogService {
  /// GET /api/v1.2/organizations/{organization_id}/products
  Future<List<Map<String, dynamic>>> getProducts() async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return [];

    try {
      final response = await ApiClient.dio.get('/organizations/$orgId/products');
      if (response.statusCode != 200) return [];
      final items = response.data['items'] as List? ?? [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['is_active'] == true)
          .toList();
    } on DioException {
      return [];
    }
  }

  /// GET /api/v1.2/organizations/{organization_id}/accounts
  /// Retourne l'id du compte intégré dont le channel correspond, ou null.
  Future<String?> getIntegrationAccountId(String channel) async {
    final orgId = SessionService.organizationId;
    if (orgId == null) return null;

    try {
      final response = await ApiClient.dio.get('/organizations/$orgId/accounts');
      if (response.statusCode != 200) return null;
      final items = response.data['items'] as List? ?? [];
      final accounts = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e));
      
      // ignore: avoid_print
      print('=== ACCOUNTS : $items ===');
      // ignore: avoid_print
      print('=== CHANNEL CHERCHÉ : $channel ===');

      final account = accounts.firstWhere(
        (a) => a['channel'].toString().toLowerCase() == channel.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      return account['id']?.toString();
    } on DioException {
      return null;
    }
  }
}

final catalogService = CatalogService();
