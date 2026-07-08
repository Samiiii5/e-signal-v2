import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/payments_mock.dart';
import '../../shared/mock/products_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/services/inbox_service.dart';
import '../../shared/services/payment_service.dart';

/// Résultat retourné au parent quand le lien est généré avec succès.
class CreateLinkSheetResult {
  final PaymentLink link;
  final String? threadId;
  const CreateLinkSheetResult({required this.link, this.threadId});
}

class CreateLinkSheet extends StatefulWidget {
  const CreateLinkSheet({super.key});

  @override
  State<CreateLinkSheet> createState() => _CreateLinkSheetState();
}

class _CreateLinkSheetState extends State<CreateLinkSheet> {
  // Step
  int _step = 1; // 1=Client, 2=Produit, 3=Livraison+Paiement

  // Step 1 — Contact
  Thread? _selectedThread;

  // Step 2 — Produit
  Product? _selectedProduct;

  // Step 3 — Livraison
  bool _hasDelivery = false;
  bool _searchingLivreur = false;
  bool _livreurFound = false;
  final _destinataireCtrl = TextEditingController();
  final _telephoneCtrl    = TextEditingController();
  final _communeCtrl      = TextEditingController();
  final _quartierCtrl     = TextEditingController();
  final _secteurCtrl      = TextEditingController();

  // Step 3 — Paiement
  String _selectedPayment = 'Wave';

  bool _isGenerating = false;
  String? _generatedUrl;
  PaymentLink? _generatedLink;

