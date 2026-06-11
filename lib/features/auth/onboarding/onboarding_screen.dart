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

  static const _convos = [
    ('KY', 'Kouamé Yao',         'Bonjour, je suis intéressé...',        '09:41', 2, Color(0xFF25D366), Icons.chat_bubble),
    ('AN', "Awa N'Guessan",      'Merci pour la proposition.',            '09:32', 1, Color(0xFF6C5CE7), Icons.email),
    ('',   '+225 07 12 34 56 78','Disponible pour demain ?',              '08:15', 2, Color(0xFF006AFF), Icons.messenger_outline_sharp),
    ('MK', 'Marc K.',            "Pouvez-vous m'envoyer le catalogue ?",  'Hier',  1, Color(0xFF25D366), Icons.sms),
    ('IC', 'Info Commande',      'Votre commande #1234 a été expédiée.',  'Lun.',  1, Color(0xFF010101), Icons.music_note),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Largeur du mockup téléphone = 72% de l'écran
    final phoneW = size.width * 0.72;
    // Marge horizontale de chaque côté du téléphone
    final phoneMargin = (size.width - phoneW) / 2;

    return Container(
      color: const Color(0xFFF7F8FA),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Titre + description (ne pas toucher) ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
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
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Zone téléphone + bulles flottantes ────────────────────────────
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // ── Mockup iPhone centré ──────────────────────────────────
                  Center(
                    child: Container(
                      width: phoneW,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        // épaisseur bordure noire
                        padding: const EdgeInsets.all(7),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: Container(
                            color: Colors.white,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Notch + status bar
                                _PhoneStatusBar(),
                                // Header Inbox
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                                  child: Row(
                                    children: [
                                      const Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      const Spacer(),
                                      const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, thickness: 0.5, color: AppColors.borderLight),
                                // 5 conversations
                                ...List.generate(_convos.length, (i) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _InboxRow(data: _convos[i]),
                                    if (i < _convos.length - 1)
                                      const Divider(height: 1, thickness: 0.5, indent: 54, color: AppColors.borderLight),
                                  ],
                                )),
                                // Home indicator
                                const SizedBox(height: 6),
                                Center(
                                  child: Container(
                                    width: 40, height: 4,
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Bulles flottantes AUTOUR du téléphone ────────────────
                  // WhatsApp vert — haut gauche (déborde à gauche du téléphone)
                  Positioned(
                    top: 10,
                    left: phoneMargin - 46,
                    child: _ChannelBubble(color: const Color(0xFF25D366), icon: Icons.call, size: 68),
                  ),
                  // Facebook bleu — milieu gauche
                  Positioned(
                    top: 140,
                    left: phoneMargin - 52,
                    child: _ChannelBubble(color: const Color(0xFF1877F2), icon: Icons.facebook, size: 68),
                  ),
                  // Chat violet — bas gauche
                  Positioned(
                    top: 270,
                    left: phoneMargin - 42,
                    child: _ChannelBubble(color: const Color(0xFF6C5CE7), icon: Icons.chat_bubble_rounded, size: 62),
                  ),
                  // Email violet — haut droite
                  Positioned(
                    top: 10,
                    right: phoneMargin - 46,
                    child: _ChannelBubble(color: const Color(0xFF6C5CE7), icon: Icons.email_rounded, size: 68),
                  ),
                  // SMS orange — milieu droite
                  Positioned(
                    top: 155,
                    right: phoneMargin - 52,
                    child: _ChannelBubble(color: const Color(0xFFF59E0B), label: 'SMS', size: 68),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Dots ─────────────────────────────────────────────────────────
            _Dots(current: currentPage, count: 4),

            const SizedBox(height: 16),

            // ── Boutons Passer / Suivant (ne pas toucher) ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Barre de statut iPhone simulée avec notch
class _PhoneStatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notch centré
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 18,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          // Status bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: const [
                Text('9:41', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Spacer(),
                Icon(Icons.signal_cellular_alt, size: 10, color: AppColors.textPrimary),
                SizedBox(width: 2),
                Icon(Icons.wifi, size: 10, color: AppColors.textPrimary),
                SizedBox(width: 2),
                Icon(Icons.battery_full, size: 10, color: AppColors.textPrimary),
              ],
            ),
          ),
        ],
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

// Bulle canal flottante — cercle coloré avec ombre et icône/texte blanc
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
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.48)
            : Text(label!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.27)),
      ),
    );
  }
}

