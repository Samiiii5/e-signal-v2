import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _searchController = TextEditingController();
  bool _isSending = false;
  bool _isMuted = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Message> _messages = [];
  Thread? _thread;
  Message? _replyToMessage;
  final Set<String> _starredIds = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, List<String>> _reactions = {};
  final Map<String, MessageStatus> _msgStatus = {};
  bool _showEmojiPicker = false;

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
    _searchController.dispose();
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

  // ── Menu 3 points ────────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) { _searchController.clear(); _searchQuery = ''; }
    });
  }

  void _showStarredMessages() {
    final starred = _messages.where((m) => _starredIds.contains(m.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StarredMessagesSheet(messages: starred, thread: _thread),
    );
  }

  void _showClientProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ClientProfileSheet(
        thread: _thread,
        messageCount: _messages.length,
        onPayment: () { Navigator.pop(context); _openCreateLink(); },
      ),
    );
  }

  void _showConversationStats() {
    final sent     = _messages.where((m) => !m.isFromContact).length;
    final received = _messages.where((m) =>  m.isFromContact).length;
    final links    = _messages.where((m) => m.type == MessageType.paymentLink).length;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConversationStatsSheet(
        total: _messages.length,
        sent: sent,
        received: received,
        links: links,
      ),
    );
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success(
      _isMuted ? 'Conversation mise en sourdine' : 'Sourdine désactivée',
    ));
  }

  void _showBlockDialog() {
    final name = _thread?.contactName ?? 'ce contact';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bloquer le contact ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Bloquer $name ? Vous ne recevrez plus ses messages.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error('$name a été bloqué'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: AppColors.white, shape: const StadiumBorder(), elevation: 0),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la conversation ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Cette action est irréversible.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: AppColors.white, shape: const StadiumBorder(), elevation: 0),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportConversation() async {
    final buf = StringBuffer();
    buf.writeln('Conversation — ${_thread?.contactName ?? 'Inconnu'}');
    buf.writeln('Exportée le ${_fmtDate(DateTime.now())}');
    buf.writeln('─' * 40);
    for (final m in _messages) {
      final who = m.isFromContact ? (_thread?.contactName ?? 'Contact') : 'Vous';
      final time = '${m.sentAt.day.toString().padLeft(2,'0')}/${m.sentAt.month.toString().padLeft(2,'0')}/${m.sentAt.year} ${m.sentAt.hour.toString().padLeft(2,'0')}:${m.sentAt.minute.toString().padLeft(2,'0')}';
      buf.writeln('[$time] $who : ${m.content}');
    }
    await Share.share(buf.toString(), subject: 'Conversation ${_thread?.contactName ?? ''}');
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

  // ── Sélection de messages ────────────────────────────────────────────────────

  void _enterSelectionMode(String msgId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(msgId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String msgId) {
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
        if (_selectedIds.isEmpty) { _isSelectionMode = false; }
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _deleteSelected() {
    final count = _selectedIds.length;
    setState(() {
      _messages.removeWhere((m) => _selectedIds.contains(m.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('$count message(s) supprimé(s)'));
  }

  void _forwardSelected() {
    final count = _selectedIds.length;
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('$count message(s) à transférer (fonctionnalité à venir)'));
  }

  // ── Réactions emoji ──────────────────────────────────────────────────────────

  void _toggleReaction(String msgId, String emoji) {
    setState(() {
      final list = _reactions.putIfAbsent(msgId, () => []);
      if (list.contains(emoji)) {
        list.remove(emoji);
        if (list.isEmpty) _reactions.remove(msgId);
      } else {
        list.add(emoji);
      }
    });
  }

  void _showReactionPicker(Message msg, Offset globalPos) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _ReactionPickerDialog(
        message: msg,
        globalPosition: globalPos,
        currentReactions: _reactions[msg.id] ?? [],
        onToggle: (emoji) { Navigator.pop(context); _toggleReaction(msg.id, emoji); },
      ),
    );
  }

  // ── Statut de livraison ──────────────────────────────────────────────────────

  void _simulateDelivery(String msgId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _msgStatus[msgId] = MessageStatus.delivered);
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _msgStatus[msgId] = MessageStatus.read);
    });
  }

  // ── URL launcher ─────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error('Impossible d\'ouvrir le lien'));
    }
  }

  // ── Image plein écran ────────────────────────────────────────────────────────

  void _showFullscreenImage(Message msg) {
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenImageViewer(message: msg),
    ));
  }

  // ── Appel / vidéo ────────────────────────────────────────────────────────────

  void _onCall() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(AppSnackbar.success('📞 Appel en cours...'));
  }

  void _onVideoCall() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(AppSnackbar.success('🎥 Appel vidéo en cours...'));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    _controller.clear();
    setState(() {
      _isSending = true;
      _replyToMessage = null;
      _showEmojiPicker = false;
      _msgStatus[msgId] = MessageStatus.sent;
    });
    try {
      await inboxService.sendMessage(widget.threadId, text);
      setState(() {
        _messages.add(Message(
          id: msgId,
          threadId: widget.threadId,
          content: text,
          isFromContact: false,
          sentAt: DateTime.now(),
        ));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _simulateDelivery(msgId);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _searchQuery.isEmpty
        ? _messages
        : _messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isSelectionMode ? 60 : (_isSearching ? 60 : 64)),
        child: _isSelectionMode
            ? _SelectionAppBar(
                count: _selectedIds.length,
                onClose: _exitSelectionMode,
                onDelete: _deleteSelected,
                onForward: _forwardSelected,
              )
            : _ChatAppBar(
                thread: _thread,
                isMuted: _isMuted,
                isSearching: _isSearching,
                searchController: _searchController,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onToggleSearch: _toggleSearch,
                onStarred: _showStarredMessages,
                onProfile: _showClientProfile,
                onStats: _showConversationStats,
                onMute: _toggleMute,
                onBlock: _showBlockDialog,
                onDeleteConversation: _showDeleteConversationDialog,
                onExport: _exportConversation,
                onCall: _onCall,
                onVideoCall: _onVideoCall,
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: displayed.isEmpty ? 1 : displayed.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _searchQuery.isNotEmpty && displayed.isEmpty
                      ? const _NoResultsBanner()
                      : const _SecurityBanner();
                }
                final msg = displayed[i - 1];
                final isSelected = _selectedIds.contains(msg.id);
                Widget bubble = switch (msg.type) {
                  MessageType.paymentLink   => _PaymentBubble(
                      message: msg,
                      onTap: () => _launchUrl('https://pay.wave.com/mock'),
                    ),
                  MessageType.location      => _LocationBubble(message: msg),
                  MessageType.orderTracking => _OrderTrackingBubble(message: msg),
                  MessageType.image         => _ImageBubble(
                      message: msg,
                      onTap: () => _showFullscreenImage(msg),
                    ),
                  _                         => _MessageBubble(
                      message: msg,
                      isStarred: _starredIds.contains(msg.id),
                      searchQuery: _searchQuery,
                      reactions: _reactions[msg.id] ?? [],
                      status: _msgStatus[msg.id],
                      onReactionTap: (emoji) => _toggleReaction(msg.id, emoji),
                    ),
                };
                return GestureDetector(
                  onLongPress: () {
                    if (_isSelectionMode) {
                      _toggleSelection(msg.id);
                    } else {
                      _enterSelectionMode(msg.id);
                    }
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(msg.id);
                    } else {
                      _showMessageOptions(msg);
                    }
                  },
                  onDoubleTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                    _showReactionPicker(msg, pos);
                  },
                  child: Container(
                    color: isSelected ? AppColors.green.withValues(alpha: 0.08) : Colors.transparent,
                    child: bubble,
                  ),
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
            showEmojiPicker: _showEmojiPicker,
            onEmojiToggle: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
            onCamera: _pickImage,
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final Thread? thread;
  final bool isMuted;
  final bool isSearching;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback onStarred;
  final VoidCallback onProfile;
  final VoidCallback onStats;
  final VoidCallback onMute;
  final VoidCallback onBlock;
  final VoidCallback onDeleteConversation;
  final VoidCallback onExport;
  final VoidCallback onCall;
  final VoidCallback onVideoCall;

  const _ChatAppBar({
    required this.thread,
    required this.isMuted,
    required this.isSearching,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggleSearch,
    required this.onStarred,
    required this.onProfile,
    required this.onStats,
    required this.onMute,
    required this.onBlock,
    required this.onDeleteConversation,
    required this.onExport,
    required this.onCall,
    required this.onVideoCall,
  });

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
          child: isSearching ? _searchRow(context) : _normalRow(context),
        ),
      ),
    );
  }

  Widget _normalRow(BuildContext context) {
    return Row(
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
              Row(
                children: [
                  Flexible(child: Text(thread?.contactName ?? '...', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                  if (isMuted) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.volume_off, size: 14, color: AppColors.textHint),
                  ],
                ],
              ),
              Text(_channelLabel(thread?.channel), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        // Appel audio
        IconButton(
          icon: const Icon(Icons.call_outlined, size: 20, color: AppColors.green),
          onPressed: onCall,
          tooltip: 'Appel audio',
        ),
        // Appel vidéo
        IconButton(
          icon: const Icon(Icons.videocam_outlined, size: 22, color: AppColors.green),
          onPressed: onVideoCall,
          tooltip: 'Appel vidéo',
        ),
        // Menu 3 points
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          color: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          onSelected: (v) {
            switch (v) {
              case 'search'  : onToggleSearch();
              case 'starred' : onStarred();
              case 'profile' : onProfile();
              case 'stats'   : onStats();
              case 'mute'    : onMute();
              case 'block'   : onBlock();
              case 'delete'  : onDeleteConversation();
              case 'export'  : onExport();
            }
          },
          itemBuilder: (_) => [
            _menuItem('search',  Icons.search_outlined,           AppColors.green,         'Rechercher'),
            _menuItem('starred', Icons.star_outline_rounded,      const Color(0xFFF59E0B), 'Messages importants'),
            _menuItem('profile', Icons.person_outline,            AppColors.primary,       'Profil du client'),
            _menuItem('stats',   Icons.bar_chart_outlined,        const Color(0xFF3B82F6), 'Statistiques'),
            const PopupMenuDivider(),
            _menuItem('mute',    isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                                                                   AppColors.textSecondary, isMuted ? 'Réactiver' : 'Mettre en sourdine'),
            _menuItem('export',  Icons.upload_outlined,           AppColors.textSecondary, 'Exporter'),
            const PopupMenuDivider(),
            _menuItem('block',   Icons.block_outlined,            Colors.redAccent,        'Bloquer le contact'),
            _menuItem('delete',  Icons.delete_outline,            Colors.redAccent,        'Supprimer la conversation'),
          ],
        ),
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textPrimary),
          onPressed: onToggleSearch,
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Rechercher dans la conversation...',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  static PopupMenuItem<String> _menuItem(String value, IconData icon, Color color, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
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
  final String searchQuery;
  final List<String> reactions;
  final MessageStatus? status;
  final void Function(String emoji)? onReactionTap;

  const _MessageBubble({
    required this.message,
    this.isStarred = false,
    this.searchQuery = '',
    this.reactions = const [],
    this.status,
    this.onReactionTap,
  });

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
            margin: EdgeInsets.only(bottom: reactions.isNotEmpty ? 4 : 8),
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
                _HighlightText(
                  text: message.content,
                  query: searchQuery,
                  baseStyle: TextStyle(fontSize: 14, color: fromContact ? AppColors.textPrimary : AppColors.white, height: 1.4),
                  highlightColor: fromContact ? const Color(0xFFFFE082) : const Color(0xFFFFF176),
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
                      _StatusTicks(status: status),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Réactions
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: 8,
                left: fromContact ? 4 : 0,
                right: fromContact ? 0 : 4,
              ),
              child: _ReactionBar(reactions: reactions, onTap: onReactionTap),
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
  final VoidCallback? onTap;
  const _PaymentBubble({required this.message, this.onTap});

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
                    onPressed: onTap,
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

// ── Bannière aucun résultat ───────────────────────────────────────────────────

class _NoResultsBanner extends StatelessWidget {
  const _NoResultsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.textHint),
          SizedBox(height: 8),
          Text('Aucun message trouvé', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Texte surligné pour la recherche ─────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final Color highlightColor;
  const _HighlightText({required this.text, required this.query, required this.baseStyle, required this.highlightColor});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lower.indexOf(q, start)) != -1) {
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: TextStyle(backgroundColor: highlightColor, fontWeight: FontWeight.w700),
      ));
      start = idx + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}

