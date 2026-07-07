import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/responsive.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: AppColors.white, shape: const StadiumBorder(), elevation: 0),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    SessionService.logout();
    router.go('/login');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.white, fontSize: 13)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = SessionService.firstName ?? '';
    final lastName  = SessionService.lastName  ?? '';
    final fullName  = '${firstName} ${lastName}'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'Non renseigné';
    final initials = _initials(firstName, lastName);

    final email       = SessionService.email?.isNotEmpty == true ? SessionService.email! : 'Non renseigné';
    final phone       = SessionService.phoneNumber?.isNotEmpty == true ? SessionService.phoneNumber! : 'Non renseigné';
    final kycLevel    = SessionService.kycLevel?.isNotEmpty == true ? SessionService.kycLevel! : 'Non renseigné';
    final status      = SessionService.status?.isNotEmpty == true ? _translateStatus(SessionService.status!) : 'Non renseigné';

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Avatar + nom
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: Responsive.w(context, 0.12).clamp(36.0, 52.0),
                          backgroundColor: AppColors.primaryLight,
                          child: Text(initials, style: TextStyle(fontSize: Responsive.w(context, 0.07).clamp(20.0, 32.0), fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 2)),
                            child: const Icon(Icons.camera_alt, size: 14, color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis, maxLines: 1),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section Informations du compte
              _Section(
                title: 'Informations du compte',
                items: [
                  _InfoItem(icon: Icons.email_outlined,    label: 'Email',        value: email),
                  _InfoItem(icon: Icons.phone_outlined,    label: 'Téléphone',    value: phone),
                  _InfoItem(icon: Icons.verified_outlined, label: 'Niveau KYC',   value: kycLevel),
                  _InfoItem(icon: Icons.info_outline,      label: 'Statut',       value: status),
                ],
              ),

              const SizedBox(height: 12),

              // Section Actions compte
              _Section(
                title: 'Gestion du compte',
                items: [
                  _MenuItem(icon: Icons.person_outline, label: 'Modifier mes informations', onTap: () => _snack('Bientôt disponible')),
                  _MenuItem(icon: Icons.lock_outline, label: 'Changer le mot de passe', onTap: () => _snack('Bientôt disponible')),
                ],
              ),

              const SizedBox(height: 12),

              // Section Canaux connectés
              _Section(
                title: 'Canaux connectés',
                child: Column(
                  children: [
                    _ChannelRow(name: 'WhatsApp Business', icon: Icons.chat_bubble, color: const Color(0xFF25D366), connected: true),
                    _ChannelRow(name: 'SMS', icon: Icons.sms, color: const Color(0xFF5C6BC0), connected: true),
                    _ChannelRow(name: 'Email', icon: Icons.email_outlined, color: const Color(0xFFEA4335), connected: true),
                    _ChannelRow(name: 'Facebook', icon: Icons.facebook, color: const Color(0xFF1877F2), connected: false),
                    _ChannelRow(name: 'Instagram', icon: Icons.camera_alt_outlined, color: const Color(0xFFE1306C), connected: false),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: () => _snack('Bientôt disponible'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Connecter un canal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Section Préférences
              _Section(
                title: 'Préférences',
                items: [
                  _ToggleItem(icon: Icons.notifications_outlined, label: 'Notifications', value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v)),
                  _MenuItem(icon: Icons.help_outline, label: 'Aide & Support', onTap: () => _snack('Bientôt disponible')),
                ],
              ),

              const SizedBox(height: 12),

              // Déconnexion
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight, width: 0.5)),
                  child: ListTile(
                    leading: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: const Color(0xFFFFEDED), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout, size: 17, color: Colors.redAccent),
                    ),
                    title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500, fontSize: 14)),
                    onTap: _logout,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('e-Signal v1.0.0 · Score360 Africa', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String firstName, String lastName) {
  final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
  final l = lastName.isNotEmpty  ? lastName[0].toUpperCase()  : '';
  return (f + l).isNotEmpty ? f + l : '?';
}

String _translateStatus(String status) {
  const map = <String, String>{
    'ACTIVE':   'Actif',
    'INVITED':  'Invité',
    'INACTIVE': 'Inactif',
    'SUSPENDED':'Suspendu',
    'PENDING':  'En attente',
  };
  return map[status.toUpperCase()] ?? status;
}

// ─── Widget info en lecture seule ─────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
      dense: true,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget>? items;
  final Widget? child;
  const _Section({required this.title, this.items, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.8)),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight, width: 0.5)),
            child: child ?? Column(children: [
              for (int i = 0; i < items!.length; i++) ...[
                items![i],
                if (i < items!.length - 1) const Divider(indent: 56, height: 0, thickness: 0.5, color: AppColors.borderLight),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      trailing: Switch(
        value: value, onChanged: onChanged,
        activeThumbColor: AppColors.white, activeTrackColor: AppColors.green,
        inactiveThumbColor: AppColors.white, inactiveTrackColor: AppColors.borderLight,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool connected;
  const _ChannelRow({required this.name, required this.icon, required this.color, required this.connected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: color),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: connected ? AppColors.statusPaidBg : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          connected ? 'Connecté' : 'En attente',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: connected ? AppColors.statusPaidText : const Color(0xFFE65100)),
        ),
      ),
    );
  }
}
