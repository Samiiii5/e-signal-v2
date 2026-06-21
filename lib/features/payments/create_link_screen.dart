import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/livreur_model.dart';
import '../../shared/models/lien_paiement_model.dart';
import '../../shared/services/livreur_service.dart';
import '../../shared/mock/threads_mock.dart';

class CreateLinkScreen extends StatefulWidget {
  final String? contactName;

  const CreateLinkScreen({super.key, this.contactName});

  @override
  State<CreateLinkScreen> createState() => _CreateLinkScreenState();
}

class _CreateLinkScreenState extends State<CreateLinkScreen> {
  int _step = 1;

  // Contact sélectionné
  Thread? _selectedContact;
  String get _effectiveContactName =>
      _selectedContact?.contactName ?? widget.contactName ?? '';

  // Étape 1 — Destination
  final _destinationController = TextEditingController();
  bool _isSearching = false;

  // Étape 2 — Livreur
  List<Livreur> _livreurs = [];
  Livreur? _selectedLivreur;

  // Étape 3 — Paiement
  final _montantController = TextEditingController();
  final _descController = TextEditingController();
  bool _isGenerating = false;
  LienPaiement? _generatedLink;

  int get _montant =>
      int.tryParse(_montantController.text.replaceAll(' ', '')) ?? 0;
  int get _frais => _selectedLivreur?.tarif ?? 0;
  int get _total => _montant + _frais;

