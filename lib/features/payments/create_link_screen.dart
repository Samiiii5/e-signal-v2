import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/models/lien_paiement_model.dart';
import '../../shared/services/catalog_service.dart';
import '../../shared/services/inbox_service.dart';
import '../../shared/services/payment_service.dart';

int _asIntPrice(dynamic n) {
  if (n is num) return n.toInt();
  if (n == null) return 0;
  final str = n.toString();
  // Essayer de parser comme int d'abord
  final intVal = int.tryParse(str);
  if (intVal != null) return intVal;
  // Si échec, essayer comme double puis convertir en int
  final doubleVal = double.tryParse(str);
  if (doubleVal != null) return doubleVal.toInt();
  return 0;
}

String _fmtNum(dynamic n) {
  final s = _asIntPrice(n).toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Libellé affiché → identifiant de fournisseur attendu par l'API.
/// Même correspondance que dans CreateLinkSheet.
String _providerFor(String label) => switch (label) {
  'Wave' => 'wave',
  'FedaPay' => 'fedapay',
  'Orange Money' => 'orange_money',
  'CinetPay' => 'cinetpay',
  'Moov Money' => 'moov_money',
  'MTN Money' => 'mtn_money',
  'Djamo' => 'djamo',
  _ => 'wave',
};

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
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _catalogProducts = [];
  bool _isLoadingProducts = true;
  String? _catalogError;

  // Step 3 — Delivery
  bool _hasDelivery = false;
  bool _searchingLivreur = false;
  bool _livreurFound = false;
  final _destinataireCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _secteurCtrl = TextEditingController();

  // Step 3 — Payment method
  String _selectedPayment = 'Wave';

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _destinataireCtrl.dispose();
    _telephoneCtrl.dispose();
    _communeCtrl.dispose();
    _quartierCtrl.dispose();
    _secteurCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _catalogError = null;
    });
    try {
      final items = await catalogService.getProducts();
      if (!mounted) return;
      setState(() {
        _catalogProducts = items;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _catalogError = 'Impossible de charger le catalogue.';
      });
    }
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

    final product = _selectedProduct!;
    final priceValue = _asIntPrice(product['base_price']);
    final currency = (product['currency'] ?? 'FCFA').toString();
    final frais = _hasDelivery ? 2000 : 0;
    final total = priceValue + frais;

    // Effective thread: picked in step 1 OR pre-filled from caller
    final effectiveThreadId = _selectedThread?.id ?? widget.threadId;

    // Même endpoint que CreateLinkSheet : POST /payment-links/organizations/{org}/product
    final PaymentLink link;
    try {
      link = await paymentService.createPaymentLink(
        catalogItemId: (product['product_id'] ?? '').toString(),
        provider: _providerFor(_selectedPayment),
        customerName: _contactName.isNotEmpty ? _contactName : null,
        customerPhone: _telephoneCtrl.text.isNotEmpty
            ? _telephoneCtrl.text
            : null,
        threadId: effectiveThreadId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Impossible de générer le lien de paiement.'),
      );
      return;
    }
    if (!mounted) return;

    final lien = LienPaiement(
      id: link.id,
      contactNom: _contactName,
      description: '📦 ${product['name']} — Commande de $_contactName',
      montantCommande: priceValue,
      fraisLivraison: frais,
      montantTotal: total,
      statut: link.status.isNotEmpty ? link.status : 'created',
      livreurNom: _hasDelivery ? 'Koné Ibrahima' : '',
      createdAt: DateTime.now(),
      lienUrl: link.checkoutUrl.isNotEmpty
          ? link.checkoutUrl
          : 'https://pay.esignal.ci/l/${link.id}',
    );

    setState(() => _isGenerating = false);

    if (!mounted) return;

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
            paymentCurrency: currency,
            paymentStatus: PaymentStatus.created,
            paymentProvider: _selectedPayment,
          ),
        );

        // Inject delivery messages if applicable
        if (_hasDelivery) {
          final addr =
              '${_communeCtrl.text.trim()}, ${_quartierCtrl.text.trim()}, ${_secteurCtrl.text.trim()}';
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
              bodyText:
                  '✅ Livreur assigné : Koné Ibrahima\n📅 Livraison prévue : Demain 14h-16h\n📞 +225 07 58 32 14 96',
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
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 22,
          ),
          onPressed: _goBack,
        ),
        title: const Text(
          'Nouveau lien de paiement',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
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
          products: _catalogProducts,
          isLoading: _isLoadingProducts,
          error: _catalogError,
          onRetry: _loadProducts,
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
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
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
                      color: done || active
                          ? AppColors.green
                          : AppColors.borderLight,
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
          const Text(
            'Pour quel client ?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sélectionnez le client qui va recevoir le lien de paiement.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (isPreFilled) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        contactName![0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contactName!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 20,
                  ),
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
                  builder: (_) => _ContactPickerSheet(
                    selected: selectedThread,
                    onPick: (t) => Navigator.pop(context, t),
                  ),
                );
                if (picked != null) onSelectThread(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasContact ? AppColors.green : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    if (hasContact) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green,
                        size: 18,
                      ),
                    ] else ...[
                      const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Choisir un contact',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
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
                  Text(
                    'Suivant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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

class _ContactPickerSheet extends StatefulWidget {
  final Thread? selected;
  final ValueChanged<Thread> onPick;
  const _ContactPickerSheet({required this.selected, required this.onPick});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  List<Thread> _threads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// GET /inbox/threads — la liste des contacts vient toujours du serveur.
  /// En cas d'échec, on affiche une erreur : proposer des contacts de
  /// démonstration ferait générer un lien pour un client qui n'existe pas.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final threads = await inboxService.getThreads();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== Chargement des contacts échoué : $e ===');
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les contacts.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choisir un contact',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _error != null
                ? _ContactPickerError(message: _error!, onRetry: _load)
                : _threads.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun contact',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _threads.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (_, i) {
                      final t = _threads[i];
                      final isSelected = widget.selected?.id == t.id;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.green
                                : AppColors.backgroundPage,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              t.contactInitials,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          t.contactName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.green,
                                size: 18,
                              )
                            : null,
                        onTap: () => widget.onPick(t),
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

class _Step2 extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final Map<String, dynamic>? selectedProduct;
  final ValueChanged<Map<String, dynamic>> onSelectProduct;
  final VoidCallback onNext;

  const _Step2({
    required this.products,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.selectedProduct,
    required this.onSelectProduct,
    required this.onNext,
  });

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  String _filter = 'all'; // 'all' | 'product' | 'service'

  List<Map<String, dynamic>> get _filteredProducts {
    if (_filter == 'all') return widget.products;
    return widget.products
        .where((p) => p['item_type']?.toString() == _filter)
        .toList();
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.backgroundStatus,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = widget.selectedProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quel produit ?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choisissez le produit commandé. Le montant sera rempli automatiquement.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.isLoading &&
                  widget.error == null &&
                  widget.products.isNotEmpty)
                Row(
                  children: [
                    _filterChip('Tous', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Produits', 'product'),
                    const SizedBox(width: 8),
                    _filterChip('Services', 'service'),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.green,
                    strokeWidth: 2,
                  ),
                )
              : widget.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_outlined,
                        size: 40,
                        color: AppColors.borderLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: widget.onRetry,
                        child: const Text(
                          'Réessayer',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : widget.products.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun produit dans le catalogue',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : _filteredProducts.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun produit dans cette catégorie',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (_, i) {
                    final p = _filteredProducts[i];
                    final isSelected =
                        selectedProduct != null &&
                        selectedProduct['product_id']?.toString() ==
                            p['product_id']?.toString();
                    return _CatalogProductTile(
                      product: p,
                      isSelected: isSelected,
                      onTap: () => widget.onSelectProduct(p),
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
              onPressed: selectedProduct != null ? widget.onNext : null,
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
                    Text(
                      'Suivant — ${_fmtNum(selectedProduct['base_price'])} ${(selectedProduct['currency'] ?? 'FCFA')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'Sélectionnez un produit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
}

// ── Tuile produit du catalogue (sélection unique) ──────────────────────────────

class _CatalogProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isSelected;
  final VoidCallback onTap;
  const _CatalogProductTile({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? '').toString();
    final description = product['description']?.toString();
    final currency = (product['currency'] ?? '').toString();
    final imageUrl = product['thumbnail_url']?.toString();
    final price = product['base_price'] ?? product['price'];
    final sku = product['sku']?.toString();
    final isService = product['item_type']?.toString() == 'service';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenLight : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.borderLight,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image produit
            Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textHint,
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.textHint,
                    ),
            ),
            const SizedBox(width: 12),
            // Nom + description + prix
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isService) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusCreatedBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Service',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusCreatedText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_fmtNum(price)} $currency',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                      if (sku != null && sku.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundStatus,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sku,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Indicateur de sélection custom (PAS un Checkbox natif)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.green : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.green : const Color(0xFF9CA3AF),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3 — Delivery ─────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final Map<String, dynamic>? product;
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
    final montant = _asIntPrice(product?['base_price']);
    final currency = (product?['currency'] ?? 'FCFA').toString();
    final thumbnailUrl = product?['thumbnail_url']?.toString();
    final frais = hasDelivery ? 2000 : 0;
    final total = montant + frais;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Livraison à domicile ?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajoutez une option de livraison. Des frais de 2 000 FCFA seront ajoutés.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
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
                  Container(
                    width: 40,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                        ? Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.textHint,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textHint,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (product!['name'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          contactName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_fmtNum(montant)} $currency',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
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
                color: hasDelivery
                    ? AppColors.greenLight
                    : AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasDelivery ? AppColors.green : AppColors.borderLight,
                  width: hasDelivery ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: hasDelivery
                        ? AppColors.greenDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Livraison à domicile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '+2 000 FCFA • Livraison rapide',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
            _LinkField(
              'Nom du destinataire',
              destinataireCtrl,
              Icons.person_outline,
            ),
            const SizedBox(height: 10),
            _LinkField(
              'Téléphone',
              telephoneCtrl,
              Icons.phone_outlined,
              kbType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _LinkField('Commune', communeCtrl, Icons.location_city_outlined),
            const SizedBox(height: 10),
            _LinkField(
              'Quartier',
              quartierCtrl,
              Icons.holiday_village_outlined,
            ),
            const SizedBox(height: 10),
            _LinkField('Secteur / Rue', secteurCtrl, Icons.signpost_outlined),
            const SizedBox(height: 16),
            // Livreur automatique
            if (searchingLivreur)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.green,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '🔍 Recherche d\'un livreur en cours...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (livreurFound) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('✅', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Livreur assigné : Koné Ibrahima',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Text(
                          '⭐ Note : 4.8',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '|',
                          style: TextStyle(color: AppColors.borderLight),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '🕐 Arrivée estimée : 20 min',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Relancer la recherche',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],

          // Payment methods
          const SizedBox(height: 20),
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.greenLight
                      : AppColors.backgroundPage,
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
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.greenDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected
                          ? AppColors.green
                          : AppColors.borderLight,
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
                    const Text(
                      'Produit',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${_fmtNum(montant)} $currency',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (hasDelivery) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Livraison',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '2 000 $currency',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenDark,
                      ),
                    ),
                    Text(
                      '${_fmtNum(total)} $currency',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenDark,
                      ),
                    ),
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
              onPressed: (isGenerating || (hasDelivery && searchingLivreur))
                  ? null
                  : onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
              ),
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                isGenerating ? 'Génération...' : 'Générer et envoyer le lien',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType kbType;
  const _LinkField(
    this.label,
    this.ctrl,
    this.icon, {
    this.kbType = TextInputType.text,
  });

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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ── Erreur de chargement des contacts ─────────────────────────────────────────

class _ContactPickerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ContactPickerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: AppColors.borderLight,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.greenLight,
              foregroundColor: AppColors.greenDark,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 20,
              ),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
