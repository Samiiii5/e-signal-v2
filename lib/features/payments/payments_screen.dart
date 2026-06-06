import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/messages_mock.dart' show PaymentStatus;
import '../../shared/mock/payments_mock.dart';
import '../../shared/services/payment_service.dart';
import 'create_link_sheet.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<PaymentLink>> _future;

  @override
  void initState() {
    super.initState();
    _future = paymentService.getPaymentLinks();
  }

  void _refresh() => setState(() {
        _future = paymentService.getPaymentLinks();
      });

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<PaymentLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateLinkSheet(),
    );
    if (created != null) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text('Paiements', style: AppTextStyles.h1),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _openCreateSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nouveau lien',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Liste ────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<PaymentLink>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    );
                  }
                  final links = snap.data ?? [];
                  if (links.isEmpty) {
                    return _EmptyState(onTap: _openCreateSheet);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _PaymentCard(link: links[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte d'un lien de paiement ─────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final PaymentLink link;
  const _PaymentCard({required this.link});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabel) = _statusStyle(link.status);

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône produit sur fond coloré pâle
            _ProductIcon(description: link.description),

            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom contact + badge statut
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          link.contactName,
                          style: AppTextStyles.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(bg: statusBg, textColor: statusText, label: statusLabel),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Description
                  Text(
                    link.description,
                    style: AppTextStyles.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Montant + méthode + date
                  Row(
                    children: [
                      Text(
                        _formatAmount(link.amount),
                        style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      _MethodPill(method: link.paymentMethod),
                      const Spacer(),
                      Text(
                        _formatDate(link.createdAt),
                        style: AppTextStyles.tiny,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String) _statusStyle(PaymentStatus s) {
    return switch (s) {
      PaymentStatus.paid    => (AppColors.statusPaidBg,    AppColors.statusPaidText,    'Payé'),
      PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente'),
      PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
      PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré'),
    };
  }

  String _formatAmount(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Icône produit ─────────────────────────────────────────────────────────────

class _ProductIcon extends StatelessWidget {
  final String description;
  const _ProductIcon({required this.description});

  static const _icons = {
    'sac': ('👜', Color(0xFFFFF3E0)),
    'robe': ('👗', Color(0xFFFCE4EC)),
    'chaussures': ('👟', Color(0xFFE8EAF6)),
    'pagne': ('🧵', Color(0xFFE0F7FA)),
    'bracelet': ('📿', Color(0xFFF3E5F5)),
    'frais': ('🚚', Color(0xFFE8F5E9)),
    'devis': ('📋', Color(0xFFFFF8E1)),
    'duo': ('🎁', Color(0xFFFFEBEE)),
  };

  @override
  Widget build(BuildContext context) {
    final desc = description.toLowerCase();
    String emoji = '💳';
    Color bg = AppColors.backgroundPage;

    for (final entry in _icons.entries) {
      if (desc.contains(entry.key)) {
        emoji = entry.value.$1;
        bg = entry.value.$2;
        break;
      }
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}

// ── Badge statut ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final Color bg;
  final Color textColor;
  final String label;
  const _StatusBadge({required this.bg, required this.textColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ── Pill méthode de paiement ──────────────────────────────────────────────────

class _MethodPill extends StatelessWidget {
  final PaymentMethod method;
  const _MethodPill({required this.method});

  @override
  Widget build(BuildContext context) {
    final isWave = method == PaymentMethod.wave;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isWave
            ? const Color(0xFFE3F0FF)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isWave ? const Color(0xFF1565C0) : const Color(0xFFE65100),
        ),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Text('Aucun lien de paiement', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            child: const Text('Créer mon premier lien'),
          ),
        ],
      ),
    );
  }
}
