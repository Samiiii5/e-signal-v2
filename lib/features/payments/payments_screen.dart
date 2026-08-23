import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_router.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../shared/services/payment_service.dart';
import 'create_link_sheet.dart';

// ── Couleurs statut (spec design) ─────────────────────────────────────────────
const _kPaidText    = Color(0xFF27500A);
const _kPaidBg      = Color(0xFFEAF3DE);
const _kPendingText = Color(0xFF534AB7);
const _kPendingBg   = Color(0xFFEEEDFE);
const _kCreatedText = AppColors.textSecondary;
const _kCreatedBg   = AppColors.backgroundPage;
const _kExpiredText = Color(0xFF5F5E5A);
const _kExpiredBg   = Color(0xFFF1EFE8);

(Color, Color, String) _statusStyle(String s) => switch (s) {
  'paid'    => (_kPaidBg,    _kPaidText,    'Payé'),
  'pending' => (_kPendingBg, _kPendingText, 'En attente'),
  'expired' => (_kExpiredBg, _kExpiredText, 'Expiré'),
  _         => (_kCreatedBg, _kCreatedText, 'Créé'),
};

// ── Formatage ─────────────────────────────────────────────────────────────────

String _fmtAmount(String raw) {
  final n = double.tryParse(raw)?.toInt() ?? 0;
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

// ── Écran principal ───────────────────────────────────────────────────────────

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentLink> _links = [];
  bool _isLoading = true;
  String? _error;
  String? _filter; // 'paid' | 'pending' | 'expired' | null

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final links = await paymentService.getPaymentLinks();
      if (!mounted) return;
      setState(() { _links = links; _isLoading = false; });
    } on PaymentUnauthorizedException {
      if (!mounted) return;
      SessionService.logout();
      navigatorKey.currentContext?.go('/login');
    } on PaymentNetworkException {
      if (!mounted) return;
      _setLoadError('Pas de connexion internet. Vérifiez votre réseau.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== Chargement des transactions échoué : $e ===');
      _setLoadError('Impossible de charger les transactions.');
    }
  }

  /// Affiche l'erreur à la place de la liste (avec bouton « Réessayer ») et la
  /// signale par un snackbar — plus aucune transaction de démonstration n'est
  /// substituée à un échec serveur.
  void _setLoadError(String message) {
    setState(() { _isLoading = false; _error = message; });
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error(message));
  }

  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<CreateLinkSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateLinkSheet(),
    );
    if (!mounted) return;
    if (result != null) await _load();
  }

  Future<void> _openExportSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExportSheet(
        allLinks: _links,
        onDone: (msg) => ScaffoldMessenger.of(context).showSnackBar(_snack(msg)),
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
                  _FilterPill(label: 'Tous',       active: _filter == null,      color: AppColors.textPrimary, onTap: () => setState(() => _filter = null)),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Payés',      active: _filter == 'paid',    color: _kPaidText,    onTap: () => setState(() => _filter = 'paid')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'En attente', active: _filter == 'pending', color: _kPendingText, onTap: () => setState(() => _filter = 'pending')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Expirés',    active: _filter == 'expired', color: _kExpiredText, onTap: () => setState(() => _filter = 'expired')),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Liste ────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const _PaymentsSkeleton()
                  : _error != null
                      ? _ErrorBanner(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppColors.green,
                          onRefresh: _load,
                          child: Builder(builder: (context) {
                            var links = _links;
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
                          }),
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
  final Color color;
  const _FilterPill({required this.label, required this.active, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : AppColors.backgroundPage,
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
                  Text(_fmtAmount(link.amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: statusText)),
                  Text(' ${link.currency}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
                ]),
                const SizedBox(height: 4),
                Text(link.catalogItemName ?? link.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_fmtDate(link.expiresAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
}

// ── Skeleton chargement ───────────────────────────────────────────────────────

class _PaymentsSkeleton extends StatelessWidget {
  const _PaymentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 100, height: 18),
            SizedBox(height: 8),
            ShimmerBox(width: 160, height: 13),
            SizedBox(height: 4),
            ShimmerBox(width: 80, height: 11),
          ],
        ),
      ),
    );
  }
}

// ── Bannière erreur réseau ────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 44, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet Export ───────────────────────────────────────────────────────

enum _ExportFilter { all, paid, pending, thisMonth, thisQuarter }

class _ExportSheet extends StatefulWidget {
  final List<PaymentLink> allLinks;
  final void Function(String) onDone;
  const _ExportSheet({required this.allLinks, required this.onDone});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  _ExportFilter _filter = _ExportFilter.all;
  bool _exporting = false;

