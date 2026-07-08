import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/products_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/models/lien_paiement_model.dart';
import '../../shared/services/inbox_service.dart';

// Return value when a link is generated
class CreateLinkResult {
  final LienPaiement lien;
  final bool hasDelivery;
  final String deliveryCommune;
  final String deliveryQuartier;
  final String deliverySecteur;

  const CreateLinkResult({
    required this.lien,
    required this.hasDelivery,
    this.deliveryCommune = '',
    this.deliveryQuartier = '',
    this.deliverySecteur = '',
  });
}

class CreateLinkScreen extends StatefulWidget {
  final String? contactName;
  final String? threadId;
  const CreateLinkScreen({super.key, this.contactName, this.threadId});

  @override
  State<CreateLinkScreen> createState() => _CreateLinkScreenState();
}

class _CreateLinkScreenState extends State<CreateLinkScreen> {
  int _step = 1;

  // Step 1 — Contact
  Thread? _selectedThread;
  String get _contactName =>
      _selectedThread?.contactName ?? widget.contactName ?? '';

  // Step 2 — Product
  Product? _selectedProduct;

  // Step 3 — Delivery
  bool _hasDelivery = false;
  bool _searchingLivreur = false;
  bool _livreurFound = false;
  final _destinataireCtrl = TextEditingController();
  final _telephoneCtrl    = TextEditingController();
  final _communeCtrl      = TextEditingController();
  final _quartierCtrl     = TextEditingController();
  final _secteurCtrl      = TextEditingController();

  // Step 3 — Payment method
  String _selectedPayment = 'Wave';

  bool _isGenerating = false;

  @override
  void dispose() {
    _destinataireCtrl.dispose();
    _telephoneCtrl.dispose();
    _communeCtrl.dispose();
    _quartierCtrl.dispose();
    _secteurCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _searchLivreur() async {
    setState(() {
      _searchingLivreur = true;
      _livreurFound = false;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _searchingLivreur = false;
      _livreurFound = true;
    });
  }

  Future<void> _generate() async {
    if (_selectedProduct == null) return;
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final total = _selectedProduct!.price + (_hasDelivery ? 2000 : 0);

    final lien = LienPaiement(
      id: 'lien_${DateTime.now().millisecondsSinceEpoch}',
      contactNom: _contactName,
      description:
          '${_selectedProduct!.emoji} ${_selectedProduct!.name} — Commande de $_contactName',
      montantCommande: _selectedProduct!.price,
      fraisLivraison: _hasDelivery ? 2000 : 0,
      montantTotal: total,
      statut: 'created',
      livreurNom: _hasDelivery ? 'Koné Ibrahima' : '',
      createdAt: DateTime.now(),
      lienUrl: 'https://pay.score360.africa/l/link',
    );

    setState(() => _isGenerating = false);

    if (!mounted) return;

    // Effective thread: picked in step 1 OR pre-filled from caller
    final effectiveThreadId = _selectedThread?.id ?? widget.threadId;

    if (effectiveThreadId != null) {
      // Inject payment link message into the thread (mock service only)
      final now = DateTime.now().toIso8601String();
      if (inboxService is MockInboxService) {
        (inboxService as MockInboxService).addMessage(
          effectiveThreadId,
          Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            direction: 'OUT',
            bodyText: lien.description,
            messageType: 'PAYMENT_LINK',
            sentAt: now,
            paymentAmount: total.toString(),
            paymentCurrency: 'FCFA',
            paymentStatus: PaymentStatus.created,
            paymentProvider: _selectedPayment,
          ),
        );

        // Inject delivery messages if applicable
        if (_hasDelivery) {
          final addr = '${_communeCtrl.text.trim()}, ${_quartierCtrl.text.trim()}, ${_secteurCtrl.text.trim()}';
          (inboxService as MockInboxService).addMessage(
            effectiveThreadId,
            Message(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
              direction: 'OUT',
              bodyText: '🚚 Livraison à domicile confirmée\nAdresse : $addr',
              sentAt: now,
            ),
          );
          (inboxService as MockInboxService).addMessage(
            effectiveThreadId,
            Message(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch + 2}',
              direction: 'OUT',
              bodyText: '✅ Livreur assigné : Koné Ibrahima\n📅 Livraison prévue : Demain 14h-16h\n📞 +225 07 58 32 14 96',
              sentAt: now,
            ),
          );
        }
      }

      // Navigate directly to the thread conversation
      context.go('/inbox/$effectiveThreadId');
    } else {
      Navigator.pop(
        context,
        CreateLinkResult(
          lien: lien,
          hasDelivery: _hasDelivery,
          deliveryCommune: _communeCtrl.text.trim(),
          deliveryQuartier: _quartierCtrl.text.trim(),
          deliverySecteur: _secteurCtrl.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
          onPressed: _goBack,
        ),
        title: const Text(
          'Nouveau lien de paiement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _StepProgress(current: _step),
        ),
      ),
      body: switch (_step) {
        1 => _Step1(
            contactName: widget.contactName,
            selectedThread: _selectedThread,
            onSelectThread: (t) => setState(() => _selectedThread = t),
            onNext: () => setState(() => _step = 2),
          ),
        2 => _Step2(
            selectedProduct: _selectedProduct,
            onSelectProduct: (p) => setState(() => _selectedProduct = p),
            onNext: () => setState(() => _step = 3),
          ),
        _ => _Step3(
            product: _selectedProduct,
            contactName: _contactName,
            hasDelivery: _hasDelivery,
            onDeliveryChanged: (v) {
              setState(() {
                _hasDelivery = v;
                if (!v) {
                  _searchingLivreur = false;
                  _livreurFound = false;
                }
              });
              if (v) _searchLivreur();
            },
            searchingLivreur: _searchingLivreur,
            livreurFound: _livreurFound,
            onRelancerRecherche: _searchLivreur,
            destinataireCtrl: _destinataireCtrl,
            telephoneCtrl: _telephoneCtrl,
            communeCtrl: _communeCtrl,
            quartierCtrl: _quartierCtrl,
            secteurCtrl: _secteurCtrl,
            selectedPayment: _selectedPayment,
            onPaymentChanged: (v) => setState(() => _selectedPayment = v),
            isGenerating: _isGenerating,
            onGenerate: _generate,
          ),
      },
    );
  }
}

