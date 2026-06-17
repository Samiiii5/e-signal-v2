import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
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
        title: const Text('Détail transaction', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status card
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
                  Text(statusLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: statusText)),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatAmount(link.amount)} FCFA',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: statusText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info card
            _InfoCard(children: [
              _InfoRow(label: 'Référence', value: link.id.toUpperCase()),
              _InfoRow(label: 'Client', value: link.contactName),
              _InfoRow(label: 'Description', value: link.description),
              _InfoRow(label: 'Canal de paiement', value: link.paymentMethod.label),
              _InfoRow(label: 'Créé le', value: _formatDate(link.createdAt)),
              _InfoRow(label: 'Expire le', value: _formatDate(link.expiresAt), isLast: true),
            ]),

            const SizedBox(height: 24),

            // Action buttons
            _ActionButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Télécharger le reçu PDF',
              color: AppColors.primary,
              onTap: () => _downloadPdf(context),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.share_outlined,
              label: 'Partager le reçu',
              color: AppColors.green,
              onTap: () => _sharePdf(context),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String, IconData) _statusMeta(PaymentStatus s) => switch (s) {
    PaymentStatus.paid    => (AppColors.statusPaidBg, AppColors.statusPaidText, 'Payé', Icons.check_circle_outline),
    PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente', Icons.hourglass_empty_outlined),
    PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé', Icons.link_outlined),
    PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré', Icons.timer_off_outlined),
  };

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('design/logo_onboarding.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final green = PdfColor.fromHex('#1E9E5E');
    final violet = PdfColor.fromHex('#6C5CE7');
    final textPrimary = PdfColor.fromHex('#1A1A2E');
    final textSecondary = PdfColor.fromHex('#6B7280');
    final borderLight = PdfColor.fromHex('#E8E9EC');
    final bgPage = PdfColor.fromHex('#F7F8FA');

    final (_, statusColor, statusLabel, _) = _statusMeta(link.status);
    final pdfStatusColor = PdfColor(statusColor.red / 255, statusColor.green / 255, statusColor.blue / 255);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logo != null) pw.Image(logo, height: 48) else pw.Text('e-Signal', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: green)),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textPrimary)),
                pw.SizedBox(height: 4),
                pw.Text('Réf: ${link.id.toUpperCase()}', style: pw.TextStyle(fontSize: 10, color: textSecondary)),
              ]),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: borderLight),
          pw.SizedBox(height: 16),

          // Status badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: pdfStatusColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(statusLabel, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),

          pw.SizedBox(height: 20),

          // Amount
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: bgPage,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Montant', style: pw.TextStyle(fontSize: 12, color: textSecondary)),
              pw.SizedBox(height: 6),
              pw.Text('${_formatAmount(link.amount)} FCFA', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: textPrimary)),
            ]),
          ),

          pw.SizedBox(height: 20),

          // Details
          _pdfRow('Client', link.contactName, textPrimary, textSecondary, borderLight),
          _pdfRow('Description', link.description, textPrimary, textSecondary, borderLight),
          _pdfRow('Canal', link.paymentMethod.label, textPrimary, textSecondary, borderLight),
          _pdfRow('Date de création', _formatDate(link.createdAt), textPrimary, textSecondary, borderLight),
          _pdfRow("Date d'expiration", _formatDate(link.expiresAt), textPrimary, textSecondary, borderLight),

          pw.Spacer(),

          // Footer
          pw.Divider(color: borderLight),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'e-Signal — Propulsé par SCORE360 Africa',
              style: pw.TextStyle(fontSize: 10, color: textSecondary),
            ),
          ),
        ],
      ),
    ));

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, PdfColor textPrimary, PdfColor textSecondary, PdfColor borderLight) {
    return pw.Column(children: [
      pw.SizedBox(height: 12),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 12, color: textSecondary)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textPrimary)),
      ]),
      pw.SizedBox(height: 12),
      pw.Divider(color: borderLight, thickness: 0.5),
    ]);
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'recu_${link.id}.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final bytes = await _buildPdfBytes();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/recu_${link.id}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'Reçu paiement — ${link.contactName}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

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

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: AppColors.borderLight),
    ]);
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
