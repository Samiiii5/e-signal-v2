import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';

class LoginPage2Screen extends StatefulWidget {
  final String identifier;
  const LoginPage2Screen({super.key, required this.identifier});

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
    setState(() { _error = null; _isLoading = true; });
    final router = GoRouter.of(context);
    try {
      final result = await authService.login(
        widget.identifier,
        _passwordController.text,
      );
      await SessionService.saveAuthResult(result);

      // Récupère l'organization_id depuis /auth/me
      final orgId = await authService.getMe();
      if (orgId != null) await SessionService.saveOrganizationId(orgId);

      if (!mounted) return;
      router.go('/pin');
    } on AccountNotActivatedException {
      if (!mounted) return;
      router.push('/login/set-password', extra: widget.identifier);
    } on BadRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackbar.error(e.message));
    } on ValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackbar.error(e.message));
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackbar.error('Erreur serveur (502). Réessayez dans quelques instants.'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackbar.error('Mot de passe incorrect. Réessayez.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onForgotPassword() async {
    try {
      await authService.forgotPassword(widget.identifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.success('Un lien de réinitialisation a été envoyé.'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Impossible d\'envoyer le lien. Réessayez.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _passwordController.text.isNotEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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

              const _ESignalLogo(),
              const SizedBox(height: 32),

              Text('Votre mot de passe', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                _maskedIdentifier(widget.identifier),
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Mot de passe', style: AppTextStyles.label),
              ),
              const SizedBox(height: 8),

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

  String _maskedIdentifier(String id) {
    if (id.contains('@')) {
      // Email : masque la partie locale sauf les 2 premiers caractères.
      final parts = id.split('@');
      final local = parts[0];
      final domain = parts[1];
      if (local.length <= 2) return id;
      return '${local.substring(0, 2)}${'•' * (local.length - 2)}@$domain';
    }
    // Numéro : masque tout sauf les 4 derniers chiffres.
    if (id.length <= 4) return id;
    return '${'•' * (id.length - 4)}${id.substring(id.length - 4)}';
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _ESignalLogo extends StatelessWidget {
  const _ESignalLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset('design/logo_onboarding.png', height: 120, fit: BoxFit.contain);
  }
}
