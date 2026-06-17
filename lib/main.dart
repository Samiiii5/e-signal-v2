import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'core/navigation/app_router.dart';
import 'core/services/network_service.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SessionService.init();
  await NotificationService.initialize();
  NetworkService.startMonitoring();
  runApp(const ESignalApp());
}

class ESignalApp extends StatelessWidget {
  const ESignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'e-Signal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: buildRouter(),
    );
  }
}
