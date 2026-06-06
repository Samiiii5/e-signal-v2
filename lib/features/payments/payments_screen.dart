import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paiements', style: AppTextStyles.h2)),
      body: const Center(child: Text('Paiements — à venir')),
    );
  }
}
