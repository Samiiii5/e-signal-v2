import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'pin_storage.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_keypad.dart';

/// Affiché au premier login (aucun PIN en mémoire) ou après réinitialisation.
/// Deux étapes : saisie → confirmation.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _input = '';
  String? _firstPin;
  bool _confirming = false;
  bool _mismatch = false;

  void _onKey(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _mismatch = false;
    });
    if (_input.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      // Étape 1 — mémorise et passe à la confirmation
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _firstPin = _input;
        _input = '';
        _confirming = true;
      });
    } else {
      // Étape 2 — confirme
      if (_input == _firstPin) {
        await PinStorage.savePin(_input);
        if (!mounted) return;
        context.go('/inbox');
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

              // Logo
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
                          ? 'Saisissez à nouveau votre code à 4 chiffres.'
                          : 'Ce code vous sera demandé à chaque ouverture.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 44),

              // Dots
              PinDots(filled: _input.length, hasError: _mismatch),

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
