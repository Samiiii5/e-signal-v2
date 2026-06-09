import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/session_service.dart';
import 'painters/slide1_painter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _finish() {
    SessionService.markOnboardingSeen();
    context.go('/login');
  }

  void _next() {
    if (_currentPage < 3) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _Slide1(onNext: _next, onSkip: _finish, currentPage: _currentPage),
          _Slide2(onNext: _next, onSkip: _finish, currentPage: _currentPage),
          _Slide3(onNext: _next, onSkip: _finish, currentPage: _currentPage),
          _Slide4(onFinish: _finish, currentPage: _currentPage),
        ],
      ),
    );
  }
}

// ── Dots indicator ────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int current;
  final int count;
  final Color activeColor;
  final Color inactiveColor;

  const _Dots({
    required this.current,
    required this.count,
    this.activeColor = AppColors.green,
    this.inactiveColor = const Color(0xFFD1D5DB),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Slide 1 : Bienvenue — conforme au mockup ─────────────────────────────────

class _Slide1 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int currentPage;

  const _Slide1({required this.onNext, required this.onSkip, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: onNext,
      child: Container(
        color: const Color(0xFF2D1B69),
        child: Stack(
          children: [
            // ── Image dame — occupe les 63% inférieurs ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height * 0.63,
              child: const Slide1Widget(),
            ),

            // ── Confettis / décorations autour de la dame ──
            // Carré vert haut-gauche
            _Confetti(top: size.height * 0.32, left: 24, w: 16, h: 10, color: const Color(0xFF22C55E), angle: 0.4),
            // Carré vert milieu-gauche
            _Confetti(top: size.height * 0.40, left: 48, w: 12, h: 8, color: const Color(0xFF22C55E), angle: -0.3),
            // Carré jaune gauche
            _Confetti(top: size.height * 0.46, left: 22, w: 10, h: 6, color: const Color(0xFFFFC107), angle: 0.6),
            // Carré vert droite-haut
            _Confetti(top: size.height * 0.30, right: 28, w: 14, h: 9, color: const Color(0xFF22C55E), angle: -0.5),
            // Carré vert droite-milieu
            _Confetti(top: size.height * 0.38, right: 50, w: 10, h: 7, color: const Color(0xFF22C55E), angle: 0.3),
            // Carré blanc droite
            _Confetti(top: size.height * 0.43, right: 24, w: 12, h: 8, color: Colors.white.withValues(alpha: 0.5), angle: -0.7),
            // Flèche verte montante gauche
            Positioned(
              top: size.height * 0.36,
              left: 18,
              child: Transform.rotate(
                angle: 0.25,
                child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF22C55E), size: 22),
              ),
            ),
            // Flèche verte montante droite
            Positioned(
              top: size.height * 0.44,
              right: 20,
              child: Transform.rotate(
                angle: -0.2,
                child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF22C55E), size: 18),
              ),
            ),
            // Tiret blanc diagonal centre
            Positioned(
              top: size.height * 0.41,
              left: size.width * 0.38,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(width: 22, height: 3, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2))),
              ),
            ),

            // ── Contenu textuel en SafeArea ──
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Logo e-Signal centré
                  _ESignalLogo(),

                  SizedBox(height: size.height * 0.045),

                  // Titre centré
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tout votre business\nconnecté, analysé,\n',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
                          ),
                          TextSpan(
                            text: 'et propulsé.',
                            style: TextStyle(color: Color(0xFF22C55E), fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description centrée
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'Centralisez vos conversations, comprenez vos performances et prenez de meilleures décisions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13, height: 1.55),
                    ),
                  ),

                  const Spacer(),

                  // 4 dots de progression centrés
                  _Dots(
                    current: currentPage,
                    count: 4,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Logo "eS" avec icône graphique + "e-Signal"
class _ESignalLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Fond semi-transparent arrondi
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            // eS + barres graphique
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'eS',
                  style: TextStyle(color: Color(0xFF22C55E), fontSize: 30, fontWeight: FontWeight.w900, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: _BarChart(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'e-Signal',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.5),
        ),
      ],
    );
  }
}

