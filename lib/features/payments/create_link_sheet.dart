import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/delivery_mock.dart';
import '../../shared/mock/payments_mock.dart';
import '../../shared/services/payment_service.dart';

class CreateLinkSheet extends StatefulWidget {
  const CreateLinkSheet({super.key});

  @override
  State<CreateLinkSheet> createState() => _CreateLinkSheetState();
}

class _CreateLinkSheetState extends State<CreateLinkSheet> {
  final _contactController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();

  Deliverer? _selectedDeliverer;
  PaymentMethod _method = PaymentMethod.wave;
  bool _isLoading = false;
  String? _generatedUrl;

  int get _orderAmount {
    final v = int.tryParse(_amountController.text.replaceAll(' ', ''));
    return v ?? 0;
  }

  int get _deliveryFee => _selectedDeliverer?.feeEstimate ?? 0;
  int get _total => _orderAmount + _deliveryFee;

  bool get _canSubmit =>
      _contactController.text.trim().isNotEmpty &&
      _descController.text.trim().isNotEmpty &&
      _orderAmount > 0 &&
      !_isLoading;

  @override
  void dispose() {
    _contactController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _isLoading = true);
    try {
      final link = await paymentService.createPaymentLink(CreatePaymentLinkDto(
        contactName: _contactController.text.trim(),
        description: _descController.text.trim(),
        amount: _total,
        paymentMethod: _method,
      ));
      if (!mounted) return;
      setState(() {
        _generatedUrl =
            'https://pay.esignal.ci/${link.id}?m=${_method.name}&a=${link.amount}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée + titre
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Nouveau lien de paiement', style: AppTextStyles.h2),
          const SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              child: _generatedUrl != null
                  ? _SuccessView(
                      url: _generatedUrl!,
                      onClose: () => Navigator.of(context).pop(
                        paymentService is MockPaymentService
                            ? null // le mock a déjà ajouté le lien
                            : null,
                      ),
                      onDone: () => Navigator.of(context).pop(true),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact
                        _Label('Nom du client'),
                        _Field(controller: _contactController, hint: 'ex : Awa N\'Guessan'),
                        const SizedBox(height: 14),

                        // Description
                        _Label('Description du produit'),
                        _Field(controller: _descController, hint: 'ex : Robe ankara taille M'),
                        const SizedBox(height: 14),

                        // Adresse livraison
                        _Label('Adresse de livraison'),
                        _Field(
                          controller: _addressController,
                          hint: 'ex : Cocody Riviera 3, Abidjan',
                        ),
                        const SizedBox(height: 14),

                        // Choix livreur
                        _Label('Choisir un livreur'),
                        const SizedBox(height: 8),
                        ...mockDeliverers.map((d) => _DelivererTile(
                              deliverer: d,
                              selected: _selectedDeliverer?.id == d.id,
                              onTap: () => setState(
                                  () => _selectedDeliverer =
                                      _selectedDeliverer?.id == d.id ? null : d),
                            )),
                        const SizedBox(height: 14),

                        // Montant commande
                        _Label('Montant commande (FCFA)'),
                        _Field(
                          controller: _amountController,
                          hint: 'ex : 25000',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // Méthode
                        _Label('Méthode de paiement'),
                        const SizedBox(height: 8),
                        _MethodSelector(
                          selected: _method,
                          onChanged: (m) => setState(() => _method = m),
                        ),
                        const SizedBox(height: 16),

                        // Récapitulatif total
                        if (_orderAmount > 0 || _deliveryFee > 0)
                          _TotalCard(
                            orderAmount: _orderAmount,
                            deliveryFee: _deliveryFee,
                            total: _total,
                          ),

                        const SizedBox(height: 20),

                        // Bouton générer
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _generate : null,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: AppColors.white, strokeWidth: 2.5),
                                  )
                                : Text('Générer le lien', style: AppTextStyles.buttonPrimary),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vue succès ───────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String url;
  final VoidCallback onClose;
  final VoidCallback onDone;

  const _SuccessView({required this.url, required this.onClose, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.greenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Lien généré !', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text(
          'Partagez ce lien avec votre client.',
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // URL générée
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPage,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  style: AppTextStyles.small.copyWith(color: AppColors.purple),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lien copié !',
                          style: AppTextStyles.small.copyWith(color: AppColors.white)),
                      backgroundColor: AppColors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Icon(Icons.copy_outlined, size: 18, color: AppColors.purple),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onDone,
            child: Text('Terminer', style: AppTextStyles.buttonPrimary),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Tuile livreur ────────────────────────────────────────────────────────────

class _DelivererTile extends StatelessWidget {
  final Deliverer deliverer;
  final bool selected;
  final VoidCallback onTap;

  const _DelivererTile({
    required this.deliverer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenLight : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.green : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Avatar livreur
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.borderLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  deliverer.name[0],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Nom + zone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deliverer.name, style: AppTextStyles.smallSemiBold),
                  Text(deliverer.zone, style: AppTextStyles.tiny),
                ],
              ),
            ),

            // Note étoiles
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
                    const SizedBox(width: 2),
                    Text(
                      deliverer.rating.toStringAsFixed(1),
                      style: AppTextStyles.tiny.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ' (${deliverer.reviewCount})',
                      style: AppTextStyles.tiny,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmt(deliverer.feeEstimate)} FCFA',
                  style: AppTextStyles.tiny.copyWith(
                      color: AppColors.green, fontWeight: FontWeight.w700),
                ),
              ],
            ),

            // Coche sélection
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.green : AppColors.borderLight,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─── Récapitulatif total ──────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final int orderAmount;
  final int deliveryFee;
  final int total;

  const _TotalCard({
    required this.orderAmount,
    required this.deliveryFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _Row('Montant commande', orderAmount),
          if (deliveryFee > 0) ...[
            const SizedBox(height: 6),
            _Row('Frais de livraison', deliveryFee),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 8),
          _Row('Total', total, isTotal: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int amount;
  final bool isTotal;

  const _Row(this.label, this.amount, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? AppTextStyles.label.copyWith(color: AppColors.green)
        : AppTextStyles.small;
    final amountStyle = isTotal
        ? AppTextStyles.h3.copyWith(color: AppColors.green)
        : AppTextStyles.small.copyWith(color: AppColors.textPrimary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(_fmt(amount), style: amountStyle),
      ],
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf FCFA';
  }
}

// ─── Sélecteur méthode ────────────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  const _MethodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PaymentMethod.values.map((m) {
        final isSelected = m == selected;
        final isWave = m == PaymentMethod.wave;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isWave ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.purpleLight : AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.purple : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.purple : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Helpers UI ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.label),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}
