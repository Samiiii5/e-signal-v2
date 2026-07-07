import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/mock/stats_mock.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _period = '7 derniers jours';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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
                    _PeriodSelector(value: _period, onChanged: (v) => setState(() => _period = v)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3 cartes métriques
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _MetricCard(
                      label: 'Revenus',
                      value: _formatAmount(mockRevenue),
                      unit: 'FCFA',
                      growth: mockRevenueGrowth,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _MetricCard(
                      label: 'Conversations',
                      value: '$mockConversations',
                      growth: mockConversationsGrowth,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _MetricCard(
                      label: 'Taux réponse',
                      value: '$mockResponseRate%',
                      growth: mockResponseRateGrowth,
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
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: _DonutChartPainter(stats: mockChannelStats, total: mockConversations),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: mockChannelStats.map((s) => Padding(
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
                            decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)),
                            child: const Text('+18.5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('${_formatAmount(mockRevenue)} FCFA', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: _LineChartPainter(data: mockDailyRevenue),
                          size: const Size(double.infinity, 120),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: mockDailyRevenue.map((d) => Text(d.day, style: const TextStyle(fontSize: 10, color: AppColors.textHint))).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
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
              const Icon(Icons.trending_up, size: 12, color: AppColors.green),
              const SizedBox(width: 2),
              Text('+${growth.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w600)),
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
    if (data.isEmpty) return;
    final maxVal = data.map((d) => d.amount).reduce(math.max);
    final minVal = data.map((d) => d.amount).reduce(math.min) * 0.8;
    final range = maxVal - minVal;
    final stepX = size.width / (data.length - 1);

    List<Offset> pts = List.generate(data.length, (i) {
      final x = i * stepX;
      final y = size.height - ((data[i].amount - minVal) / range) * size.height;
      return Offset(x, y);
    });

    // Fill under curve
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) { fillPath.lineTo(p.dx, p.dy); }
    fillPath..lineTo(pts.last.dx, size.height)..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.green.withValues(alpha: 0.2), AppColors.green.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Line
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

    // Peak dot
    final peak = pts.reduce((a, b) => a.dy < b.dy ? a : b);
    canvas.drawCircle(peak, 5, Paint()..color = AppColors.white);
    canvas.drawCircle(peak, 3, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
