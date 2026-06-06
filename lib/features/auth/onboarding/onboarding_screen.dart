import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/session_service.dart';
import 'painters/slide1_painter.dart';
import 'painters/slide2_painter.dart';
import 'painters/slide3_painter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      title: 'Tous vos messages, un seul endroit',
      body: 'Centralisez WhatsApp, TikTok, SMS, Facebook et Email dans une inbox unique.',
    ),
    _SlideData(
      title: 'Pilotez votre activité',
      body: 'Visualisez vos statistiques en temps réel : messages reçus, canal préféré, temps de réponse moyen.',
    ),
    _SlideData(
      title: 'Encaissez depuis vos conversations',
      body: 'Générez un lien de paiement Wave ou Orange Money directement dans la conversation.',
    ),
  ];

  void _finish() {
    SessionService.markOnboardingSeen();
    context.go('/login');
  }

  void _next() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.onboardingGradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Bouton Passer — haut à droite
              Positioned(
                top: 8,
                right: 20,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

              // Contenu principal
              Column(
                children: [
                  const SizedBox(height: 48),

                  // Illustration
                  Expanded(
                    flex: 5,
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: const [
                        _IllustrationFrame(painter: Slide1Painter()),
                        _IllustrationFrame(painter: Slide2Painter()),
                        _IllustrationFrame(painter: Slide3Painter()),
                      ],
                    ),
                  ),

                  // Texte
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _SlideText(
                          key: ValueKey(_currentPage),
                          slide: _slides[_currentPage],
                        ),
                      ),
                    ),
                  ),

                  // Dots + Bouton
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                    child: Column(
                      children: [
                        _DotsIndicator(current: _currentPage, count: 3),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: AppColors.green,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 52),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentPage == 2 ? 'Commencer' : 'Suivant',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sous-widgets ───────────────────────────────────────────────

class _SlideData {
  final String title;
  final String body;
  const _SlideData({required this.title, required this.body});
}

class _IllustrationFrame extends StatelessWidget {
  final CustomPainter painter;
  const _IllustrationFrame({required this.painter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: CustomPaint(
        painter: painter,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  final _SlideData slide;
  const _SlideText({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.greenLight,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int current;
  final int count;
  const _DotsIndicator({required this.current, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.white : AppColors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
