import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/models/lien_paiement_model.dart';
import '../../shared/services/inbox_service.dart';
import '../payments/create_link_screen.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  List<Message> _messages = [];
  Thread? _thread;
  Message? _replyToMessage;
  final Set<String> _starredIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await inboxService.getMessages(widget.threadId);
    final threads = await inboxService.getThreads();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _thread = threads.where((t) => t.id == widget.threadId).firstOrNull;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Actions du menu contextuel ───────────────────────────────────────────────

  void _showMessageOptions(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MessageOptionsSheet(
        message: msg,
        isStarred: _starredIds.contains(msg.id),
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: msg.content));
          ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('Message copié'));
        },
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyToMessage = msg);
        },
        onStar: () {
          Navigator.pop(context);
          setState(() {
            if (_starredIds.contains(msg.id)) {
              _starredIds.remove(msg.id);
            } else {
              _starredIds.add(msg.id);
            }
          });
        },
        onPayment: msg.isFromContact
            ? () {
                Navigator.pop(context);
                _openCreateLink();
              }
            : null,
        onEdit: !msg.isFromContact
            ? () {
                Navigator.pop(context);
                _showEditDialog(msg);
              }
            : null,
        onDelete: () {
          Navigator.pop(context);
          _showDeleteConfirm(msg);
        },
      ),
    );
  }

  void _showEditDialog(Message msg) {
    final editController = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: editController,
          maxLines: 4,
          minLines: 1,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundPage,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              setState(() {
                final idx = _messages.indexWhere((m) => m.id == msg.id);
                if (idx != -1) {
                  _messages[idx] = Message(
                    id: msg.id,
                    threadId: msg.threadId,
                    content: newText,
                    isFromContact: msg.isFromContact,
                    sentAt: msg.sentAt,
                    type: msg.type,
                    paymentAmount: msg.paymentAmount,
                    paymentCurrency: msg.paymentCurrency,
                    paymentStatus: msg.paymentStatus,
                    paymentProvider: msg.paymentProvider,
                  );
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('Message modifié'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Message msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce message ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Cette action est irréversible.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _messages.removeWhere((m) => m.id == msg.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('Message supprimé'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── Lien de paiement ─────────────────────────────────────────────────────────

  Future<void> _openCreateLink() async {
    final lien = await Navigator.push<LienPaiement?>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLinkScreen(contactName: _thread?.contactName ?? 'Client'),
      ),
    );
    if (!mounted || lien == null) return;
    setState(() {
      _messages.add(Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        threadId: widget.threadId,
        content: lien.description,
        isFromContact: false,
        sentAt: DateTime.now(),
        type: MessageType.paymentLink,
        paymentAmount: lien.montantTotal.toString(),
        paymentCurrency: 'FCFA',
        paymentStatus: PaymentStatus.created,
        paymentProvider: 'wave',
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(AppSnackbar.success('Lien de paiement envoyé dans la conversation'));
    }
  }

  // ── Helpers message ──────────────────────────────────────────────────────────

  void _addMessage(Message msg) {
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendTextMessage(String content) {
    _addMessage(Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      threadId: widget.threadId,
      content: content,
      isFromContact: false,
      sentAt: DateTime.now(),
    ));
  }

  // ── Pièce jointe ─────────────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    final contactName = _thread?.contactName ?? 'le client';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AttachmentSheet(
        onPayment: () { Navigator.pop(context); _openCreateLink(); },
        onLocation: () {
          Navigator.pop(context);
          _addMessage(Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            threadId: widget.threadId,
            content: 'Boutique Score360 Africa\nCocody Riviera 3, Abidjan\n5.356, -3.987',
            isFromContact: false,
            sentAt: DateTime.now(),
            type: MessageType.location,
          ));
        },
        onCatalogue: () { Navigator.pop(context); _showCatalogueSheet(); },
        onDevis: () { Navigator.pop(context); _showDevisSheet(); },
        onPromotion: () {
          Navigator.pop(context);
          _sendTextMessage(
            '🎁 Offre spéciale pour vous, $contactName !\n'
            'Robe ankara taille M à 15 000 FCFA\n'
            'Valable jusqu\'au ${_fmtDate(DateTime.now().add(const Duration(days: 7)))}.\n'
            'Intéressé(e) ? Répondez-nous 😊',
          );
        },
        onTracking: () {
          Navigator.pop(context);
          _addMessage(Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            threadId: widget.threadId,
            content: 'CMD-${DateTime.now().millisecondsSinceEpoch % 100000}',
            isFromContact: false,
            sentAt: DateTime.now(),
            type: MessageType.orderTracking,
          ));
        },
        onReview: () {
          Navigator.pop(context);
          _sendTextMessage(
            'Bonjour $contactName 😊\n'
            'Êtes-vous satisfait(e) de votre commande ?\n'
            'Notez-nous : ⭐⭐⭐⭐⭐\n'
            'Votre avis compte beaucoup pour nous !',
          );
        },
        onPhoto: () { Navigator.pop(context); _pickImage(); },
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xFile == null || !mounted) return;
      _addMessage(Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        threadId: widget.threadId,
        content: 'Photo produit',
        isFromContact: false,
        sentAt: DateTime.now(),
        type: MessageType.image,
        imagePath: xFile.path,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error('Impossible d\'accéder à la galerie'));
    }
  }

  void _showCatalogueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CatalogueSheet(
        onSend: (product) {
          Navigator.pop(context);
          _sendTextMessage(
            '📦 *${product.name}*\n'
            '${product.emoji}  ${product.description}\n'
            'Prix : ${product.price} FCFA\n'
            'Intéressé(e) ? Répondez-nous !',
          );
        },
      ),
    );
  }

  void _showDevisSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DevisSheet(
        contactName: _thread?.contactName ?? 'Client',
        onSend: (msg) {
          Navigator.pop(context);
          _sendTextMessage(msg);
        },
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    _controller.clear();
    setState(() {
      _isSending = true;
      _replyToMessage = null;
    });
    try {
      await inboxService.sendMessage(widget.threadId, text);
      await _load();
      if (mounted) ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(AppSnackbar.success('Message envoyé'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatAppBar(thread: _thread),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _messages.isEmpty ? 1 : _messages.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return const _SecurityBanner();
                final msg = _messages[i - 1];
                Widget bubble = switch (msg.type) {
                  MessageType.paymentLink   => _PaymentBubble(message: msg),
                  MessageType.location      => _LocationBubble(message: msg),
                  MessageType.orderTracking => _OrderTrackingBubble(message: msg),
                  MessageType.image         => _ImageBubble(message: msg),
                  _                         => _MessageBubble(message: msg, isStarred: _starredIds.contains(msg.id)),
                };
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(msg),
                  child: bubble,
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            isSending: _isSending,
            onSend: _send,
            onPayment: _openCreateLink,
            onAttachment: _showAttachmentSheet,
            replyTo: _replyToMessage,
            onCancelReply: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final Thread? thread;
  const _ChatAppBar({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.backgroundPage,
                child: Text(
                  thread?.contactInitials ?? '?',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(thread?.contactName ?? '...', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(_channelLabel(thread?.channel), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textSecondary), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  String _channelLabel(Channel? ch) => switch (ch) {
    Channel.whatsapp => 'WhatsApp',
    Channel.facebook => 'Facebook',
    Channel.sms      => 'SMS',
    Channel.tiktok   => 'TikTok',
    Channel.email    => 'Email',
    null             => '...',
  };
}

// ── Bannière sécurité ─────────────────────────────────────────────────────────

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messages et appels chiffrés de bout en bout. Personne en dehors de cette conversation ne peut les lire ou les écouter.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle message ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isStarred;
  const _MessageBubble({required this.message, this.isStarred = false});

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: fromContact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Étoile si marqué
          if (isStarred)
            Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                left: fromContact ? 4 : 0,
                right: fromContact ? 0 : 4,
              ),
              child: const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: fromContact ? AppColors.white : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(fromContact ? 4 : 18),
                bottomRight: Radius.circular(fromContact ? 18 : 4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: fromContact ? 0.06 : 0.12), blurRadius: 6, offset: const Offset(0, 2))],
              border: fromContact ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.content,
                  style: TextStyle(fontSize: 14, color: fromContact ? AppColors.textPrimary : AppColors.white, height: 1.4),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.sentAt),
                      style: TextStyle(fontSize: 10, color: fromContact ? AppColors.textHint : AppColors.white.withValues(alpha: 0.65)),
                    ),
                    if (!fromContact) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 12, color: AppColors.white.withValues(alpha: 0.65)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Bulle paiement ────────────────────────────────────────────────────────────

class _PaymentBubble extends StatelessWidget {
  final Message message;
  const _PaymentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.greenLight, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: AppColors.greenDark),
                  const SizedBox(width: 6),
                  const Text('Lien de paiement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                  const Spacer(),
                  if (message.paymentStatus != null) _PaymentStatusBadge(status: message.paymentStatus!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                '${message.paymentAmount ?? "0"} FCFA',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text('Valide 7 jours', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            if (message.paymentStatus != PaymentStatus.paid)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('Voir le lien', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      PaymentStatus.paid    => (AppColors.statusPaidBg,    AppColors.statusPaidText,    'Payé'),
      PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente'),
      PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
      PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

// ── Menu contextuel (long press) ──────────────────────────────────────────────

class _MessageOptionsSheet extends StatelessWidget {
  final Message message;
  final bool isStarred;
  final VoidCallback onCopy;
  final VoidCallback onReply;
  final VoidCallback onStar;
  final VoidCallback? onPayment;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _MessageOptionsSheet({
    required this.message,
    required this.isStarred,
    required this.onCopy,
    required this.onReply,
    required this.onStar,
    required this.onDelete,
    this.onPayment,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Titre discret
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Options du message', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 4),

          // Aperçu du message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Options
          _OptionTile(
            icon: Icons.content_copy_outlined,
            iconColor: AppColors.primary,
            label: 'Copier',
            onTap: onCopy,
          ),
          _OptionTile(
            icon: Icons.reply_outlined,
            iconColor: AppColors.green,
            label: 'Répondre',
            onTap: onReply,
          ),
          _OptionTile(
            icon: isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: isStarred ? 'Retirer le marquage' : 'Marquer',
            onTap: onStar,
          ),

          // Actions spécifiques selon émetteur
          if (onPayment != null)
            _OptionTile(
              icon: Icons.credit_card_outlined,
              iconColor: AppColors.primary,
              label: 'Créer un lien de paiement',
              onTap: onPayment!,
            ),
          if (onEdit != null)
            _OptionTile(
              icon: Icons.edit_outlined,
              iconColor: AppColors.textSecondary,
              label: 'Modifier',
              onTap: onEdit!,
            ),

          const Divider(height: 16, indent: 20, endIndent: 20, color: AppColors.borderLight),

          _OptionTile(
            icon: Icons.delete_outline,
            iconColor: Colors.redAccent,
            label: 'Supprimer',
            labelColor: Colors.redAccent,
            onTap: onDelete,
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: labelColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle localisation ────────────────────────────────────────────────────────

class _LocationBubble extends StatelessWidget {
  final Message message;
  const _LocationBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte mock
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4F0),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Stack(
                children: [
                  // Grille de rues simulée
                  CustomPaint(size: const Size(double.infinity, 110), painter: _MapGridPainter()),
                  // Pin central
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_pin, size: 32, color: Color(0xFFE53E3E)),
                        SizedBox(height: 2),
                        Text('Boutique', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.store_outlined, size: 14, color: AppColors.green),
                      SizedBox(width: 6),
                      Text('Boutique Score360 Africa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text('Cocody Riviera 3, Abidjan', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${message.sentAt.hour.toString().padLeft(2,'0')}:${message.sentAt.minute.toString().padLeft(2,'0')}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCDE8DC)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

// ── Bulle suivi commande ──────────────────────────────────────────────────────

class _OrderTrackingBubble extends StatelessWidget {
  final Message message;
  const _OrderTrackingBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.check_circle_rounded, 'Commandé', true),
      (Icons.inventory_2_outlined, 'En préparation', true),
      (Icons.local_shipping_outlined, 'En livraison', false),
      (Icons.home_outlined, 'Livré', false),
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  const Text('Suivi commande', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(8)),
                    child: Text('CMD-${message.content}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: List.generate(steps.length, (i) {
                  final (icon, label, done) = steps[i];
                  final isLast = i == steps.length - 1;
                  final isCurrent = !done && (i == 0 || steps[i - 1].$3);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(icon, size: 20, color: done ? AppColors.green : (isCurrent ? const Color(0xFFF59E0B) : AppColors.borderLight)),
                          if (!isLast) Container(width: 2, height: 22, color: done ? AppColors.green.withValues(alpha: 0.3) : AppColors.borderLight),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(label, style: TextStyle(
                          fontSize: 13,
                          fontWeight: (done || isCurrent) ? FontWeight.w600 : FontWeight.w400,
                          color: done ? AppColors.green : (isCurrent ? const Color(0xFFF59E0B) : AppColors.textHint),
                        )),
                      ),
                      if (isCurrent) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: const Text('En cours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${message.sentAt.hour.toString().padLeft(2,'0')}:${message.sentAt.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle image ───────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final Message message;
  const _ImageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.file(
                File(message.imagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: AppColors.backgroundPage,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textHint, size: 40)),
                ),
              ),
              Positioned(
                bottom: 6, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${message.sentAt.hour.toString().padLeft(2,'0')}:${message.sentAt.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BottomSheet pièce jointe ──────────────────────────────────────────────────

typedef _VoidCb = VoidCallback;

class _AttachmentSheet extends StatelessWidget {
  final _VoidCb onPayment;
  final _VoidCb onLocation;
  final _VoidCb onCatalogue;
  final _VoidCb onDevis;
  final _VoidCb onPromotion;
  final _VoidCb onTracking;
  final _VoidCb onReview;
  final _VoidCb onPhoto;

  const _AttachmentSheet({
    required this.onPayment,
    required this.onLocation,
    required this.onCatalogue,
    required this.onDevis,
    required this.onPromotion,
    required this.onTracking,
    required this.onReview,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      _AttachOpt(Icons.credit_card_outlined,    const Color(0xFF6C5CE7), const Color(0xFFF0EEFF), 'Paiement',       onPayment),
      _AttachOpt(Icons.location_on_outlined,    AppColors.green,         AppColors.greenLight,    'Localisation',   onLocation),
      _AttachOpt(Icons.grid_view_outlined,      const Color(0xFFF97316), const Color(0xFFFFF3E0), 'Catalogue',      onCatalogue),
      _AttachOpt(Icons.receipt_long_outlined,   const Color(0xFF3B82F6), const Color(0xFFEFF6FF), 'Devis rapide',   onDevis),
      _AttachOpt(Icons.local_offer_outlined,    const Color(0xFFEC4899), const Color(0xFFFDF2F8), 'Promotion',      onPromotion),
      _AttachOpt(Icons.local_shipping_outlined, const Color(0xFF4F46E5), const Color(0xFFEEF2FF), 'Suivi commande', onTracking),
      _AttachOpt(Icons.star_outline_rounded,    const Color(0xFFF59E0B), const Color(0xFFFEF3C7), 'Avis client',    onReview),
      _AttachOpt(Icons.photo_camera_outlined,   const Color(0xFF059669), const Color(0xFFECFDF5), 'Photo produit',  onPhoto),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Raccourcis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            childAspectRatio: 0.80,
            children: options.map((o) => _AttachItem(opt: o)).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AttachOpt {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final VoidCallback onTap;
  const _AttachOpt(this.icon, this.color, this.bg, this.label, this.onTap);
}

class _AttachItem extends StatelessWidget {
  final _AttachOpt opt;
  const _AttachItem({required this.opt});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: opt.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: opt.bg, shape: BoxShape.circle),
            child: Icon(opt.icon, size: 24, color: opt.color),
          ),
          const SizedBox(height: 7),
          Text(
            opt.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── BottomSheet catalogue ─────────────────────────────────────────────────────

class _CatalogueProduct {
  final String name;
  final String emoji;
  final String description;
  final int price;
  const _CatalogueProduct(this.name, this.emoji, this.description, this.price);
}

class _CatalogueSheet extends StatelessWidget {
  final void Function(_CatalogueProduct) onSend;
  const _CatalogueSheet({required this.onSend});

  static const _products = [
    _CatalogueProduct('Robe ankara', '👗', 'Taille S/M/L • Coton premium', 25000),
    _CatalogueProduct('Sac en cuir', '👜', 'Cuir véritable • Marron/Noir', 45000),
    _CatalogueProduct('Ensemble bogolan', '🎽', 'Tissu traditionnel • Unisexe', 18000),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Catalogue produits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Appuyez sur un produit pour l\'envoyer', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 16),
          ..._products.map((p) => _ProductTile(product: p, onTap: () => onSend(p))),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final _CatalogueProduct product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderLight)),
              child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(product.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmt(product.price)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.green)),
                const Text('FCFA', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.send_rounded, size: 18, color: AppColors.green),
          ],
        ),
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

// ── BottomSheet devis rapide ──────────────────────────────────────────────────

class _DevisSheet extends StatefulWidget {
  final String contactName;
  final void Function(String) onSend;
  const _DevisSheet({required this.contactName, required this.onSend});

  @override
  State<_DevisSheet> createState() => _DevisSheetState();
}

class _DevisSheetState extends State<_DevisSheet> {
  final _prodCtrl = TextEditingController();
  final _qtyCtrl  = TextEditingController(text: '1');
  final _prixCtrl = TextEditingController();

  @override
  void dispose() { _prodCtrl.dispose(); _qtyCtrl.dispose(); _prixCtrl.dispose(); super.dispose(); }

  int get _qty   => int.tryParse(_qtyCtrl.text) ?? 0;
  int get _prix  => int.tryParse(_prixCtrl.text.replaceAll(' ', '')) ?? 0;
  int get _total => _qty * _prix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Devis rapide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 16),
            _DevisField('Produit / service', _prodCtrl, TextInputType.text),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DevisField('Quantité', _qtyCtrl, TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: _DevisField('Prix unitaire (FCFA)', _prixCtrl, TextInputType.number, onChanged: (_) => setState(() {}))),
            ]),
            if (_total > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                    Text('${_fmtN(_total)} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_prodCtrl.text.trim().isNotEmpty && _total > 0)
                    ? () => widget.onSend(
                          '📋 *Devis pour ${widget.contactName}*\n\n'
                          '• Produit : ${_prodCtrl.text.trim()}\n'
                          '• Quantité : $_qty\n'
                          '• Prix unitaire : ${_fmtN(_prix)} FCFA\n'
                          '━━━━━━━━━━━━━━\n'
                          '💰 *Total : ${_fmtN(_total)} FCFA*\n\n'
                          'Pour valider, envoyez-nous un message. 🙏',
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Envoyer le devis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtN(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _DevisField extends StatelessWidget {
  final String hint;
  final TextEditingController ctrl;
  final TextInputType kbType;
  final ValueChanged<String>? onChanged;
  const _DevisField(this.hint, this.ctrl, this.kbType, {this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: kbType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPayment;
  final VoidCallback onAttachment;
  final Message? replyTo;
  final VoidCallback onCancelReply;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPayment,
    required this.onAttachment,
    required this.onCancelReply,
    this.replyTo,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bandeau de réponse citée
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: AppColors.green, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo!.isFromContact ? 'Contact' : 'Vous',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                    onPressed: onCancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              // Icône trombone
              GestureDetector(
                onTap: onAttachment,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPage,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(Icons.attach_file, size: 18, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hasText
                    ? GestureDetector(
                        key: const ValueKey('send'),
                        onTap: isSending ? null : onSend,
                        child: Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          child: isSending
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                              : const Icon(Icons.send, color: AppColors.white, size: 20),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('mic'),
                        onTap: () {},
                        child: Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.mic, color: AppColors.white, size: 20),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPayment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.greenDark),
                  SizedBox(width: 6),
                  Text('Paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
