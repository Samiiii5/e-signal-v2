import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'session_service.dart';

class NotificationService {
  // URL de ton backend — à changer après déploiement sur Render
  static const String _backendUrl = 'http://127.0.0.1:8000';

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Demander la permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Récupérer le FCM token
    final token = await messaging.getToken();
    print('=============================');
    print('FCM Token: $token');
    print('=============================');

    // Envoyer le token au backend
    if (token != null) {
      await _registerToken(token);
    }

    // Gérer les notifications quand l'app est ouverte
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification reçue en foreground :');
      print('Titre : ${message.notification?.title}');
      print('Corps : ${message.notification?.body}');
    });

    // Gérer le tap sur une notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tappée :');
      print('Titre : ${message.notification?.title}');
    });
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
          'organization_id': organizationId,
        },
      );
      print('=== FCM Token enregistré sur le backend ===');
    } catch (e) {
      print('=== Erreur enregistrement FCM Token : $e ===');
    }
  }
}