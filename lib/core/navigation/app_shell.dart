import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/network_banner.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _tabs = [
    _TabItem(label: 'Inbox', icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
    _TabItem(label: 'Paiements', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
    _TabItem(label: 'Profil', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // Bannière réseau — hauteur animée 0 ↔ 36px
          const NetworkBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.textHint,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: AppTextStyles.navLabel,
          unselectedLabelStyle: AppTextStyles.tiny,
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    activeIcon: Icon(t.activeIcon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({required this.label, required this.icon, required this.activeIcon});
}