// Mini bar chart avec flèche — intégré dans le logo
class _BarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF22C55E);
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _BarChartPainter(color: color)),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Color color;
  const _BarChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width / 5;
    // 3 barres croissantes
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, w, size.height * 0.45), p);
    canvas.drawRect(Rect.fromLTWH(w * 1.5, size.height * 0.30, w, size.height * 0.70), p);
    canvas.drawRect(Rect.fromLTWH(w * 3.0, 0, w, size.height), p);
    // Flèche en haut de la 3e barre
    final arrow = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 3.5, 0), Offset(size.width, 0), arrow);
    canvas.drawLine(Offset(size.width - 4, 0), Offset(size.width, 0), arrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Confetti générique positionnable
class _Confetti extends StatelessWidget {
  final double? top, bottom, left, right;
  final double w, h;
  final Color color;
  final double angle;

  const _Confetti({
    this.top, this.bottom, this.left, this.right,
    required this.w, required this.h,
    required this.color, required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}

// ── Slide 2 : Inbox unifiée (fond blanc) ─────────────────────────────────────

class _Slide2 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int currentPage;

  const _Slide2({required this.onNext, required this.onSkip, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Titre
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(text: 'Centralisez toutes vos\n', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, height: 1.3)),
                    TextSpan(text: 'conversations', style: TextStyle(color: AppColors.green, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'WhatsApp, SMS, Email, Facebook\net plus encore dans une seule inbox.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              // Mockup inbox simplifié
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: const Row(
                          children: [
                            Text('Inbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Spacer(),
                            Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                            SizedBox(width: 12),
                            Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderLight),
                      // Conversations mockées
                      ..._mockConvos.map((c) => _MiniConvo(data: c)),
                    ],
                  ),
                ),
              ),
              // Icônes canaux flottants (rangée)
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChannelBubble(label: 'WA', color: const Color(0xFF25D366)),
                  _ChannelBubble(label: 'f', color: const Color(0xFF1877F2)),
                  _ChannelBubble(label: 'SMS', color: const Color(0xFFF59E0B)),
                  _ChannelBubble(label: '@', color: AppColors.primary),
                  _ChannelBubble(label: 'IG', color: const Color(0xFFE1306C)),
                ],
              ),
              const SizedBox(height: 24),
              _NavButtons(onSkip: onSkip, onNext: onNext, currentPage: currentPage),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static const _mockConvos = [
    ('KY', 'Kouamé Yao', 'Bonjour, je suis intéressé...', '09:41', 2, Color(0xFF25D366)),
    ('AN', 'Awa N\'Guessan', 'Merci pour la proposition,', '09:32', 1, Color(0xFF25D366)),
    ('MK', 'Marc K.', 'Pouvez-vous m\'envoyer le...', 'Hier', 3, Color(0xFF1877F2)),
  ];
}

class _MiniConvo extends StatelessWidget {
  final (String, String, String, String, int, Color) data;
  const _MiniConvo({required this.data});

  @override
  Widget build(BuildContext context) {
    final (initials, name, preview, time, unread, channelColor) = data;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.backgroundPage, child: Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 7, backgroundColor: channelColor)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 2),
                Text(preview, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 10, backgroundColor: AppColors.primary, child: Text('$unread', style: const TextStyle(fontSize: 10, color: AppColors.white, fontWeight: FontWeight.w700))),
          ],
        ],
      ),
    );
  }
}

class _ChannelBubble extends StatelessWidget {
  final String label;
  final Color color;
  const _ChannelBubble({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Center(child: Text(label, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 12))),
    );
  }
}

// ── Slide 3 : Analytics (fond blanc) ─────────────────────────────────────────

