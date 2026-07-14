import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final items = await NotificationService.fetchHistory();
      if (!mounted) return;
      setState(() { _notifications = items; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Impossible de charger les notifications.'; });
    }
  }

  Future<void> _onTapNotification(AppNotification n) async {
    if (!n.isRead) {
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      });
      NotificationService.markAsRead(n.id);
    }
    if (!mounted) return;
    GoRouter.of(context).go('/inbox?channel=${n.channel}&thread_id=${n.threadId ?? ''}');
  }

  void _deleteNotification(AppNotification n) {
    setState(() => _notifications.removeWhere((x) => x.id == n.id));
    NotificationService.deleteNotification(n.id, wasUnread: !n.isRead);
  }

  void _markAllAsRead() {
    final unreadIds = _notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    NotificationService.markAllAsRead(unreadIds);
  }

  void _clearAll() {
    final ids = _notifications.map((n) => n.id).toList();
    if (ids.isEmpty) return;
    setState(() => _notifications = []);
    NotificationService.clearAll(ids);
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      _buildActionsRow(),
                      Expanded(
                        child: _notifications.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: _notifications.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _NotificationTile(
                                    notification: _notifications[i],
                                    onTap: () => _onTapNotification(_notifications[i]),
                                    onDismissed: () => _deleteNotification(_notifications[i]),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildActionsRow() {
    if (_notifications.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
            label: const Text('Vider tout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.borderLight),
          const SizedBox(height: 12),
          const Text('Aucune notification', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  (Color, String) _channelStyle(String channel) => switch (channel) {
        'whatsapp'  => (AppColors.green, 'W'),
        'messenger' => (const Color(0xFF1877F2), 'f'),
        'sms'       => (AppColors.purple, '💬'),
        'email'     => (AppColors.error, '✉'),
        'tiktok'    => (const Color(0xFF010101), '♪'),
        'instagram' => (const Color(0xFFE1306C), '📷'),
        _           => (AppColors.textSecondary, '?'),
      };

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (color, glyph) = _channelStyle(notification.channel);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: AppColors.white),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(child: Text(glyph, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800))),
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
                            notification.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_fmtDate(notification.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
