import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  PaymentStatus? _filter;

  @override
  void initState() {
    super.initState();
    _future = paymentService.getPaymentLinks();
  }

  void _refresh() => setState(() => _future = paymentService.getPaymentLinks());

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<PaymentLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateLinkSheet(),
    );
    if (created != null) _refresh();
  }

  void _openExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSheet(
        onCsv: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(_snack('Export CSV en cours...'));
        },
        onExcel: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(_snack('Export Excel en cours...'));
        },
      ),
    );
  }

  SnackBar _snack(String msg) => SnackBar(
    content: Text(msg, style: const TextStyle(color: AppColors.white)),
    backgroundColor: AppColors.green,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 2),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Paiements', style: AppTextStyles.h1, overflow: TextOverflow.ellipsis),
                  ),
                  // Bouton Exporter — icône + texte compact
                  GestureDetector(
                    onTap: _openExportSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.download_outlined, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 4),
                          Text('Exporter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton Nouveau — compact
                  GestureDetector(
                    onTap: _openCreateSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add, size: 14, color: AppColors.white),
                          SizedBox(width: 4),
                          Text('Nouveau', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Chips filtres ─────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _FilterPill(label: 'Tous', active: _filter == null, onTap: () => setState(() => _filter = null)),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Payés', active: _filter == PaymentStatus.paid, onTap: () => setState(() => _filter = PaymentStatus.paid), color: AppColors.statusPaidText),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'En attente', active: _filter == PaymentStatus.pending, onTap: () => setState(() => _filter = PaymentStatus.pending), color: AppColors.statusPendingText),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Expirés', active: _filter == PaymentStatus.expired, onTap: () => setState(() => _filter = PaymentStatus.expired), color: AppColors.textSecondary),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Liste ────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<PaymentLink>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.green));
                  }
                  var links = snap.data ?? [];
                  if (_filter != null) links = links.where((l) => l.status == _filter).toList();
                  if (links.isEmpty) return _EmptyState(onTap: _openCreateSheet);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => ctx.push('/payment-detail', extra: links[i]),
                      child: _PaymentItem(link: links[i]),
                    ),
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

// ── Chip filtre ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;
  const _FilterPill({required this.label, required this.active, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.white : AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Item de liste ─────────────────────────────────────────────────────────────

class _PaymentItem extends StatelessWidget {
  final PaymentLink link;
  const _PaymentItem({required this.link});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabel) = _statusStyle(link.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_fmt(link.amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: statusText)),
                  const Text(' FCFA', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
                ]),
                const SizedBox(height: 4),
                Text('Client : ${link.contactName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(_fmtDate(link.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusText)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
        ],
      ),
    );
  }

  (Color, Color, String) _statusStyle(PaymentStatus s) => switch (s) {
    PaymentStatus.paid    => (AppColors.statusPaidBg,    AppColors.statusPaidText,    'Payé'),
    PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente'),
    PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
    PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré'),
  };

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

// ── Bottom sheet Export ───────────────────────────────────────────────────────

class _ExportSheet extends StatelessWidget {
  final VoidCallback onCsv;
  final VoidCallback onExcel;
  const _ExportSheet({required this.onCsv, required this.onExcel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Exporter les transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 24),
          _ExportTile(
            icon: Icons.table_chart_outlined,
            label: 'Exporter en CSV',
            subtitle: 'Compatible Excel, Google Sheets',
            color: AppColors.green,
            onTap: onCsv,
          ),
          const SizedBox(height: 12),
          _ExportTile(
            icon: Icons.grid_on_outlined,
            label: 'Exporter en Excel',
            subtitle: 'Fichier .xlsx natif Microsoft Excel',
            color: AppColors.primary,
            onTap: onExcel,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExportTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ]),
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
          const Text('Aucun lien de paiement', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Créer mon premier lien'),
          ),
        ],
      ),
    );
  }
}