// ── Step progress ─────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int current;
  const _StepProgress({required this.current});

  @override
  Widget build(BuildContext context) {
    const labels = ['Client', 'Produit', 'Livraison'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
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
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.green : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1 — Contact ──────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final String? contactName;
  final Thread? selectedThread;
  final ValueChanged<Thread> onSelectThread;
  final VoidCallback onNext;

  const _Step1({
    required this.contactName,
    required this.selectedThread,
    required this.onSelectThread,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isPreFilled = contactName != null;
    final displayName = selectedThread?.contactName ?? contactName ?? '';
    final hasContact = displayName.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pour quel client ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Sélectionnez le client qui va recevoir le lien de paiement.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          if (isPreFilled) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        contactName![0].toUpperCase(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(contactName!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
                ],
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () async {
                final picked = await showModalBottomSheet<Thread>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _ContactPickerSheet(selected: selectedThread, onPick: (t) => Navigator.pop(context, t)),
                );
                if (picked != null) onSelectThread(picked);
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
                        child: Center(child: Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.white))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                      const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                    ] else ...[
                      const Icon(Icons.person_outline, size: 20, color: AppColors.textHint),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Choisir un contact', style: TextStyle(fontSize: 14, color: AppColors.textHint))),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: hasContact ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
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
      ),
    );
  }
}

class _ContactPickerSheet extends StatelessWidget {
  final Thread? selected;
  final ValueChanged<Thread> onPick;
  const _ContactPickerSheet({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Choisir un contact', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: mockThreads.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (_, i) {
                final t = mockThreads[i];
                final isSelected = selected?.id == t.id;
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: isSelected ? AppColors.green : AppColors.backgroundPage, shape: BoxShape.circle),
                    child: Center(child: Text(t.contactInitials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? AppColors.white : AppColors.textPrimary))),
                  ),
                  title: Text(t.contactName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18) : null,
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

