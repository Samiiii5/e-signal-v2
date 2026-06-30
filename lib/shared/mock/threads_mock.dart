// Canaux de messagerie supportés
enum Channel { whatsapp, facebook, sms, tiktok, email }

// Statut d'une conversation
enum ThreadStatus { open, resolved, pending }

class Thread {
  final String id;
  final String contactName;
  final String contactInitials;
  final Channel channel;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final ThreadStatus status;

  const Thread({
    required this.id,
    required this.contactName,
    required this.contactInitials,
    required this.channel,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.status,
  });

  Thread copyWith({String? lastMessage, DateTime? lastMessageAt}) => Thread(
    id: id,
    contactName: contactName,
    contactInitials: contactInitials,
    channel: channel,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unreadCount: unreadCount,
    status: status,
  );
}

final mockThreads = <Thread>[
  Thread(
    id: 'thread_001',
    contactName: 'Awa N\'Guessan',
    contactInitials: 'AN',
    channel: Channel.whatsapp,
    lastMessage: 'Merci pour le lien, j\'ai payé 🙏',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 4)),
    unreadCount: 0,
    status: ThreadStatus.resolved,
  ),
  Thread(
    id: 'thread_002',
    contactName: 'Kofi Mensah',
    contactInitials: 'KM',
    channel: Channel.facebook,
    lastMessage: 'Est-ce que vous livrez à Yopougon ?',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 18)),
    unreadCount: 3,
    status: ThreadStatus.open,
  ),
  Thread(
    id: 'thread_003',
    contactName: 'Fatou Diallo',
    contactInitials: 'FD',
    channel: Channel.sms,
    lastMessage: 'Quel est le prix du lot de 10 ?',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
    unreadCount: 1,
    status: ThreadStatus.open,
  ),
  Thread(
    id: 'thread_004',
    contactName: 'Aminata Koné',
    contactInitials: 'AK',
    channel: Channel.tiktok,
    lastMessage: 'J\'ai vu votre vidéo, c\'est disponible ?',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
    unreadCount: 5,
    status: ThreadStatus.open,
  ),
  Thread(
    id: 'thread_005',
    contactName: 'Jean-Baptiste Aka',
    contactInitials: 'JA',
    channel: Channel.email,
    lastMessage: 'Bonjour, je souhaite un devis pour 50 unités.',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 5)),
    unreadCount: 0,
    status: ThreadStatus.pending,
  ),
  Thread(
    id: 'thread_006',
    contactName: 'Binta Coulibaly',
    contactInitials: 'BC',
    channel: Channel.whatsapp,
    lastMessage: 'OK je vais réfléchir, merci',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 8)),
    unreadCount: 0,
    status: ThreadStatus.resolved,
  ),
  Thread(
    id: 'thread_007',
    contactName: 'Moussa Traoré',
    contactInitials: 'MT',
    channel: Channel.facebook,
    lastMessage: 'Vous avez le modèle en bleu ?',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
    unreadCount: 2,
    status: ThreadStatus.open,
  ),
  Thread(
    id: 'thread_008',
    contactName: 'Rose Yao',
    contactInitials: 'RY',
    channel: Channel.sms,
    lastMessage: 'Quand sera disponible la prochaine livraison ?',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    unreadCount: 0,
    status: ThreadStatus.open,
  ),
];
