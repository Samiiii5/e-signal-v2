import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/pin/pin_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  String _initials = '?';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await PinStorage.getDisplayName();
    final initials = await PinStorage.getInitials();
    if (mounted) {
      setState(() {
        _displayName = name ?? 'Utilisateur';
        _initials = initials;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: AppTextStyles.h3),
        content: Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              backgroundColor: Colors.transparent,
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final router = GoRouter.of(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_seen');
      await PinStorage.clearPin();
      router.go('/login');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.small.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Avatar + identité ──────────────────────────────────
              _Avatar(initials: _initials),
              const SizedBox(height: 14),
              Text(_displayName, style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'Administrateur · Score360 Africa',
                style: AppTextStyles.small,
              ),

              const SizedBox(height: 32),

              // ── Sections ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Compte
                    _SectionTitle('Mon compte'),
                    const SizedBox(height: 10),
                    _MenuCard(items: [
                      _MenuItem(
                        icon: Icons.camera_alt_outlined,
                        iconBg: AppColors.greenLight,
                        iconColor: AppColors.greenDark,
                        label: 'Photo de profil',
                        onTap: () => _showSnackbar('Modification photo — bientôt disponible'),
                      ),
                      _MenuItem(
                        icon: Icons.person_outline,
                        iconBg: AppColors.greenLight,
                        iconColor: AppColors.greenDark,
                        label: 'Modifier mes informations',
                        onTap: () => _showSnackbar('Modification infos — bientôt disponible'),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Section Sécurité
                    _SectionTitle('Sécurité'),
                    const SizedBox(height: 10),
                    _MenuCard(items: [
                      _MenuItem(
                        icon: Icons.lock_outline,
                        iconBg: AppColors.purpleLight,
                        iconColor: AppColors.purpleDark,
                        label: 'Changer le mot de passe',
                        onTap: () => _showSnackbar('Changement mot de passe — bientôt disponible'),
                      ),
                      _MenuItem(
                        icon: Icons.pin_outlined,
                        iconBg: AppColors.purpleLight,
                        iconColor: AppColors.purpleDark,
                        label: 'Modifier le code PIN',
                        onTap: () async {
                          await PinStorage.clearPin();
                          if (mounted) context.go('/pin/setup');
                        },
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Section Préférences
                    _SectionTitle('Préférences'),
                    const SizedBox(height: 10),
                    _MenuCard(items: [
                      _ToggleItem(
                        icon: Icons.notifications_outlined,
                        iconBg: AppColors.greenLight,
                        iconColor: AppColors.greenDark,
                        label: 'Notifications',
                        value: _notificationsEnabled,
                        onChanged: (v) => setState(() => _notificationsEnabled = v),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Section Déconnexion
                    _MenuCard(items: [
                      _MenuItem(
                        icon: Icons.logout,
                        iconBg: const Color(0xFFFFEDED),
                        iconColor: Colors.redAccent,
                        label: 'Déconnexion',
                        labelColor: Colors.redAccent,
                        onTap: _logout,
                        showChevron: false,
                      ),
                    ]),

                    const SizedBox(height: 32),

                    // Version
                    Center(
                      child: Text(
                        'e-Signal v1.0.0 · Score360 Africa',
                        style: AppTextStyles.tiny,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.greenLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        // Petit bouton caméra
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt, size: 13, color: AppColors.white),
          ),
        ),
      ],
    );
  }
}

// ─── Titre de section ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.tiny.copyWith(
        color: AppColors.textHint,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Card de menu ─────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(
                indent: 56,
                endIndent: 0,
                height: 0,
                thickness: 0.5,
                color: AppColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Item de menu standard ────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icône dans carré arrondi
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: labelColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Item toggle ──────────────────────────────────────────────────────────────

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.green,
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: AppColors.borderLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
