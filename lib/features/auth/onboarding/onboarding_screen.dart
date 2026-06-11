import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/session_service.dart';

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

// ── Slide 1 ───────────────────────────────────────────────────────────────────

class _Slide1 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int currentPage;

  const _Slide1({required this.onNext, required this.onSkip, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      color: const Color(0xFF2D1B69),
      child: Stack(
        children: [
          // ── Dame bas-gauche, dépasse légèrement vers le haut ──────────────
          Positioned(
            bottom: 48,        // laisse de la place pour les dots
            left: 0,
            child: Image.asset(
              'design/image_onboarding1.png',
              width: size.width * 0.62,
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomLeft,
            ),
          ),

          // ── Icônes canaux flottantes repositionnées ───────────────────────
          // Message vert — haut-droite de la dame
          Positioned(
            bottom: size.height * 0.44,
            right: size.width * 0.32,
            child: _FloatingIcon(icon: Icons.chat_bubble_rounded, color: const Color(0xFF1E9E5E)),
          ),
          // Email violet — droite au niveau de la taille
          Positioned(
            bottom: size.height * 0.30,
            right: 20,
            child: _FloatingIcon(icon: Icons.email_rounded, color: const Color(0xFF6C5CE7)),
          ),
          // SMS/smartphone vert — bas-droite de la dame
          Positioned(
            bottom: size.height * 0.18,
            right: 28,
            child: _FloatingIcon(icon: Icons.sms_rounded, color: const Color(0xFF1E9E5E)),
          ),
          // WhatsApp cercle vert — gauche de la dame
          Positioned(
            bottom: size.height * 0.28,
            left: 8,
            child: _FloatingIcon(icon: Icons.chat_rounded, color: const Color(0xFF25D366)),
          ),
          // Notification — au-dessus à gauche
          Positioned(
            bottom: size.height * 0.50,
            left: 24,
            child: _FloatingIcon(icon: Icons.notifications_rounded, color: Colors.white),
          ),
          // Graphique — haut-droite loin de la dame
          Positioned(
            bottom: size.height * 0.52,
            right: 20,
            child: _FloatingIcon(icon: Icons.bar_chart_rounded, color: const Color(0xFF1E9E5E)),
          ),

          // ── Décoration géométrique bas-droite ─────────────────────────────
          Positioned(
            bottom: 60,
            right: 20,
            child: SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(painter: _GeoDeco()),
            ),
          ),

          // ── Contenu principal (logo + texte + dots) ───────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Logo e-Signal — image réelle
                  Image.asset(
                    'design/logo_onboarding.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Titre centré
                  SizedBox(
                    width: double.infinity,
                    child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tout votre business\nconnecté, analysé,\n',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        TextSpan(
                          text: 'et propulsé.',
                          style: TextStyle(
                            color: Color(0xFF1E9E5E),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),

                  const SizedBox(height: 14),

                  // Description centrée
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                    'Centralisez vos conversations, comprenez\nvos performances et prenez de meilleures\ndécisions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                    ),
                  ),
                  ),

                  const Spacer(),

                  // 4 dots centrés — pas de boutons
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
          ),
        ],
      ),
    );
  }
}

// ── Icône canal flottante ─────────────────────────────────────────────────────

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _FloatingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Décoration géométrique bas-droite ─────────────────────────────────────────