  @override
  void dispose() {
    _destinationController.dispose();
    _montantController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _searchLivreurs() async {
    if (_destinationController.text.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final livreurs = await livreurService
          .getLivreursDisponibles(_destinationController.text.trim());
      if (!mounted) return;
      setState(() {
        _livreurs = livreurs;
        _step = 2;
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _generateLink() async {
    if (_montant <= 0 || _selectedLivreur == null) return;
    setState(() => _isGenerating = true);
    try {
      final lien = await livreurService.genererLienPaiement(
        CreateLienDto(
          contactNom: _effectiveContactName,
          description: _descController.text.trim().isEmpty
              ? 'Commande client'
              : _descController.text.trim(),
          montantCommande: _montant,
          livreurId: _selectedLivreur!.id,
          livreurNom: _selectedLivreur!.nom,
          fraisLivraison: _frais,
          destination: _destinationController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _generatedLink = lien);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _goBack() {
    if (_generatedLink != null) {
      Navigator.pop(context);
    } else if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
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
        title: Text(
          _generatedLink != null
              ? 'Lien généré ✓'
              : 'Nouvelle livraison',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: _generatedLink == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _StepProgress(current: _step),
              )
            : null,
      ),
      body: _generatedLink != null
          ? _SuccessView(
              lien: _generatedLink!,
              onSend: () => Navigator.pop(context, _generatedLink),
              onCopy: () {
                Clipboard.setData(
                    ClipboardData(text: _generatedLink!.lienUrl));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(_snackSuccess('Lien copié dans le presse-papier'));
              },
            )
          : switch (_step) {
              1 => _Step1(
                  controller: _destinationController,
                  isLoading: _isSearching,
                  onNext: _searchLivreurs,
                  selectedContact: _selectedContact,
                  onSelectContact: (t) => setState(() => _selectedContact = t),
                ),
              2 => _Step2(
                  destination: _destinationController.text.trim(),
                  livreurs: _livreurs,
                  onSelect: (l) => setState(() {
                    _selectedLivreur = l;
                    _step = 3;
                  }),
                ),
              _ => _Step3(
                  livreur: _selectedLivreur!,
                  montantController: _montantController,
                  descController: _descController,
                  montant: _montant,
                  frais: _frais,
                  total: _total,
                  isGenerating: _isGenerating,
                  onMontantChanged: (_) => setState(() {}),
                  onGenerate: _generateLink,
                ),
            },
    );
  }
}

SnackBar _snackSuccess(String msg) => SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

// ── Indicateur d'étapes ───────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int current;
  const _StepProgress({required this.current});

  @override
  Widget build(BuildContext context) {
    final labels = ['Destination', 'Livreur', 'Paiement'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
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

// ── Étape 1 : Destination ─────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onNext;
  final Thread? selectedContact;
  final ValueChanged<Thread> onSelectContact;

  const _Step1({
    required this.controller,
    required this.isLoading,
    required this.onNext,
    required this.selectedContact,
    required this.onSelectContact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adresse de livraison',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Renseignez l\'adresse du client pour trouver les livreurs disponibles à proximité.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),

          const _FieldLabel('Client'),
          _ContactSelector(
            selected: selectedContact,
            onTap: () async {
              final picked = await showModalBottomSheet<Thread>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _ContactPickerSheet(),
              );
              if (picked != null) onSelectContact(picked);
            },
          ),

          const SizedBox(height: 16),
          const _FieldLabel('Adresse de livraison du client'),
          _InputField(
            controller: controller,
            hint: 'ex : Cocody Riviera 3, Abidjan',
            prefix: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textHint),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Rechercher les livreurs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

// ── Sélecteur de contact ──────────────────────────────────────────────────────

class _ContactSelector extends StatelessWidget {
  final Thread? selected;
  final VoidCallback onTap;
  const _ContactSelector({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              _ContactAvatar(initials: selected!.contactInitials, channel: selected!.channel, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selected!.contactName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
                    Text(_channelLabel(selected!.channel),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
            ] else ...[
              const Icon(Icons.person_outline, size: 18, color: AppColors.textHint),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Sélectionner un client',
                    style: TextStyle(fontSize: 14, color: AppColors.textHint)),
              ),
              const Icon(Icons.keyboard_arrow_right, size: 18, color: AppColors.textHint),
            ],
          ],
        ),
      ),
    );
  }

  String _channelLabel(Channel c) => switch (c) {
    Channel.whatsapp  => 'WhatsApp',
    Channel.facebook  => 'Facebook',
    Channel.sms       => 'SMS',
    Channel.tiktok    => 'TikTok',
    Channel.email     => 'Email',
  };
}

// ── BottomSheet sélection contact ─────────────────────────────────────────────

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet();

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Thread> get _filtered {
    if (_query.isEmpty) return mockThreads;
    final q = _query.toLowerCase();
    return mockThreads.where((t) => t.contactName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // Titre
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choisir un client',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 14),

            // Barre de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un contact...',
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Liste
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final t = _filtered[i];
                  return _ContactTile(
                    thread: t,
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Thread thread;
  final VoidCallback onTap;
  const _ContactTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _ContactAvatar(initials: thread.contactInitials, channel: thread.channel, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(thread.contactName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      _ChannelBadge(channel: thread.channel),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(thread.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String initials;
  final Channel channel;
  final double size;
  const _ContactAvatar({required this.initials, required this.channel, required this.size});

  static const _colors = [
    Color(0xFF6C5CE7),
    Color(0xFF1E9E5E),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[initials.hashCode.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(fontSize: size * 0.33, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  final Channel channel;
  const _ChannelBadge({required this.channel});

  static const _meta = {
    Channel.whatsapp : (Color(0xFF25D366), Color(0xFFE8FBF0), 'WhatsApp'),
    Channel.facebook : (Color(0xFF1877F2), Color(0xFFE8F0FE), 'Facebook'),
    Channel.sms      : (Color(0xFF6B7280), Color(0xFFF3F4F6), 'SMS'),
    Channel.tiktok   : (Color(0xFF1A1A1A), Color(0xFFF3F4F6), 'TikTok'),
    Channel.email    : (Color(0xFFEA4335), Color(0xFFFEEBE9), 'Email'),
  };

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, label) = _meta[channel]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ── Étape 2 : Choisir un livreur ──────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final String destination;
  final List<Livreur> livreurs;
  final ValueChanged<Livreur> onSelect;

  const _Step2({
    required this.destination,
    required this.livreurs,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text(
          'Livreurs disponibles',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.green),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                destination,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...livreurs.map((l) => _LivreurCard(
              livreur: l,
              onSelect: () => onSelect(l),
            )),
      ],
    );
  }
}

class _LivreurCard extends StatelessWidget {
  final Livreur livreur;
  final VoidCallback onSelect;

  const _LivreurCard({required this.livreur, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6C5CE7),
      AppColors.green,
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      AppColors.textSecondary,
    ];
    final avatarColor = colors[livreur.id.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                livreur.photo,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: avatarColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(livreur.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Stars(note: livreur.note),
                    const SizedBox(width: 6),
                    Text(
                      livreur.note.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text(
                      ' · ${livreur.nombreLivraisons} livraisons',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(livreur.tempsEstime, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Text(
                      '${_fmt(livreur.tarif)} FCFA',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bouton sélectionner
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: livreur.disponible ? onSelect : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                livreur.disponible ? 'Choisir' : 'Indispo',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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

class _Stars extends StatelessWidget {
  final double note;
  const _Stars({required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < note.floor();
        final half = !filled && (note - note.floor()) >= 0.5 && i == note.floor();
        return Icon(
          half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_outline_rounded),
          size: 13,
          color: const Color(0xFFFFC107),
        );
      }),
    );
  }
}

// ── Étape 3 : Détails du paiement ─────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final Livreur livreur;
  final TextEditingController montantController;
  final TextEditingController descController;
  final int montant;
  final int frais;
  final int total;
  final bool isGenerating;
  final ValueChanged<String> onMontantChanged;
  final VoidCallback onGenerate;

  const _Step3({
    required this.livreur,
    required this.montantController,
    required this.descController,
    required this.montant,
    required this.frais,
    required this.total,
    required this.isGenerating,
    required this.onMontantChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du paiement',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Résumé livreur sélectionné
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_outlined, size: 18, color: AppColors.greenDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(livreur.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                      Text('Frais : ${_fmt(livreur.tarif)} FCFA · ${livreur.tempsEstime}', style: const TextStyle(fontSize: 11, color: AppColors.greenDark)),
                    ],
                  ),
                ),
                _Stars(note: livreur.note),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const _FieldLabel('Montant de la commande (FCFA)'),
          _InputField(
            controller: montantController,
            hint: 'ex : 25 000',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onMontantChanged,
            prefix: const Icon(Icons.payments_outlined, size: 18, color: AppColors.textHint),
          ),

          const SizedBox(height: 14),

          const _FieldLabel('Description (optionnel)'),
          _InputField(
            controller: descController,
            hint: 'ex : Robe ankara taille M',
            prefix: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textHint),
          ),

          const SizedBox(height: 20),

          // Card récapitulatif — s'affiche dès qu'un montant est saisi
          if (montant > 0 || frais > 0) ...[
            _RecapCard(montant: montant, frais: frais, total: total),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (montant > 0 && !isGenerating) ? onGenerate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
              ),
              child: isGenerating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Générer le lien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.link_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
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

class _RecapCard extends StatelessWidget {
  final int montant;
  final int frais;
  final int total;
  const _RecapCard({required this.montant, required this.frais, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _RecapRow('Montant commande', montant),
          const SizedBox(height: 8),
          _RecapRow('Frais livraison', frais),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
          _RecapRow('Total', total, isTotal: true),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isTotal;
  const _RecapRow(this.label, this.amount, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          '${_fmt(amount)} FCFA',
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: isTotal ? AppColors.green : AppColors.textPrimary,
          ),
        ),
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
    return buf.toString();
  }
}

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final LienPaiement lien;
  final VoidCallback onSend;
  final VoidCallback onCopy;

  const _SuccessView({required this.lien, required this.onSend, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          // Icône succès
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lien généré avec succès !',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Envoyez ce lien à ${lien.contactNom} pour qu\'il puisse payer.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Montant total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${_fmt(lien.montantTotal)} FCFA',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                ),
                const SizedBox(height: 2),
                Text(
                  lien.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.greenDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // URL du lien
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lien.lienUrl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onCopy,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.copy_outlined, size: 18, color: Color(0xFF6C5CE7)),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bouton Envoyer dans la conversation
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Envoyer dans la conversation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bouton Copier le lien
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onCopy,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Copier le lien', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
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

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: prefix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
