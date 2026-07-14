/// Modèle unifié pour NotificationsScreen / NotificationItem.
///
/// Le backend (GET /api/notifications/history/{user_id}) ne renvoie
/// aujourd'hui que des notifications de type message (title/body/sent_at/
/// data:{channel, thread_id}) — les champs appel/paiement restent optionnels,
/// prêts à être renseignés quand le backend exposera ces événements.
library;

enum NotificationType { message, call, payment, generic }

enum AttachmentType { image, document, audio, video }

enum DeliveryStatus { sent, delivered, read }

enum CallType { voice, video, whatsapp }

enum CallDirection { incoming, outgoing, missed }

enum TransactionDirection { received, sent }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool isRead;
  final String channel; // whatsapp | sms | email | messenger | tiktok | instagram | payment
  final String? threadId;
  final NotificationType type;

  // Champs universels
  final String senderName;
  final bool isPriority;

  // Messages
  final int? threadUnreadCount;
  final String? groupName;
  final AttachmentType? attachmentType;
  final DeliveryStatus? deliveryStatus;

  // Appels
  final CallType? callType;
  final CallDirection? callDirection;
  final int? missedCallCount;
  final Duration? ringDuration;
  final String? callerPhone;

  // Paiements
  final num? amount;
  final String? currency;
  final TransactionDirection? transactionDirection;
  final String? transactionReference;
  final num? balanceAfter;
  final String? counterpartName;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.isRead,
    required this.channel,
    this.threadId,
    this.type = NotificationType.message,
    required this.senderName,
    this.isPriority = false,
    this.threadUnreadCount,
    this.groupName,
    this.attachmentType,
    this.deliveryStatus,
    this.callType,
    this.callDirection,
    this.missedCallCount,
    this.ringDuration,
    this.callerPhone,
    this.amount,
    this.currency,
    this.transactionDirection,
    this.transactionReference,
    this.balanceAfter,
    this.counterpartName,
  });

  /// GET /api/notifications/history/{user_id} → toujours type message.
  /// Le backend n'envoie pas de nom d'expéditeur séparé ; le body suit le
  /// format observé "Nom : message", qu'on tente d'extraire.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : <String, dynamic>{};
    final isRead = json['read'] == true || (json['status'] ?? '').toString() == 'read';
    final title = (json['title'] ?? '').toString();
    final rawBody = (json['body'] ?? '').toString();

    var senderName = title;
    var preview = rawBody;
    final match = RegExp(r'^([^:]{1,40}):\s*(.*)$').firstMatch(rawBody);
    if (match != null && match.group(1)!.trim().isNotEmpty) {
      senderName = match.group(1)!.trim();
      preview = match.group(2)!.trim();
    }

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      title: title,
      body: preview,
      sentAt: DateTime.tryParse((json['sent_at'] ?? '').toString()) ?? DateTime.now(),
      isRead: isRead,
      channel: (data['channel'] ?? '').toString(),
      threadId: data['thread_id']?.toString(),
      senderName: senderName,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        sentAt: sentAt,
        isRead: isRead ?? this.isRead,
        channel: channel,
        threadId: threadId,
        type: type,
        senderName: senderName,
        isPriority: isPriority,
        threadUnreadCount: threadUnreadCount,
        groupName: groupName,
        attachmentType: attachmentType,
        deliveryStatus: deliveryStatus,
        callType: callType,
        callDirection: callDirection,
        missedCallCount: missedCallCount,
        ringDuration: ringDuration,
        callerPhone: callerPhone,
        amount: amount,
        currency: currency,
        transactionDirection: transactionDirection,
        transactionReference: transactionReference,
        balanceAfter: balanceAfter,
        counterpartName: counterpartName,
      );
}
