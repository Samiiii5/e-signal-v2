import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../widgets/network_banner.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      _showQuickActions(context);
      return;
    }
    final adjustedIndex = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      adjustedIndex,
      initialLocation: adjustedIndex == navigationShell.currentIndex,
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Action rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.chat_bubble_outline,
              label: 'Nouvelle conversation',
              color: AppColors.green,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).go('/inbox');
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.credit_card_outlined,
              label: 'Nouveau lien de paiement',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                // push et non go : go remplace la pile, le retour depuis
                // l'écran de création n'aurait alors plus rien à dépiler.
                GoRouter.of(context).push('/create-link');
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.bar_chart,
              label: 'Voir les stats',
              color: const Color(0xFF0EA5E9),
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).go('/stats');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Map shell index (0-3) to display index (0,1,3,4) — slot 2 is the + button
    final displayIndex = navigationShell.currentIndex >= 2
        ? navigationShell.currentIndex + 1
        : navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _WhatsAppNavBar(
        currentIndex: displayIndex,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}

// ── Custom WhatsApp-style bottom nav bar ─────────────────────────────────────

class _WhatsAppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _WhatsAppNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(
      label: 'Inbox',
      iconOff: Icons.chat_bubble_outline,
      iconOn: Icons.chat_bubble,
    ),
    _NavItem(
      label: 'Stats',
      iconOff: Icons.bar_chart_outlined,
      iconOn: Icons.bar_chart,
    ),
    _NavItem(label: '', iconOff: Icons.add, iconOn: Icons.add), // + button
    _NavItem(
      label: 'Paiements',
      iconOff: Icons.credit_card_outlined,
      iconOn: Icons.credit_card,
    ),
    _NavItem(
      label: 'Profil',
      iconOff: Icons.person_outline,
      iconOn: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 65 + bottom,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE8E9EC), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = i == currentIndex;
            if (i == 2) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? item.iconOn : item.iconOff,
                      size: 26,
                      color: active ? AppColors.green : AppColors.textHint,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? AppColors.green : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData iconOff;
  final IconData iconOn;
  const _NavItem({
    required this.label,
    required this.iconOff,
    required this.iconOn,
  });
}

// ── Quick action tile ─────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
