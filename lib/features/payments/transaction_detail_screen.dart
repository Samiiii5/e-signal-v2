import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/payment_link.dart';
import '../../shared/services/payment_service.dart';

// ── Couleurs statut (identiques à payments_screen.dart) ───────────────────────
const _kPaidText    = Color(0xFF27500A);
const _kPaidBg      = Color(0xFFEAF3DE);
const _kPendingText = Color(0xFF534AB7);
const _kPendingBg   = Color(0xFFEEEDFE);
const _kCreatedText = AppColors.textSecondary;
const _kCreatedBg   = AppColors.backgroundPage;
const _kExpiredText = Color(0xFF5F5E5A);
const _kExpiredBg   = Color(0xFFF1EFE8);

class TransactionDetailScreen extends StatefulWidget {
  final PaymentLink link;
  const TransactionDetailScreen({super.key, required this.link});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _downloading = false;
  bool _cancelling = false;
  PaymentLink? _detail;

  PaymentLink get _link => _detail ?? widget.link;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await paymentService.getPaymentLinkDetail(widget.link.id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      // Silently fallback to widget.link
    }
  }

  Future<void> _cancelLink() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler ce lien ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Cette action est irréversible. Le lien ne pourra plus être utilisé.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler le lien', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await paymentService.cancelPaymentLink(_link.id);
      if (!mounted) return;
      _showSnackBar('Lien annulé avec succès', AppColors.textSecondary);
      Navigator.pop(context);
    } on PaymentNetworkException {
      if (!mounted) return;
      _showSnackBar('Erreur réseau. Vérifiez votre connexion.', Colors.redAccent);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d\'annuler le lien.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabel, statusIcon) = _statusMeta(_link.status);

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
                    '${_fmtAmount(_link.amount)} ${_link.currency}',
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
                  _InfoRow(label: 'Référence', value: _link.id.toUpperCase()),
                  if (_link.catalogItemName != null)
                    _InfoRow(label: 'Article', value: _link.catalogItemName!),
                  _InfoRow(label: 'Description', value: _link.description),
                  _InfoRow(label: 'Montant', value: '${_fmtAmount(_link.amount)} ${_link.currency}'),
                  _InfoRow(label: 'Fournisseur', value: _providerLabel(_link.provider)),
                  _InfoRow(label: 'Statut', value: statusLabel, valueColor: statusText),
                  if (_link.paymentStatus != null)
                    _InfoRow(label: 'Statut paiement', value: _link.paymentStatus!),
                  if (_link.openedAt != null)
                    _InfoRow(label: 'Ouvert le', value: _fmtDate(_link.openedAt!)),
                  _InfoRow(label: 'Expire le', value: _fmtDate(_link.expiresAt), isLast: true),
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

            // ── Bouton Annuler (seulement si pas payé/expiré) ─────────
            if (_link.status != 'paid' && _link.status != 'expired') ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelLink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                  icon: _cancelling
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(_cancelling ? 'Annulation...' : 'Annuler le lien', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],

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
      Directory dir;
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        dir = downloads;
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final fileName = 'recu_${_link.id}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      _showSnackBar('Reçu sauvegardé dans Téléchargements/$fileName', AppColors.green);
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

    final (_, statusColor, statusLabel, _) = _statusMeta(_link.status);
    final pdfStatus = PdfColor(statusColor.r, statusColor.g, statusColor.b);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('e-Signal', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: green)),
              pw.SizedBox(height: 2),
              pw.Text('Propulsé par SCORE360 Africa', style: pw.TextStyle(fontSize: 9, color: textSecondary)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textPrimary)),
              pw.SizedBox(height: 4),
              pw.Text('Réf : ${_link.id.toUpperCase()}', style: pw.TextStyle(fontSize: 10, color: textSecondary)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.Divider(color: divider),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: pw.BoxDecoration(color: pdfStatus, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Text(statusLabel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(color: bgGray, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
            child: pw.Center(
              child: pw.Text('${_fmtAmount(_link.amount)} ${_link.currency}',
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: textPrimary)),
            ),
          ),
          pw.SizedBox(height: 20),
          if (_link.catalogItemName != null)
            _pdfRow('Article', _link.catalogItemName!, textPrimary, textSecondary, divider),
          _pdfRow('Description', _link.description, textPrimary, textSecondary, divider),
          _pdfRow('Fournisseur', _providerLabel(_link.provider), textPrimary, textSecondary, divider),
          _pdfRow("Date d'expiration", _fmtDate(_link.expiresAt), textPrimary, textSecondary, divider),
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

  (Color, Color, String, IconData) _statusMeta(String s) => switch (s) {
    'paid'    => (_kPaidBg,    _kPaidText,    'Payé',        Icons.check_circle_outline),
    'pending' => (_kPendingBg, _kPendingText, 'En attente',  Icons.hourglass_empty_outlined),
    'expired' => (_kExpiredBg, _kExpiredText, 'Expiré',      Icons.timer_off_outlined),
    _         => (_kCreatedBg, _kCreatedText, 'Créé',        Icons.link_outlined),
  };
}

String _fmtAmount(String raw) {
  final n = int.tryParse(raw) ?? 0;
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  const m = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
}

String _providerLabel(String provider) {
  return switch (provider.toLowerCase()) {
    'wave'         => 'Wave',
    'fedapay'      => 'FedaPay',
    'orange_money' => 'Orange Money',
    'cinetpay'     => 'CinetPay',
    'moov_money'   => 'Moov Money',
    'mtn_money'    => 'MTN Money',
    'djamo'        => 'Djamo',
    _              => provider,
  };
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
