import 'package:flutter/material.dart';
import 'core/navigation/app_router.dart';
import 'core/services/network_service.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
