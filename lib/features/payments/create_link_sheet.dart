import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/services/catalog_service.dart';
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
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _catalogProducts = [];
  bool _isLoadingProducts = true;
  String? _catalogError;
  String _catalogFilter = 'all'; // 'all' | 'product' | 'service'

  List<Map<String, dynamic>> get _filteredCatalogProducts {
    if (_catalogFilter == 'all') return _catalogProducts;
    return _catalogProducts
        .where((p) => p['item_type']?.toString() == _catalogFilter)
        .toList();
  }

  // Step 3 — Livraison
  bool _hasDelivery = false;
  bool _searchingLivreur = false;
  bool _livreurFound = false;
  final _destinataireCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _secteurCtrl = TextEditingController();

  // Step 3 — Paiement
  String _selectedPayment = 'Wave';

  bool _isGenerating = false;
  String? _generatedUrl;
  PaymentLink? _generatedLink;

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
    setState(() => _isGenerating = true);

    final p = _selectedProduct!;
    final priceValue = _asInt(p['base_price']);
    final currency = (p['currency'] ?? 'FCFA').toString();
    final frais = _hasDelivery ? 2000 : 0;
    final total = priceValue + frais;

    try {
      final link = await paymentService.createPaymentLink(
        catalogItemId: (p['product_id'] ?? '').toString(),
        provider: _providerFor(_selectedPayment),
        customerName: _selectedThread?.contactName,
        customerPhone: _telephoneCtrl.text.isNotEmpty
            ? _telephoneCtrl.text
            : null,
        threadId: _selectedThread?.id,
      );

      if (!mounted) return;

      // Injecte le message dans la conversation du client sélectionné
      if (_selectedThread != null && inboxService is MockInboxService) {
        (inboxService as MockInboxService).addMessage(
          _selectedThread!.id,
          Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            direction: 'OUT',
            bodyText: '📦 ${p['name']}\n💰 $total $currency',
            messageType: 'PAYMENT_LINK',
            sentAt: DateTime.now().toIso8601String(),
            paymentAmount: total.toString(),
            paymentCurrency: currency,
            paymentStatus: PaymentStatus.created,
            paymentProvider: _selectedPayment,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatedUrl = link.checkoutUrl.isNotEmpty
            ? link.checkoutUrl
            : 'https://pay.esignal.ci/l/${link.id}';
        _generatedLink = link;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
    }
  }

  static String _providerFor(String label) => switch (label) {
    'Wave' => 'wave',
    'FedaPay' => 'fedapay',
    'Orange Money' => 'orange_money',
    'CinetPay' => 'cinetpay',
    'Moov Money' => 'moov_money',
    'MTN Money' => 'mtn_money',
    'Djamo' => 'djamo',
    _ => 'wave',
  };

  static int _asInt(dynamic n) {
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

  static String _fmtPrice(dynamic n) {
    final s = _asInt(n).toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _catalogFilterChip(String label, String value) {
    final selected = _catalogFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _catalogFilter = value),
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
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
        const Text(
          'Sélectionnez le client qui recevra le lien.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
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
                        _selectedThread!.contactInitials,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedThread!.contactName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _channelLabel(_selectedThread!.channel),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
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

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: hasContact ? () => setState(() => _step = 2) : null,
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
    );
  }

  // ── Étape 2 — Produit ───────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel produit ?', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        const Text(
          'Le montant sera rempli automatiquement.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (!_isLoadingProducts &&
            _catalogError == null &&
            _catalogProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _catalogFilterChip('Tous', 'all'),
                const SizedBox(width: 8),
                _catalogFilterChip('Produits', 'product'),
                const SizedBox(width: 8),
                _catalogFilterChip('Services', 'service'),
              ],
            ),
          ),

        if (_isLoadingProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.green,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_catalogError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
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
                    _catalogError!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadProducts,
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
            ),
          )
        else if (_catalogProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Aucun produit dans le catalogue',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else if (_filteredCatalogProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Aucun produit dans cette catégorie',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ..._filteredCatalogProducts.map((p) {
            final isSelected =
                _selectedProduct != null &&
                _selectedProduct!['product_id']?.toString() ==
                    p['product_id']?.toString();
            return _PaymentProductTile(
              product: p,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedProduct = p),
            );
          }),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedProduct != null
                ? () => setState(() => _step = 3)
                : null,
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
                Text(
                  _selectedProduct != null
                      ? 'Suivant — ${_fmtPrice(_selectedProduct!['base_price'])} ${(_selectedProduct!['currency'] ?? 'FCFA')}'
                      : 'Sélectionnez un produit',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
    final montant = _asInt(_selectedProduct?['base_price']);
    final currency = (_selectedProduct?['currency'] ?? 'FCFA').toString();
    final thumbnailUrl = _selectedProduct?['thumbnail_url']?.toString();
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_selectedProduct!['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _selectedThread?.contactName ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_fmtPrice(montant)} $currency',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),

        // Toggle livraison
        GestureDetector(
          onTap: () {
            final newVal = !_hasDelivery;
            setState(() {
              _hasDelivery = newVal;
              if (!newVal) {
                _searchingLivreur = false;
                _livreurFound = false;
              }
            });
            if (newVal) _searchLivreur();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _hasDelivery
                  ? AppColors.greenLight
                  : AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasDelivery ? AppColors.green : AppColors.borderLight,
                width: _hasDelivery ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: _hasDelivery
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
                  value: _hasDelivery,
                  onChanged: (v) {
                    setState(() {
                      _hasDelivery = v;
                      if (!v) {
                        _searchingLivreur = false;
                        _livreurFound = false;
                      }
                    });
                    if (v) _searchLivreur();
                  },
                  activeThumbColor: AppColors.green,
                ),
              ],
            ),
          ),
        ),

        // Champs adresse
        if (_hasDelivery) ...[
          const SizedBox(height: 12),
          _SheetField('Destinataire', _destinataireCtrl, Icons.person_outline),
          const SizedBox(height: 8),
          _SheetField(
            'Téléphone',
            _telephoneCtrl,
            Icons.phone_outlined,
            kbType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          _SheetField('Commune', _communeCtrl, Icons.location_city_outlined),
          const SizedBox(height: 8),
          _SheetField(
            'Quartier',
            _quartierCtrl,
            Icons.holiday_village_outlined,
          ),
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
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.green,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '🔍 Recherche d\'un livreur en cours...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (_livreurFound) ...[
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
                      Text('✅', style: TextStyle(fontSize: 15)),
                      SizedBox(width: 8),
                      Text(
                        'Livreur assigné : Koné Ibrahima',
                        style: TextStyle(
                          fontSize: 13,
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
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('|', style: TextStyle(color: AppColors.borderLight)),
                      SizedBox(width: 10),
                      Text(
                        '🕐 Arrivée estimée : 20 min',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _searchLivreur,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              child: const Text(
                'Relancer la recherche',
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],

        // Méthodes de paiement
        const SizedBox(height: 20),
        const Text(
          'Mode de paiement',
          style: TextStyle(
            fontSize: 14,
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
          final isSel = _selectedPayment == name;
          return GestureDetector(
            onTap: () => setState(() => _selectedPayment = name),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? AppColors.greenLight : AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? AppColors.green : AppColors.borderLight,
                  width: isSel ? 1.5 : 0.5,
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
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        color: isSel
                            ? AppColors.greenDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isSel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: isSel ? AppColors.green : AppColors.borderLight,
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
                    '${_fmtPrice(montant)} $currency',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_hasDelivery) ...[
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenDark,
                    ),
                  ),
                  Text(
                    '${_fmtPrice(total)} $currency',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.greenDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_isGenerating || (_hasDelivery && _searchingLivreur))
                ? null
                : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
              disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
            ),
            icon: _isGenerating
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
    );
  }
}

// ── Contact picker ────────────────────────────────────────────────────────────

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
        maxHeight: MediaQuery.of(context).size.height * 0.55,
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
                      final isSel = widget.selected?.id == t.id;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSel
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
                                color: isSel
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
                        trailing: isSel
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
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.greenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: AppColors.green,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Lien généré !',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Partagez ce lien avec votre client.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.purple),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(AppSnackbar.success('Lien copié !'));
                },
                child: const Icon(
                  Icons.copy_outlined,
                  size: 18,
                  color: AppColors.purple,
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text(
              'Terminer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
  const _SheetField(
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

// ── Tuile produit du catalogue (sélection unique) ──────────────────────────────

class _PaymentProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isSelected;
  final VoidCallback onTap;
  const _PaymentProductTile({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? '').toString();
    final rawDescription = product['description']?.toString();
    final description = (rawDescription != null && rawDescription.isNotEmpty)
        ? _stripHtml(rawDescription)
        : null;
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_CreateLinkSheetState._fmtPrice(price)} $currency',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                      if (sku != null && sku.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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

  static String _stripHtml(String html) {
    // Supprimer toutes les balises HTML
    String text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Décoder les entités HTML courantes
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&ecirc;', 'ê')
        .replaceAll('&agrave;', 'à')
        .replaceAll('&acirc;', 'â')
        .replaceAll('&ocirc;', 'ô')
        .replaceAll('&ucirc;', 'û')
        .replaceAll('&ugrave;', 'ù')
        .replaceAll('&ccedil;', 'ç');
    // Supprimer les espaces multiples et trim
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
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
