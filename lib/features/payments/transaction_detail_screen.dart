import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/messages_mock.dart' show PaymentStatus;
import '../../shared/mock/payments_mock.dart';

class TransactionDetailScreen extends StatefulWidget {
  final PaymentLink link;
  const TransactionDetailScreen({super.key, required this.link});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabel, statusIcon) = _statusMeta(widget.link.status);

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
            // ── Carte statut ──────────────────────────────────────────
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
                  Text(statusLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: statusText)),
                  const SizedBox(height: 8),
                  Text(
                    '${_fmt(widget.link.amount)} FCFA',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: statusText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section Informations ──────────────────────────────────
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
                  _InfoRow(label: 'Référence', value: widget.link.id.toUpperCase()),
                  _InfoRow(label: 'Client', value: widget.link.contactName),
                  _InfoRow(label: 'Description', value: widget.link.description),
                  _InfoRow(label: 'Montant', value: '${_fmt(widget.link.amount)} FCFA'),
                  _InfoRow(label: 'Canal', value: widget.link.paymentMethod.label),
                  _InfoRow(label: 'Statut', value: statusLabel, valueColor: statusText),
                  _InfoRow(label: 'Créé le', value: _fmtDate(widget.link.createdAt)),
                  _InfoRow(label: 'Expire le', value: _fmtDate(widget.link.expiresAt), isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Bouton Télécharger le reçu ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _downloadReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.green.withValues(alpha: 0.6),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: _downloading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  _downloading ? 'Génération...' : 'Télécharger le reçu',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Bouton Partager ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showSnackBar('Partage en cours...', AppColors.textSecondary),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green, width: 1.5),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Partager', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _buildPdf();

      // Tente le dossier Downloads standard Android
      Directory dir;
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        dir = downloads;
      } else {
        // Fallback : stockage interne de l'app
        dir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'recu_${widget.link.id}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showSnackBar('Reçu sauvegardé dans Téléchargements/$fileName', AppColors.green);

      // Ouvre le fichier directement
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<List<int>> _buildPdf() async {
    final doc = pw.Document();

    final green = PdfColor.fromHex('#22C55E');
    final textPrimary = PdfColor.fromHex('#1A1A1A');
    final textSecondary = PdfColor.fromHex('#6B7280');
    final bgGray = PdfColor.fromHex('#F5F5F5');
    final divider = PdfColor.fromHex('#E5E7EB');

    final (_, statusColor, statusLabel, _) = _statusMeta(widget.link.status);
    final pdfStatus = PdfColor(statusColor.r, statusColor.g, statusColor.b);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tête
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('e-Signal', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: green)),
              pw.SizedBox(height: 2),
              pw.Text('Propulsé par SCORE360 Africa', style: pw.TextStyle(fontSize: 9, color: textSecondary)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textPrimary)),
              pw.SizedBox(height: 4),
              pw.Text('Réf : ${widget.link.id.toUpperCase()}', style: pw.TextStyle(fontSize: 10, color: textSecondary)),
            ]),
          ]),

          pw.SizedBox(height: 20),
          pw.Divider(color: divider),
          pw.SizedBox(height: 16),

          // Badge statut
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: pw.BoxDecoration(color: pdfStatus, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Text(statusLabel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),

          pw.SizedBox(height: 16),

          // Montant
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(color: bgGray, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
            child: pw.Center(
              child: pw.Text('${_fmt(widget.link.amount)} FCFA',
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: textPrimary)),
            ),
          ),

          pw.SizedBox(height: 20),

          // Tableau infos
          _pdfRow('Client', widget.link.contactName, textPrimary, textSecondary, divider),
          _pdfRow('Description', widget.link.description, textPrimary, textSecondary, divider),
          _pdfRow('Canal de paiement', widget.link.paymentMethod.label, textPrimary, textSecondary, divider),
          _pdfRow('Date de création', _fmtDate(widget.link.createdAt), textPrimary, textSecondary, divider),
          _pdfRow("Date d'expiration", _fmtDate(widget.link.expiresAt), textPrimary, textSecondary, divider),

          pw.Spacer(),
          pw.Divider(color: divider),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('e-Signal — Propulsé par SCORE360 Africa',
              style: pw.TextStyle(fontSize: 9, color: textSecondary))),
        ],
      ),
    ));

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, PdfColor tp, PdfColor ts, PdfColor div) {
    return pw.Column(children: [
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11, color: ts)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: tp)),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: div, thickness: 0.5),
    ]);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  (Color, Color, String, IconData) _statusMeta(PaymentStatus s) => switch (s) {
    PaymentStatus.paid    => (AppColors.statusPaidBg,    AppColors.statusPaidText,    'Payé',        Icons.check_circle_outline),
    PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente',  Icons.hourglass_empty_outlined),
    PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé',        Icons.link_outlined),
    PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré',      Icons.timer_off_outlined),
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Flexible(
              child: Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary),
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
