import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/mock/publications_mock.dart';
import '../../shared/services/inbox_service.dart';
import '../../shared/services/comments_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/websocket_service.dart';
import 'notifications_screen.dart';
import 'publication_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  final String? initialChannel;
  final String? initialThreadId;
  const InboxScreen({super.key, this.initialChannel, this.initialThreadId});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _Filter _activeFilter = _Filter.all;
  bool _isLoading = true;
  List<Thread> _threads = [];
  List<Map<String, dynamic>> _apiPosts = [];
  bool _postsLoading = false;
  String? _postsError;
  String? _networkFilter; // null = Tous, 'facebook', 'instagram', 'tiktok'

  // Filtres du bottom sheet
  String? _bsChannelFilter;
  bool _bsUnreadOnly = false;
  String? _error;

  bool get _hasActiveSheetFilter => _bsChannelFilter != null || _bsUnreadOnly;

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  final Set<String> _typingThreads = {};

  /// Un minuteur d'expiration par conversation — annulable et réarmable, pour
  /// que plusieurs événements consécutifs ne se marchent pas dessus.
  final Map<String, Timer> _typingTimers = {};

  // ── Pagination de la liste des conversations ───────────────────────────────
  static const _pageSize = 50;
  final _threadsScrollController = ScrollController();
  bool _isLoadingMoreThreads = false;
  bool _hasMoreThreads = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.toLowerCase()),
    );
    if (widget.initialChannel != null) {
      _activeFilter = _channelToFilter(widget.initialChannel!);
    }
    _threadsScrollController.addListener(_onThreadsScroll);
    _loadThreads();
    NotificationService.fetchHistory().catchError((_) => <AppNotification>[]);
    _connectWebSocket();
  }

  /// Déclenche le chargement de la page suivante à l'approche du bas de liste.
  void _onThreadsScroll() {
    if (!_threadsScrollController.hasClients) return;
    final position = _threadsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMoreThreads();
    }
  }

  void _connectWebSocket() {
    _wsSubscription?.cancel();
    final orgId = SessionService.organizationId;
    final token = SessionService.accessToken;
    if (orgId == null || token == null) return;
    webSocketService.connect(organizationId: orgId, token: token);
    _wsSubscription = webSocketService.events.listen(_onWsEvent);
  }

  void _onWsEvent(Map<String, dynamic> event) {
    // Tous les événements documentés sont plats (thread_id/channel/... à la
    // racine, sans enveloppe "data").
    switch (event['event']) {
      case 'new_message':
        debugPrint('WS event reçu: ${event['event']}');
        debugPrint('WS thread_id: ${event['thread_id']}');
        debugPrint('WS contact_name: ${event['contact_name']}');
        debugPrint('WS threads actuels: ${_threads.map((t) => t.id).toList()}');
        _onNewMessageEvent(event);
      case 'thread_assigned':
        _updateThread(
          event['thread_id']?.toString(),
          (t) => t.copyWith(
            assignedToUserId: event['assigned_to_user_id']?.toString(),
          ),
        );
      case 'thread_unassigned':
        _updateThread(
          event['thread_id']?.toString(),
          (t) => t.copyWithUnassigned(),
        );
      case 'thread_resolved':
        _updateThread(
          event['thread_id']?.toString(),
          (t) => t.copyWith(status: 'resolved'),
        );
      case 'new_comment':
        _onNewCommentEvent(event);
      case 'contact_typing':
        _handleContactTyping(event);
      case 'messages_read':
        _handleMessagesRead(event);
      case 'message_status_updated':
        _handleMessageStatusUpdated(event);
      case 'contact_presence_updated':
        _handleContactPresenceUpdated(event);
    }
  }

  void _updateThread(String? threadId, Thread Function(Thread) transform) {
    if (threadId == null) return;
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;
    setState(() => _threads[idx] = transform(_threads[idx]));
  }

  void _onNewMessageEvent(Map<String, dynamic> data) {
    final threadId = data['thread_id']?.toString();
    if (threadId == null) return;
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) {
      // Conversation pas encore connue localement (nouveau contact) : un
      // refetch complet est le seul moyen fiable de l'obtenir.
      _loadThreads();
      return;
    }

    final channel = data['channel']?.toString();
    final contactName = data['contact_name']?.toString();
    // contact_name n'est fourni que pour WhatsApp — Messenger/Instagram
    // gardent le nom déjà connu du thread.
    final newContactName =
        (channel == 'whatsapp' && contactName != null && contactName.isNotEmpty)
        ? contactName
        : null;
    final messageJson = data['message'];
    final sentAtRaw = messageJson is Map
        ? messageJson['sent_at']?.toString()
        : null;
    final sentAt = DateTime.tryParse(sentAtRaw ?? '') ?? DateTime.now();
    // Extraire le contenu du message pour l'afficher dans inbox
    final messageContent = messageJson is Map
        ? (messageJson['text']?.toString() ?? messageJson['body']?.toString())
        : null;
    // copyWith() garde l'ancienne valeur si lastMessage est null — on
    // reproduit le même repli pour que le cache reste cohérent avec l'UI.
    final effectiveLastMessage =
        messageContent ?? _threads[idx].lastMessage ?? '';

    // Mettre à jour le cache (HttpInboxService._cachedThreads)
    inboxService.updateThreadLastMessage(
      threadId,
      effectiveLastMessage,
      sentAt,
    );

    // Mettre à jour l'UI
    setState(() {
      final updated = _threads[idx].copyWith(
        contactName: newContactName,
        unreadCount: _threads[idx].unreadCount + 1,
        lastMessageAt: sentAt.toIso8601String(),
        lastMessage: messageContent,
      );
      _threads.removeAt(idx);
      _threads.insert(0, updated);
    });

    debugPrint(
      '=== Inbox UI mise à jour : nouveau message thread $threadId ===',
    );
  }

  void _onNewCommentEvent(Map<String, dynamic> data) {
    final commenterName = data['commenter_name']?.toString();
    final bodyText = (data['body_text'] ?? '').toString();
    NotificationService.showLocalNotification(
      title: 'Nouveau commentaire',
      body: commenterName != null ? '$commenterName : $bodyText' : bodyText,
    );
    NotificationService.fetchHistory().catchError((_) => <AppNotification>[]);
    if (_activeFilter == _Filter.commentaires) _loadPosts();
  }

  void _handleContactTyping(Map<String, dynamic> data) {
    final threadId = data['thread_id']?.toString();
    if (threadId == null) return;
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;

    // Toujours annuler le minuteur en cours : un nouvel événement réarme le
    // délai au lieu de laisser expirer le précédent.
    _typingTimers.remove(threadId)?.cancel();

    if (data['is_typing'] == false) {
      setState(() => _typingThreads.remove(threadId));
      return;
    }

    setState(() => _typingThreads.add(threadId));
    // 7 secondes d'auto-expiration, conformément à la documentation WebSocket.
    _typingTimers[threadId] = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        _typingThreads.remove(threadId);
        _typingTimers.remove(threadId);
      });
    });
  }

  void _handleMessagesRead(Map<String, dynamic> data) {
    final threadId = data['thread_id']?.toString();
    if (threadId == null) return;
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;
    // Réinitialiser le compteur de messages non lus
    setState(() => _threads[idx] = _threads[idx].copyWith(unreadCount: 0));
  }

  void _handleMessageStatusUpdated(Map<String, dynamic> data) {
    // Gérer le statut des messages si nécessaire dans InboxScreen
    // Pour l'instant, cet événement est plus pertinent pour ChatScreen
    debugPrint(
      'WS message_status_updated: ${data['message_id']} -> ${data['status']}',
    );
  }

  void _handleContactPresenceUpdated(Map<String, dynamic> data) {
    // Gérer le statut de présence si nécessaire
    debugPrint(
      'WS contact_presence_updated: ${data['thread_id']} -> ${data['presence']}',
    );
  }

  _Filter _channelToFilter(String channel) => switch (channel) {
    'whatsapp' => _Filter.whatsapp,
    'sms' => _Filter.sms,
    'email' => _Filter.email,
    'messenger' => _Filter.facebook,
    'instagram' => _Filter.instagram,
    'tiktok' => _Filter.tiktok,
    _ => _Filter.all,
  };

  @override
  void didUpdateWidget(covariant InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'écran reste monté (IndexedStack de la shell route) quand on tape une
    // notification alors que l'onglet Inbox est déjà ouvert : initState ne
    // se redéclenche pas, donc on réagit ici au changement de query params.
    if (widget.initialChannel != null &&
        widget.initialChannel != oldWidget.initialChannel) {
      setState(() => _activeFilter = _channelToFilter(widget.initialChannel!));
    }
    if (widget.initialThreadId != null &&
        widget.initialThreadId != oldWidget.initialThreadId) {
      _loadThreads();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadThreads();
      _connectWebSocket();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _threadsScrollController.dispose();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    _wsSubscription?.cancel();
    webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _loadThreads({bool forceRefresh = false}) async {
    // Si forceRefresh → invalider le cache
    if (forceRefresh) {
      inboxService.invalidateThreadsCache();
    }

    // ÉTAPE 1 : Afficher le cache immédiatement si disponible (pas de spinner)
    final cached = inboxService.cachedThreads;
    if (cached != null && !forceRefresh) {
      setState(() {
        _threads = cached;
        _isLoading = false; // pas de spinner
        // Le cache ne contient que la première page.
        _hasMoreThreads = cached.length >= _pageSize;
      });
      debugPrint('=== Inbox : cache affiché immédiatement ===');

      // ÉTAPE 2 : Revalidation en arrière-plan
      _revalidateThreadsInBackground();
      return;
    }

    // Première ouverture → spinner + appel API
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final threads = await inboxService.getThreads(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _isLoading = false;
        _error = null;
        _hasMoreThreads = threads.length >= _pageSize;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('_UnauthorizedException')) {
        SessionService.logout();
        GoRouter.of(context).go('/login');
        return;
      }
      setState(() {
        _isLoading = false;
        _error = msg.contains('_NetworkException')
            ? 'Pas de connexion internet. Vérifiez votre réseau.'
            : 'Impossible de charger les conversations.';
        // keep previous threads on error
      });
    }
  }

  // Revalidation silencieuse en arrière-plan
  Future<void> _revalidateThreadsInBackground() async {
    try {
      debugPrint('=== Revalidation threads en arrière-plan ===');
      // Invalider puis recharger depuis l'API
      inboxService.invalidateThreadsCache();
      final freshThreads = await inboxService.getThreads(limit: _pageSize);
      if (!mounted) return;
      // Mettre à jour seulement si différent
      if (_threadsChanged(freshThreads)) {
        setState(() {
          _threads = freshThreads;
          // La revalidation repart de la première page.
          _hasMoreThreads = freshThreads.length >= _pageSize;
        });
        debugPrint('=== Threads mis à jour silencieusement ===');
      }
    } catch (_) {
      // Silencieux — on garde le cache affiché
      debugPrint('=== Revalidation échouée — cache conservé ===');
    }
  }

  /// Charge la page suivante et l'ajoute à la liste déjà affichée.
  ///
  /// Désactivé pendant une recherche ou un filtrage : la liste visible est
  /// alors un sous-ensemble local, et l'offset serveur n'y correspondrait pas.
  Future<void> _loadMoreThreads() async {
    if (_isLoadingMoreThreads || !_hasMoreThreads || _isLoading) return;
    if (_searchQuery.isNotEmpty ||
        _activeFilter != _Filter.all ||
        _hasActiveSheetFilter) {
      return;
    }

    setState(() => _isLoadingMoreThreads = true);
    try {
      final page = await inboxService.getThreads(
        limit: _pageSize,
        offset: _threads.length,
      );
      if (!mounted) return;
      // Écarter les conversations déjà présentes (le temps réel peut avoir
      // remonté un thread entre deux pages).
      final knownIds = _threads.map((t) => t.id).toSet();
      final fresh = page.where((t) => !knownIds.contains(t.id)).toList();
      setState(() {
        _threads = [..._threads, ...fresh];
        _hasMoreThreads = page.length >= _pageSize;
        _isLoadingMoreThreads = false;
      });
      debugPrint(
        '=== Page suivante : ${fresh.length} conversations ajoutées '
        '(total ${_threads.length}) ===',
      );
    } catch (e) {
      if (!mounted) return;
      // Échec non bloquant : la liste déjà chargée reste affichée.
      debugPrint('=== Chargement page suivante échoué : $e ===');
      setState(() => _isLoadingMoreThreads = false);
    }
  }

  // Comparer si les threads ont changé
  bool _threadsChanged(List<Thread> fresh) {
    if (fresh.length != _threads.length) return true;
    for (int i = 0; i < fresh.length; i++) {
      if (fresh[i].id != _threads[i].id) return true;
      if (fresh[i].lastMessage != _threads[i].lastMessage) return true;
      if (fresh[i].unreadCount != _threads[i].unreadCount) return true;
    }
    return false;
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });
    try {
      final posts = await commentsService.getPosts(
        channel: _networkFilter,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _apiPosts = posts;
        _postsLoading = false;
      });
    } on CommentsUnauthorizedException {
      if (!mounted) return;
      SessionService.logout();
      GoRouter.of(context).go('/login');
    } on CommentsUnavailableException {
      if (!mounted) return;
      setState(() {
        _postsLoading = false;
        _postsError = 'Service temporairement indisponible.';
      });
    } on CommentsNetworkException {
      if (!mounted) return;
      _setPostsError('Vérifiez votre connexion internet.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('=== Chargement des publications échoué : $e ===');
      _setPostsError('Impossible de charger les publications.');
    }
  }

  /// Affiche le bandeau d'erreur (avec bouton de rechargement) et le signale par
  /// un snackbar — plus aucune publication de démonstration n'est substituée.
  void _setPostsError(String message) {
    setState(() {
      _apiPosts = [];
      _postsLoading = false;
      _postsError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error(message));
  }

  Widget _buildPublicationsView() {
    const networks = [
      (null, 'Tous', null),
      ('facebook', 'Facebook', Color(0xFF1877F2)),
      ('instagram', 'Instagram', Color(0xFFE1306C)),
    ];

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: networks.map<Widget>((entry) {
              final (value, label, color) = entry;
              final isActive = _networkFilter == value;
              final activeColor = color ?? AppColors.green;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _networkFilter = value);
                    _loadPosts();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        if (_postsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: Color(0xFF92400E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _postsError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadPosts,
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _postsLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : (_apiPosts.isEmpty
                    ? const _EmptyState(query: '')
                    : RefreshIndicator(
                        onRefresh: _loadPosts,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          itemCount: _apiPosts.length,
                          separatorBuilder: (_, __) => const Divider(
                            indent: 66,
                            height: 0,
                            thickness: 0.5,
                            color: AppColors.borderLight,
                          ),
                          itemBuilder: (_, i) =>
                              _ApiPostTile(post: _apiPosts[i]),
                        ),
                      )),
        ),
      ],
    );
  }

  List<Thread> get _filtered {
    var list = List<Thread>.from(_threads);
    switch (_activeFilter) {
      case _Filter.whatsapp:
        list = list.where((t) => t.channel == 'whatsapp').toList();
      case _Filter.sms:
        list = list.where((t) => t.channel == 'sms').toList();
      case _Filter.email:
        list = list.where((t) => t.channel == 'email').toList();
      case _Filter.facebook:
        list = list.where((t) => t.channel == 'messenger').toList();
      case _Filter.instagram:
        list = list.where((t) => t.channel == 'instagram').toList();
      case _Filter.tiktok:
        list = list.where((t) => t.channel == 'tiktok').toList();
      case _Filter.unread:
        list = list.where((t) => t.unreadCount > 0).toList();
      case _Filter.all:
        break;
      case _Filter.commentaires:
        return _threads; // handled separately in build
    }
    if (_bsChannelFilter != null) {
      list = list.where((t) => t.channel == _bsChannelFilter).toList();
    }
    if (_bsUnreadOnly) {
      list = list.where((t) => t.unreadCount > 0).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((t) => t.contactName.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return list;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        initialChannel: _bsChannelFilter,
        initialUnreadOnly: _bsUnreadOnly,
        onApply: (channel, unreadOnly) {
          setState(() {
            _bsChannelFilter = channel;
            _bsUnreadOnly = unreadOnly;
            if (channel != null) _activeFilter = _Filter.all;
          });
        },
        onReset: () => setState(() {
          _bsChannelFilter = null;
          _bsUnreadOnly = false;
          _activeFilter = _Filter.all;
        }),
      ),
    );
  }

  Widget _buildErrorBanner() {
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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadThreads,
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

  int get _totalUnread => _threads.fold(0, (sum, t) => sum + t.unreadCount);

  @override
  Widget build(BuildContext context) {
    final threads = _filtered;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Image.asset(
                    'design/logo_onboarding.png',
                    height: Responsive.h(context, 0.07).clamp(44.0, 68.0),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationService.unreadCount,
                        builder: (context, count, _) {
                          if (count <= 0) return const SizedBox.shrink();
                          return Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: _hasActiveSheetFilter
                              ? AppColors.green
                              : AppColors.textSecondary,
                        ),
                        onPressed: _openFilterSheet,
                      ),
                      if (_hasActiveSheetFilter)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un contact ou un message...',
                    hintStyle: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Filter chips
            SizedBox(
              height: Responsive.h(context, 0.045).clamp(34.0, 42.0),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _Filter.values
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          filter: f,
                          isActive: _activeFilter == f,
                          unreadCount: f == _Filter.all ? _totalUnread : 0,
                          onTap: () {
                            setState(() => _activeFilter = f);
                            if (f == _Filter.commentaires) _loadPosts();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _isLoading
                  ? const _InboxSkeleton()
                  : _error != null && _threads.isEmpty
                  ? _buildErrorBanner()
                  : _activeFilter == _Filter.commentaires
                  ? _buildPublicationsView()
                  : threads.isEmpty
                  ? _EmptyState(query: _searchQuery)
                  : RefreshIndicator(
                      onRefresh: _revalidateThreadsInBackground,
                      color: AppColors.green,
                      child: ListView.separated(
                        controller: _threadsScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        // +1 pour l'indicateur de chargement de page suivante
                        itemCount:
                            threads.length + (_isLoadingMoreThreads ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(
                          indent: 76,
                          height: 0,
                          thickness: 0.5,
                          color: AppColors.borderLight,
                        ),
                        itemBuilder: (_, i) {
                          if (i >= threads.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _ThreadTile(
                            thread: threads[i],
                            onReturn: _loadThreads,
                            isTyping: _typingThreads.contains(threads[i].id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, __) => const Divider(
        indent: 76,
        height: 0,
        thickness: 0.5,
        color: AppColors.borderLight,
      ),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            ShimmerBox(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(
                        width: 130,
                        height: 13,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const Spacer(),
                      ShimmerBox(
                        width: 32,
                        height: 11,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 11,
                    borderRadius: BorderRadius.circular(5),
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

// ── Filtres ───────────────────────────────────────────────────────────────────

enum _Filter {
  all,
  whatsapp,
  sms,
  email,
  facebook,
  instagram,
  tiktok,
  unread,
  commentaires,
}

extension _FilterLabel on _Filter {
  String get label => switch (this) {
    _Filter.all => 'Tous',
    _Filter.whatsapp => 'WhatsApp',
    _Filter.sms => 'SMS',
    _Filter.email => 'Email',
    _Filter.facebook => 'Facebook',
    _Filter.instagram => 'Instagram',
    _Filter.tiktok => 'TikTok',
    _Filter.unread => 'Non lus',
    _Filter.commentaires => 'Commentaires',
  };
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  final bool isActive;
  final int unreadCount;
  final VoidCallback onTap;
  const _FilterChip({
    required this.filter,
    required this.isActive,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.green : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.white : AppColors.textSecondary,
              ),
            ),
            if (isActive && unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Thread tile ───────────────────────────────────────────────────────────────

class _ThreadTile extends StatelessWidget {
  final Thread thread;
  final VoidCallback? onReturn;
  final bool isTyping;
  const _ThreadTile({
    required this.thread,
    this.onReturn,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;
    return InkWell(
      onTap: () async {
        await context.push('/inbox/${thread.id}', extra: thread);
        onReturn?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                _ContactAvatar(
                  initials: thread.contactInitials,
                  channel: thread.channel,
                ),
                if (thread.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.contactName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.green
                              : AppColors.textHint,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTyping
                              ? 'écrit...'
                              : (thread.lastMessage ??
                                    _channelDisplayName(thread.channel)),
                          style: TextStyle(
                            fontSize: 13,
                            color: isTyping
                                ? AppColors.green
                                : hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: isTyping
                                ? FontWeight.w600
                                : hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${thread.unreadCount > 99 ? "99+" : thread.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
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

  String _channelDisplayName(String ch) => switch (ch) {
    'whatsapp' => 'WhatsApp',
    'sms' => 'SMS',
    'email' => 'Email',
    'messenger' => 'Facebook Messenger',
    'tiktok' => 'TikTok',
    _ => ch,
  };

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${local.day}/${local.month}';
  }
}

class _ContactAvatar extends StatelessWidget {
  final String initials;
  final String channel;
  const _ContactAvatar({required this.initials, required this.channel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.backgroundPage,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _channelColor(channel),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _channelLabel(channel),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.white,
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

  Color _channelColor(String ch) => switch (ch) {
    'whatsapp' => const Color(0xFF25D366),
    'messenger' => const Color(0xFF1877F2),
    'sms' => const Color(0xFF5C6BC0),
    'tiktok' => const Color(0xFF010101),
    'email' => const Color(0xFFEA4335),
    _ => AppColors.textSecondary,
  };

  String _channelLabel(String ch) => switch (ch) {
    'whatsapp' => 'W',
    'messenger' => 'f',
    'sms' => 'S',
    'tiktok' => 'T',
    'email' => '@',
    _ => ch.isNotEmpty ? ch[0].toUpperCase() : '?',
  };
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.borderLight,
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
                ? 'Aucun résultat pour "$query"'
                : 'Aucune conversation',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet filtres ──────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? initialChannel;
  final bool initialUnreadOnly;
  final void Function(String? channel, bool unreadOnly) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.initialChannel,
    required this.initialUnreadOnly,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _channel;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
    _unreadOnly = widget.initialUnreadOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
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
          // Titre
          const Text(
            'Filtrer les conversations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Section Canal
          const Text(
            'Canal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _ChannelOption(
            label: 'Tous',
            value: null,
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
          ),
          _ChannelOption(
            label: 'WhatsApp',
            value: 'whatsapp',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFF25D366),
          ),
          _ChannelOption(
            label: 'SMS',
            value: 'sms',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFF5C6BC0),
          ),
          _ChannelOption(
            label: 'Email',
            value: 'email',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFFEA4335),
          ),
          _ChannelOption(
            label: 'Facebook',
            value: 'messenger',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFF1877F2),
          ),
          _ChannelOption(
            label: 'Instagram',
            value: 'instagram',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFFE1306C),
          ),
          _ChannelOption(
            label: 'TikTok',
            value: 'tiktok',
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v),
            color: const Color(0xFF010101),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Section Statut
          const Text(
            'Statut',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _CheckOption(
            label: 'Tous les messages',
            checked: !_unreadOnly,
            onTap: () => setState(() => _unreadOnly = false),
          ),
          _CheckOption(
            label: 'Non lus seulement',
            checked: _unreadOnly,
            onTap: () => setState(() => _unreadOnly = true),
          ),

          const SizedBox(height: 24),

          // Boutons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Réinitialiser',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_channel, _unreadOnly);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E9E5E),
                    foregroundColor: AppColors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Appliquer les filtres',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

class _ChannelOption extends StatelessWidget {
  final String label;
  final String? value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;
  final Color? color;

  const _ChannelOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (color != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E9E5E)
                      : AppColors.borderLight,
                  width: 2,
                ),
                color: selected ? const Color(0xFF1E9E5E) : AppColors.white,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: AppColors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiPostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _ApiPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final postId = (post['post_id'] ?? '').toString();
    final channel = (post['channel'] ?? '').toString().toLowerCase();
    final rawCaption = (post['caption'] ?? '').toString().trim();
    final title = rawCaption.isEmpty
        ? 'Publication sans titre'
        : (rawCaption.length > 50
              ? '${rawCaption.substring(0, 50)}…'
              : rawCaption);
    final totalComments = (post['total_comments'] as num?)?.toInt() ?? 0;
    final newComments = (post['new_comments_count'] as num?)?.toInt() ?? 0;
    final rawDate = post['posted_at'];
    final postedAt = rawDate != null
        ? DateTime.tryParse(rawDate.toString())
        : null;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicationDetailScreen(
            publication: Publication(
              id: postId,
              title: title,
              network: channel.isNotEmpty ? channel : 'facebook',
              commentCount: totalComments,
              publishedAt: postedAt ?? DateTime.now(),
              comments: const [],
            ),
            apiPostId: postId,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            _NetworkCircle(network: channel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
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
                      if (postedAt != null)
                        Text(
                          _fmtDate(postedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalComments commentaires',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (newComments > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$newComments',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenDark,
                            ),
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

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    const mois = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
  }
}

class _NetworkCircle extends StatelessWidget {
  final String network;
  const _NetworkCircle({required this.network});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (network) {
      'facebook' => (const Color(0xFF1877F2), 'f'),
      'instagram' => (const Color(0xFFE1306C), '📷'),
      'tiktok' => (const Color(0xFF010101), '♪'),
      _ => (AppColors.textSecondary, '?'),
    };
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckOption({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: checked
                      ? const Color(0xFF1E9E5E)
                      : AppColors.borderLight,
                  width: 2,
                ),
                color: checked ? const Color(0xFF1E9E5E) : AppColors.white,
              ),
              child: checked
                  ? const Icon(Icons.check, size: 13, color: AppColors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
