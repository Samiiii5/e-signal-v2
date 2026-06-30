import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/mock/users_mock.dart';

class LoginPage1Screen extends StatefulWidget {
  const LoginPage1Screen({super.key});

  @override
  State<LoginPage1Screen> createState() => _LoginPage1ScreenState();
}

class _LoginPage1ScreenState extends State<LoginPage1Screen> {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isLoading = false;
  String? _error;

  // Pays disponibles (extensible)
  _Country _selectedCountry = _countries[0];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _fullPhone => '${_selectedCountry.dialCode}${_phoneController.text.trim()}';

  Future<void> _onNext() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final exists = await authService.checkPhone(_fullPhone);
      if (!mounted) return;
      if (exists) {
        context.go('/login/password', extra: _fullPhone);
      } else {
        setState(() => _error = 'Aucun compte associé à ce numéro.');
      }
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _phoneController.text.trim().length >= 8 && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 52),

              // Logo eS
              const _ESignalLogo(),

              const SizedBox(height: 40),

              Text('Bienvenue', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour accéder à votre messagerie.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 40),

              // Label
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Numéro de téléphone', style: AppTextStyles.label),
              ),
              const SizedBox(height: 8),

              // Champ téléphone
              _PhoneField(
                controller: _phoneController,
                focusNode: _focusNode,
                isFocused: _isFocused,
                selectedCountry: _selectedCountry,
                onCountryChanged: (c) => setState(() => _selectedCountry = c),
                onChanged: (_) => setState(() => _error = null),
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

              // Bouton Suivant
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onNext : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text('Suivant', style: AppTextStyles.buttonPrimary),
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
      height: 120,
      fit: BoxFit.contain,
    );
  }
}

// ─── Champ téléphone ──────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final _Country selectedCountry;
  final ValueChanged<_Country> onCountryChanged;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.onChanged,
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
      child: Row(
        children: [
          // Sélecteur de pays
          _CountryPicker(
            selected: selectedCountry,
            onChanged: onCountryChanged,
          ),

          // Séparateur
          Container(width: 1, height: 24, color: AppColors.borderLight),

          // Input numéro
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: '07 00 00 00 00',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sélecteur de pays ────────────────────────────────────────────────────────

class _CountryPicker extends StatelessWidget {
  final _Country selected;
  final ValueChanged<_Country> onChanged;

  const _CountryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Country>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.white,
      offset: const Offset(0, 44),
      itemBuilder: (_) => _countries
          .map((c) => PopupMenuItem(
                value: c,
                child: Row(
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text(c.dialCode, style: AppTextStyles.body),
                    const SizedBox(width: 6),
                    Text(c.name, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(selected.dialCode, style: AppTextStyles.label),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Données pays ─────────────────────────────────────────────────────────────

class _Country {
  final String flag;
  final String name;
  final String dialCode;
  const _Country({required this.flag, required this.name, required this.dialCode});
}

const _countries = [
  _Country(flag: '🇨🇮', name: 'Côte d\'Ivoire', dialCode: '+225'),
  _Country(flag: '🇸🇳', name: 'Sénégal', dialCode: '+221'),
  _Country(flag: '🇲🇱', name: 'Mali', dialCode: '+223'),
  _Country(flag: '🇧🇫', name: 'Burkina Faso', dialCode: '+226'),
  _Country(flag: '🇨🇲', name: 'Cameroun', dialCode: '+237'),
];
