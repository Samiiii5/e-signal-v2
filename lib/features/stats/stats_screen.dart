import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../shared/mock/stats_mock.dart';
import '../../shared/models/dashboard_model.dart';
import '../../shared/services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _period = '7 derniers jours';
  bool _isLoading = true;
  String? _error;
  DashboardData? _data;

  // Valeurs affichées — uniquement ce que l'API a réellement renvoyé.
  // Aucune donnée de démonstration : un chiffre absent reste absent.
  int _revenue = 0;
  int _conversations = 0;
  double _responseRate = 0;
  double _revenueGrowth = 0;
  double _conversationsGrowth = 0;
  double _responseRateGrowth = 0;
  List<ChannelStat> _channelStats = [];
  List<DailyRevenue> _dailyRevenue = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String _periodParam() => switch (_period) {
    '30 derniers jours' => '30d',
    'Ce mois'           => 'month',
    _                   => '7d',
  };

  Future<void> _loadDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await statsService.getDashboard(period: _periodParam());
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _applyData(data);
      });
    } on StatsUnauthorizedException {
      if (!mounted) return;
      SessionService.logout();
      GoRouter.of(context).go('/login');
    } on StatsUnavailableException {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Statistiques temporairement indisponibles.'; });
    } on StatsNetworkException {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Vérifiez votre connexion internet.'; });
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== Chargement du tableau de bord échoué : $e ===');
      setState(() { _isLoading = false; _error = 'Impossible de charger les statistiques.'; });
    }
  }

  void _applyData(DashboardData data) {
    // Repartir de zéro : sans cette remise à plat, changer de période
    // laisserait affichées les valeurs de la période précédente si la
    // nouvelle réponse ne contient pas la section correspondante.
    _revenue = 0;
    _conversations = 0;
    _responseRate = 0;
    _revenueGrowth = 0;
    _conversationsGrowth = 0;
    _responseRateGrowth = 0;
    _channelStats = [];
    _dailyRevenue = [];

    // ── KPIs ────────────────────────────────────────────────────────────────
    if (data.kpis.isNotEmpty) {
      for (final kpi in data.kpis) {
        final label = (kpi['label'] ?? kpi['key'] ?? '').toString().toLowerCase();
        final rawVal = kpi['value'];
        final rawChange = kpi['change'] ?? kpi['growth'] ?? kpi['trend_value'];

        double toDouble(dynamic v) {
          if (v == null) return 0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString().replaceAll('%', '').trim()) ?? 0;
        }

        final val = toDouble(rawVal);
        final change = toDouble(rawChange);

        // Le signe est conservé : une baisse doit s'afficher comme une baisse.
        if (label.contains('revenu') || label.contains('revenue') || label.contains('chiffre')) {
          _revenue = val.toInt();
          _revenueGrowth = change;
        } else if (label.contains('convers')) {
          _conversations = val.toInt();
          _conversationsGrowth = change;
        } else if (label.contains('répon') || label.contains('response') || label.contains('taux')) {
          _responseRate = val;
          _responseRateGrowth = change;
        }
      }
    }

    // ── Revenue series ───────────────────────────────────────────────────────
    if (data.revenueSeries.isNotEmpty) {
      final pts = data.revenueSeries['data'] ??
          data.revenueSeries['points'] ??
          data.revenueSeries['values'];
      if (pts is List && pts.isNotEmpty) {
        final parsed = <DailyRevenue>[];
        for (final pt in pts) {
          if (pt is Map) {
            final lbl = (pt['label'] ?? pt['day'] ?? pt['date'] ?? '').toString();
            final amt = pt['value'] ?? pt['amount'] ?? pt['revenue'] ?? 0;
            parsed.add(DailyRevenue(
              day: lbl.length > 3 ? lbl.substring(0, 3) : lbl,
              amount: (amt is num ? amt : double.tryParse(amt.toString()) ?? 0).toDouble(),
            ));
          }
        }
        if (parsed.length >= 2) _dailyRevenue = parsed;
      }
    }

    // ── Channel split ────────────────────────────────────────────────────────
    if (data.channelSplit.isNotEmpty) {
      const channelColors = {
        'whatsapp': 0xFF22C55E,
        'sms': 0xFF3B82F6,
        'email': 0xFF8B5CF6,
        'messenger': 0xFFF59E0B,
        'facebook': 0xFFF59E0B,
        'instagram': 0xFFEC4899,
        'tiktok': 0xFF000000,
      };
      const channelNames = {
        'whatsapp': 'WhatsApp',
        'sms': 'SMS',
        'email': 'Email',
        'messenger': 'Facebook',
        'facebook': 'Facebook',
        'instagram': 'Instagram',
        'tiktok': 'TikTok',
      };
      final parsed = <ChannelStat>[];
      for (final ch in data.channelSplit) {
        final key = (ch['channel'] ?? ch['name'] ?? '').toString().toLowerCase();
        final pct = ch['percentage'] ?? ch['percent'] ?? ch['share'] ?? 0;
        final count = ch['count'] ?? 0;
        final pctVal = pct is num ? pct.toInt() : int.tryParse(pct.toString()) ?? 0;
        if (pctVal > 0 || (count is num && count > 0)) {
          parsed.add(ChannelStat(
            name: channelNames[key] ?? key,
            percentage: pctVal,
            color: channelColors[key] ?? 0xFF9CA3AF,
          ));
        }
      }
      if (parsed.isNotEmpty) _channelStats = parsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2.5))
            // Aucune donnée jamais reçue + erreur → écran d'erreur plein.
            // Si _data existe, on garde les vrais chiffres à l'écran et on
            // signale l'échec de rafraîchissement par un simple bandeau.
            : (_error != null && _data == null)
            ? _StatsErrorState(error: _error!, onRetry: _loadDashboard)
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                color: AppColors.green,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            const Text('Stats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            _PeriodSelector(
                              value: _period,
                              onChanged: (v) {
                                setState(() => _period = v);
                                _loadDashboard();
                              },
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(error: _error!, onRetry: _loadDashboard),
                      ],

                      const SizedBox(height: 20),

                      // 3 cartes métriques
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(child: _MetricCard(
                              label: 'Revenus',
                              value: _formatAmount(_revenue),
                              unit: _data?.currency ?? 'FCFA',
                              growth: _revenueGrowth,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _MetricCard(
                              label: 'Conversations',
                              value: '$_conversations',
                              growth: _conversationsGrowth,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _MetricCard(
                              label: 'Taux réponse',
                              value: '${_responseRate.toStringAsFixed(0)}%',
                              growth: _responseRateGrowth,
                            )),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Graphique donut canaux
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight, width: 0.5),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Conversations par canal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 16),
                              if (_channelStats.isEmpty)
                                const _NoDataHint()
                              else
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: CustomPaint(
                                      painter: _DonutChartPainter(stats: _channelStats, total: _conversations),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      children: _channelStats.map((s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(s.color), shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                            Text('${s.percentage}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                          ],
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Graphique courbe revenus
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight, width: 0.5),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Évolution des revenus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _revenueGrowth >= 0 ? AppColors.greenLight : const Color(0xFFFFEDED),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _revenueGrowth >= 0
                                          ? '+${_revenueGrowth.toStringAsFixed(1)}%'
                                          : '${_revenueGrowth.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _revenueGrowth >= 0 ? AppColors.greenDark : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${_formatAmount(_revenue)} ${_data?.currency ?? 'FCFA'}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_dailyRevenue.length < 2)
                                const _NoDataHint()
                              else ...[
                                SizedBox(
                                  height: 120,
                                  child: CustomPaint(
                                    painter: _LineChartPainter(data: _dailyRevenue),
                                    size: const Size(double.infinity, 120),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: _dailyRevenue.map((d) => Text(d.day, style: const TextStyle(fontSize: 10, color: AppColors.textHint))).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
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
}

// ── Écran d'erreur (aucune donnée disponible) ─────────────────────────────────

class _StatsErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _StatsErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_chart_outlined, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Absence de données pour la période ────────────────────────────────────────

class _NoDataHint extends StatelessWidget {
  const _NoDataHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'Aucune donnée pour cette période',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ),
    );
  }
}

// ── Bandeau d'erreur ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_outlined, size: 16, color: Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Réessayer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de période ──────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            MediaQuery.of(context).size.width - 200, 80, 20, 0,
          ),
          items: ['7 derniers jours', '30 derniers jours', 'Ce mois'].map((v) =>
            PopupMenuItem(value: v, child: Text(v)),
          ).toList(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Carte métrique ────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double growth;
  const _MetricCard({required this.label, required this.value, this.unit, required this.growth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (unit != null) Text(unit!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                growth >= 0 ? Icons.trending_up : Icons.trending_down,
                size: 12,
                color: growth >= 0 ? AppColors.green : Colors.red,
              ),
              const SizedBox(width: 2),
              Text(
                growth >= 0
                    ? '+${growth.toStringAsFixed(1)}%'
                    : '${growth.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: growth >= 0 ? AppColors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Donut chart painter ───────────────────────────────────────────────────────

class _DonutChartPainter extends CustomPainter {
  final List<ChannelStat> stats;
  final int total;
  const _DonutChartPainter({required this.stats, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    double start = -math.pi / 2;

    for (final s in stats) {
      final sweep = s.percentage / 100 * 2 * math.pi;
      canvas.drawArc(rect, start, sweep - 0.04, false, Paint()
        ..color = Color(s.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt);
      start += sweep;
    }

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$total\n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const TextSpan(text: 'Total', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<DailyRevenue> data;
  const _LineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxVal = data.map((d) => d.amount).reduce(math.max);
    final minVal = data.map((d) => d.amount).reduce(math.min) * 0.8;
    final range = maxVal - minVal;
    if (range == 0) return;
    final stepX = size.width / (data.length - 1);

    final pts = List.generate(data.length, (i) {
      final x = i * stepX;
      final y = size.height - ((data[i].amount - minVal) / range) * size.height;
      return Offset(x, y);
    });

    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) { fillPath.lineTo(p.dx, p.dy); }
    fillPath..lineTo(pts.last.dx, size.height)..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.green.withValues(alpha: 0.2), AppColors.green.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    final peak = pts.reduce((a, b) => a.dy < b.dy ? a : b);
    canvas.drawCircle(peak, 5, Paint()..color = AppColors.white);
    canvas.drawCircle(peak, 3, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
