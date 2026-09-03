import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/services/catalog_service.dart';
import '../../shared/services/inbox_service.dart';
import '../../shared/services/websocket_service.dart';
import 'widgets/payment_link_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;

  /// Thread pré-chargé depuis l'écran parent (optionnel).
  /// S'il est fourni, on évite un appel redondant à getThreads().
  final Thread? thread;
  const ChatScreen({super.key, required this.threadId, this.thread});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Une ligne de la timeline : soit un séparateur de date, soit un message.
class _TimelineRow {
  final String? separatorLabel;
  final Message? message;
  const _TimelineRow.separator(this.separatorLabel) : message = null;
  const _TimelineRow.message(this.message) : separatorLabel = null;
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
  final Set<String> _pinnedIds = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, List<String>> _reactions = {};
  final Map<String, MessageStatus> _msgStatus = {};
  bool _showEmojiPicker = false;

  bool _isLoadingMessages = true;
  String? _loadError;
  bool _hasMore = false;
  String? _nextBeforeId;
  bool _isLoadingMore = false;

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  bool _isContactTyping = false;
  Timer? _typingTimer;
  DateTime? _lastSeenAt;

  /// Dernier envoi de typing_on — sert d'anti-rebond (5 s) pour ne pas
  /// bombarder le serveur à chaque frappe.
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    // Utiliser le thread pré-chargé si disponible — évite un appel getThreads() inutile.
    if (widget.thread != null) _thread = widget.thread;
    _controller.addListener(() => setState(() {}));
    _controller.addListener(_onTypingChanged);
    _scrollController.addListener(_onScroll);
    _loadMessages();
    // Établir la connexion WebSocket pour cet écran
    _connectWebSocket();
  }

  /// POST /inbox/messenger/sender-action — le contact voit « en train
  /// d'écrire ». L'action n'existe que sur Messenger : inutile de l'envoyer
  /// pour WhatsApp, SMS ou Email.
  void _onTypingChanged() {
    if (_thread?.channel != 'messenger') return;
    final threadId = _thread?.id;
    if (threadId == null) return;

    if (_controller.text.trim().isEmpty) {
      if (_lastTypingSent == null) return;
      _lastTypingSent = null;
      inboxService.sendTypingAction(threadId, false);
      return;
    }

    final last = _lastTypingSent;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastTypingSent = DateTime.now();
    inboxService.sendTypingAction(threadId, true);
  }

  void _connectWebSocket() {
    final orgId = SessionService.organizationId;
    final token = SessionService.accessToken;
    if (orgId == null || token == null) {
      debugPrint('=== WS non connecté: orgId ou token null ===');
      return;
    }
    webSocketService.connect(organizationId: orgId, token: token);
    // Ne réagit qu'aux événements de la conversation ouverte
    _wsSubscription = webSocketService.events
        .where((e) => e['thread_id']?.toString() == widget.threadId)
        .listen(_onWsEvent);
  }

  @override
  void dispose() {
    // Prévenir le contact que la saisie est terminée avant de quitter l'écran.
    final threadId = _thread?.id;
    if (_lastTypingSent != null &&
        threadId != null &&
        _thread?.channel == 'messenger') {
      inboxService.sendTypingAction(threadId, false);
    }
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _wsSubscription?.cancel();
    _typingTimer?.cancel();
    // NE PAS appeler webSocketService.disconnect() ici
    // car c'est un singleton partagé avec InboxScreen
    super.dispose();
  }

  // ── Événements WebSocket temps réel ──────────────────────────────────────────

  void _onWsEvent(Map<String, dynamic> event) {
    // Tous les événements documentés sont plats (thread_id à la racine).
    switch (event['event']) {
      case 'new_message':
        _handleWsNewMessage(event);
      case 'message_status_updated':
        _handleWsStatusUpdate(event);
      case 'contact_typing':
        _handleWsContactTyping(event);
      case 'contact_presence_updated':
        _handleWsPresenceUpdate(event);
      case 'messages_read':
        _handleWsMessagesRead(event);
      case 'inbound_call':
        _handleWsInboundCall(event);
    }
  }

  void _handleWsNewMessage(Map<String, dynamic> data) {
    final msgJson = data['message'];
    if (msgJson is! Map) return;
    final newMsg = Message.fromJson(Map<String, dynamic>.from(msgJson));

    // Anti-doublon par ID exact
    if (_messages.any((m) => m.id == newMsg.id)) return;

    // Anti-doublon pour messages OUT : si le WebSocket arrive avant que
    // _send()/_sendLocation() n'ait reçu la réponse HTTP et remplacé l'ID
    // local ('msg_timestamp') par le vrai ID serveur, on retrouve la bulle
    // optimiste par contenu + direction + horodatage proche et on la
    // remplace au lieu d'ajouter un doublon.
    if (newMsg.direction == 'OUT') {
      final sentAt = newMsg.sentAtDt;
      final idx = _messages.indexWhere(
        (m) =>
            m.direction == 'OUT' &&
            m.content == newMsg.content &&
            m.sentAtDt.difference(sentAt).abs() < const Duration(seconds: 10),
      );
      if (idx != -1) {
        final localId = _messages[idx].id;
        setState(() {
          _messages[idx] = newMsg;
          // Transférer le statut de l'ancien ID local vers le vrai ID serveur.
          final oldStatus = _msgStatus.remove(localId);
          _msgStatus[newMsg.id] = oldStatus ?? MessageStatus.sent;
        });
        return;
      }
    }

    setState(() {
      _messages.add(newMsg);
      if (newMsg.initialStatus != null) {
        _msgStatus[newMsg.id] = newMsg.initialStatus!;
      }
      _isContactTyping = false;
    });

    // Ajouter aussi au cache
    inboxService.addMessageToCache(widget.threadId, newMsg);

    // Invalider le cache threads pour mettre à jour le dernier message
    inboxService.invalidateThreadsCache();

    _typingTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    if (newMsg.isFromContact) _markAsRead();
  }

  void _handleWsStatusUpdate(Map<String, dynamic> data) {
    final messageId = data['message_id']?.toString();
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (messageId == null) return;
    final mapped = switch (status) {
      'read' => MessageStatus.read,
      'delivered' => MessageStatus.delivered,
      _ => null,
    };
    if (mapped == null) return;
    setState(() => _msgStatus[messageId] = mapped);
  }

  void _handleWsContactTyping(Map<String, dynamic> data) {
    _typingTimer?.cancel();
    final isTyping = data['is_typing'] == true;
    if (!isTyping) {
      setState(() => _isContactTyping = false);
      return;
    }
    setState(() => _isContactTyping = true);
    _typingTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _isContactTyping = false);
    });
  }

  void _handleWsPresenceUpdate(Map<String, dynamic> data) {
    final lastSeenAt = data['last_seen_at']?.toString();
    if (lastSeenAt == null) return;
    final parsed = DateTime.tryParse(lastSeenAt);
    if (parsed == null) return;
    setState(() => _lastSeenAt = parsed);
  }

  void _handleWsMessagesRead(Map<String, dynamic> data) {
    final readBefore = DateTime.tryParse(
      (data['read_before'] ?? '').toString(),
    );
    if (readBefore == null) return;
    setState(() {
      for (final m in _messages) {
        if (m.direction == 'OUT' && m.sentAtDt.isBefore(readBefore)) {
          _msgStatus[m.id] = MessageStatus.read;
        }
      }
    });
  }

  void _handleWsInboundCall(Map<String, dynamic> data) {
    final call = data['call'];
    final fromWaId =
        (call is Map ? call['from_wa_id']?.toString() : null) ??
        'numéro inconnu';
    ScaffoldMessenger.of(context).showSnackBar(
      AppSnackbar.success('📞 Appel WhatsApp entrant de $fromWaId'),
    );
  }

  void _onScroll() {
    if (_hasMore &&
        !_isLoadingMore &&
        _scrollController.hasClients &&
        _scrollController.offset <= 80) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages({bool forceRefresh = false}) async {
    if (forceRefresh) {
      inboxService.invalidateMessagesCache(widget.threadId);
    }

    // ÉTAPE 1 : Afficher le cache immédiatement
    final cached = inboxService.cachedMessages(widget.threadId);
    if (cached != null && !forceRefresh) {
      setState(() {
        _messages = cached;
        _isLoadingMessages = false; // pas de spinner
        _loadError = null;
        for (final m in cached) {
          if (m.initialStatus != null && !_msgStatus.containsKey(m.id)) {
            _msgStatus[m.id] = m.initialStatus!;
          }
        }
      });
      debugPrint('=== Messages : cache affiché immédiatement ===');
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // ÉTAPE 2 : Revalidation en arrière-plan
      _revalidateMessagesInBackground();
      return;
    }

    // Première ouverture → spinner + appel API
    if (!_isLoadingMessages) {
      setState(() {
        _isLoadingMessages = true;
        _loadError = null;
      });
    }
    try {
      // Charger les messages et (si nécessaire) le thread en parallèle.
      // Si le thread n'est pas encore connu, utiliser le cache des threads
      // plutôt que de rappeler getThreads() (déjà chargé par InboxScreen).
      final Future<List<Thread>?> threadsFuture = _thread == null
          ? (inboxService.cachedThreads != null
                ? Future.value(inboxService.cachedThreads)
                : inboxService.getThreads())
          : Future.value(null);
      final result = await inboxService.getMessages(widget.threadId);
      final threads = await threadsFuture;
      if (!mounted) return;
      setState(() {
        _messages = result.messages;
        _hasMore = result.hasMore;
        _nextBeforeId = result.nextBeforeId;
        // Ne mettre à jour _thread que s'il n'était pas déjà connu.
        if (threads != null) {
          _thread = threads.where((t) => t.id == widget.threadId).firstOrNull;
        }
        // ignore: avoid_print
        print(
          '=== _loadMessages: thread=${_thread?.id} provider=${_thread?.metadataProvider} channel=${_thread?.channel} ===',
        );
        for (final m in result.messages) {
          if (m.initialStatus != null && !_msgStatus.containsKey(m.id)) {
            _msgStatus[m.id] = m.initialStatus!;
          }
        }
        _isLoadingMessages = false;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _markAsRead();
    } on InboxUnauthorizedException {
      if (!mounted) return;
      SessionService.logout();
      GoRouter.of(context).go('/login');
    } on InboxForbiddenException {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
        _loadError = 'Accès non autorisé à cette conversation.';
      });
    } on InboxNetworkException {
      if (!mounted) return;
      _setLoadError('Vérifiez votre connexion internet.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== _loadMessages error: $e ===');
      _setLoadError('Impossible de charger la conversation.');
    }
  }

  /// Affiche l'erreur à la place de la liste (avec bouton « Réessayer ») et la
  /// signale par un snackbar. Aucune donnée de démonstration n'est substituée :
  /// le commercial doit savoir que la conversation n'a pas pu être chargée.
  void _setLoadError(String message) {
    setState(() {
      _isLoadingMessages = false;
      _loadError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error(message));
  }

  // Revalidation silencieuse en arrière-plan
  Future<void> _revalidateMessagesInBackground() async {
    try {
      debugPrint('=== Revalidation messages en arrière-plan ===');
      inboxService.invalidateMessagesCache(widget.threadId);
      final result = await inboxService.getMessages(widget.threadId);
      if (!mounted) return;
      // Mettre à jour seulement si nouveaux messages
      if (result.messages.length > _messages.length) {
        setState(() {
          _messages = result.messages;
          _hasMore = result.hasMore;
          _nextBeforeId = result.nextBeforeId;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        debugPrint('=== Messages mis à jour silencieusement ===');
      }
    } catch (_) {
      debugPrint('=== Revalidation messages échouée — cache conservé ===');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _nextBeforeId == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await inboxService.getMessages(
        widget.threadId,
        beforeId: _nextBeforeId,
      );
      if (!mounted) return;
      setState(() {
        _messages = [...result.messages, ..._messages];
        _hasMore = result.hasMore;
        _nextBeforeId = result.nextBeforeId;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await inboxService.markAsRead(widget.threadId);
    } catch (_) {}
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(AppSnackbar.success('Message copié'));
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
                if (_msgStatus[msg.id] == MessageStatus.read) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppSnackbar.error(
                      'Ce message a déjà été lu et ne peut plus être modifié',
                    ),
                  );
                  return;
                }
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
        title: const Text(
          'Modifier le message',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          minLines: 1,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundPage,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
                    direction: msg.direction,
                    bodyText: newText,
                    messageType: msg.messageType,
                    mediaUrl: msg.mediaUrl,
                    status: msg.status,
                    sentAt: msg.sentAt,
                    paymentAmount: msg.paymentAmount,
                    paymentCurrency: msg.paymentCurrency,
                    paymentStatus: msg.paymentStatus,
                    paymentProvider: msg.paymentProvider,
                  );
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackbar.success('Message modifié'));
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
        title: const Text(
          'Supprimer ce message ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _messages.removeWhere((m) => m.id == msg.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackbar.success('Message supprimé'));
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
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
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
        onPayment: () {
          Navigator.pop(context);
          _openCreateLink();
        },
      ),
    );
  }

  void _showConversationStats() {
    final sent = _messages.where((m) => !m.isFromContact).length;
    final received = _messages.where((m) => m.isFromContact).length;
    final links = _messages
        .where((m) => m.messageType.toUpperCase() == 'PAYMENT_LINK')
        .length;
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
    ScaffoldMessenger.of(context).showSnackBar(
      AppSnackbar.success(
        _isMuted ? 'Conversation mise en sourdine' : 'Sourdine désactivée',
      ),
    );
  }

  void _showBlockDialog() {
    final name = _thread?.contactName ?? 'ce contact';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Bloquer le contact ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bloquer $name ? Vous ne recevrez plus ses messages.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackbar.error('$name a été bloqué'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
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
        title: const Text(
          'Supprimer la conversation ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
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

  Future<void> _exportConversation() async {
    final buf = StringBuffer();
    buf.writeln('Conversation — ${_thread?.contactName ?? 'Inconnu'}');
    buf.writeln('Exportée le ${_fmtDate(DateTime.now())}');
    buf.writeln('─' * 40);
    for (final m in _messages) {
      final who = m.isFromContact
          ? (_thread?.contactName ?? 'Contact')
          : 'Vous';
      final dt = m.sentAtDt;
      final time =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      buf.writeln('[$time] $who : ${m.content}');
    }
    await Share.share(
      buf.toString(),
      subject: 'Conversation ${_thread?.contactName ?? ''}',
    );
  }

  // ── Lien de paiement ─────────────────────────────────────────────────────────

  void _openCreateLink() {
    context.push(
      '/create-link',
      extra: <String, String?>{
        'contactName': _thread?.contactName ?? 'Client',
        'threadId': widget.threadId,
      },
    );
  }

  // ── Helpers message ──────────────────────────────────────────────────────────

  void _addMessage(Message msg) {
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendTextMessage(String content) {
    _addMessage(
      Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        direction: 'OUT',
        bodyText: content,
        sentAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  // ── Pièce jointe ─────────────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    final contactName = _thread?.contactName ?? 'le client';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AttachmentSheet(
        onPayment: () {
          Navigator.pop(context);
          _openCreateLink();
        },
        onLocation: () {
          Navigator.pop(context);
          _sendLocation();
        },
        onCatalogue: () {
          Navigator.pop(context);
          _showCatalogueSheet();
        },
        onDevis: () {
          Navigator.pop(context);
          _showDevisSheet();
        },
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
          _addMessage(
            Message(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              direction: 'OUT',
              bodyText: 'CMD-${DateTime.now().millisecondsSinceEpoch % 100000}',
              messageType: 'ORDER_TRACKING',
              sentAt: DateTime.now().toIso8601String(),
            ),
          );
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
        onPhoto: () {
          Navigator.pop(context);
          _pickImage();
        },
      ),
    );
  }

  Future<void> _sendLocation() async {
    // 1. Vérifier que le GPS est activé
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackbar.error('Activez la localisation de votre téléphone'),
        );
      }
      return;
    }

    // 2. Vérifier/demander la permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppSnackbar.error('Permission GPS refusée'));
      }
      return;
    }

    // 3. Afficher un indicateur de chargement pendant la géolocalisation
    setState(() => _isSending = true);

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackbar.error('Impossible d\'obtenir votre position'),
        );
      }
      return;
    }

    debugPrint(
      '=== GPS position réelle : ${position.latitude}, ${position.longitude} ===',
    );

    // 4. Formater le contenu
    final content =
        '📍 Ma localisation :\nhttps://maps.google.com/?q=${position.latitude},${position.longitude}';

    // 5. Optimistic update — afficher la bulle avant confirmation serveur
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add(
        Message(
          id: msgId,
          direction: 'OUT',
          bodyText: content,
          messageType: 'LOCATION',
          sentAt: DateTime.now().toIso8601String(),
        ),
      );
      _isSending = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // 6. Envoyer au backend
    final provider = _thread?.metadataProvider ?? _thread?.channel ?? '';
    final integrationAccountId = _thread?.integrationAccountId;

    try {
      await inboxService.sendMessage(
        threadId: widget.threadId,
        provider: provider,
        integrationAccountId: integrationAccountId,
        type: 'text',
        content: content,
      );
      inboxService.invalidateMessagesCache(widget.threadId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == msgId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Échec de l\'envoi de la localisation'));
    }
  }

  /// Envoi d'une photo, en deux temps : téléversement du fichier pour obtenir
  /// une URL publique, puis envoi du message avec cette URL. Le serveur (et
  /// Meta derrière lui) ne peut pas lire un chemin local — poster
  /// `media_url: /data/user/0/.../image.jpg` ne partirait jamais.
  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    if (_isSending) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );
    } catch (e) {
      debugPrint('=== PICK IMAGE ERROR: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackbar.error(
            source == ImageSource.camera
                ? 'Impossible d\'accéder à l\'appareil photo'
                : 'Impossible d\'accéder à la galerie',
          ),
        );
      }
      return;
    }

    final imagePath = picked?.path;
    if (imagePath == null || !mounted) return;

    if (_thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error(
          'Conversation non chargée. Veuillez patienter ou rafraîchir.',
        ),
      );
      return;
    }

    final provider = _thread?.metadataProvider ?? _thread?.channel ?? '';
    final integrationAccountId = _thread?.integrationAccountId;
    final localMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final sentAt = DateTime.now().toIso8601String();

    // Bulle optimiste : le fichier local s'affiche (Image.file) pendant le
    // téléversement, puis son URL distante remplace le chemin local.
    setState(() {
      _isSending = true;
      _replyToMessage = null;
      _showEmojiPicker = false;
      _msgStatus[localMsgId] = MessageStatus.sent;
      _messages.add(
        Message(
          id: localMsgId,
          direction: 'OUT',
          messageType: 'IMAGE',
          mediaUrl: imagePath,
          sentAt: sentAt,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      debugPrint('=== SEND IMAGE: $imagePath provider=$provider ===');
      final remoteUrl = await inboxService.uploadMedia(imagePath);
      final serverMsgId = await inboxService.sendMessage(
        threadId: widget.threadId,
        provider: provider,
        integrationAccountId: integrationAccountId,
        type: 'image',
        mediaUrl: remoteUrl,
      );
      inboxService.invalidateMessagesCache(widget.threadId);
      if (!mounted) return;

      // Même règle que pour le texte : sans le vrai message_id serveur,
      // message_status_updated (WebSocket) ne retrouve jamais ce message.
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localMsgId);
        if (idx == -1) return;
        _messages[idx] = Message(
          id: serverMsgId ?? localMsgId,
          direction: 'OUT',
          messageType: 'IMAGE',
          mediaUrl: remoteUrl,
          sentAt: sentAt,
          status: 'sent',
        );
        if (serverMsgId != null) {
          final oldStatus = _msgStatus.remove(localMsgId);
          _msgStatus[serverMsgId] = oldStatus ?? MessageStatus.sent;
        }
      });
    } catch (e) {
      debugPrint('=== SEND IMAGE ERROR ===');
      debugPrint('e.runtimeType: ${e.runtimeType}');
      debugPrint('e: $e');
      if (e is DioException) {
        debugPrint('statusCode: ${e.response?.statusCode}');
        debugPrint('responseData: ${e.response?.data}');
        debugPrint('requestUrl: ${e.requestOptions.uri}');
      }
      debugPrint('=======================');
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == localMsgId);
        _msgStatus.remove(localMsgId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error(_apiErrorMessage(e, 'Échec de l\'envoi de la photo')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Message d'erreur lisible pour un échec d'appel API — partagé par l'envoi
  /// de texte et l'envoi de photo pour que les deux réagissent pareil.
  String _apiErrorMessage(Object e, String fallback) {
    if (e is ArgumentError) {
      // Provider absent du thread — sendMessage() refuse de deviner le canal.
      return 'Canal de la conversation inconnu — impossible d\'envoyer';
    }
    if (e is InboxMediaUploadException) return e.message;
    if (e is DioException) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;
      final serverMsg = responseData is Map
          ? (responseData['detail'] ?? responseData['message'] ?? '')
          : '';
      return switch (status) {
        400 => 'Message invalide : $serverMsg',
        401 => 'Session expirée, reconnectez-vous',
        403 => 'Fenêtre de messagerie expirée (24h)',
        404 => 'Conversation introuvable',
        413 => 'Fichier trop volumineux',
        415 => 'Format de fichier non pris en charge',
        422 => 'Contenu rejeté par le serveur : $serverMsg',
        429 => 'Trop de messages envoyés, attendez',
        500 => 'Erreur serveur, réessayez plus tard',
        502 => 'Service temporairement indisponible',
        null => 'Pas de connexion internet',
        _ => 'Erreur $status : $serverMsg',
      };
    }
    return fallback;
  }

  void _showCatalogueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CatalogueSheet(
        onSend: (selectedProducts) {
          Navigator.pop(context);
          _sendCatalogSelection(selectedProducts);
        },
      ),
    );
  }

  Future<void> _sendCatalogSelection(
    List<Map<String, dynamic>> selectedProducts,
  ) async {
    final provider = _thread?.metadataProvider ?? _thread?.channel;
    final accountId = _thread?.integrationAccountId;
    if (provider == null || provider.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Conversation introuvable'));
      return;
    }
    if (accountId == null || accountId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Compte d\'intégration introuvable'));
      return;
    }
    try {
      debugPrint(
        '=== Account ID du thread: $accountId pour provider: $provider ===',
      );
      final items = selectedProducts
          .map(
            (p) => {
              'product_id': p['product_id'].toString(),
              'title': p['name']?.toString() ?? '',
              'image_url': p['thumbnail_url']?.toString() ?? '',
            },
          )
          .where((item) => item['product_id'].toString().isNotEmpty)
          .toList();
      debugPrint(
        '=== CAROUSEL body : thread=${widget.threadId} provider=$provider accountId=$accountId items=$items ===',
      );
      final serverMessageId = await inboxService.sendCarousel(
        threadId: widget.threadId,
        provider: provider,
        integrationAccountId: accountId,
        catalogItemIds: items,
      );
      // Invalider le cache et recharger pour obtenir le vrai message serveur
      inboxService.invalidateMessagesCache(widget.threadId);
      if (!mounted) return;

      // Utiliser le vrai message_id du serveur (fallback local si absent de
      // la réponse) pour que WebSocket puisse mettre à jour le statut
      // correctement via message_status_updated.
      final msgId =
          serverMessageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      _addMessage(
        Message(
          id: msgId,
          direction: 'OUT',
          bodyText:
              '📦 Catalogue envoyé — ${selectedProducts.length} produit${selectedProducts.length > 1 ? 's' : ''}',
          messageType: 'CAROUSEL',
          sentAt: DateTime.now().toIso8601String(),
          status: 'sent',
        ),
      );
      setState(() => _msgStatus[msgId] = MessageStatus.sent);
      debugPrint('=== CAROUSEL envoyé ✅ serverMsgId: $msgId ===');

      // Recharger en arrière-plan pour remplacer la bulle optimiste par le
      // vrai message du serveur (utile surtout si serverMessageId était null).
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _revalidateMessagesInBackground();
      });
    } catch (e) {
      debugPrint('=== Erreur envoi catalogue: $e ===');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error('Échec de l\'envoi du catalogue: ${e.toString()}'),
      );
    }
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
    const m = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  // ── Séparateurs de dates (règle WhatsApp) ────────────────────────────────────

  /// Intercale un séparateur de date avant chaque premier message d'un jour.
  List<_TimelineRow> _buildTimeline(List<Message> messages) {
    final rows = <_TimelineRow>[];
    DateTime? previousDay;
    for (final msg in messages) {
      final sentAt = msg.sentAtDt;
      final msgDay = DateTime(sentAt.year, sentAt.month, sentAt.day);
      if (previousDay == null || previousDay != msgDay) {
        rows.add(_TimelineRow.separator(_formatSeparatorDate(sentAt)));
        previousDay = msgDay;
      }
      rows.add(_TimelineRow.message(msg));
    }
    return rows;
  }

  String _formatSeparatorDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff < 7) {
      const jours = [
        'Lundi',
        'Mardi',
        'Mercredi',
        'Jeudi',
        'Vendredi',
        'Samedi',
        'Dimanche',
      ];
      return jours[date.weekday - 1];
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(AppSnackbar.success('$count message(s) supprimé(s)'));
  }

  void _replySelected() {
    if (_selectedIds.isEmpty) return;
    final msgId = _selectedIds.first;
    final msg = _messages.firstWhere(
      (m) => m.id == msgId,
      orElse: () => _messages.first,
    );
    _exitSelectionMode();
    setState(() => _replyToMessage = msg);
  }

  void _starSelected() {
    setState(() {
      for (final id in _selectedIds) {
        if (_starredIds.contains(id)) {
          _starredIds.remove(id);
        } else {
          _starredIds.add(id);
        }
      }
    });
    _exitSelectionMode();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(AppSnackbar.success('Favori mis à jour'));
  }

  void _copySelected() {
    final msgs = _messages.where((m) => _selectedIds.contains(m.id)).toList();
    final text = msgs.map((m) => m.content).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _exitSelectionMode();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(AppSnackbar.success('Message copié'));
  }

  void _forwardSelected() {
    _doForwardSelected();
  }

  Future<void> _doForwardSelected() async {
    final threads = await inboxService.getThreads();
    if (!mounted) return;
    final count = _selectedIds.length;
    _exitSelectionMode();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ForwardSheet(
        threads: threads,
        currentThreadId: widget.threadId,
        onForward: (thread) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            AppSnackbar.success(
              '$count message(s) transféré(s) à ${thread.contactName}',
            ),
          );
        },
      ),
    );
  }

  void _showInfoSelected() {
    if (_selectedIds.isEmpty) return;
    final msgId = _selectedIds.first;
    final msg = _messages.firstWhere(
      (m) => m.id == msgId,
      orElse: () => _messages.first,
    );
    final status = _msgStatus[msgId];
    _exitSelectionMode();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageInfoSheet(message: msg, status: status),
    );
  }

  void _pinSelected() {
    setState(() {
      for (final id in _selectedIds) {
        if (_pinnedIds.contains(id)) {
          _pinnedIds.remove(id);
        } else {
          _pinnedIds.add(id);
        }
      }
    });
    _exitSelectionMode();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(AppSnackbar.success('Message épinglé'));
  }

  void _editSelected() {
    if (_selectedIds.isEmpty) return;
    final msgId = _selectedIds.first;
    final msg = _messages.firstWhere(
      (m) => m.id == msgId,
      orElse: () => _messages.first,
    );
    _exitSelectionMode();
    if (_msgStatus[msgId] == MessageStatus.read) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error(
          'Ce message a déjà été lu et ne peut plus être modifié',
        ),
      );
      return;
    }
    _showEditDialog(msg);
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
        onToggle: (emoji) {
          Navigator.pop(context);
          _toggleReaction(msg.id, emoji);
        },
      ),
    );
  }

  // ── Image plein écran ────────────────────────────────────────────────────────

  void _showFullscreenImage(Message msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(message: msg),
      ),
    );
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

    // Vérification que le thread est chargé
    if (_thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackbar.error(
          'Conversation non chargée. Veuillez patienter ou rafraîchir.',
        ),
      );
      return;
    }

    // Créer ID local temporaire (optimistic) — remplacé par le vrai
    // message_id serveur une fois la réponse reçue.
    final localMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final provider = _thread?.metadataProvider ?? _thread?.channel ?? '';
    final integrationAccountId = _thread?.integrationAccountId;
    _controller.clear();
    // Optimistic update : le message apparaît tout de suite, avant même la
    // réponse du serveur. Les coches réelles arrivent via message_status_updated.
    setState(() {
      _isSending = true;
      _replyToMessage = null;
      _showEmojiPicker = false;
      _msgStatus[localMsgId] = MessageStatus.sent;
      _messages.add(
        Message(
          id: localMsgId,
          direction: 'OUT',
          bodyText: text,
          sentAt: DateTime.now().toIso8601String(),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    try {
      debugPrint('=== SEND DEBUG ===');
      debugPrint('threadId: ${widget.threadId}');
      debugPrint('thread.channel: ${_thread?.channel}');
      debugPrint('thread.metadataProvider: ${_thread?.metadataProvider}');
      debugPrint(
        'thread.integrationAccountId: ${_thread?.integrationAccountId}',
      );
      debugPrint('provider utilisé: $provider');
      debugPrint('integrationAccountId utilisé: $integrationAccountId');
      debugPrint('content: $text');
      debugPrint('==================');
      final serverMsgId = await inboxService.sendMessage(
        threadId: widget.threadId,
        provider: provider,
        integrationAccountId: integrationAccountId,
        type: 'text',
        content: text,
      );

      // Remplacer l'ID local par le vrai ID serveur — sans ça,
      // message_status_updated (WebSocket) ne trouve jamais ce message
      // dans _msgStatus et l'horloge ne progresse jamais.
      if (serverMsgId != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == localMsgId);
          if (idx != -1) {
            final oldMsg = _messages[idx];
            _messages[idx] = Message(
              id: serverMsgId,
              direction: oldMsg.direction,
              bodyText: oldMsg.bodyText,
              messageType: oldMsg.messageType,
              sentAt: oldMsg.sentAt,
              status: 'sent',
            );
            // Transférer le statut au vrai ID
            final oldStatus = _msgStatus.remove(localMsgId);
            _msgStatus[serverMsgId] = oldStatus ?? MessageStatus.sent;
          }
        });
        debugPrint(
          '=== _send: localId $localMsgId → serverMsgId $serverMsgId ===',
        );
      }

      // Le message envoyé n'est pas dans le cache — l'invalider pour que
      // le prochain chargement de la conversation le récupère depuis l'API.
      inboxService.invalidateMessagesCache(widget.threadId);
    } catch (e) {
      debugPrint('=== SEND ERROR ===');
      debugPrint('e.runtimeType: ${e.runtimeType}');
      debugPrint('e: $e');
      if (e is DioException) {
        debugPrint('statusCode: ${e.response?.statusCode}');
        debugPrint('responseData: ${e.response?.data}');
        debugPrint('requestData: ${e.requestOptions.data}');
        debugPrint('requestUrl: ${e.requestOptions.uri}');
      }
      debugPrint('==================');
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == localMsgId);
        _msgStatus.remove(localMsgId);
      });
      final errorMsg = _apiErrorMessage(e, 'Échec de l\'envoi du message');
      ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error(errorMsg));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _searchQuery.isEmpty
        ? _messages
        : _messages
              .where(
                (m) => m.content.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    final timeline = _buildTimeline(displayed);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          _isSelectionMode ? 60 : (_isSearching ? 60 : 64),
        ),
        child: _isSelectionMode
            ? _SelectionAppBar(
                count: _selectedIds.length,
                onClose: _exitSelectionMode,
                onReply: _replySelected,
                onStar: _starSelected,
                onDelete: _deleteSelected,
                onForward: _forwardSelected,
                onInfo: _showInfoSelected,
                onCopy: _copySelected,
                onEdit: _editSelected,
                onPin: _pinSelected,
              )
            : _ChatAppBar(
                thread: _thread,
                isMuted: _isMuted,
                isTyping: _isContactTyping,
                lastSeenAt: _lastSeenAt,
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
          if (_isLoadingMessages)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.green,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_loadError != null && _messages.isEmpty)
            Expanded(
              child: _MessagesErrorState(
                error: _loadError!,
                onRetry: _loadMessages,
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: displayed.isEmpty
                    ? 1
                    : timeline.length + (_isLoadingMore ? 2 : 1),
                itemBuilder: (_, i) {
                  if (_isLoadingMore && i == 0) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.green,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  final idx = _isLoadingMore ? i - 1 : i;
                  if (idx == 0) {
                    return _searchQuery.isNotEmpty && displayed.isEmpty
                        ? const _NoResultsBanner()
                        : const _SecurityBanner();
                  }
                  final row = timeline[idx - 1];
                  if (row.separatorLabel != null) {
                    return _DateSeparator(label: row.separatorLabel!);
                  }
                  final msg = row.message!;
                  final isSelected = _selectedIds.contains(msg.id);
                  Widget bubble = switch (msg.type) {
                    MessageType.paymentLink => PaymentLinkBubble(message: msg),
                    MessageType.location => _LocationBubble(message: msg),
                    MessageType.orderTracking => _OrderTrackingBubble(
                      message: msg,
                    ),
                    MessageType.image => _ImageBubble(
                      message: msg,
                      onTap: () => _showFullscreenImage(msg),
                    ),
                    MessageType.sticker => _StickerBubble(message: msg),
                    MessageType.audio => _AudioBubble(message: msg),
                    MessageType.video => _VideoBubble(message: msg),
                    MessageType.document => _DocumentBubble(message: msg),
                    MessageType.carousel => _CarouselBubble(message: msg),
                    MessageType.contact => _ContactBubble(message: msg),
                    _ => _MessageBubble(
                      message: msg,
                      isStarred: _starredIds.contains(msg.id),
                      isPinned: _pinnedIds.contains(msg.id),
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
                      final pos =
                          box?.localToGlobal(Offset.zero) ?? Offset.zero;
                      _showReactionPicker(msg, pos);
                    },
                    child: Container(
                      color: (isSelected && _isSelectionMode)
                          ? const Color(0xFFE8F8F0)
                          : Colors.transparent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_isSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.green
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.green
                                        : Colors.grey.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          Expanded(child: bubble),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: _InputBar(
              controller: _controller,
              isSending: _isSending,
              onSend: _send,
              onPayment: _openCreateLink,
              onAttachment: _showAttachmentSheet,
              replyTo: _replyToMessage,
              onCancelReply: () => setState(() => _replyToMessage = null),
              showEmojiPicker: _showEmojiPicker,
              onEmojiToggle: () =>
                  setState(() => _showEmojiPicker = !_showEmojiPicker),
              onCamera: () => _pickImage(ImageSource.camera),
            ),
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
  final bool isTyping;
  final DateTime? lastSeenAt;

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
    this.isTyping = false,
    this.lastSeenAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
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
          icon: const Icon(
            Icons.arrow_back,
            size: 22,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.backgroundPage,
              child: Text(
                thread?.contactInitials ?? '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (thread?.isOnline == true)
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      thread?.contactName ?? '...',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMuted) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.volume_off,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ],
                ],
              ),
              Text(
                _subtitle(),
                style: TextStyle(
                  fontSize: 12,
                  color: isTyping ? AppColors.green : AppColors.textSecondary,
                  fontWeight: isTyping ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Appel audio
        IconButton(
          icon: const Icon(
            Icons.call_outlined,
            size: 20,
            color: AppColors.green,
          ),
          onPressed: onCall,
          tooltip: 'Appel audio',
        ),
        // Appel vidéo
        IconButton(
          icon: const Icon(
            Icons.videocam_outlined,
            size: 22,
            color: AppColors.green,
          ),
          onPressed: onVideoCall,
          tooltip: 'Appel vidéo',
        ),
        // Menu 3 points
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
          onSelected: (v) {
            switch (v) {
              case 'search':
                onToggleSearch();
              case 'starred':
                onStarred();
              case 'profile':
                onProfile();
              case 'stats':
                onStats();
              case 'mute':
                onMute();
              case 'block':
                onBlock();
              case 'delete':
                onDeleteConversation();
              case 'export':
                onExport();
            }
          },
          itemBuilder: (_) => [
            _menuItem(
              'search',
              Icons.search_outlined,
              AppColors.green,
              'Rechercher',
            ),
            _menuItem(
              'starred',
              Icons.star_outline_rounded,
              const Color(0xFFF59E0B),
              'Messages importants',
            ),
            _menuItem(
              'profile',
              Icons.person_outline,
              AppColors.primary,
              'Profil du client',
            ),
            _menuItem(
              'stats',
              Icons.bar_chart_outlined,
              const Color(0xFF3B82F6),
              'Statistiques',
            ),
            const PopupMenuDivider(),
            _menuItem(
              'mute',
              isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              AppColors.textSecondary,
              isMuted ? 'Réactiver' : 'Mettre en sourdine',
            ),
            _menuItem(
              'export',
              Icons.upload_outlined,
              AppColors.textSecondary,
              'Exporter',
            ),
            const PopupMenuDivider(),
            _menuItem(
              'block',
              Icons.block_outlined,
              Colors.redAccent,
              'Bloquer le contact',
            ),
            _menuItem(
              'delete',
              Icons.delete_outline,
              Colors.redAccent,
              'Supprimer la conversation',
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 22,
            color: AppColors.textPrimary,
          ),
          onPressed: onToggleSearch,
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              autofocus: true,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Rechercher dans la conversation...',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textHint,
                ),
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

  static PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    Color color,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  String _channelLabel(String? ch) => switch (ch) {
    'whatsapp' => 'WhatsApp',
    'messenger' => 'Facebook',
    'sms' => 'SMS',
    'tiktok' => 'TikTok',
    'email' => 'Email',
    _ => ch ?? '...',
  };

  // Le point vert sur l'avatar porte déjà l'état "en ligne" — ici on
  // n'affiche que "vu il y a X min" quand le contact n'est pas en ligne.
  String _subtitle() {
    if (isTyping) return 'en train d\'écrire...';
    if (lastSeenAt != null && thread?.isOnline != true) {
      return _fmtLastSeen(lastSeenAt!);
    }
    return _channelLabel(thread?.channel);
  }

  String _fmtLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'vu à l\'instant';
    if (diff.inMinutes < 60) return 'vu il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'vu il y a ${diff.inHours} h';
    return 'vu il y a ${diff.inDays} j';
  }
}

// ── Bannière sécurité ─────────────────────────────────────────────────────────

class _MessagesErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _MessagesErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: AppColors.borderLight,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Séparateur de date (style WhatsApp) ────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.borderLight, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.borderLight, thickness: 0.5),
          ),
        ],
      ),
    );
  }
}

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
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
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
  final bool isPinned;
  final String searchQuery;
  final List<String> reactions;
  final MessageStatus? status;
  final void Function(String emoji)? onReactionTap;

  const _MessageBubble({
    required this.message,
    this.isStarred = false,
    this.isPinned = false,
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
        crossAxisAlignment: fromContact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          // Étoile si marqué
          if (isStarred || isPinned)
            Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                left: fromContact ? 4 : 0,
                right: fromContact ? 0 : 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isStarred)
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  if (isStarred && isPinned) const SizedBox(width: 4),
                  if (isPinned)
                    const Icon(
                      Icons.push_pin,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: fromContact ? 0.06 : 0.12,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: fromContact
                  ? Border.all(color: AppColors.borderLight, width: 0.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _LinkAwareText(
                  text: message.content,
                  query: searchQuery,
                  baseStyle: TextStyle(
                    fontSize: 14,
                    color: fromContact
                        ? AppColors.textPrimary
                        : AppColors.white,
                    height: 1.4,
                  ),
                  highlightColor: fromContact
                      ? const Color(0xFFFFE082)
                      : const Color(0xFFFFF176),
                  fromContact: fromContact,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.sentAtDt),
                      style: TextStyle(
                        fontSize: 10,
                        color: fromContact
                            ? AppColors.textHint
                            : AppColors.white.withValues(alpha: 0.65),
                      ),
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

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Texte avec détection de liens ─────────────────────────────────────────────

/// Découpe le texte d'un message autour des URLs qu'il contient : le texte
/// normal garde le surlignage de recherche existant (_HighlightText), et
/// chaque URL devient un lien cliquable formaté selon son type.
class _LinkAwareText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final Color highlightColor;
  final bool fromContact;

  const _LinkAwareText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
    required this.fromContact,
  });

  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final matches = _urlPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return _HighlightText(
        text: text,
        query: query,
        baseStyle: baseStyle,
        highlightColor: highlightColor,
      );
    }

    final pieces = <Widget>[];
    int cursor = 0;
    for (final match in matches) {
      final before = text.substring(cursor, match.start);
      if (before.trim().isNotEmpty) {
        pieces.add(
          _HighlightText(
            text: before.trim(),
            query: query,
            baseStyle: baseStyle,
            highlightColor: highlightColor,
          ),
        );
      }
      final url = match.group(0)!;
      debugPrint('=== LIEN détecté : $url ===');
      pieces.add(_LinkChip(url: url, fromContact: fromContact));
      cursor = match.end;
    }
    final after = text.substring(cursor);
    if (after.trim().isNotEmpty) {
      pieces.add(
        _HighlightText(
          text: after.trim(),
          query: query,
          baseStyle: baseStyle,
          highlightColor: highlightColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < pieces.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          pieces[i],
        ],
      ],
    );
  }
}

