import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await authService.requestOtp(identifier);
      if (!mounted) return;
      context.push('/otp-verification', extra: <String, String>{'identifier': identifier});
    } on BadRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error(e.message));
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Erreur serveur. Réessayez dans quelques instants.'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Une erreur est survenue. Réessayez.'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _identifierCtrl.text.trim().length >= 3 && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              Image.asset('design/logo_onboarding.png', height: 90, fit: BoxFit.contain),
              const SizedBox(height: 32),

              Text('Mot de passe oublié', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Entrez votre email ou numéro de téléphone pour recevoir un code de vérification.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Identifiant', style: AppTextStyles.label),
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
                  controller: _identifierCtrl,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) { if (canSubmit) _onSend(); },
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    hintText: 'email@exemple.com ou +225...',
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onSend : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text('Envoyer le code', style: AppTextStyles.buttonPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
