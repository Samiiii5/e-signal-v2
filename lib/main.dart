import 'package:flutter/material.dart';
import 'core/navigation/app_router.dart';
import 'core/services/api_client.dart';
import 'core/services/network_service.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.init();
  ApiClient.init();
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
