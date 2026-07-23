import 'package:flutter/foundation.dart';

class Thread {
  final String id;
  final String contactName;
  final String? contactPictureUrl;
  final String channel;
  final String?
  metadataProvider; // provider réel pour l'API (ex: 'facebook' vs 'messenger')
  final String? integrationAccountId;
  final String? lastMessageAt;
  final int unreadCount;
  final String status;
  final String? assignedToUserId;
  final String? lastMessage; // Contenu du dernier message
  final bool isOnline; // Indicateur de présence en ligne
  final String? presence; // 'online', 'offline', 'away', etc.

  const Thread({
    required this.id,
    required this.contactName,
    this.contactPictureUrl,
    required this.channel,
    this.metadataProvider,
    this.integrationAccountId,
    this.lastMessageAt,
    required this.unreadCount,
    required this.status,
    this.assignedToUserId,
    this.lastMessage,
    this.isOnline = false,
    this.presence,
  });

  String get contactInitials {
    final parts = contactName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final f = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    final l = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0].toUpperCase()
        : '';
    final result = f + l;
    return result.isNotEmpty ? result : '?';
  }

  /// Copie partielle — un paramètre omis (null) conserve la valeur existante.
  Thread copyWith({
    String? contactName,
    String? contactPictureUrl,
    String? channel,
    String? metadataProvider,
    String? integrationAccountId,
    String? lastMessageAt,
    int? unreadCount,
    String? status,
    String? assignedToUserId,
    String? lastMessage,
    bool? isOnline,
    String? presence,
  }) => Thread(
    id: id,
    contactName: contactName ?? this.contactName,
    contactPictureUrl: contactPictureUrl ?? this.contactPictureUrl,
    channel: channel ?? this.channel,
    metadataProvider: metadataProvider ?? this.metadataProvider,
    integrationAccountId: integrationAccountId ?? this.integrationAccountId,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    status: status ?? this.status,
    assignedToUserId: assignedToUserId ?? this.assignedToUserId,
    lastMessage: lastMessage ?? this.lastMessage,
    isOnline: isOnline ?? this.isOnline,
    presence: presence ?? this.presence,
  );

  /// Copie avec assignedToUserId explicitement remis à null (thread_unassigned).
  Thread copyWithUnassigned() => Thread(
    id: id,
    contactName: contactName,
    contactPictureUrl: contactPictureUrl,
    channel: channel,
    metadataProvider: metadataProvider,
    integrationAccountId: integrationAccountId,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount,
    status: status,
    assignedToUserId: null,
    lastMessage: lastMessage,
    isOnline: isOnline,
    presence: presence,
  );

  factory Thread.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final channel = (json['channel'] ?? '').toString().toLowerCase();
    final metaProvider = metadata is Map
        ? metadata['provider']?.toString()
        : null;
    final metadataProvider = (metaProvider ?? channel).toLowerCase();
    final metaAccountId = metadata is Map
        ? metadata['integration_account_id']?.toString()
        : null;
    final integrationAccountId =
        metaAccountId ??
        json['integration_account_id']?.toString() ??
        json['integrationAccountId']?.toString();

    debugPrint(
      '=== Thread channel=$channel provider=$metadataProvider accountId=$integrationAccountId ===',
    );

    return Thread(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      contactName: () {
        final contact = json['contact'];
        if (contact is Map) {
          return (contact['full_name'] ?? contact['name'] ?? 'Inconnu')
              .toString();
        }
        return (json['contactName'] ??
                json['contact_name'] ??
                contact ??
                'Inconnu')
            .toString();
      }(),
      contactPictureUrl:
          json['contactPictureUrl']?.toString() ??
          json['contact_picture_url']?.toString(),
      channel: channel,
      metadataProvider: metadataProvider,
      integrationAccountId: integrationAccountId,
      lastMessageAt:
          json['lastMessageAt']?.toString() ??
          json['last_message_at']?.toString(),
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      status: (json['status'] ?? 'open').toString().toLowerCase(),
      assignedToUserId:
          json['assignedToUserId']?.toString() ??
          json['assigned_to_user_id']?.toString(),
      lastMessage:
          json['lastMessage']?.toString() ??
          json['last_message']?.toString() ??
          json['last_message_text']?.toString(),
      isOnline:
          json['is_online'] == true || json['presence']?.toString() == 'online',
      presence: json['presence']?.toString(),
    );
  }
}

final mockThreads = <Thread>[
  Thread(
    id: 'thread_001',
    contactName: "Awa N'Guessan",
    channel: 'whatsapp',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(minutes: 4))
        .toIso8601String(),
    unreadCount: 0,
    status: 'resolved',
    lastMessage: 'Merci pour votre réponse !',
    isOnline: true,
  ),
  Thread(
    id: 'thread_002',
    contactName: 'Kofi Mensah',
    channel: 'messenger',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(minutes: 18))
        .toIso8601String(),
    unreadCount: 3,
    status: 'open',
    lastMessage: 'Je suis intéressé par vos produits',
    isOnline: false,
  ),
  Thread(
    id: 'thread_003',
    contactName: 'Fatou Diallo',
    channel: 'sms',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    unreadCount: 1,
    status: 'open',
    lastMessage: 'Pouvez-vous me donner plus de détails ?',
    isOnline: false,
  ),
  Thread(
    id: 'thread_004',
    contactName: 'Aminata Koné',
    channel: 'tiktok',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(hours: 2, minutes: 30))
        .toIso8601String(),
    unreadCount: 5,
    status: 'open',
    lastMessage: 'J\'adore votre contenu !',
    isOnline: true,
  ),
  Thread(
    id: 'thread_005',
    contactName: 'Jean-Baptiste Aka',
    channel: 'email',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    unreadCount: 0,
    status: 'pending',
    lastMessage: 'Re: Votre demande de devis',
    isOnline: false,
  ),
  Thread(
    id: 'thread_006',
    contactName: 'Binta Coulibaly',
    channel: 'whatsapp',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(hours: 8))
        .toIso8601String(),
    unreadCount: 0,
    status: 'resolved',
    lastMessage: 'Problème résolu, merci !',
    isOnline: false,
  ),
  Thread(
    id: 'thread_007',
    contactName: 'Moussa Traoré',
    channel: 'messenger',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    unreadCount: 2,
    status: 'open',
    lastMessage: 'Quand êtes-vous disponible ?',
    isOnline: true,
  ),
  Thread(
    id: 'thread_008',
    contactName: 'Rose Yao',
    channel: 'sms',
    lastMessageAt: DateTime.now()
        .subtract(const Duration(days: 1, hours: 3))
        .toIso8601String(),
    unreadCount: 0,
    status: 'open',
    lastMessage: 'Ok, je vous rappelle',
    isOnline: false,
  ),
];