// ── BottomSheet messages importants ──────────────────────────────────────────

class _StarredMessagesSheet extends StatelessWidget {
  final List<Message> messages;
  final Thread? thread;
  const _StarredMessagesSheet({required this.messages, required this.thread});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  const Text('Messages importants', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(10)),
                    child: Text('${messages.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_border_rounded, size: 44, color: AppColors.textHint),
                      SizedBox(height: 8),
                      Text('Aucun message marqué', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ]))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final fromContact = m.isFromContact;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: fromContact ? AppColors.backgroundPage : AppColors.greenLight,
                                child: Text(fromContact ? (thread?.contactInitials ?? '?') : 'Moi',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                        color: fromContact ? AppColors.textPrimary : AppColors.greenDark)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fromContact ? (thread?.contactName ?? '') : 'Vous',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    const SizedBox(height: 3),
                                    Text(m.content, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            ],
                          ),
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

// ── BottomSheet profil client ─────────────────────────────────────────────────

class _ClientProfileSheet extends StatelessWidget {
  final Thread? thread;
  final int messageCount;
  final VoidCallback onPayment;
  const _ClientProfileSheet({required this.thread, required this.messageCount, required this.onPayment});

  @override
  Widget build(BuildContext context) {
    const avatarColors = [Color(0xFF6C5CE7), AppColors.green, Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFFEC4899)];
    final color = thread == null ? AppColors.green : avatarColors[(thread!.contactInitials.hashCode.abs()) % avatarColors.length];
    final channelLabel = switch (thread?.channel) {
      Channel.whatsapp => 'WhatsApp', Channel.facebook => 'Facebook',
      Channel.sms => 'SMS', Channel.tiktok => 'TikTok', Channel.email => 'Email', null => '—',
    };

