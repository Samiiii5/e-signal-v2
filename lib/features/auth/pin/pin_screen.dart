import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'pin_storage.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_keypad.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  String _input = '';
  String _initials = '?';
  String _displayName = '';
  bool _error = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  Future<void> _loadUser() async {
    final name = await PinStorage.getDisplayName();
    final initials = await PinStorage.getInitials();
    if (mounted) {
      setState(() {
        _displayName = name ?? '';
        _initials = initials;
      });
    }
  }

  Future<void> _onKey(String digit) async {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = false;
    });
    if (_input.length == 4) await _verify();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _verify() async {
    final ok = await PinStorage.checkPin(_input);
    if (!mounted) return;
    if (ok) {
      context.go('/inbox');
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _error = true;
        _input = '';
      });
    }
  }

  Future<void> _onForgotPin() async {
    await PinStorage.clearPin();
    if (!mounted) return;
    context.go('/pin/setup');
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 64),

              // Avatar initiales
              _Avatar(initials: _initials),
              const SizedBox(height: 16),

              // Prénom
              if (_displayName.isNotEmpty)
                Text(_displayName, style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Entrez votre code PIN',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 44),

              // 4 dots avec shake si erreur
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) {
                  final offset = _error
                      ? 10 * (0.5 - (_shakeAnimation.value % 0.5)).abs()
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset * (_shakeAnimation.value > 0.5 ? 1 : -1), 0),
                    child: child,
                  );
                },
                child: PinDots(filled: _input.length, hasError: _error),
              ),

              if (_error) ...[
                const SizedBox(height: 10),
                Text(
                  'Code incorrect, réessayez.',
                  style: AppTextStyles.small.copyWith(color: Colors.redAccent),
                ),
              ],

              const Spacer(),

              // Pavé numérique
              PinKeypad(onKey: _onKey, onDelete: _onDelete),

              const SizedBox(height: 24),

              // Code PIN oublié
              TextButton(
                onPressed: _onForgotPin,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: Colors.transparent,
                ),
                child: Text(
                  'Code PIN oublié ?',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.greenLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.green,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