  List<PaymentLink> get _filtered {
    final now = DateTime.now();
    return switch (_filter) {
      _ExportFilter.all         => widget.allLinks,
      _ExportFilter.paid        => widget.allLinks.where((l) => l.status == 'paid').toList(),
      _ExportFilter.pending     => widget.allLinks.where((l) => l.status == 'pending').toList(),
      _ExportFilter.thisMonth   => widget.allLinks.where((l) {
          final dt = l.expiresAtDate;
          return dt != null && dt.year == now.year && dt.month == now.month;
        }).toList(),
      _ExportFilter.thisQuarter => widget.allLinks.where((l) {
          final dt = l.expiresAtDate;
          if (dt == null) return false;
          final q = (now.month - 1) ~/ 3;
          final lq = (dt.month - 1) ~/ 3;
          return dt.year == now.year && lq == q;
        }).toList(),
    };
  }

  String _dateTag() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
  }

  String _statusLabel(String s) => switch (s) {
    'paid'    => 'Payé',
    'pending' => 'En attente',
    'expired' => 'Expiré',
    _         => 'Créé',
  };

  Future<File> _saveFile(String name, List<int> bytes) async {
    final dl = Directory('/storage/emulated/0/Download');
    final dir = await dl.exists() ? dl : await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final links = _filtered;
      final buf = StringBuffer();
      buf.writeln('Référence,Description,Montant,Devise,Statut,Fournisseur,Expiration');
      for (final l in links) {
        buf.writeln('"${l.id.toUpperCase()}","${l.description}",${l.amount},"${l.currency}","${_statusLabel(l.status)}","${l.provider}","${_fmtDate(l.expiresAt)}"');
      }
      final name = 'esignal_transactions_${_dateTag()}.csv';
      final file = await _saveFile(name, buf.toString().codeUnits);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone('✅ Fichier CSV sauvegardé dans Téléchargements');
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone('Erreur export CSV : $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final links = _filtered;
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];

      final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1E9E5E'),
        horizontalAlign: HorizontalAlign.Center,
      );

      final headers = ['Référence', 'Description', 'Montant', 'Devise', 'Statut', 'Fournisseur', 'Expiration'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      for (var r = 0; r < links.length; r++) {
        final l = links[r];
        final row = [l.id.toUpperCase(), l.description, l.amount, l.currency, _statusLabel(l.status), l.provider, _fmtDate(l.expiresAt)];
        for (var c = 0; c < row.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          cell.value = TextCellValue(row[c]);
        }
      }

      for (var c = 0; c < headers.length; c++) {
        sheet.setColumnWidth(c, 22);
      }

      final bytes = excel.encode()!;
      final name = 'esignal_transactions_${_dateTag()}.xlsx';
      final file = await _saveFile(name, bytes);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone('✅ Fichier Excel sauvegardé dans Téléchargements');
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone('Erreur export Excel : $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _filtered.length;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Exporter les transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
                child: Text('$count transaction${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Filtrer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Toutes',       active: _filter == _ExportFilter.all,         onTap: () => setState(() => _filter = _ExportFilter.all)),
                const SizedBox(width: 6),
                _FilterChip(label: 'Payées',        active: _filter == _ExportFilter.paid,        onTap: () => setState(() => _filter = _ExportFilter.paid)),
                const SizedBox(width: 6),
                _FilterChip(label: 'En attente',    active: _filter == _ExportFilter.pending,      onTap: () => setState(() => _filter = _ExportFilter.pending)),
                const SizedBox(width: 6),
                _FilterChip(label: 'Ce mois',       active: _filter == _ExportFilter.thisMonth,    onTap: () => setState(() => _filter = _ExportFilter.thisMonth)),
                const SizedBox(width: 6),
                _FilterChip(label: 'Ce trimestre',  active: _filter == _ExportFilter.thisQuarter,  onTap: () => setState(() => _filter = _ExportFilter.thisQuarter)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ExportTile(
            icon: Icons.table_chart_outlined,
            label: 'Exporter en CSV',
            subtitle: 'Compatible Excel, Google Sheets',
            color: AppColors.green,
            loading: _exporting,
            onTap: _exporting ? null : _exportCsv,
          ),
          const SizedBox(height: 10),
          _ExportTile(
            icon: Icons.grid_on_outlined,
            label: 'Exporter en Excel',
            subtitle: 'Fichier .xlsx — en-têtes en gras vert',
            color: const Color(0xFF217346),
            loading: _exporting,
            onTap: _exporting ? null : _exportExcel,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _exporting ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.green : AppColors.borderLight),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppColors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _ExportTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.backgroundPage.withValues(alpha: 0.5) : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: loading
                ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onTap == null ? AppColors.textHint : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Icon(Icons.chevron_right, color: onTap == null ? AppColors.borderLight : AppColors.textSecondary, size: 20),
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