    return Container(
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          // Avatar
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(child: Text(thread?.contactInitials ?? '?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color))),
          ),
          const SizedBox(height: 12),
          Text(thread?.contactName ?? 'Inconnu', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(12)),
            child: Text(channelLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          // Infos
          Container(
            decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight, width: 0.5)),
            child: Column(
              children: [
                _ProfileInfoRow(Icons.chat_bubble_outline, 'Messages échangés', '$messageCount', isFirst: true),
                _ProfileInfoRow(Icons.calendar_today_outlined, 'Premier contact', '15 Jan 2025'),
                _ProfileInfoRow(Icons.link_outlined, 'Liens de paiement', '2 envoyés', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onPayment,
              icon: const Icon(Icons.credit_card_outlined, size: 16),
              label: const Text('Créer un lien de paiement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  const _ProfileInfoRow(this.icon, this.label, this.value, {this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.borderLight, indent: 16, endIndent: 16),
      ],
    );
  }
}

// ── BottomSheet statistiques ──────────────────────────────────────────────────

class _ConversationStatsSheet extends StatelessWidget {
  final int total;
  final int sent;
  final int received;
  final int links;
  const _ConversationStatsSheet({required this.total, required this.sent, required this.received, required this.links});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.bar_chart_outlined, size: 20, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text('Statistiques', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          // Grille de métriques 2x2
          Row(children: [
            Expanded(child: _StatCard('Total messages', '$total', Icons.chat_bubble_outline, const Color(0xFF3B82F6))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Envoyés', '$sent', Icons.send_outlined, AppColors.green)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard('Reçus', '$received', Icons.inbox_outlined, const Color(0xFF6C5CE7))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Liens paiement', '$links', Icons.link_outlined, const Color(0xFFF59E0B))),
          ]),
          const SizedBox(height: 16),
          // Carte taux de réponse
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E9E5E), Color(0xFF1A6B3A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: Colors.white),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps de réponse moyen', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 2),
                    Text('~5 min', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                Spacer(),
                Text('🏆', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderLight)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Montant encaissé', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('45 000 FCFA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
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
  final VoidCallback? onTap;
  const _ImageBubble({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Align(
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
                Text(_fmt(product.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.green)),
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
  final bool showEmojiPicker;
  final VoidCallback onEmojiToggle;
  final VoidCallback onCamera;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPayment,
    required this.onAttachment,
    required this.onCancelReply,
    required this.showEmojiPicker,
    required this.onEmojiToggle,
    required this.onCamera,
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
              // Emoji toggle
              GestureDetector(
                onTap: onEmojiToggle,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: showEmojiPicker ? AppColors.greenLight : AppColors.backgroundPage,
                    shape: BoxShape.circle,
                    border: Border.all(color: showEmojiPicker ? AppColors.green : AppColors.borderLight),
                  ),
                  child: Icon(
                    showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    size: 18,
                    color: showEmojiPicker ? AppColors.green : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Champ de saisie avec trombone intégré à droite
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      suffixIcon: GestureDetector(
                        onTap: onAttachment,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.attach_file, size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Caméra
              GestureDetector(
                onTap: onCamera,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPage,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              // Micro / Envoi
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
        ],
      ),
    );
  }
}

// ── AppBar mode sélection ─────────────────────────────────────────────────────

class _SelectionAppBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onForward;

  const _SelectionAppBar({
    required this.count,
    required this.onClose,
    required this.onDelete,
    required this.onForward,
  });

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
                icon: const Icon(Icons.close, size: 22, color: AppColors.textPrimary),
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  '$count sélectionné${count > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_outlined, size: 22, color: AppColors.textSecondary),
                onPressed: onForward,
                tooltip: 'Transférer',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Indicateurs de statut (coches) ───────────────────────────────────────────

class _StatusTicks extends StatelessWidget {
  final MessageStatus? status;
  const _StatusTicks({this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return Icon(Icons.access_time, size: 11, color: Colors.white.withValues(alpha: 0.5));
    }
    return switch (status!) {
      MessageStatus.sent      => Icon(Icons.done, size: 12, color: Colors.white.withValues(alpha: 0.65)),
      MessageStatus.delivered => Icon(Icons.done_all, size: 12, color: Colors.white.withValues(alpha: 0.65)),
      MessageStatus.read      => const Icon(Icons.done_all, size: 12, color: Color(0xFF34D399)),
    };
  }
}

// ── Barre de réactions ────────────────────────────────────────────────────────

class _ReactionBar extends StatelessWidget {
  final List<String> reactions;
  final void Function(String emoji)? onTap;
  const _ReactionBar({required this.reactions, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.map((emoji) => GestureDetector(
        onTap: () => onTap?.call(emoji),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.backgroundPage,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 14)),
        ),
      )).toList(),
    );
  }
}

// ── Sélecteur de réactions ────────────────────────────────────────────────────

class _ReactionPickerDialog extends StatelessWidget {
  final Message message;
  final Offset globalPosition;
  final List<String> currentReactions;
  final void Function(String emoji) onToggle;

  const _ReactionPickerDialog({
    required this.message,
    required this.globalPosition,
    required this.currentReactions,
    required this.onToggle,
  });

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '👏', '🙏', '🔥'];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 24,
          right: 24,
          bottom: 100,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _emojis.map((e) {
                  final selected = currentReactions.contains(e);
                  return GestureDetector(
                    onTap: () => onToggle(e),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.greenLight : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Visualiseur plein écran image ─────────────────────────────────────────────

class _FullscreenImageViewer extends StatelessWidget {
  final Message message;
  const _FullscreenImageViewer({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${message.sentAt.day.toString().padLeft(2,'0')}/${message.sentAt.month.toString().padLeft(2,'0')}/${message.sentAt.year}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: message.imagePath != null
              ? Image.file(
                  File(message.imagePath!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                )
              : const Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}
