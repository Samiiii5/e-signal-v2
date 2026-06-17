import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Gestionnaire de background messages — doit être une fonction top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('[FCM Background] ${message.notification?.title} — ${message.notification?.body}', name: 'FCM');
}

class NotificationService {
  NotificationService._();
  static final _messaging = FirebaseMessaging.instance;

  /// Initialise FCM : permissions, token, handlers foreground + background
  static Future<void> initialize() async {
    // Handler background (doit être enregistré tôt)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Demande la permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    dev.log('[FCM] Permission: ${settings.authorizationStatus}', name: 'FCM');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Récupère et affiche le token FCM
    final token = await _messaging.getToken();
    dev.log('[FCM] Token: $token', name: 'FCM');
    // ignore: avoid_print
    print('=============================');
    // ignore: avoid_print
    print('FCM Token: $token');
    // ignore: avoid_print
    print('=============================');

    // Rafraîchissement du token
    _messaging.onTokenRefresh.listen((newToken) {
      dev.log('[FCM] Token rafraîchi: $newToken', name: 'FCM');
    });

    // Notifications en foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap sur notification quand l'app est en background (mais pas terminée)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Notification ayant lancé l'app depuis l'état terminé
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onMessageOpenedApp(initial);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    dev.log('[FCM Foreground] ${n?.title} — ${n?.body}', name: 'FCM');
    // TODO: afficher une in-app notification (SnackBar ou overlay)
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    dev.log('[FCM Tap] ${message.notification?.title} — data: ${message.data}', name: 'FCM');
    // TODO: naviguer vers l'écran concerné selon message.data
  }
}