// ── Step 2 — Product ──────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final Product? selectedProduct;
  final ValueChanged<Product> onSelectProduct;
  final VoidCallback onNext;

  const _Step2({
    required this.selectedProduct,
    required this.onSelectProduct,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quel produit ?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Choisissez le produit commandé. Le montant sera rempli automatiquement.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: mockProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = mockProducts[i];
              final isSelected = selectedProduct?.id == p.id;
              return GestureDetector(
                onTap: () => onSelectProduct(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.greenLight : AppColors.backgroundPage,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.green : AppColors.borderLight, width: isSelected ? 1.5 : 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderLight)),
                        child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(p.category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_fmt(p.price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isSelected ? AppColors.greenDark : AppColors.green)),
                          const Text('FCFA', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: isSelected ? AppColors.green : AppColors.borderLight,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: selectedProduct != null ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selectedProduct != null)
                    Text('Suivant — ${_fmt(selectedProduct!.price)} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
                  else
                    const Text('Sélectionnez un produit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Step 3 — Delivery ─────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final Product? product;
  final String contactName;
  final bool hasDelivery;
  final ValueChanged<bool> onDeliveryChanged;
  final bool searchingLivreur;
  final bool livreurFound;
  final VoidCallback onRelancerRecherche;
  final TextEditingController destinataireCtrl;
  final TextEditingController telephoneCtrl;
  final TextEditingController communeCtrl;
  final TextEditingController quartierCtrl;
  final TextEditingController secteurCtrl;
  final String selectedPayment;
  final ValueChanged<String> onPaymentChanged;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _Step3({
    required this.product,
    required this.contactName,
    required this.hasDelivery,
    required this.onDeliveryChanged,
    required this.searchingLivreur,
    required this.livreurFound,
    required this.onRelancerRecherche,
    required this.destinataireCtrl,
    required this.telephoneCtrl,
    required this.communeCtrl,
    required this.quartierCtrl,
    required this.secteurCtrl,
    required this.selectedPayment,
    required this.onPaymentChanged,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final montant = product?.price ?? 0;
    final frais = hasDelivery ? 2000 : 0;
    final total = montant + frais;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Livraison à domicile ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Ajoutez une option de livraison. Des frais de 2 000 FCFA seront ajoutés.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),

          // Récap produit
          if (product != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight, width: 0.5),
              ),
              child: Row(
                children: [
                  Text(product!.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(contactName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${_fmt(montant)} FCFA', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.green)),
                ],
              ),
            ),

          // Toggle livraison
          GestureDetector(
            onTap: () => onDeliveryChanged(!hasDelivery),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: hasDelivery ? AppColors.greenLight : AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hasDelivery ? AppColors.green : AppColors.borderLight, width: hasDelivery ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 20, color: hasDelivery ? AppColors.greenDark : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Livraison à domicile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('+2 000 FCFA • Livraison rapide', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: hasDelivery,
                    onChanged: onDeliveryChanged,
                    activeThumbColor: AppColors.green,
                  ),
                ],
              ),
            ),
          ),

          // Address fields
          if (hasDelivery) ...[
            const SizedBox(height: 16),
            _LinkField('Nom du destinataire', destinataireCtrl, Icons.person_outline),
            const SizedBox(height: 10),
            _LinkField('Téléphone', telephoneCtrl, Icons.phone_outlined, kbType: TextInputType.phone),
            const SizedBox(height: 10),
            _LinkField('Commune', communeCtrl, Icons.location_city_outlined),
            const SizedBox(height: 10),
            _LinkField('Quartier', quartierCtrl, Icons.holiday_village_outlined),
            const SizedBox(height: 10),
            _LinkField('Secteur / Rue', secteurCtrl, Icons.signpost_outlined),
            const SizedBox(height: 16),
            // Livreur automatique
            if (searchingLivreur)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('🔍 Recherche d\'un livreur en cours...', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              )
            else if (livreurFound) ...[
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
                    const Row(
                      children: [
                        Text('✅', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Livreur assigné : Koné Ibrahima',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Text('⭐ Note : 4.8', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        SizedBox(width: 12),
                        Text('|', style: TextStyle(color: AppColors.borderLight)),
                        SizedBox(width: 12),
                        Text('🕐 Arrivée estimée : 20 min', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onRelancerRecherche,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  ),
                  child: const Text('Relancer la recherche', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ],

          // Payment methods
          const SizedBox(height: 20),
          const Text('Mode de paiement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
            final name = entry.$2;
            final isSelected = selectedPayment == name;
            return GestureDetector(
              onTap: () => onPaymentChanged(name),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.greenLight : AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.green : AppColors.borderLight,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.greenDark : AppColors.textPrimary,
                          )),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected ? AppColors.green : AppColors.borderLight,
                    ),
                  ],
                ),
              ),
            );
          }),

          // Total recap
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Produit', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${_fmt(montant)} FCFA', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
                if (hasDelivery) ...[
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Livraison', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text('2 000 FCFA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.green, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                    Text('${_fmt(total)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (isGenerating || (hasDelivery && searchingLivreur)) ? null : onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
              ),
              icon: isGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                isGenerating ? 'Génération...' : 'Générer et envoyer le lien',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _LinkField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType kbType;
  const _LinkField(this.label, this.ctrl, this.icon, {this.kbType = TextInputType.text});

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
