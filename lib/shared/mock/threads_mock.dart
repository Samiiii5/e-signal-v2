class Thread {
  final String id;
  final String contactName;
  final String? contactPictureUrl;
  final String channel;
  final String? lastMessageAt;
  final int unreadCount;
  final String status;
  final String? assignedToUserId;

  const Thread({
    required this.id,
    required this.contactName,
    this.contactPictureUrl,
    required this.channel,
    this.lastMessageAt,
    required this.unreadCount,
    required this.status,
    this.assignedToUserId,
  });

  String get contactInitials {
    final parts = contactName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final f = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    final l = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0].toUpperCase() : '';
    final result = f + l;
    return result.isNotEmpty ? result : '?';
  }

  /// Copie avec assignedToUserId explicitement remis à null (thread_unassigned).
  Thread copyWithUnassigned() => Thread(
        id: id,
        contactName: contactName,
        contactPictureUrl: contactPictureUrl,
        channel: channel,
        lastMessageAt: lastMessageAt,
        unreadCount: unreadCount,
        status: status,
        assignedToUserId: null,
      );

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      contactName: () {
        final contact = json['contact'];
        if (contact is Map) return (contact['full_name'] ?? contact['name'] ?? 'Inconnu').toString();
        return (json['contactName'] ?? json['contact_name'] ?? contact ?? 'Inconnu').toString();
      }(),
      contactPictureUrl: json['contactPictureUrl']?.toString() ?? json['contact_picture_url']?.toString(),
      channel: (json['channel'] ?? '').toString().toLowerCase(),
      lastMessageAt: json['lastMessageAt']?.toString() ?? json['last_message_at']?.toString(),
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      status: (json['status'] ?? 'open').toString().toLowerCase(),
      assignedToUserId: json['assignedToUserId']?.toString() ?? json['assigned_to_user_id']?.toString(),
    );
  }
}

final mockThreads = <Thread>[
  Thread(
    id: 'thread_001',
    contactName: "Awa N'Guessan",
    channel: 'whatsapp',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
    unreadCount: 0,
    status: 'resolved',
  ),
  Thread(
    id: 'thread_002',
    contactName: 'Kofi Mensah',
    channel: 'messenger',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 18)).toIso8601String(),
    unreadCount: 3,
    status: 'open',
  ),
  Thread(
    id: 'thread_003',
    contactName: 'Fatou Diallo',
    channel: 'sms',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    unreadCount: 1,
    status: 'open',
  ),
  Thread(
    id: 'thread_004',
    contactName: 'Aminata Koné',
    channel: 'tiktok',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String(),
    unreadCount: 5,
    status: 'open',
  ),
  Thread(
    id: 'thread_005',
    contactName: 'Jean-Baptiste Aka',
    channel: 'email',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
    unreadCount: 0,
    status: 'pending',
  ),
  Thread(
    id: 'thread_006',
    contactName: 'Binta Coulibaly',
    channel: 'whatsapp',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
    unreadCount: 0,
    status: 'resolved',
  ),
  Thread(
    id: 'thread_007',
    contactName: 'Moussa Traoré',
    channel: 'messenger',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    unreadCount: 2,
    status: 'open',
  ),
  Thread(
    id: 'thread_008',
    contactName: 'Rose Yao',
    channel: 'sms',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)).toIso8601String(),
    unreadCount: 0,
    status: 'open',
  ),
];
