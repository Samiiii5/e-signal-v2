import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ESignalApp());
}

class ESignalApp extends StatelessWidget {
  const ESignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-Signal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Text('e-Signal'),
        ),
      ),
    );
  }
}
