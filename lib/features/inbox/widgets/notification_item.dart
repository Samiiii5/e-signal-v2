import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/models/notification_model.dart';

/// Widget unique réutilisé pour tous les types de notification — le rendu
/// s'adapte à [AppNotification.type] (message / appel / paiement / générique).
class NotificationItem extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final ValueChanged<String>? onQuickReply;
  final VoidCallback? onCallBack;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
    required this.onArchive,
    required this.onDelete,
    this.onQuickReply,
    this.onCallBack,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> {
  bool _replyOpen = false;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  (Color, String) _channelStyle(String channel) => switch (channel) {
        'whatsapp'  => (AppColors.green, 'W'),
        'messenger' => (const Color(0xFF1877F2), 'f'),
        'sms'       => (AppColors.purple, '💬'),
        'email'     => (AppColors.error, '✉'),
        'tiktok'    => (const Color(0xFF010101), '♪'),
        'instagram' => (const Color(0xFFE1306C), '📷'),
        'payment'   => (AppColors.purple, '₣'),
        _           => (AppColors.textSecondary, '?'),
      };

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final (channelColor, glyph) = _channelStyle(n.channel);

    return Slidable(
      key: ValueKey(n.id),
      startActionPane: n.isRead
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.28,
              children: [
                SlidableAction(
                  onPressed: (_) => widget.onMarkRead(),
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  icon: Icons.done,
                  label: 'Lu',
                  borderRadius: BorderRadius.circular(14),
                ),
              ],
            ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => widget.onArchive(),
            backgroundColor: AppColors.textSecondary,
            foregroundColor: AppColors.white,
            icon: Icons.archive_outlined,
            label: 'Archiver',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
          ),
          SlidableAction(
            onPressed: (_) => widget.onDelete(),
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
            icon: Icons.delete_outline,
            label: 'Supprimer',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: n.isRead ? AppColors.white : AppColors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(channelColor, glyph),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(n),
                    const SizedBox(height: 3),
                    _buildBody(n),
                    if (_replyOpen) _buildQuickReply(),
                  ],
                ),
              ),
              if (!n.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color channelColor, String glyph) {
    final n = widget.notification;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: AppColors.backgroundPage, shape: BoxShape.circle),
          child: Center(
            child: Text(
              _initials(n.senderName),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: channelColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: Center(child: Text(glyph, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800))),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(AppNotification n) {
    return Row(
      children: [
        if (n.isPriority) const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.priority_high_rounded, size: 14, color: AppColors.error),
        ),
        Expanded(
          child: Text(
            n.senderName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(_fmtDate(n.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildBody(AppNotification n) {
    switch (n.type) {
      case NotificationType.call:
        return _buildCallBody(n);
      case NotificationType.payment:
        return _buildPaymentBody(n);
      case NotificationType.message:
      case NotificationType.generic:
        return _buildMessageBody(n);
    }
  }

  Widget _buildMessageBody(AppNotification n) {
    final attachmentMeta = switch (n.attachmentType) {
      AttachmentType.image => (Icons.image_outlined, 'Photo'),
      AttachmentType.document => (Icons.description_outlined, 'Document'),
      AttachmentType.audio => (Icons.mic_none_rounded, 'Audio'),
      AttachmentType.video => (Icons.videocam_outlined, 'Vidéo'),
      null => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (n.title.isNotEmpty && n.title != n.senderName)
          Text(n.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachmentMeta != null) ...[
              Icon(attachmentMeta.$1, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            if (n.deliveryStatus != null) ...[
              Icon(
                n.deliveryStatus == DeliveryStatus.read ? Icons.done_all : Icons.done,
                size: 14,
                color: n.deliveryStatus == DeliveryStatus.read ? AppColors.green : AppColors.textHint,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                attachmentMeta != null ? attachmentMeta.$2 : n.body,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (n.groupName != null || (n.threadUnreadCount ?? 0) > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (n.groupName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.backgroundStatus, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.group_outlined, size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(n.groupName!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const Spacer(),
              if ((n.threadUnreadCount ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)),
                  child: Text('${n.threadUnreadCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white)),
                ),
            ],
          ),
        ],
        if (widget.onQuickReply != null && !_replyOpen) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _replyOpen = true),
            child: const Text('Répondre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
          ),
        ],
      ],
    );
  }

  Widget _buildCallBody(AppNotification n) {
    final isMissed = n.callDirection == CallDirection.missed;
    final typeLabel = switch (n.callType) {
      CallType.video => 'Appel vidéo',
      CallType.whatsapp => 'Appel WhatsApp',
      CallType.voice || null => 'Appel vocal',
    };
    final icon = switch (n.callType) {
      CallType.video => Icons.videocam_outlined,
      _ => Icons.call,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isMissed ? AppColors.error : AppColors.green),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                (n.missedCallCount ?? 0) > 1
                    ? '${n.missedCallCount} appels manqués'
                    : isMissed ? '$typeLabel manqué' : typeLabel,
                style: TextStyle(fontSize: 13, color: isMissed ? AppColors.error : AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
            if (n.ringDuration != null)
              Text('${n.ringDuration!.inSeconds}s', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _CallActionButton(icon: Icons.call, label: 'Rappeler', color: AppColors.green, onTap: widget.onCallBack),
            const SizedBox(width: 8),
            _CallActionButton(icon: Icons.message_outlined, label: 'Message', color: AppColors.textSecondary, onTap: widget.onTap),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentBody(AppNotification n) {
    final isReceived = n.transactionDirection == TransactionDirection.received;
    final color = isReceived ? AppColors.green : AppColors.error;
    final sign = isReceived ? '+' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isReceived ? Icons.south_west_rounded : Icons.north_east_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$sign${n.amount} ${n.currency ?? 'FCFA'}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (n.transactionReference != null || n.balanceAfter != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (n.transactionReference != null) 'Réf. ${n.transactionReference}',
              if (n.balanceAfter != null) 'Solde : ${n.balanceAfter} ${n.currency ?? 'FCFA'}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickReply() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _replyCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Réponse rapide...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onSubmitted: _submitReply,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _submitReply(_replyCtrl.text),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.green,
              child: Icon(Icons.send_rounded, size: 14, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _submitReply(String text) {
    if (text.trim().isEmpty) return;
    widget.onQuickReply?.call(text.trim());
    _replyCtrl.clear();
    setState(() => _replyOpen = false);
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _CallActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
