import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/services/inbox_service.dart';
import '../../shared/services/notification_service.dart';
import 'widgets/notification_item.dart';

enum _NotifFilter { all, message, call, payment }

extension on _NotifFilter {
  String get label => switch (this) {
    _NotifFilter.all     => 'Tous',
    _NotifFilter.message => 'Messages',
    _NotifFilter.call    => 'Appels',
    _NotifFilter.payment => 'Paiements',
  };

  NotificationType? get type => switch (this) {
    _NotifFilter.all     => null,
    _NotifFilter.message => NotificationType.message,
    _NotifFilter.call    => NotificationType.call,
    _NotifFilter.payment => NotificationType.payment,
  };
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  final Set<String> _removingIds = {};
  _NotifFilter _activeFilter = _NotifFilter.all;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    NotificationService.newNotificationTick.addListener(_onNewNotification);
  }

  @override
  void dispose() {
    NotificationService.newNotificationTick.removeListener(_onNewNotification);
    super.dispose();
  }

  /// Déclenché à chaque notification FCM reçue en foreground — recharge la
  /// liste sans afficher le skeleton, la plus récente arrive en tête grâce
  /// au tri par sentAt fait dans fetchHistory().
  void _onNewNotification() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final items = await NotificationService.fetchHistory();
      if (!mounted) return;
      setState(() { _notifications = items; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() { _isLoading = false; _error = 'Impossible de charger les notifications.'; });
    }
  }

  List<AppNotification> get _filtered {
    final type = _activeFilter.type;
    if (type == null) return _notifications;
    return _notifications.where((n) => n.type == type).toList();
  }

  Map<String, List<AppNotification>> _groupByDate(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final sections = <String, List<AppNotification>>{
      'Aujourd\'hui': [],
      'Hier': [],
      'Cette semaine': [],
      'Plus ancien': [],
    };
    for (final n in items) {
      final d = DateTime(n.sentAt.year, n.sentAt.month, n.sentAt.day);
      if (d == today) {
        sections['Aujourd\'hui']!.add(n);
      } else if (d == yesterday) {
        sections['Hier']!.add(n);
      } else if (d.isAfter(weekAgo)) {
        sections['Cette semaine']!.add(n);
      } else {
        sections['Plus ancien']!.add(n);
      }
    }
    sections.removeWhere((_, v) => v.isEmpty);
    return sections;
  }

  Future<void> _onTapNotification(AppNotification n) async {
    if (!n.isRead) {
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      });
      NotificationService.markAsRead(n);
    }
    if (!mounted) return;
    GoRouter.of(context).go('/inbox?channel=${n.channel}&thread_id=${n.threadId ?? ''}');
  }

  void _markRead(AppNotification n) {
    if (n.isRead) return;
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    });
    NotificationService.markAsRead(n);
  }

  /// Fait disparaître la tuile en douceur (fade + collapse) avant de la
  /// retirer de la liste et d'exécuter l'action réelle.
  Future<void> _animateAndRemove(AppNotification n, VoidCallback action) async {
    setState(() => _removingIds.add(n.id));
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _notifications.removeWhere((x) => x.id == n.id);
      _removingIds.remove(n.id);
    });
    action();
  }

  void _deleteNotification(AppNotification n) {
    _animateAndRemove(n, () => NotificationService.deleteNotification(n));
  }

  void _archiveNotification(AppNotification n) {
    // Pas d'endpoint d'archivage côté backend pour l'instant : on masque
    // localement la notification sans toucher à Firestore.
    _animateAndRemove(n, () {});
  }

  void _markAllAsRead() {
    final unreadIds = _notifications.where((n) => !n.isRead).toList();
    if (unreadIds.isEmpty) return;
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    NotificationService.markAllAsRead(unreadIds);
  }

  Future<void> _confirmClearAll() async {
    if (_notifications.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vider toutes les notifications ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text('Cette action est irréversible.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vider tout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) _clearAll();
  }

  void _clearAll() {
    final items = List<AppNotification>.from(_notifications);
    setState(() => _notifications = []);
    NotificationService.clearAll(items);
  }

  Future<void> _sendQuickReply(AppNotification n, String text) async {
    if (n.threadId != null) {
      await inboxService.sendMessage(threadId: n.threadId!, provider: n.channel, content: text);
    }
    _markRead(n);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('Réponse envoyée'));
  }

  Future<void> _callBack(AppNotification n) async {
    final phone = n.callerPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.error('Numéro indisponible'));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.borderLight),
        ),
      ),
      body: _isLoading
          ? const _SkeletonList()
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            _buildFilterChips(),
                            _buildActionsRow(),
                            Expanded(
                              child: _filtered.isEmpty ? _buildEmptyFilterState() : _buildList(),
                            ),
                          ],
                        ),
                ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _NotifFilter.values.map((f) {
          final isActive = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.green : AppColors.backgroundStatus,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionsRow() {
    if (_notifications.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 16, color: AppColors.green),
              label: const Text('Tout marquer comme lu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            ),
          ),
          TextButton.icon(
            onPressed: _confirmClearAll,
            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
            label: const Text('Vider tout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final sections = _groupByDate(_filtered);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: ListView(
        key: ValueKey(_activeFilter),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final entry in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
            for (final n in entry.value) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _removingIds.contains(n.id) ? 0 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: _removingIds.contains(n.id)
                      ? const SizedBox(width: double.infinity)
                      : NotificationItem(
                          notification: n,
                          onTap: () => _onTapNotification(n),
                          onMarkRead: () => _markRead(n),
                          onArchive: () => _archiveNotification(n),
                          onDelete: () => _deleteNotification(n),
                          onQuickReply: n.type == NotificationType.message ? (text) => _sendQuickReply(n, text) : null,
                          onCallBack: n.type == NotificationType.call ? () => _callBack(n) : null,
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none_outlined, size: 72, color: AppColors.borderLight),
                    const SizedBox(height: 16),
                    const Text('Aucune notification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    const Text(
                      'Vous serez notifié ici dès qu\'un nouveau message ou événement arrivera',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_off_outlined, size: 40, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Text('Aucune notification "${_activeFilter.label}"', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
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

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundStatus,
      highlightColor: AppColors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.backgroundStatus, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 120, color: AppColors.backgroundStatus),
                      const SizedBox(height: 8),
                      Container(height: 10, width: double.infinity, color: AppColors.backgroundStatus),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 180, color: AppColors.backgroundStatus),
                    ],
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
