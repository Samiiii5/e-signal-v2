import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/mock/users_mock.dart';

class LoginPage2Screen extends StatefulWidget {
  final String phone;
  const LoginPage2Screen({super.key, required this.phone});

  @override
  State<LoginPage2Screen> createState() => _LoginPage2ScreenState();
}

class _LoginPage2ScreenState extends State<LoginPage2Screen> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await authService.login(widget.phone, _passwordController.text);
      if (!mounted) return;
      context.go('/inbox');
    } catch (_) {
      setState(() => _error = 'Mot de passe incorrect. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onForgotPassword() async {
    await authService.forgotPassword(widget.phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Un lien de réinitialisation a été envoyé.',
          style: AppTextStyles.small.copyWith(color: AppColors.white),
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _passwordController.text.isNotEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Logo
              const _ESignalLogo(),

              const SizedBox(height: 32),

              Text('Votre mot de passe', style: AppTextStyles.h1),
              const SizedBox(height: 8),

              // Numéro masqué
              Text(
                _maskedPhone(widget.phone),
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 40),

              // Label
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Mot de passe', style: AppTextStyles.label),
              ),
              const SizedBox(height: 8),

              // Champ mot de passe
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isFocused ? AppColors.greenLight : AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFocused ? AppColors.green : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _passwordController,
                  focusNode: _focusNode,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() => _error = null),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) { if (canSubmit) _onLogin(); },
                ),
              ),

              // Erreur
              if (_error != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: AppTextStyles.small.copyWith(color: Colors.redAccent),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Bouton Se connecter
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onLogin : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text('Se connecter', style: AppTextStyles.buttonPrimary),
                ),
              ),

              const SizedBox(height: 20),

              // Mot de passe oublié
              TextButton(
                onPressed: _onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                child: Text(
                  'Mot de passe oublié ?',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskedPhone(String phone) {
    if (phone.length <= 6) return phone;
    final visible = phone.substring(phone.length - 4);
    final masked = '•' * (phone.length - 4);
    return '$masked$visible';
  }
}

// ─── Logo (partagé) ───────────────────────────────────────────────────────────

class _ESignalLogo extends StatelessWidget {
  const _ESignalLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.onboardingGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'eS',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
