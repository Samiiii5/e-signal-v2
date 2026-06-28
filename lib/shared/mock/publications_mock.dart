class PublicationComment {
  final String id;
  final String authorName;
  final String initials;
  final String text;
  final DateTime sentAt;

  const PublicationComment({
    required this.id,
    required this.authorName,
    required this.initials,
    required this.text,
    required this.sentAt,
  });
}

class Publication {
  final String id;
  final String title;
  final String network; // facebook | instagram | tiktok
  final int commentCount;
  final DateTime publishedAt;
  final List<PublicationComment> comments;

  const Publication({
    required this.id,
    required this.title,
    required this.network,
    required this.commentCount,
    required this.publishedAt,
    required this.comments,
  });
}

final mockPublications = <Publication>[
  Publication(
    id: 'pub_001',
    title: 'Nouvelle collection Ankara 🎉',
    network: 'instagram',
    commentCount: 12,
    publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    comments: [
      PublicationComment(id: 'c_001', authorName: 'Awa N\'Guessan',   initials: 'AN', text: 'C\'est trop beau ! Vous livrez à Yopougon ?',          sentAt: DateTime.now().subtract(const Duration(minutes: 30))),
      PublicationComment(id: 'c_002', authorName: 'Fatou Diallo',     initials: 'FD', text: 'Prix disponible svp 🙏',                               sentAt: DateTime.now().subtract(const Duration(hours: 1))),
      PublicationComment(id: 'c_003', authorName: 'Koné Ibrahim',     initials: 'KI', text: 'Trop classe ! Je commande pour ma femme',              sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),
    ],
  ),
  Publication(
    id: 'pub_002',
    title: 'Boubous brodés pour les fêtes 🥻',
    network: 'facebook',
    commentCount: 8,
    publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
    comments: [
      PublicationComment(id: 'c_004', authorName: 'Mariam Coulibaly', initials: 'MC', text: 'Vous avez en taille XXL ?',                            sentAt: DateTime.now().subtract(const Duration(hours: 3))),
      PublicationComment(id: 'c_005', authorName: 'Sékou Traoré',     initials: 'ST', text: 'C\'est pour une cérémonie le 15. Délai de livraison ?', sentAt: DateTime.now().subtract(const Duration(hours: 4))),
      PublicationComment(id: 'c_006', authorName: 'Adja Bah',         initials: 'AB', text: 'Magnifique ❤️❤️',                                      sentAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 30))),
    ],
  ),
  Publication(
    id: 'pub_003',
    title: 'Promo sacs en cuir — 20% off 👜',
    network: 'tiktok',
    commentCount: 24,
    publishedAt: DateTime.now().subtract(const Duration(days: 1)),
    comments: [
      PublicationComment(id: 'c_007', authorName: 'Bintou Sanogo',   initials: 'BS', text: 'C\'est en vrai cuir ou synthétique ?',                  sentAt: DateTime.now().subtract(const Duration(hours: 10))),
      PublicationComment(id: 'c_008', authorName: 'Yves Koffi',      initials: 'YK', text: 'J\'en veux 2 ! Comment je commande ?',                  sentAt: DateTime.now().subtract(const Duration(hours: 12))),
      PublicationComment(id: 'c_009', authorName: 'Aminata Touré',   initials: 'AT', text: 'La promo est valable jusqu\'à quand ?',                  sentAt: DateTime.now().subtract(const Duration(hours: 14))),
    ],
  ),
  Publication(
    id: 'pub_004',
    title: 'Tissus bogolan — arrivage direct du Mali 🎨',
    network: 'instagram',
    commentCount: 5,
    publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    comments: [
      PublicationComment(id: 'c_010', authorName: 'Rokia Doumbia',    initials: 'RD', text: 'C\'est vendu au mètre ou en rouleau ?',                 sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
      PublicationComment(id: 'c_011', authorName: 'Cheick Coulibaly', initials: 'CC', text: 'Super tissu ! Je passe samedi',                         sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 5))),
      PublicationComment(id: 'c_012', authorName: 'Oulaye Koné',      initials: 'OK', text: 'Vous avez d\'autres couleurs svp ?',                    sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 8))),
    ],
  ),
  Publication(
    id: 'pub_005',
    title: 'Bijoux africains fait main ✨',
    network: 'facebook',
    commentCount: 3,
    publishedAt: DateTime.now().subtract(const Duration(days: 3)),
    comments: [
      PublicationComment(id: 'c_013', authorName: 'Néné Camara',     initials: 'NC', text: 'Trop joli le collier ! C\'est quel prix ?',              sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 2))),
      PublicationComment(id: 'c_014', authorName: 'Hawa Diarra',     initials: 'HD', text: 'Vous faites la personnalisation ?',                      sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 4))),
      PublicationComment(id: 'c_015', authorName: 'Djeneba Kouyaté', initials: 'DK', text: 'J\'adore les perles africaines 💛',                      sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 6))),
    ],
  ),
];
