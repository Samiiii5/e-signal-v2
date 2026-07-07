import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';

class LoginPage1Screen extends StatefulWidget {
  const LoginPage1Screen({super.key});

  @override
  State<LoginPage1Screen> createState() => _LoginPage1ScreenState();
}

class _LoginPage1ScreenState extends State<LoginPage1Screen> {
  final _identifierController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onNext() {
    final id = _identifierController.text.trim();
    if (id.length < 3) {
      setState(() => _error = 'Saisissez au moins 3 caractères.');
      return;
    }
    context.go('/login/password', extra: id);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _identifierController.text.trim().length >= 3;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: Responsive.hpad(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: Responsive.vspaceLarge(context)),

              _ESignalLogo(),

              SizedBox(height: Responsive.vspace(context)),

              Text('Bienvenue', style: AppTextStyles.h1),
              SizedBox(height: Responsive.vspaceSmall(context) * 0.5),
              Text(
                'Connectez-vous pour accéder à votre messagerie.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),

              SizedBox(height: Responsive.vspace(context)),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Identifiant', style: AppTextStyles.label),
              ),
              const SizedBox(height: 8),

              _IdentifierField(
                controller: _identifierController,
                focusNode: _focusNode,
                isFocused: _isFocused,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) { if (canSubmit) _onNext(); },
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

              SizedBox(height: Responsive.vspace(context)),

              SizedBox(
                width: double.infinity,
                height: Responsive.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: canSubmit ? _onNext : null,
                  child: Text('Suivant', style: AppTextStyles.buttonPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _ESignalLogo extends StatelessWidget {
  const _ESignalLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'design/logo_onboarding.png',
      height: Responsive.logoHeight(context),
      fit: BoxFit.contain,
    );
  }
}

// ─── Champ identifiant ────────────────────────────────────────────────────────

class _IdentifierField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const _IdentifierField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isFocused ? AppColors.greenLight : AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? AppColors.green : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        style: AppTextStyles.body,
        decoration: const InputDecoration(
          hintText: 'Email ou numéro de téléphone',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
