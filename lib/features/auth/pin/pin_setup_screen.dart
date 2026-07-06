import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';
import 'pin_storage.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_keypad.dart';

/// Affiché au premier login (aucun PIN en mémoire) ou après réinitialisation.
/// Deux étapes : saisie → confirmation → appel POST /auth/set-pin.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _pinLength = 5;

  String _input = '';
  String? _firstPin;
  bool _confirming = false;
  bool _mismatch = false;
  bool _isLoading = false;

  void _onKey(String digit) {
    if (_input.length >= _pinLength || _isLoading) return;
    setState(() {
      _input += digit;
      _mismatch = false;
    });
    if (_input.length == _pinLength) _onComplete();
  }

  void _onDelete() {
    if (_input.isEmpty || _isLoading) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _firstPin = _input;
        _input = '';
        _confirming = true;
      });
    } else {
      if (_input == _firstPin) {
        setState(() => _isLoading = true);
        try {
          await authService.setPin(_input);
          await PinStorage.savePin(_input);
          if (mounted) context.go('/inbox');
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(AppSnackbar.error('Impossible de définir le PIN. Réessayez.'));
            _restart();
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        setState(() {
          _mismatch = true;
          _input = '';
        });
      }
    }
  }

  void _restart() {
    setState(() {
      _input = '';
      _firstPin = null;
      _confirming = false;
      _mismatch = false;
    });
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

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.onboardingGradient,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(Icons.lock_outline, color: AppColors.white, size: 28),
                ),
              ),

              const SizedBox(height: 28),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_confirming),
                  children: [
                    Text(
                      _confirming ? 'Confirmez votre PIN' : 'Choisissez un code PIN',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _confirming
                          ? 'Saisissez à nouveau votre code à $_pinLength chiffres.'
                          : 'Ce code vous sera demandé à chaque ouverture.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 44),

              PinDots(filled: _input.length, total: _pinLength, hasError: _mismatch),

              if (_mismatch) ...[
                const SizedBox(height: 12),
                Text(
                  'Les codes ne correspondent pas.',
                  style: AppTextStyles.small.copyWith(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _restart,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.green,
                    backgroundColor: Colors.transparent,
                  ),
                  child: Text('Recommencer', style: AppTextStyles.small.copyWith(color: AppColors.green)),
                ),
              ],

              const Spacer(),

              PinKeypad(onKey: _onKey, onDelete: _onDelete),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
