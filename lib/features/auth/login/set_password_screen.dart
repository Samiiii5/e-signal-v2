import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Affiché lorsque le serveur retourne 403 :
/// le compte existe mais n'a pas encore de mot de passe défini.
class SetPasswordScreen extends StatefulWidget {
  final String phone;
  const SetPasswordScreen({super.key, required this.phone});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validate() {
    final pass    = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
    if (pass != confirm)  return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  Future<void> _onSubmit() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }

    setState(() { _error = null; _isLoading = true; });
    try {
      // TODO: appeler l'endpoint de définition de mot de passe
      // await authService.setPassword(widget.phone, _passwordCtrl.text);
      await Future.delayed(const Duration(milliseconds: 800)); // simulé
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mot de passe créé avec succès. Connectez-vous.',
            style: AppTextStyles.small.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      context.go('/login/password', extra: widget.phone);
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _passwordCtrl.text.isNotEmpty &&
        _confirmCtrl.text.isNotEmpty &&
        !_isLoading;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Logo centré
              Center(
                child: Image.asset(
                  'design/logo_onboarding.png',
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),

              Text('Définir votre mot de passe', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Votre compte est prêt. Créez un mot de passe pour y accéder.',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 32),

              // Champ mot de passe
              Text('Mot de passe', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _PasswordField(
                controller: _passwordCtrl,
                focusNode: _passFocus,
                obscure: _obscurePass,
                hint: 'Minimum 8 caractères',
                onToggle: () => setState(() => _obscurePass = !_obscurePass),
                onChanged: (_) => setState(() => _error = null),
              ),

              const SizedBox(height: 16),

              // Champ confirmation
              Text('Confirmer le mot de passe', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _PasswordField(
                controller: _confirmCtrl,
                focusNode: _confirmFocus,
                obscure: _obscureConfirm,
                hint: 'Répétez votre mot de passe',
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) { if (canSubmit) _onSubmit(); },
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AppTextStyles.small.copyWith(color: Colors.redAccent),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onSubmit : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text('Créer mon mot de passe', style: AppTextStyles.buttonPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Champ mot de passe réutilisable ──────────────────────────────────────────

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final String hint;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.hint,
    required this.onToggle,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _focused ? AppColors.greenLight : AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? AppColors.green : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: IconButton(
            icon: Icon(
              widget.obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: widget.onToggle,
          ),
        ),
      ),
    );
  }
}
