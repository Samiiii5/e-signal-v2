import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/navigation/app_router.dart';
import 'core/services/api_client.dart';
import 'core/services/network_service.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/notification_service.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await Firebase.initializeApp();
  await SessionService.init();
  ApiClient.init();
  NetworkService.startMonitoring();
  await NotificationService.initializeListeners();
  if (SessionService.isLoggedIn) {
    NotificationService.registerFCMToken();
  }
  
  FlutterNativeSplash.remove();
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