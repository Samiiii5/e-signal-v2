import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      final response = await ApiClient.dio.get(
        '/organizations/$orgId/products',
      );
      if (response.statusCode != 200) return [];
      final items = response.data['items'] as List? ?? [];
      final products = items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['is_active'] == true)
          .toList();

      // Debug: afficher les produits pour vérifier les prix
      for (var p in products) {
        debugPrint(
          '=== Produit: ${p['name']}, base_price: ${p['base_price']}, price: ${p['price']} ===',
        );
      }

      return products;
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
      final response = await ApiClient.dio.get(
        '/organizations/$orgId/accounts',
      );
      if (response.statusCode != 200) return null;
      final items = response.data['items'] as List? ?? [];
      final accounts = items.whereType<Map>().map(
        (e) => Map<String, dynamic>.from(e),
      );

      // ignore: avoid_print
      print('=== ACCOUNTS : $items ===');
      // ignore: avoid_print
      print('=== CHANNEL CHERCHÉ : $channel ===');

      // Chercher un compte qui correspond au channel
      // Pour messenger/whatsapp, on cherche un compte Facebook/Meta
      String? accountId;
      for (final account in accounts) {
        final displayName =
            account['display_name']?.toString().toLowerCase() ?? '';

        // Messenger correspond aux comptes Facebook
        if (channel.toLowerCase() == 'messenger' &&
            (displayName.contains('facebook') ||
                displayName.contains('meta'))) {
          accountId = account['account_id']?.toString();
          break;
        }
        // WhatsApp correspond aux comptes WhatsApp
        if (channel.toLowerCase() == 'whatsapp' &&
            (displayName.contains('whatsapp') ||
                displayName.contains('meta'))) {
          accountId = account['account_id']?.toString();
          break;
        }
        // Fallback: si le channel correspond au display_name
        if (displayName.contains(channel.toLowerCase())) {
          accountId = account['account_id']?.toString();
          break;
        }
      }

      // ignore: avoid_print
      print('=== ACCOUNT ID TROUVÉ : $accountId ===');
      return accountId;
    } on DioException {
      return null;
    }
  }
}

final catalogService = CatalogService();