  @override
  void dispose() {
    _destinataireCtrl.dispose();
    _telephoneCtrl.dispose();
    _communeCtrl.dispose();
    _quartierCtrl.dispose();
    _secteurCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchLivreur() async {
    setState(() { _searchingLivreur = true; _livreurFound = false; });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _searchingLivreur = false; _livreurFound = true; });
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);

    final p = _selectedProduct!;
    final frais = _hasDelivery ? 2000 : 0;
    final total = p.price + frais;

    // Persiste le lien dans le service paiement
    final link = await paymentService.createPaymentLink(CreatePaymentLinkDto(
      contactName: _selectedThread?.contactName ?? '',
      description: '${p.emoji} ${p.name}',
      amount: total,
      paymentMethod: PaymentMethodLabel.fromLabel(_selectedPayment),
    ));

    if (!mounted) return;

    // Injecte le message dans la conversation du client sélectionné
    if (_selectedThread != null) {
      final now = DateTime.now();
      inboxService.addMessage(
        _selectedThread!.id,
        Message(
          id: 'msg_${now.millisecondsSinceEpoch}',
          threadId: _selectedThread!.id,
          content: '${p.emoji} ${p.name}\n💰 $total FCFA',
          isFromContact: false,
          sentAt: now,
          type: MessageType.paymentLink,
          paymentAmount: total.toString(),
          paymentCurrency: 'FCFA',
          paymentStatus: PaymentStatus.created,
          paymentProvider: _selectedPayment,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _generatedUrl = 'https://pay.esignal.ci/l/${link.id}?a=$total';
      _generatedLink = link;
    });
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + titre
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                Text('Nouveau lien de paiement', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                if (_generatedUrl == null) _StepIndicator(current: _step),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _generatedUrl != null
                  ? _SuccessView(
                      url: _generatedUrl!,
                      onDone: () {
                        final result = CreateLinkSheetResult(
                          link: _generatedLink!,
                          threadId: _selectedThread?.id,
                        );
                        if (_selectedThread != null) {
                          // Navigation vers la conversation : go() ferme la sheet et navigue
                          context.go('/inbox/${_selectedThread!.id}');
                        } else {
                          Navigator.of(context).pop(result);
                        }
                      },
                    )
                  : _step == 1
                      ? _buildStep1()
                      : _step == 2
                          ? _buildStep2()
                          : _buildStep3(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Étape 1 — Client ────────────────────────────────────────────────────────

  Widget _buildStep1() {
    final hasContact = _selectedThread != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pour quel client ?', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        const Text('Sélectionnez le client qui recevra le lien.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // Sélecteur contact
        GestureDetector(
          onTap: () async {
            final picked = await showModalBottomSheet<Thread>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => _ContactPickerSheet(
                selected: _selectedThread,
                onPick: (t) => Navigator.pop(context, t),
              ),
            );
            if (picked != null) setState(() => _selectedThread = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasContact ? AppColors.green : AppColors.borderLight),
            ),
            child: Row(
              children: [
                if (hasContact) ...[
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: Center(child: Text(
                      _selectedThread!.contactInitials,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedThread!.contactName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(_channelLabel(_selectedThread!.channel),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  )),
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                ] else ...[
                  const Icon(Icons.person_outline, size: 20, color: AppColors.textHint),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Choisir un contact',
                      style: TextStyle(fontSize: 14, color: AppColors.textHint))),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: hasContact ? () => setState(() => _step = 2) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green, foregroundColor: AppColors.white,
              shape: const StadiumBorder(), elevation: 0,
              disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Suivant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Étape 2 — Produit ───────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel produit ?', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        const Text('Le montant sera rempli automatiquement.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        ...mockProducts.map((p) {
          final isSelected = _selectedProduct?.id == p.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedProduct = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.greenLight : AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? AppColors.green : AppColors.borderLight,
                    width: isSelected ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderLight)),
                    child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(p.category, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )),
                  Text(_fmt(p.price), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.greenDark : AppColors.green)),
                  const SizedBox(width: 6),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.green : AppColors.borderLight, size: 18,
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _selectedProduct != null ? () => setState(() => _step = 3) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green, foregroundColor: AppColors.white,
              shape: const StadiumBorder(), elevation: 0,
              disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedProduct != null
                      ? 'Suivant — ${_fmt(_selectedProduct!.price)}'
                      : 'Sélectionnez un produit',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Étape 3 — Livraison + Paiement ──────────────────────────────────────────

  Widget _buildStep3() {
    final montant = _selectedProduct?.price ?? 0;
    final frais = _hasDelivery ? 2000 : 0;
    final total = montant + frais;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Récap produit
        if (_selectedProduct != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight, width: 0.5),
            ),
            child: Row(
              children: [
                Text(_selectedProduct!.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedProduct!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(_selectedThread?.contactName ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )),
                Text(_fmt(montant), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green)),
              ],
            ),
          ),

        // Toggle livraison
        GestureDetector(
          onTap: () {
            final newVal = !_hasDelivery;
            setState(() {
              _hasDelivery = newVal;
              if (!newVal) { _searchingLivreur = false; _livreurFound = false; }
            });
            if (newVal) _searchLivreur();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _hasDelivery ? AppColors.greenLight : AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _hasDelivery ? AppColors.green : AppColors.borderLight,
                  width: _hasDelivery ? 1.5 : 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 20,
                    color: _hasDelivery ? AppColors.greenDark : AppColors.textSecondary),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Livraison à domicile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('+2 000 FCFA • Livraison rapide', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )),
                Switch(value: _hasDelivery, onChanged: (v) {
                  setState(() {
                    _hasDelivery = v;
                    if (!v) { _searchingLivreur = false; _livreurFound = false; }
                  });
                  if (v) _searchLivreur();
                }, activeThumbColor: AppColors.green),
              ],
            ),
          ),
        ),

        // Champs adresse
        if (_hasDelivery) ...[
          const SizedBox(height: 12),
          _SheetField('Destinataire', _destinataireCtrl, Icons.person_outline),
          const SizedBox(height: 8),
          _SheetField('Téléphone', _telephoneCtrl, Icons.phone_outlined, kbType: TextInputType.phone),
          const SizedBox(height: 8),
          _SheetField('Commune', _communeCtrl, Icons.location_city_outlined),
          const SizedBox(height: 8),
          _SheetField('Quartier', _quartierCtrl, Icons.holiday_village_outlined),
          const SizedBox(height: 8),
          _SheetField('Secteur / Rue', _secteurCtrl, Icons.signpost_outlined),
          const SizedBox(height: 12),

          // Livreur auto
          if (_searchingLivreur)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('🔍 Recherche d\'un livreur en cours...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          else if (_livreurFound) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Text('✅', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 8),
                    Text('Livreur assigné : Koné Ibrahima',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                  ]),
                  const SizedBox(height: 6),
                  const Row(children: [
                    Text('⭐ Note : 4.8', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    SizedBox(width: 10),
                    Text('|', style: TextStyle(color: AppColors.borderLight)),
                    SizedBox(width: 10),
                    Text('🕐 Arrivée estimée : 20 min', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],
              ),
            ),
            TextButton(
              onPressed: _searchLivreur,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              child: const Text('Relancer la recherche', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
            ),
          ],
        ],

        // Méthodes de paiement
        const SizedBox(height: 20),
        const Text('Mode de paiement',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...[
          ('💛', 'Wave'),
          ('🟠', 'Orange Money'),
          ('🔵', 'CinetPay'),
          ('🟣', 'Moov Money'),
          ('💛', 'MTN Money'),
          ('💙', 'Djamo'),
        ].map((entry) {
          final emoji = entry.$1;
          final name  = entry.$2;
          final isSel = _selectedPayment == name;
          return GestureDetector(
            onTap: () => setState(() => _selectedPayment = name),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? AppColors.greenLight : AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? AppColors.green : AppColors.borderLight, width: isSel ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name, style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                    color: isSel ? AppColors.greenDark : AppColors.textPrimary,
                  ))),
                  Icon(
                    isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18, color: isSel ? AppColors.green : AppColors.borderLight,
                  ),
                ],
              ),
            ),
          );
        }),

        // Total
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Produit', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text(_fmt(montant), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
              if (_hasDelivery) ...[
                const SizedBox(height: 6),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Livraison', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text('2 000 FCFA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ]),
              ],
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: AppColors.green, height: 1)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                Text(_fmt(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: (_isGenerating || (_hasDelivery && _searchingLivreur)) ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green, foregroundColor: AppColors.white,
              shape: const StadiumBorder(), elevation: 0,
              disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
            ),
            icon: _isGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isGenerating ? 'Génération...' : 'Générer et envoyer le lien',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  String _channelLabel(String channel) {
    return switch (channel) {
      'whatsapp' => 'WhatsApp',
      'messenger' => 'Facebook',
      'sms' => 'SMS',
      'tiktok' => 'TikTok',
      'email' => 'Email',
      _ => channel,
    };
  }
}

