class LienPaiement {
  final String id;
  final String contactNom;
  final String description;
  final int montantCommande;
  final int fraisLivraison;
  final int montantTotal;
  final String statut; // "created" | "pending" | "paid" | "expired"
  final String livreurNom;
  final DateTime createdAt;
  final String lienUrl;

  const LienPaiement({
    required this.id,
    required this.contactNom,
    required this.description,
    required this.montantCommande,
    required this.fraisLivraison,
    required this.montantTotal,
    required this.statut,
    required this.livreurNom,
    required this.createdAt,
    required this.lienUrl,
  });
}
