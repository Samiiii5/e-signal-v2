import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inbox', style: AppTextStyles.h2)),
      body: const Center(child: Text('Inbox — à venir')),
    );
  }
}