class _Slide3 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int currentPage;

  const _Slide3({required this.onNext, required this.onSkip, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(text: 'Comprenez', style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' ce qui\nfait grandir votre business', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Des tableaux de bord clairs pour suivre\nvos performances en temps réel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              // Cartes métriques
              Row(
                children: [
                  Expanded(child: _MetricCard(label: 'Revenus', value: '1 250 000\nFCFA', growth: '+18.5%')),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(label: 'Conversations', value: '324', growth: '+12.3%')),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(label: 'Taux réponse', value: '92%', growth: '+7.1%')),
                ],
              ),
              const SizedBox(height: 16),
              // Donut simplifié (représentation visuelle)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conversations par canal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _DonutSimple(),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _LegendItem(color: Color(0xFF22C55E), label: 'WhatsApp', pct: '45%'),
                            _LegendItem(color: Color(0xFF3B82F6), label: 'SMS', pct: '20%'),
                            _LegendItem(color: Color(0xFF8B5CF6), label: 'Email', pct: '20%'),
                            _LegendItem(color: Color(0xFFF59E0B), label: 'Facebook', pct: '10%'),
                            _LegendItem(color: Color(0xFFEC4899), label: 'Instagram', pct: '5%'),
                          ],
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _NavButtons(onSkip: onSkip, onNext: onNext, currentPage: currentPage),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String growth;
  const _MetricCard({required this.label, required this.value, required this.growth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2)),
          const SizedBox(height: 4),
          Text(growth, style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DonutSimple extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: CustomPaint(painter: _DonutPainter()),
    );
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final colors = [0xFF22C55E, 0xFF3B82F6, 0xFF8B5CF6, 0xFFF59E0B, 0xFFEC4899];
    final sweeps = [0.45, 0.20, 0.20, 0.10, 0.05];
    double start = -3.14159 / 2;
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = Color(colors[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      canvas.drawArc(rect, start, sweeps[i] * 2 * 3.14159, false, paint);
      start += sweeps[i] * 2 * 3.14159 + 0.05;
    }
    // Centre label
    final tp = TextPainter(
      text: const TextSpan(text: '324\nTotal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String pct;
  const _LegendItem({required this.color, required this.label, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const Spacer(),
          Text(pct, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Slide 4 : Passez à l'action (fond vert très clair) ───────────────────────

class _Slide4 extends StatelessWidget {
  final VoidCallback onFinish;
  final int currentPage;

  const _Slide4({required this.onFinish, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0FFF4),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(text: 'Décidez', style: TextStyle(color: AppColors.green, fontSize: 26, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' avec des insights\nexploitables et finançables', style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Transformez vos données en actions et accédez à plus d\'opportunités.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              // Grille 2x2 de features
              Row(
                children: [
                  Expanded(child: _FeatureCard(icon: Icons.bar_chart_rounded, label: 'Insights', color: AppColors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _FeatureCard(icon: Icons.track_changes_rounded, label: 'Décisions', color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _FeatureCard(icon: Icons.trending_up_rounded, label: 'Croissance', color: const Color(0xFFF59E0B))),
                  const SizedBox(width: 12),
                  Expanded(child: _FeatureCard(icon: Icons.account_balance_wallet_rounded, label: 'Financement', color: const Color(0xFF3B82F6))),
                ],
              ),
              const Spacer(),
              // Dots
              _Dots(current: currentPage, count: 4, activeColor: AppColors.green),
              const SizedBox(height: 24),
              // Bouton Commencer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Commencer maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Lien Se connecter
              GestureDetector(
                onTap: onFinish,
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Vous avez déjà un compte ? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      TextSpan(text: 'Se connecter', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
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
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeatureCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Boutons nav Passer / Suivant ──────────────────────────────────────────────

class _NavButtons extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final int currentPage;
  const _NavButtons({required this.onSkip, required this.onNext, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Dots(current: currentPage, count: 4),
        Row(
          children: [
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Passer', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Suivant', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
