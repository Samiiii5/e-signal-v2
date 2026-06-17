import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/messages_mock.dart' show PaymentStatus;
import '../../shared/mock/payments_mock.dart';
import '../../shared/services/payment_service.dart';
import 'create_link_sheet.dart';
import 'transaction_detail_screen.dart';

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

  Future<void> _openExportSheet() async {
    final links = await _future;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSheet(links: links),
    );
  }

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
                  OutlinedButton.icon(
                    onPressed: _openExportSheet,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exporter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
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
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(link: links[i]),
                      )),
                      child: _PaymentCard(link: links[i]),
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

// ── Carte d'un lien de paiement ───────────────────────────────────────────────

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
            _ProductIcon(description: link.description),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  Text(
                    link.description,
                    style: AppTextStyles.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

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

// ── Export Sheet ──────────────────────────────────────────────────────────────

class _ExportSheet extends StatefulWidget {
  final List<PaymentLink> links;
  const _ExportSheet({required this.links});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _loading = false;

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _statusLabel(PaymentStatus s) => switch (s) {
    PaymentStatus.paid    => 'Payé',
    PaymentStatus.pending => 'En attente',
    PaymentStatus.created => 'Créé',
    PaymentStatus.expired => 'Expiré',
  };

  Future<void> _exportCsv() async {
    setState(() => _loading = true);
    try {
      final buf = StringBuffer();
      buf.writeln('Référence,Client,Description,Montant,Statut,Canal,Créé le,Expire le');
      for (final l in widget.links) {
        buf.writeln('"${l.id}","${l.contactName}","${l.description}",${l.amount},"${_statusLabel(l.status)}","${l.paymentMethod.label}","${_formatDate(l.createdAt)}","${_formatDate(l.expiresAt)}"');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/transactions_esignal.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'Export transactions e-Signal');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _loading = true);
    try {
      final xcel = Excel.createExcel();
      final sheet = xcel['Transactions'];

      sheet.appendRow([
        TextCellValue('Référence'),
        TextCellValue('Client'),
        TextCellValue('Description'),
        TextCellValue('Montant (FCFA)'),
        TextCellValue('Statut'),
        TextCellValue('Canal'),
        TextCellValue('Créé le'),
        TextCellValue('Expire le'),
      ]);

      for (final l in widget.links) {
        sheet.appendRow([
          TextCellValue(l.id),
          TextCellValue(l.contactName),
          TextCellValue(l.description),
          IntCellValue(l.amount),
          TextCellValue(_statusLabel(l.status)),
          TextCellValue(l.paymentMethod.label),
          TextCellValue(_formatDate(l.createdAt)),
          TextCellValue(_formatDate(l.expiresAt)),
        ]);
      }

      final bytes = xcel.encode();
      if (bytes == null) throw Exception('Erreur encodage Excel');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/transactions_esignal.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'Export transactions e-Signal');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Exporter les transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('${widget.links.length} transaction(s)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: AppColors.green),
            )
          else
            Column(children: [
              _ExportOption(
                icon: Icons.table_chart_outlined,
                label: 'Exporter en CSV',
                subtitle: 'Compatible Excel, Google Sheets',
                color: AppColors.green,
                onTap: _exportCsv,
              ),
              const SizedBox(height: 12),
              _ExportOption(
                icon: Icons.grid_on_outlined,
                label: 'Exporter en Excel',
                subtitle: 'Fichier .xlsx natif Microsoft Excel',
                color: AppColors.primary,
                onTap: _exportExcel,
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
            ]),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExportOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
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