// ── Indicateur d'étapes ───────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    const labels = ['Client', 'Produit', 'Livraison'];
    return Row(
      children: List.generate(3, (i) {
        final step = i + 1;
        final active = step == current;
        final done = step < current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || active ? AppColors.green : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.green : AppColors.textHint,
                )),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Contact picker ────────────────────────────────────────────────────────────

class _ContactPickerSheet extends StatelessWidget {
  final Thread? selected;
  final ValueChanged<Thread> onPick;
  const _ContactPickerSheet({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Choisir un contact', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: mockThreads.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (_, i) {
                final t = mockThreads[i];
                final isSel = selected?.id == t.id;
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: isSel ? AppColors.green : AppColors.backgroundPage,
                        shape: BoxShape.circle),
                    child: Center(child: Text(t.contactInitials, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isSel ? AppColors.white : AppColors.textPrimary))),
                  ),
                  title: Text(t.contactName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18) : null,
                  onTap: () => onPick(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String url;
  final VoidCallback onDone;
  const _SuccessView({required this.url, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Lien généré !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Partagez ce lien avec votre client.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(url, style: const TextStyle(fontSize: 12, color: AppColors.purple), maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(AppSnackbar.success('Lien copié !'));
                },
                child: const Icon(Icons.copy_outlined, size: 18, color: AppColors.purple),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green, foregroundColor: AppColors.white,
              shape: const StadiumBorder(), elevation: 0,
            ),
            child: const Text('Terminer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ── Champ de saisie ───────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType kbType;
  const _SheetField(this.label, this.ctrl, this.icon, {this.kbType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: kbType,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
