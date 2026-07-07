import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String identifier;
  const OtpScreen({super.key, required this.identifier});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onResend() async {
    setState(() => _isResending = true);
    try {
      await authService.requestOtp(widget.identifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.success('Code renvoyé.'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Impossible de renvoyer le code. Réessayez.'),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onVerify() {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) return;
    context.push('/reset-password', extra: <String, String>{
      'identifier': widget.identifier,
      'otp_code': otp,
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _otpCtrl.text.trim().length >= 4;

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

              Text('Vérification', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Entrez le code reçu sur votre email.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Code de vérification', style: AppTextStyles.label),
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
                  controller: _otpCtrl,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 12,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) { if (canSubmit) _onVerify(); },
                  style: AppTextStyles.body.copyWith(letterSpacing: 4),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14, letterSpacing: 4),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onVerify : null,
                  child: Text('Vérifier', style: AppTextStyles.buttonPrimary),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _isResending ? null : _onResend,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                child: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                      )
                    : Text(
                        'Renvoyer le code',
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
