import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:esignal/core/navigation/app_router.dart';
import 'package:esignal/core/services/session_service.dart';

class NotificationService {
  // URL de ton backend — à changer après déploiement sur Render
  static const String _backendUrl = 'https://e-signal-v2-backend-notifications.onrender.com';

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
      print('Notification reçue en foreground :');
      print('Titre : ${message.notification?.title}');
      print('Corps : ${message.notification?.body}');
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
      print('=============================');
      print('FCM Token: $token');
      print('=============================');
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      print('=== Erreur FCM Token : $e ===');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final userId = SessionService.userId;
      final organizationId = SessionService.organizationId;

      if (userId == null || organizationId == null) {
        print('=== FCM Token non envoyé : userId ou organizationId null ===');
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
      print('=== FCM Token enregistré sur le backend ===');
    } catch (e) {
      print('=== Erreur enregistrement FCM Token : $e ===');
    }
  }
}