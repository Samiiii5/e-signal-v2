import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil', style: AppTextStyles.h2)),
      body: const Center(child: Text('Profil — à venir')),
    );
  }
}