/// Lien cliquable dans une bulle de message — mis en forme selon son type
/// (carte, paiement, ou lien générique raccourci).
class _LinkChip extends StatelessWidget {
  final String url;
  final bool fromContact;
  const _LinkChip({required this.url, required this.fromContact});

  bool get _isMapLink {
    final lower = url.toLowerCase();
    return lower.contains('maps.google.com') ||
        lower.contains('google.com/maps') ||
        lower.contains('goo.gl/maps');
  }

  bool get _isPaymentLink {
    final lower = url.toLowerCase();
    return lower.contains('wave.com') || lower.contains('cinetpay.com');
  }

  String _shorten(String u) => u.length > 40 ? '${u.substring(0, 40)}...' : u;

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Impossible d\'ouvrir le lien'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? icon;
    final String label;
    if (_isMapLink) {
      icon = '📍';
      label = 'Voir sur la carte';
    } else if (_isPaymentLink) {
      icon = '💳';
      label = 'Lien de paiement';
    } else {
      icon = null;
      label = _shorten(url);
    }
    final linkColor = fromContact ? const Color(0xFF1565C0) : AppColors.white;

    return InkWell(
      onTap: () => _openLink(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: linkColor,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Titre discret
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Options du message',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
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

          const Divider(
            height: 16,
            indent: 20,
            endIndent: 20,
            color: AppColors.borderLight,
          ),

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
              width: 36,
              height: 36,
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
          Text(
            'Aucun message trouvé',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
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
  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
  });

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
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = idx + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
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
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Messages importants',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPage,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${messages.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_border_rounded,
                            size: 44,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Aucun message marqué',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppColors.borderLight,
                      ),
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
                                backgroundColor: fromContact
                                    ? AppColors.backgroundPage
                                    : AppColors.greenLight,
                                child: Text(
                                  fromContact
                                      ? (thread?.contactInitials ?? '?')
                                      : 'Moi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: fromContact
                                        ? AppColors.textPrimary
                                        : AppColors.greenDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fromContact
                                          ? (thread?.contactName ?? '')
                                          : 'Vous',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.content,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
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
  const _ClientProfileSheet({
    required this.thread,
    required this.messageCount,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    const avatarColors = [
      Color(0xFF6C5CE7),
      AppColors.green,
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
    ];
    final color = thread == null
        ? AppColors.green
        : avatarColors[(thread!.contactInitials.hashCode.abs()) %
              avatarColors.length];
    final channelLabel = switch (thread?.channel) {
      'whatsapp' => 'WhatsApp',
      'messenger' => 'Facebook',
      'sms' => 'SMS',
      'tiktok' => 'TikTok',
      'email' => 'Email',
      _ => '—',
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
          const SizedBox(height: 24),
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                thread?.contactInitials ?? '?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            thread?.contactName ?? 'Inconnu',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              channelLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Infos
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight, width: 0.5),
            ),
            child: Column(
              children: [
                _ProfileInfoRow(
                  Icons.chat_bubble_outline,
                  'Messages échangés',
                  '$messageCount',
                  isFirst: true,
                ),
                _ProfileInfoRow(
                  Icons.calendar_today_outlined,
                  'Premier contact',
                  '15 Jan 2025',
                ),
                _ProfileInfoRow(
                  Icons.link_outlined,
                  'Liens de paiement',
                  '2 envoyés',
                  isLast: true,
                ),
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
              label: const Text(
                'Créer un lien de paiement',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
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
  const _ProfileInfoRow(
    this.icon,
    this.label,
    this.value, {
    this.isFirst = false,
    this.isLast = false,
  });

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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            color: AppColors.borderLight,
            indent: 16,
            endIndent: 16,
          ),
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
  const _ConversationStatsSheet({
    required this.total,
    required this.sent,
    required this.received,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 20,
                color: Color(0xFF3B82F6),
              ),
              SizedBox(width: 8),
              Text(
                'Statistiques',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Grille de métriques 2x2
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'Total messages',
                  '$total',
                  Icons.chat_bubble_outline,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  'Envoyés',
                  '$sent',
                  Icons.send_outlined,
                  AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'Reçus',
                  '$received',
                  Icons.inbox_outlined,
                  const Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  'Liens paiement',
                  '$links',
                  Icons.link_outlined,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Carte taux de réponse
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E9E5E), Color(0xFF1A6B3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: Colors.white),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temps de réponse moyen',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '~5 min',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
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
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant encaissé',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '45 000 FCFA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle localisation ────────────────────────────────────────────────────────

class _LocationBubble extends StatelessWidget {
  final Message message;
  const _LocationBubble({required this.message});

  static final RegExp _urlPattern = RegExp(r'https?://\S+');
  static final RegExp _coordsPattern = RegExp(r'q=(-?\d+\.?\d*),(-?\d+\.?\d*)');

  String get _mapsUrl =>
      _urlPattern.firstMatch(message.content)?.group(0) ??
      'https://maps.google.com/';

  String get _label {
    final firstLine = message.content
        .split('\n')
        .first
        .replaceAll('📍', '')
        .trim();
    return firstLine.isNotEmpty ? firstLine : 'Position partagée';
  }

  String? get _coordsLabel {
    final match = _coordsPattern.firstMatch(message.content);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte mock — pas de rendu de carte réelle, juste un repère visuel
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4F0),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Stack(
                children: [
                  // Grille de rues simulée
                  CustomPaint(
                    size: const Size(double.infinity, 110),
                    painter: _MapGridPainter(),
                  ),
                  // Pin central
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      size: 32,
                      color: Color(0xFFE53E3E),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_coordsLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _coordsLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final uri = Uri.tryParse(_mapsUrl);
                            if (uri != null && await canLaunchUrl(uri)) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 13,
                                  color: AppColors.greenDark,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Voir sur la carte',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${message.sentAtDt.hour.toString().padLeft(2, '0')}:${message.sentAtDt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
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
    final paint = Paint()
      ..color = const Color(0xFFCDE8DC)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Suivi commande',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CMD-${message.content}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
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
                          Icon(
                            icon,
                            size: 20,
                            color: done
                                ? AppColors.green
                                : (isCurrent
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.borderLight),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 22,
                              color: done
                                  ? AppColors.green.withValues(alpha: 0.3)
                                  : AppColors.borderLight,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (done || isCurrent)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: done
                                ? AppColors.green
                                : (isCurrent
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.textHint),
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'En cours',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
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
                  '${message.sentAtDt.hour.toString().padLeft(2, '0')}:${message.sentAtDt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
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
        alignment: message.isFromContact
            ? Alignment.centerLeft
            : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                _buildImage(),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${message.sentAtDt.hour.toString().padLeft(2, '0')}:${message.sentAtDt.minute.toString().padLeft(2, '0')}',
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

  /// Les images reçues du serveur portent une URL HTTP ; celles que le
  /// commercial vient de choisir dans sa galerie portent un chemin local.
  /// Image.file ne sait lire que le second cas — d'où l'aiguillage.
  Widget _buildImage() {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return _placeholder();

    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          return Container(
            height: 200,
            width: double.infinity,
            color: AppColors.backgroundPage,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.green,
                  value: total != null
                      ? progress.cumulativeBytesLoaded / total
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return Image.file(
      File(url),
      fit: BoxFit.cover,
      width: double.infinity,
      height: 200,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    height: 160,
    width: double.infinity,
    color: AppColors.backgroundPage,
    child: const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textHint,
        size: 40,
      ),
    ),
  );
}

// ── Bulle Sticker ─────────────────────────────────────────────────────────────

class _StickerBubble extends StatelessWidget {
  final Message message;
  const _StickerBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    Widget content;
    
    if (url != null && url.isNotEmpty) {
      content = Image.network(
        url,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image, 
          size: 48, 
          color: AppColors.textHint,
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isFromContact ? AppColors.backgroundPage : AppColors.greenLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              message.content.isNotEmpty ? message.content : 'Sticker',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: message.isFromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: message.isFromContact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            content,
            const SizedBox(height: 4),
            Text(
              '${message.sentAtDt.hour.toString().padLeft(2, '0')}:${message.sentAtDt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle audio ───────────────────────────────────────────────────────────────

class _AudioBubble extends StatefulWidget {
  final Message message;
  const _AudioBubble({required this.message});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final fromContact = widget.message.isFromContact;
    final fg = fromContact ? AppColors.textPrimary : AppColors.white;
    final track = fromContact
        ? AppColors.borderLight
        : Colors.white.withValues(alpha: 0.3);
    final progress = fromContact ? AppColors.green : AppColors.white;

    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fromContact ? AppColors.white : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: fromContact
              ? Border.all(color: AppColors.borderLight, width: 0.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _isPlaying = !_isPlaying),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: fromContact
                      ? AppColors.greenLight
                      : Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 18,
                  color: fromContact ? AppColors.greenDark : AppColors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.mic_none_rounded,
              size: 16,
              color: fg.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.35,
                  minHeight: 3,
                  backgroundColor: track,
                  color: progress,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:32',
              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle vidéo ───────────────────────────────────────────────────────────────

class _VideoBubble extends StatelessWidget {
  final Message message;
  const _VideoBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppSnackbar.error('Lecture vidéo non disponible')),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFF3A3A45),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '1:24',
                      style: TextStyle(fontSize: 10, color: Colors.white),
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

// ── Bulle document ────────────────────────────────────────────────────────────

class _DocumentBubble extends StatelessWidget {
  final Message message;
  const _DocumentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    final fileName = message.content.trim().isNotEmpty
        ? message.content.trim()
        : 'Document';
    final fg = fromContact ? AppColors.textPrimary : AppColors.white;
    final sub = fromContact
        ? AppColors.textSecondary
        : Colors.white.withValues(alpha: 0.7);

    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fromContact ? AppColors.white : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: fromContact
              ? Border.all(color: AppColors.borderLight, width: 0.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fromContact
                    ? AppColors.backgroundPage
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                color: fromContact ? AppColors.textSecondary : AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('245 KB', style: TextStyle(fontSize: 11, color: sub)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackbar.error('Ouverture non disponible')),
              style: TextButton.styleFrom(
                backgroundColor: fromContact
                    ? AppColors.greenLight
                    : Colors.white.withValues(alpha: 0.2),
                foregroundColor: fromContact
                    ? AppColors.greenDark
                    : AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text(
                'Ouvrir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle carousel produits ────────────────────────────────────────────────────

class _CarouselBubble extends StatelessWidget {
  final Message message;
  const _CarouselBubble({required this.message});

  int get _productCount {
    final match = RegExp(r'(\d+)').firstMatch(message.content);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    final count = _productCount;

    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📦', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Catalogue envoyé',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count > 0
                      ? '$count produit${count > 1 ? "s" : ""}'
                      : 'Produits envoyés',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greenDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle contact ─────────────────────────────────────────────────────────────

class _ContactBubble extends StatelessWidget {
  final Message message;
  const _ContactBubble({required this.message});

  static final RegExp _phonePattern = RegExp(r'[+\d][\d\s]{6,}');

  String get _name {
    final firstLine = message.content.split('\n').first.trim();
    return firstLine.isNotEmpty ? firstLine : 'Contact';
  }

  String? get _phone =>
      _phonePattern.firstMatch(message.content)?.group(0)?.trim();

  String get _initials {
    final parts = _name.split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final f = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    final l = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0].toUpperCase()
        : '';
    final result = f + l;
    return result.isNotEmpty ? result : '?';
  }

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    final fg = fromContact ? AppColors.textPrimary : AppColors.white;
    final sub = fromContact
        ? AppColors.textSecondary
        : Colors.white.withValues(alpha: 0.7);

    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fromContact ? AppColors.white : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: fromContact
              ? Border.all(color: AppColors.borderLight, width: 0.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: fromContact
                  ? AppColors.backgroundPage
                  : Colors.white.withValues(alpha: 0.2),
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_phone != null) ...[
                    const SizedBox(height: 2),
                    Text(_phone!, style: TextStyle(fontSize: 12, color: sub)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackbar.success('Appel en cours...')),
              icon: Icon(
                Icons.call,
                color: fromContact ? AppColors.green : AppColors.white,
                size: 20,
              ),
              tooltip: 'Appeler',
            ),
          ],
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
      _AttachOpt(
        Icons.credit_card_outlined,
        const Color(0xFF6C5CE7),
        const Color(0xFFF0EEFF),
        'Paiement',
        onPayment,
      ),
      _AttachOpt(
        Icons.location_on_outlined,
        AppColors.green,
        AppColors.greenLight,
        'Localisation',
        onLocation,
      ),
      _AttachOpt(
        Icons.grid_view_outlined,
        const Color(0xFFF97316),
        const Color(0xFFFFF3E0),
        'Catalogue',
        onCatalogue,
      ),
      _AttachOpt(
        Icons.receipt_long_outlined,
        const Color(0xFF3B82F6),
        const Color(0xFFEFF6FF),
        'Devis rapide',
        onDevis,
      ),
      _AttachOpt(
        Icons.local_offer_outlined,
        const Color(0xFFEC4899),
        const Color(0xFFFDF2F8),
        'Promotion',
        onPromotion,
      ),
      _AttachOpt(
        Icons.local_shipping_outlined,
        const Color(0xFF4F46E5),
        const Color(0xFFEEF2FF),
        'Suivi commande',
        onTracking,
      ),
      _AttachOpt(
        Icons.star_outline_rounded,
        const Color(0xFFF59E0B),
        const Color(0xFFFEF3C7),
        'Avis client',
        onReview,
      ),
      _AttachOpt(
        Icons.photo_camera_outlined,
        const Color(0xFF059669),
        const Color(0xFFECFDF5),
        'Photo produit',
        onPhoto,
      ),
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
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Raccourcis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            childAspectRatio: 0.75,
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: opt.bg, shape: BoxShape.circle),
            child: Icon(opt.icon, size: 24, color: opt.color),
          ),
          const SizedBox(height: 7),
          Text(
            opt.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── BottomSheet catalogue (sélection multiple, max 10) ────────────────────────

class _CatalogueSheet extends StatefulWidget {
  final void Function(List<Map<String, dynamic>>) onSend;
  const _CatalogueSheet({required this.onSend});

  @override
  State<_CatalogueSheet> createState() => _CatalogueSheetState();
}

class _CatalogueSheetState extends State<_CatalogueSheet> {
  static const _maxSelection = 10;

  List<Map<String, dynamic>> _products = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _error;
  String _filter = 'all'; // 'all' | 'product' | 'service'

  List<Map<String, dynamic>> get _filteredProducts {
    if (_filter == 'all') return _products;
    return _products
        .where((p) => p['item_type']?.toString() == _filter)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await catalogService.getProducts();
      debugPrint(
        '=== PRODUIT : ${items.isNotEmpty ? items.first : "vide"} ===',
      );
      if (!mounted) return;
      setState(() {
        _products = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger le catalogue.';
      });
    }
  }

  String _idFor(Map<String, dynamic> product, int index) {
    return (product['product_id'] ?? index.toString()).toString();
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < _maxSelection) {
        _selectedIds.add(id);
      }
    });
    debugPrint('=== TOGGLE $id → selectedIds: $_selectedIds ===');
  }

  void _confirmSend() {
    final selected = <Map<String, dynamic>>[];
    for (var i = 0; i < _products.length; i++) {
      if (_selectedIds.contains(_idFor(_products[i], i))) {
        selected.add(_products[i]);
      }
    }
    if (selected.isEmpty) return;
    widget.onSend(selected);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selectedIds.length;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                const SizedBox(height: 18),
                const Text(
                  'Catalogue produits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Sélectionnez jusqu\'à $_maxSelection produits'
                      : '$count produit${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: count == 0 ? FontWeight.w400 : FontWeight.w600,
                    color: count == 0
                        ? AppColors.textSecondary
                        : AppColors.green,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isLoading && _error == null && _products.isNotEmpty)
                  Row(
                    children: [
                      _filterChip('Tous', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('Produits', 'product'),
                      const SizedBox(width: 8),
                      _filterChip('Services', 'service'),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.green,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _error != null
                ? _buildError()
                : _products.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Aucun produit dans le catalogue',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : _filteredProducts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Aucun produit dans cette catégorie',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    shrinkWrap: true,
                    itemCount: _filteredProducts.length,
                    itemBuilder: (_, i) {
                      final product = _filteredProducts[i];
                      final id = _idFor(product, i);

                      final isSelected = _selectedIds.contains(id);
                      final isDisabled = !isSelected && count >= _maxSelection;
                      return _ProductTile(
                        product: product,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                        onTap: isDisabled ? null : () => _toggle(id),
                      );
                    },
                  ),
          ),
          if (!_isLoading && _error == null && _products.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: count == 0 ? null : _confirmSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.borderLight,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    count == 0
                        ? 'Envoyer'
                        : 'Envoyer ($count produit${count > 1 ? 's' : ''})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _buildError() {
    return Padding(
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
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
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
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;
  const _ProductTile({
    required this.product,
    required this.isSelected,
    required this.isDisabled,
    this.onTap,
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
    final price = product['base_price'];
    final sku = product['sku']?.toString();
    final isService = product['item_type']?.toString() == 'service';

    return Opacity(
      opacity: isDisabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                          Flexible(
                            flex: 0,
                            child: Container(
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
                                overflow: TextOverflow.ellipsis,
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
                        Flexible(
                          flex: 0,
                          child: Text(
                            '${_fmt(price)} $currency',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                    color: isSelected
                        ? AppColors.green
                        : (isDisabled
                              ? AppColors.borderLight
                              : const Color(0xFF9CA3AF)),
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
      ),
    );
  }

  static String _fmt(dynamic n) {
    if (n == null) return '0';

    // Gérer les nombres décimaux (double) et entiers
    int val;
    if (n is num) {
      val = n.toInt();
    } else {
      // Essayer de parser comme string
      final str = n.toString();
      // Si c'est un nombre décimal comme "32900.00", prendre la partie entière
      final dotIndex = str.indexOf('.');
      final numStr = dotIndex >= 0 ? str.substring(0, dotIndex) : str;
      val = int.tryParse(numStr) ?? 0;
    }

    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
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

// ── BottomSheet devis rapide ──────────────────────────────────────────────────

class _DevisSheet extends StatefulWidget {
  final String contactName;
  final void Function(String) onSend;
  const _DevisSheet({required this.contactName, required this.onSend});

  @override
  State<_DevisSheet> createState() => _DevisSheetState();
}

class _DevisSheetState extends State<_DevisSheet> {
  Map<String, dynamic>? _selectedProduct;
  final _qtyCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();

  // Catalogue réel — même instance globale (et donc même cache) que le
  // catalogue du chat et les écrans de paiement.
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  /// GET /organizations/{org_id}/products
  ///
  /// `catalogService.getProducts()` renvoie son cache mémoire (valable 30 min)
  /// sans requête réseau lorsqu'il est encore frais : si le commercial a déjà
  /// ouvert le catalogue ou l'écran de paiement, la liste est immédiate.
  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final items = await catalogService.getProducts();
      if (!mounted) return;
      setState(() {
        _products = items;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== Chargement du catalogue (devis) échoué : $e ===');
      setState(() {
        _isLoadingProducts = false;
        _productsError = 'Impossible de charger le catalogue.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackbar.error('Impossible de charger le catalogue.'));
    }
  }

  int get _qty => int.tryParse(_qtyCtrl.text) ?? 0;
  int get _prix => int.tryParse(_prixCtrl.text.replaceAll(' ', '')) ?? 0;
  int get _total => _qty * _prix;

  void _selectProduct(Map<String, dynamic> p) {
    setState(() {
      _selectedProduct = p;
      _prixCtrl.text = _priceOf(p).toString();
    });
  }

  /// base_price peut arriver en nombre ou en chaîne décimale (« 32900.00 »).
  static int _priceOf(Map<String, dynamic> p) {
    final raw = p['base_price'];
    if (raw is num) return raw.toInt();
    final str = raw?.toString() ?? '';
    final dotIndex = str.indexOf('.');
    final numStr = dotIndex >= 0 ? str.substring(0, dotIndex) : str;
    return int.tryParse(numStr) ?? 0;
  }

  static String _nameOf(Map<String, dynamic> p) => (p['name'] ?? '').toString();

  /// Pictogramme déduit du type d'article — le catalogue Score360 ne fournit
  /// pas d'emoji, contrairement aux anciennes données de démonstration.
  static String _emojiFor(Map<String, dynamic> p) =>
      p['item_type']?.toString() == 'service' ? '🛠️' : '📦';

  /// Vignette du produit : image du catalogue, ou icône de repli.
  Widget _thumbnail(Map<String, dynamic> p, double size) {
    final imageUrl = p['thumbnail_url']?.toString();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: AppColors.textHint,
              ),
            )
          : const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: AppColors.textHint,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Devis rapide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product selector — chargement
            if (_isLoadingProducts)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Chargement du catalogue…',
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ],
                ),
              )
            // Product selector — erreur
            else if (_productsError != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_outlined,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _productsError!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadProducts,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Réessayer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            // Product selector — catalogue chargé
            else
              GestureDetector(
                onTap: () async {
                  final p = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                              'Choisir un produit',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_products.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                'Aucun produit dans le catalogue',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _products.length,
                                itemBuilder: (_, i) {
                                  final p = _products[i];
                                  return InkWell(
                                    onTap: () => Navigator.pop(context, p),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundPage,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _thumbnail(p, 34),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _nameOf(p),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_fmtN(_priceOf(p))} FCFA',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (p != null) _selectProduct(p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedProduct != null
                          ? AppColors.green
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedProduct != null) ...[
                        _thumbnail(_selectedProduct!, 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _nameOf(_selectedProduct!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fmtN(_priceOf(_selectedProduct!))} FCFA',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Sélectionner un produit',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ],
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DevisField(
                    'Quantité',
                    _qtyCtrl,
                    TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    useLabel: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DevisField(
                    'Prix unitaire (FCFA)',
                    _prixCtrl,
                    TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_total > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greenDark,
                      ),
                    ),
                    Text(
                      '${_fmtN(_total)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_selectedProduct != null && _qty > 0)
                    ? () => widget.onSend(
                        '📋 *Devis pour ${widget.contactName}*\n\n'
                        '• Produit : ${_emojiFor(_selectedProduct!)} ${_nameOf(_selectedProduct!)}\n'
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
                  disabledBackgroundColor: AppColors.green.withValues(
                    alpha: 0.4,
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text(
                  'Envoyer le devis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
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
  final String label;
  final bool useLabel;
  final TextEditingController ctrl;
  final TextInputType kbType;
  final ValueChanged<String>? onChanged;
  const _DevisField(
    this.label,
    this.ctrl,
    this.kbType, {
    this.onChanged,
    this.useLabel = false,
  });

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
        decoration: useLabel
            ? InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
                floatingLabelStyle: const TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              )
            : InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
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
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
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
                border: const Border(
                  left: BorderSide(color: AppColors.green, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo!.isFromContact ? 'Contact' : 'Vous',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: showEmojiPicker
                        ? AppColors.greenLight
                        : AppColors.backgroundPage,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: showEmojiPicker
                          ? AppColors.green
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Icon(
                    showEmojiPicker
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    size: 18,
                    color: showEmojiPicker
                        ? AppColors.green
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Champ de saisie avec trombone intégré à droite
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPage,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: onAttachment,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.attach_file,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Caméra
              GestureDetector(
                onTap: onCamera,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPage,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
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
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: AppColors.white,
                                  size: 20,
                                ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('mic'),
                        onTap: () {},
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: AppColors.white,
                            size: 20,
                          ),
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
  final VoidCallback onReply;
  final VoidCallback onStar;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onEdit;
  final VoidCallback onPin;

  const _SelectionAppBar({
    required this.count,
    required this.onClose,
    required this.onReply,
    required this.onStar,
    required this.onCopy,
    required this.onForward,
    required this.onDelete,
    required this.onInfo,
    required this.onEdit,
    required this.onPin,
  });

  static const _iconColor = AppColors.textPrimary;

  static const _btnConstraints = BoxConstraints(minWidth: 36, minHeight: 36);
  static const _btnPadding = EdgeInsets.all(8);

  @override
  Widget build(BuildContext context) {
    final single = count == 1;
    return Container(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: _iconColor),
                onPressed: onClose,
                padding: _btnPadding,
                constraints: _btnConstraints,
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _iconColor,
                ),
              ),
              const Spacer(),
              if (single)
                IconButton(
                  icon: const Icon(Icons.reply, size: 20, color: _iconColor),
                  onPressed: onReply,
                  padding: _btnPadding,
                  constraints: _btnConstraints,
                  tooltip: 'Répondre',
                ),
              IconButton(
                icon: const Icon(
                  Icons.star_border_rounded,
                  size: 20,
                  color: _iconColor,
                ),
                onPressed: onStar,
                padding: _btnPadding,
                constraints: _btnConstraints,
                tooltip: 'Favori',
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: onDelete,
                padding: _btnPadding,
                constraints: _btnConstraints,
                tooltip: 'Supprimer',
              ),
              IconButton(
                icon: const Icon(Icons.forward, size: 20, color: _iconColor),
                onPressed: onForward,
                padding: _btnPadding,
                constraints: _btnConstraints,
                tooltip: 'Transférer',
              ),
              if (single)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: _iconColor,
                    size: 20,
                  ),
                  padding: _btnPadding,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'info':
                        onInfo();
                        break;
                      case 'copy':
                        onCopy();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'pin':
                        onPin();
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'info',
                      child: Text(
                        'Infos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(
                        'Copier',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        'Modifier',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(
                        'Épingler',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ],
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
      return Icon(
        Icons.access_time,
        size: 11,
        color: Colors.white.withValues(alpha: 0.5),
      );
    }
    // coche simple = sent, coche double grise = delivered, double bleue = read
    return switch (status!) {
      MessageStatus.sent => Icon(
        Icons.done,
        size: 12,
        color: Colors.white.withValues(alpha: 0.65),
      ),
      MessageStatus.delivered => Icon(
        Icons.done_all,
        size: 12,
        color: Colors.white.withValues(alpha: 0.65),
      ),
      MessageStatus.read => const Icon(
        Icons.done_all,
        size: 12,
        color: Color(0xFF34B7F1),
      ),
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
      children: reactions
          .map(
            (emoji) => GestureDetector(
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
            ),
          )
          .toList(),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                        color: selected
                            ? AppColors.greenLight
                            : Colors.transparent,
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
          '${message.sentAtDt.day.toString().padLeft(2, '0')}/${message.sentAtDt.month.toString().padLeft(2, '0')}/${message.sentAtDt.year}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: _buildImage())),
    );
  }

  /// Même aiguillage que _ImageBubble : URL HTTP pour les images reçues,
  /// chemin local pour celles choisies dans la galerie.
  Widget _buildImage() {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return _broken();

    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          return SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white70,
              value: total != null
                  ? progress.cumulativeBytesLoaded / total
                  : null,
            ),
          );
        },
        errorBuilder: (_, __, ___) => _broken(),
      );
    }

    return Image.file(
      File(url),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _broken(),
    );
  }

  Widget _broken() =>
      const Icon(Icons.broken_image, color: Colors.white54, size: 64);
}

// ── Infos message ─────────────────────────────────────────────────────────────

class _MessageInfoSheet extends StatelessWidget {
  final Message message;
  final MessageStatus? status;

  const _MessageInfoSheet({required this.message, this.status});

  @override
  Widget build(BuildContext context) {
    final dt = message.sentAtDt;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      null => ('En attente', AppColors.textHint, Icons.access_time),
      MessageStatus.sent => ('Envoyé', AppColors.textSecondary, Icons.done),
      MessageStatus.delivered => (
        'Livré',
        AppColors.textSecondary,
        Icons.done_all,
      ),
      MessageStatus.read => ('Lu', AppColors.green, Icons.done_all),
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 20),
          const Text(
            'Infos du message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Envoyé le',
            value: '$dateStr à $timeStr',
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: statusIcon,
            label: 'Statut',
            value: statusLabel,
            valueColor: statusColor,
          ),
        ],
      ),
    );
  }
}

// ── Ligne info ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: valueColor ?? AppColors.textSecondary),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Transfert de message ──────────────────────────────────────────────────────

class _ForwardSheet extends StatelessWidget {
  final List<Thread> threads;
  final String currentThreadId;
  final void Function(Thread) onForward;

  const _ForwardSheet({
    required this.threads,
    required this.currentThreadId,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final others = threads.where((t) => t.id != currentThreadId).toList();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 20),
          const Text(
            'Transférer à...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (others.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune autre conversation.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...others.map(
              (t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.backgroundPage,
                  child: Text(
                    t.contactInitials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                subtitle: Text(
                  t.channel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.send_outlined,
                  size: 18,
                  color: AppColors.green,
                ),
                onTap: () => onForward(t),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