// ── Slide 3 : Analytics ───────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Titre
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(text: 'Comprenez ', style: TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
                    TextSpan(text: 'ce qui\nfait grandir votre business', style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Des tableaux de bord clairs pour suivre\nvos performances en temps réel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),

              // ── Layout exact de l'image 1 : col gauche + col droite ──────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colonne gauche : 3 cards métriques empilées
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // Card Revenus grande
                          _StatCard(
                            label: 'Revenus',
                            value: '1 250 000\nFCFA',
                            growth: '+18.5%',
                            showChart: true,
                            chartColor: AppColors.green,
                          ),
                          const SizedBox(height: 10),
                          // Card Conversations petite
                          _StatCard(
                            label: 'Conversations',
                            value: '324',
                            growth: '+12.3%',
                            showChart: true,
                            chartColor: AppColors.primary,
                          ),
                          const SizedBox(height: 10),
                          // Card Taux de réponse petite
                          _StatCard(
                            label: 'Taux de réponse',
                            value: '92%',
                            growth: '+7.1%',
                            showChart: false,
                            chartColor: AppColors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Colonne droite : card donut
                    Expanded(
                      flex: 6,
                      child: _DonutCard(),
                    ),
                  ],
                ),
              ),

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
      ),
    );
  }
}

// Card métrique (Revenus / Conversations / Taux de réponse)
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String growth;
  final bool showChart;
  final Color chartColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.growth,
    required this.showChart,
    required this.chartColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.15)),
              ),
              if (showChart) ...[
                SizedBox(
                  width: 36, height: 24,
                  child: CustomPaint(painter: _MiniChartPainter(color: chartColor)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(growth, style: TextStyle(fontSize: 11, color: chartColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// Mini graphique courbe tendance haussière
class _MiniChartPainter extends CustomPainter {
  final Color color;
  const _MiniChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..cubicTo(size.width * 0.2, size.height * 0.70, size.width * 0.4, size.height * 0.50, size.width * 0.5, size.height * 0.40)
      ..cubicTo(size.width * 0.6, size.height * 0.30, size.width * 0.8, size.height * 0.15, size.width, size.height * 0.05);

    canvas.drawPath(path, paint);

    // Petite flèche en haut à droite
    canvas.drawLine(Offset(size.width - 6, size.height * 0.05), Offset(size.width, size.height * 0.05), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// Card donut "Conversations par canal"
class _DonutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conversations\npar canal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary, height: 1.3)),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 80, height: 80,
              child: CustomPaint(painter: _DonutPainter()),
            ),
          ),
          const SizedBox(height: 12),
          const _LegendItem(color: Color(0xFF22C55E), label: 'WhatsApp', pct: '45%'),
          const _LegendItem(color: Color(0xFF3B82F6), label: 'SMS',      pct: '20%'),
          const _LegendItem(color: Color(0xFF8B5CF6), label: 'Email',    pct: '20%'),
          const _LegendItem(color: Color(0xFFF59E0B), label: 'Facebook', pct: '10%'),
          const _LegendItem(color: Color(0xFFEC4899), label: 'Instagram',pct: '5%'),
        ],
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

// ── Slide 4 : Passez à l'action ──────────────────────────────────────────────

class _Slide4 extends StatelessWidget {
  final VoidCallback onFinish;
  final int currentPage;

  const _Slide4({required this.onFinish, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A6B3A), Color(0xFF1E9E5E)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 28),

            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Décidez ',
                      style: TextStyle(color: Color(0xFFB9F5D8), fontSize: 28, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    TextSpan(
                      text: 'avec des insights\nexploitables et finançables',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Transformez vos données en actions\net accédez à plus d\'opportunités.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 14, height: 1.5),
              ),
            ),

            const SizedBox(height: 16),

            // Zone centrale : homme + 4 cards flottantes
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Image homme centrée
                  Positioned(
                    bottom: 0,
                    child: Image.asset(
                      'design/image_onboarding4.png',
                      height: size.height * 0.48,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Card Insights — haut gauche
                  Positioned(
                    top: size.height * 0.01,
                    left: 16,
                    child: _FloatingFeatureCard(
                      icon: Icons.bar_chart_rounded,
                      label: 'Insights',
                      iconColor: AppColors.green,
                    ),
                  ),

                  // Card Décisions — haut droite
                  Positioned(
                    top: size.height * 0.01,
                    right: 16,
                    child: _FloatingFeatureCard(
                      icon: Icons.track_changes_rounded,
                      label: 'Décisions',
                      iconColor: AppColors.primary,
                    ),
                  ),

                  // Card Croissance — bas gauche
                  Positioned(
                    bottom: size.height * 0.10,
                    left: 16,
                    child: _FloatingFeatureCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Croissance',
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ),

                  // Card Financement — bas droite
                  Positioned(
                    bottom: size.height * 0.10,
                    right: 16,
                    child: _FloatingFeatureCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Financement',
                      iconColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),

            // Dots
            _Dots(
              current: currentPage,
              count: 4,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 20),

            // Bouton Commencer maintenant — vert pleine largeur
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.green,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Commencer maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lien Se connecter
            GestureDetector(
              onTap: onFinish,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Vous avez déjà un compte ? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
                    const TextSpan(text: 'Se connecter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// Card feature flottante (slide 4)
class _FloatingFeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _FloatingFeatureCard({required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
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