class _GeoDeco extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sWhite = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final sGold = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final sGreen = Paint()
      ..color = const Color(0xFF1E9E5E).withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Triangle blanc
    final tri = Path()
      ..moveTo(size.width * 0.10, size.height * 0.95)
      ..lineTo(size.width * 0.50, size.height * 0.05)
      ..lineTo(size.width * 0.90, size.height * 0.95)
      ..close();
    canvas.drawPath(tri, sWhite);

    // Losange doré
    final dia = Path()
      ..moveTo(size.width * 0.65, 0)
      ..lineTo(size.width, size.height * 0.30)
      ..lineTo(size.width * 0.65, size.height * 0.60)
      ..lineTo(size.width * 0.30, size.height * 0.30)
      ..close();
    canvas.drawPath(dia, sGold);

    // Petit carré vert
    final sq = Path()
      ..moveTo(size.width * 0.05, size.height * 0.30)
      ..lineTo(size.width * 0.25, size.height * 0.20)
      ..lineTo(size.width * 0.35, size.height * 0.40)
      ..lineTo(size.width * 0.15, size.height * 0.50)
      ..close();
    canvas.drawPath(sq, sGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Slide 2 : Inbox unifiée ───────────────────────────────────────────────────

class _Slide2 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int currentPage;

  const _Slide2({required this.onNext, required this.onSkip, required this.currentPage});

  // (initiales, nom, aperçu, heure, badge, couleurCanal, icôneCanal)
  static const _convos = [
    ('KY', 'Kouamé Yao',        'Bonjour, je suis intéressé...',        '09:41', 2, Color(0xFF25D366), Icons.chat_bubble),
    ('AN', "Awa N'Guessan",     'Merci pour la proposition.',            '09:32', 1, Color(0xFF6C5CE7), Icons.email),
    ('',   '+225 07 12 34 56 78','Disponible pour demain ?',              '08:15', 2, Color(0xFF006AFF), Icons.messenger_outline_sharp),
    ('MK', 'Marc K.',           'Pouvez-vous m\'envoyer le catalogue ?', 'Hier',  1, Color(0xFF25D366), Icons.sms),
    ('IC', 'Info Commande',     'Votre commande #1234 a été expédiée.',  'Lun.',  1, Color(0xFF010101), Icons.music_note),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      color: const Color(0xFFF7F8FA),
      child: SafeArea(
        child: Stack(
          children: [
            // ── Contenu principal ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Titre
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Centralisez toutes vos\n',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
                        ),
                        TextSpan(
                          text: 'conversations',
                          style: TextStyle(color: AppColors.green, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WhatsApp, SMS, Email, Facebook\net plus encore dans une seule inbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  ),

                  const SizedBox(height: 20),

                  // ── Mockup téléphone ────────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 10)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Column(
                          children: [
                            // Barre de statut simulée
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: const Row(
                                children: [
                                  Text('9:41', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Spacer(),
                                  Icon(Icons.signal_cellular_alt, size: 12, color: AppColors.textPrimary),
                                  SizedBox(width: 3),
                                  Icon(Icons.wifi, size: 12, color: AppColors.textPrimary),
                                  SizedBox(width: 3),
                                  Icon(Icons.battery_full, size: 12, color: AppColors.textPrimary),
                                ],
                              ),
                            ),
                            // Header Inbox
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: Row(
                                children: [
                                  const Text('Inbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const Spacer(),
                                  Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                                  const SizedBox(width: 14),
                                  Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5, color: AppColors.borderLight),
                            // 5 conversations
                            Expanded(
                              child: ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: _convos.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1, thickness: 0.5,
                                  indent: 60, color: AppColors.borderLight,
                                ),
                                itemBuilder: (_, i) => _InboxRow(data: _convos[i]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dots
                  _Dots(current: currentPage, count: 4),

                  const SizedBox(height: 16),

                  // Boutons Passer / Suivant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Passer', style: TextStyle(fontSize: 15)),
                      ),
                      ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Suivant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Bulles canaux flottantes autour du téléphone ─────────────────
            // WhatsApp — haut gauche
            Positioned(
              top: size.height * 0.22,
              left: 0,
              child: _ChannelBubble(color: const Color(0xFF25D366), icon: Icons.chat_bubble, size: 62),
            ),
            // Facebook — milieu gauche
            Positioned(
              top: size.height * 0.42,
              left: 0,
              child: _ChannelBubble(color: const Color(0xFF1877F2), icon: Icons.facebook, size: 62),
            ),
            // Chat/TikTok — bas gauche
            Positioned(
              top: size.height * 0.60,
              left: 4,
              child: _ChannelBubble(color: const Color(0xFF6C5CE7), icon: Icons.chat_rounded, size: 58),
            ),
            // Email — haut droite
            Positioned(
              top: size.height * 0.22,
              right: 0,
              child: _ChannelBubble(color: const Color(0xFF6C5CE7), icon: Icons.email_rounded, size: 62),
            ),
            // SMS — milieu droite
            Positioned(
              top: size.height * 0.44,
              right: 0,
              child: _ChannelBubble(color: const Color(0xFFF59E0B), label: 'SMS', size: 62),
            ),
          ],
        ),
      ),
    );
  }
}

// Ligne de conversation dans le mockup inbox
class _InboxRow extends StatelessWidget {
  final (String, String, String, String, int, Color, IconData) data;
  const _InboxRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final (initials, name, preview, time, badge, channelColor, channelIcon) = data;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + badge canal
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: channelColor.withValues(alpha: 0.12),
                child: Text(
                  initials.isEmpty ? '#' : initials,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: channelColor),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: channelColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: Icon(channelIcon, size: 8, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 2),
                Text(preview, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Badge non-lus violet
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
    );
  }
}

// Bulle canal flottante (grand cercle coloré avec icône blanche)
class _ChannelBubble extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? label;
  final double size;
  const _ChannelBubble({required this.color, this.icon, this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.46)
            : Text(label!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.28)),
      ),
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
