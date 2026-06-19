import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/messages_mock.dart' show PaymentStatus;
import '../../shared/mock/payments_mock.dart';

class TransactionDetailScreen extends StatelessWidget {
  final PaymentLink link;
  const TransactionDetailScreen({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabel, statusIcon) = _statusMeta(link.status);

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Détail du paiement',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Carte statut ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(statusIcon, size: 40, color: statusText),
                  const SizedBox(height: 12),
                  Text(
                    statusLabel,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: statusText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_fmt(link.amount)} FCFA',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: statusText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section Informations ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Text('Informations', style: AppTextStyles.label),
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  _InfoRow(label: 'Référence', value: link.id.toUpperCase()),
                  _InfoRow(label: 'Client', value: link.contactName),
                  _InfoRow(label: 'Description', value: link.description),
                  _InfoRow(label: 'Montant', value: '${_fmt(link.amount)} FCFA'),
                  _InfoRow(label: 'Canal', value: link.paymentMethod.label),
                  _InfoRow(label: 'Statut', value: statusLabel, valueColor: statusText),
                  _InfoRow(label: 'Créé le', value: _fmtDate(link.createdAt)),
                  _InfoRow(label: 'Expire le', value: _fmtDate(link.expiresAt), isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Bouton Télécharger le reçu ─────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showSnackBar(context, 'Reçu généré', AppColors.green),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text(
                  'Télécharger le reçu',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Bouton Partager ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showSnackBar(context, 'Partage en cours...', AppColors.textSecondary),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green, width: 1.5),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text(
                  'Partager',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  (Color, Color, String, IconData) _statusMeta(PaymentStatus s) => switch (s) {
    PaymentStatus.paid    => (AppColors.statusPaidBg, AppColors.statusPaidText, 'Payé', Icons.check_circle_outline),
    PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente', Icons.hourglass_empty_outlined),
    PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé', Icons.link_outlined),
    PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré', Icons.timer_off_outlined),
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

// ── Ligne d'info ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;
  const _InfoRow({required this.label, required this.value, this.valueColor, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.borderLight),
      ],
    );
  }
}
