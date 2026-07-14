import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:esignal/core/navigation/app_router.dart';
import 'package:esignal/core/services/session_service.dart';

/// Notification affichée dans NotificationsScreen — mappée depuis la réponse
/// de GET /api/notifications/history/{user_id} (les documents Firestore
/// /users/{userId}/notifications/{notifId} sous-jacents).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool isRead;
  final String channel;
  final String? threadId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.isRead,
    required this.channel,
    this.threadId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : <String, dynamic>{};
    final isRead = json['read'] == true || (json['status'] ?? '').toString() == 'read';
    return AppNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      sentAt: DateTime.tryParse((json['sent_at'] ?? '').toString()) ?? DateTime.now(),
      isRead: isRead,
      channel: (data['channel'] ?? '').toString(),
      threadId: data['thread_id']?.toString(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        sentAt: sentAt,
        isRead: isRead ?? this.isRead,
        channel: channel,
        threadId: threadId,
      );
}

class NotificationService {
  // URL de ton backend — à changer après déploiement sur Render
  static const String _backendUrl = 'https://e-signal-v2-backend-notifications.onrender.com';
  static const String _apiKey = 'Esignal2027!';

  /// Nombre de notifications non lues — alimente le badge sur la cloche de
  /// l'inbox. Mis à jour dès l'appel des méthodes ci-dessous (pas d'attente
  /// réseau) pour un rendu immédiat côté UI.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static CollectionReference<Map<String, dynamic>>? _notificationsCollection() {
    final userId = SessionService.userId;
    if (userId == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications');
  }

  /// GET /api/notifications/history/{user_id}
  static Future<List<AppNotification>> fetchHistory() async {
    final userId = SessionService.userId;
    if (userId == null) return [];

    final dio = Dio();
    final resp = await dio.get(
      '$_backendUrl/api/notifications/history/$userId',
      options: Options(headers: {'X-API-Key': _apiKey}),
    );

    final data = resp.data;
    final raw = (data is Map ? data['notifications'] as List? : null) ?? [];
    final items = raw
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    unreadCount.value = items.where((n) => !n.isRead).length;
    return items;
  }

  static Future<void> markAsRead(String notifId) async {
    unreadCount.value = (unreadCount.value - 1).clamp(0, 1 << 31);
    try {
      await _notificationsCollection()?.doc(notifId).update({'read': true});
    } catch (e) {
      debugPrint('=== Erreur markAsRead : $e ===');
    }
  }

  static Future<void> deleteNotification(String notifId, {required bool wasUnread}) async {
    if (wasUnread) unreadCount.value = (unreadCount.value - 1).clamp(0, 1 << 31);
    try {
      await _notificationsCollection()?.doc(notifId).delete();
    } catch (e) {
      debugPrint('=== Erreur deleteNotification : $e ===');
    }
  }

  static Future<void> markAllAsRead(List<String> notifIds) async {
    if (notifIds.isEmpty) return;
    unreadCount.value = 0;
    final col = _notificationsCollection();
    if (col == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in notifIds) {
        batch.update(col.doc(id), {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('=== Erreur markAllAsRead : $e ===');
    }
  }

  static Future<void> clearAll(List<String> notifIds) async {
    if (notifIds.isEmpty) return;
    unreadCount.value = 0;
    final col = _notificationsCollection();
    if (col == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in notifIds) {
        batch.delete(col.doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('=== Erreur clearAll : $e ===');
    }
  }

  // Appeler au démarrage dans main.dart
  static Future<void> initializeListeners() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Gérer les notifications quand l'app est ouverte
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notification reçue en foreground :');
      debugPrint('Titre : ${message.notification?.title}');
      debugPrint('Corps : ${message.notification?.body}');
    });

    // Gérer le tap sur une notification quand l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Gérer le tap sur une notification qui a lancé l'app depuis l'état terminé
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      // navigatorKey n'est attaché qu'après le premier build de MaterialApp.router
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationTap(initialMessage));
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final channel = message.data['channel'];
    final threadId = message.data['thread_id'];
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/inbox?channel=$channel&thread_id=$threadId');
  }

  // Appeler après connexion réussie
  static Future<void> registerFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      debugPrint('=============================');
      debugPrint('FCM Token: $token');
      debugPrint('=============================');
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('=== Erreur FCM Token : $e ===');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final userId = SessionService.userId;
      final organizationId = SessionService.organizationId;

      if (userId == null || organizationId == null) {
        debugPrint('=== FCM Token non envoyé : userId ou organizationId null ===');
        return;
      }

      final dio = Dio();
      await dio.post(
        '$_backendUrl/api/notifications/register-token',
        data: {
          'user_id': userId,
          'fcm_token': token,
          'platform': 'android',
          'organization_id': organizationId,
        },
      );
      debugPrint('=== FCM Token enregistré sur le backend ===');
    } catch (e) {
      debugPrint('=== Erreur enregistrement FCM Token : $e ===');
    }
  }
}