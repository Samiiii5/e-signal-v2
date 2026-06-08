import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
  PaymentStatus? _filter; // null = Tous

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Paiements', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _openCreateSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nouveau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filter chips
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

            // List
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
                    itemBuilder: (_, i) => _PaymentItem(link: links[i]),
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
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.white : AppColors.textSecondary)),
      ),
    );
  }
}

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
                  Text(_formatAmount(link.amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: statusText)),
                  const Text(' FCFA', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
                ]),
                const SizedBox(height: 4),
                Text('Client : ${link.contactName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(_formatDate(link.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusText)),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _statusStyle(PaymentStatus s) => switch (s) {
    PaymentStatus.paid => (AppColors.statusPaidBg, AppColors.statusPaidText, 'Payé'),
    PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente'),
    PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
    PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré'),
  };

  String _formatAmount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white, shape: const StadiumBorder(), elevation: 0),
            child: const Text('Créer mon premier lien'),
          ),
        ],
      ),
    );
  }
}
