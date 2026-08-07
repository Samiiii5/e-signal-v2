import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:esignal/core/navigation/app_router.dart';
import 'package:esignal/core/services/session_service.dart';
import 'package:esignal/shared/models/notification_model.dart';

export 'package:esignal/shared/models/notification_model.dart';

class NotificationService {
  // URL de ton backend — à changer après déploiement sur Render
  static const String _backendUrl = 'https://e-signal-v2-backend-notifications.onrender.com';

  /// Clé d'API du backend notifications.
  ///
  /// En production, la valeur DOIT être injectée à la compilation :
  ///   `flutter build apk --dart-define=NOTIFICATION_API_KEY=LA_CLE`
  ///   `flutter run --dart-define=NOTIFICATION_API_KEY=LA_CLE`
  ///
  /// La valeur par défaut n'est qu'un repli de développement : toute clé écrite
  /// en dur dans le code source est compilée dans l'APK et reste extractible.
  static const String _apiKey = String.fromEnvironment(
    'NOTIFICATION_API_KEY',
    defaultValue: 'Esignal2027!',
  );

  /// Client HTTP dédié au backend notifications — distinct d'[ApiClient] :
  /// URL de base et authentification différentes. Les délais d'attente évitent
  /// qu'un démarrage à froid de Render bloque l'application indéfiniment.
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  /// Nombre de notifications non lues — alimente le badge sur la cloche de
  /// l'inbox. Mis à jour dès l'appel des méthodes ci-dessous (pas d'attente
  /// réseau) pour un rendu immédiat côté UI.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Incrémenté à chaque notification FCM reçue en foreground — écouté par
  /// NotificationsScreen pour se rafraîchir automatiquement.
  static final ValueNotifier<int> newNotificationTick = ValueNotifier<int>(0);

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsReady = false;

  static Future<void> _initLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Notifications e-Signal',
        description: 'Notifications des messages et événements e-Signal',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      _localNotificationsReady = true;
    } catch (e) {
      debugPrint('=== Erreur init notifications locales : $e ===');
    }
  }

  /// Notification locale (ex: new_comment WebSocket) — distincte du push FCM.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (!_localNotificationsReady) return;
    const androidDetails = AndroidNotificationDetails(
      'esignal_events',
      'Événements e-Signal',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('=== Erreur notification locale : $e ===');
    }
  }

  static CollectionReference<Map<String, dynamic>>? _notificationsCollection() {
    final userId = SessionService.userId;
    if (userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  /// GET /api/notifications/history/{user_id}
  static Future<List<AppNotification>> fetchHistory() async {
    final userId = SessionService.userId;
    if (userId == null) return [];

    final resp = await _dio.get(
      '/api/notifications/history/$userId',
      options: Options(headers: {'X-API-Key': _apiKey}),
    );
    final data = resp.data;
    final raw = (data is Map ? data['notifications'] as List? : null) ?? [];
    final items =
        raw
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    unreadCount.value = items.where((n) => !n.isRead).length;
    return items;
  }

  static Future<void> markAsRead(AppNotification n) async {
    if (n.isRead) return;
    unreadCount.value = (unreadCount.value - 1).clamp(0, 1 << 31);
    try {
      await _notificationsCollection()?.doc(n.id).update({'read': true});
    } catch (e) {
      debugPrint('=== Erreur markAsRead : $e ===');
    }
  }

  static Future<void> deleteNotification(AppNotification n) async {
    if (!n.isRead) {
      unreadCount.value = (unreadCount.value - 1).clamp(0, 1 << 31);
    }
    try {
      await _notificationsCollection()?.doc(n.id).delete();
    } catch (e) {
      debugPrint('=== Erreur deleteNotification : $e ===');
    }
  }

  static Future<void> markAllAsRead(List<AppNotification> items) async {
    final unreadIds = items.where((n) => !n.isRead).map((n) => n.id).toList();
    unreadCount.value = 0;
    if (unreadIds.isEmpty) return;
    final col = _notificationsCollection();
    if (col == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in unreadIds) {
        batch.update(col.doc(id), {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('=== Erreur markAllAsRead : $e ===');
    }
  }

  static Future<void> clearAll(List<AppNotification> items) async {
    final ids = items.map((n) => n.id).toList();
    unreadCount.value = 0;
    if (ids.isEmpty) return;
    final col = _notificationsCollection();
    if (col == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids) {
        batch.delete(col.doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('=== Erreur clearAll : $e ===');
    }
  }

  // Appeler au démarrage dans main.dart
  static Future<void> initializeListeners() async {
    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Gérer les notifications quand l'app est ouverte
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notification reçue en foreground :');
      debugPrint('Titre : ${message.notification?.title}');
      debugPrint('Corps : ${message.notification?.body}');
      // Signale à NotificationsScreen (si affiché) de se rafraîchir.
      newNotificationTick.value++;
      // Rafraîchir l'historique et le badge de la cloche
      fetchHistory().catchError((e) {
        debugPrint('Error fetching notification history: $e');
        return <AppNotification>[];
      });
    });

    // Gérer le tap sur une notification quand l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Gérer le tap sur une notification qui a lancé l'app depuis l'état terminé
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      // navigatorKey n'est attaché qu'après le premier build de MaterialApp.router
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationTap(initialMessage),
      );
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
      debugPrint(
        '=== FCM Token obtenu : ${token != null ? "oui (${token.length} car.)" : "non"} ===',
      );
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
        debugPrint(
          '=== FCM Token non envoyé : userId ou organizationId null ===',
        );
        return;
      }

      await _dio.post(
        '/api/notifications/register-token',
        data: {
          'user_id': userId,
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'organization_id': organizationId,
        },
      );
      debugPrint('=== FCM Token enregistré sur le backend ===');
    } catch (e) {
      debugPrint('=== Erreur enregistrement FCM Token : $e ===');
    }
  }
}
