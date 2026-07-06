import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';
import 'pin_storage.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_keypad.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  static const _pinLength = 5;

  String _input = '';
  bool _error = false;
  bool _isLoading = false;
  bool? _isSetupMode; // null = encore en cours de chargement

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    PinStorage.hasPinSet().then((has) {
      if (mounted) setState(() => _isSetupMode = !has);
    });
  }

  void _onKey(String digit) {
    if (_input.length >= _pinLength || _isLoading) return;
    setState(() {
      _input += digit;
      _error = false;
    });
    if (_input.length == _pinLength) _verify();
  }

  void _onDelete() {
    if (_input.isEmpty || _isLoading) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);

    if (_isSetupMode == true) {
      // Premier login : envoie le PIN au serveur, puis le sauvegarde localement.
      try {
        await authService.setPin(_input);
        await PinStorage.savePin(_input);
        SessionService.validatePin();
        if (mounted) context.go('/inbox');
      } catch (_) {
        _shakeController.forward(from: 0);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(AppSnackbar.error('Impossible de définir le PIN. Réessayez.'));
          setState(() { _error = true; _input = ''; _isLoading = false; });
        }
      }
    } else {
      // Retour en session : vérifie le hash local.
      final ok = await PinStorage.checkPin(_input);
      if (ok) {
        SessionService.validatePin();
        if (mounted) context.go('/inbox');
      } else {
        _shakeController.forward(from: 0);
        if (mounted) setState(() { _error = true; _input = ''; _isLoading = false; });
      }
    }
  }

  void _onForgotPin() {
    final router = GoRouter.of(context);
    SessionService.logout();
    PinStorage.clearPin();
    router.go('/login');
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = _isSetupMode == true;
    final subtitle = isSetup
        ? 'Choisissez un code PIN à 5 chiffres'
        : 'Entrez votre code PIN';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 64),

                _Avatar(initials: _initials(SessionService.displayName ?? '')),
                const SizedBox(height: 16),

                Text(SessionService.displayName ?? '', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(subtitle, style: AppTextStyles.bodySecondary),

                const SizedBox(height: 44),

                if (_isSetupMode == null)
                  const CircularProgressIndicator(color: AppColors.green)
                else ...[
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
                    child: PinDots(filled: _input.length, total: _pinLength, hasError: _error),
                  ),

                  if (_error) ...[
                    const SizedBox(height: 10),
                    Text(
                      isSetup ? 'Erreur. Réessayez.' : 'Code incorrect, réessayez.',
                      style: AppTextStyles.small.copyWith(color: Colors.redAccent),
                    ),
                  ],

                  const SizedBox(height: 48),

                  PinKeypad(onKey: _onKey, onDelete: _onDelete),

                  const SizedBox(height: 24),

                  if (!isSetup)
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
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts[0].isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
}

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
