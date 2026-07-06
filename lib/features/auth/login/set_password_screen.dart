import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/services/auth_service.dart';

/// Affiché quand le serveur retourne 403 (compte INVITED).
/// L'utilisateur saisit le mot de passe temporaire reçu par email
/// et choisit un nouveau mot de passe pour activer son compte.
class SetPasswordScreen extends StatefulWidget {
  final String identifier;
  const SetPasswordScreen({super.key, required this.identifier});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _tempCtrl    = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _tempFocus    = FocusNode();
  final _newFocus     = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscureTemp    = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _error;

  @override
  void dispose() {
    _tempCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _tempFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_tempCtrl.text.isEmpty) return 'Saisissez votre mot de passe temporaire.';
    if (_newCtrl.text.length < 8) return 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
    if (_newCtrl.text != _confirmCtrl.text) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  Future<void> _onSubmit() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }

    setState(() { _error = null; _isLoading = true; });
    try {
      final result = await authService.firstLogin(
        widget.identifier,
        _tempCtrl.text,
        _newCtrl.text,
      );
      await SessionService.saveAuthResult(result);

      final orgId = await authService.getMe();
      if (orgId != null) await SessionService.saveOrganizationId(orgId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.success('Compte activé. Choisissez votre code PIN.'),
      );
      context.go('/pin');
    } on BadRequestException catch (e) {
      setState(() => _error = e.message);
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    } on ServerException {
      setState(() => _error = 'Erreur serveur. Réessayez dans quelques instants.');
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Vérifiez votre mot de passe temporaire.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _tempCtrl.text.isNotEmpty &&
        _newCtrl.text.isNotEmpty &&
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

              Center(
                child: Image.asset('design/logo_onboarding.png', height: 90, fit: BoxFit.contain),
              ),
              const SizedBox(height: 32),

              Text('Activer votre compte', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Saisissez le mot de passe temporaire reçu par email, puis choisissez un nouveau mot de passe.',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 20),

              // Identifiant pré-rempli (lecture seule) — l'utilisateur sait pour quel compte.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.identifier,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text('Mot de passe temporaire', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _PasswordField(
                controller: _tempCtrl,
                focusNode: _tempFocus,
                obscure: _obscureTemp,
                hint: 'Reçu par email',
                onToggle: () => setState(() => _obscureTemp = !_obscureTemp),
                onChanged: (_) => setState(() => _error = null),
              ),

              const SizedBox(height: 16),

              Text('Nouveau mot de passe', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _PasswordField(
                controller: _newCtrl,
                focusNode: _newFocus,
                obscure: _obscureNew,
                hint: 'Minimum 8 caractères',
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                onChanged: (_) => setState(() => _error = null),
              ),

              const SizedBox(height: 16),

              Text('Confirmer le nouveau mot de passe', style: AppTextStyles.label),
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
                      : Text('Activer mon compte', style: AppTextStyles.buttonPrimary),
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
