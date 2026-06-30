class Livreur {
  final String id;
  final String nom;
  final String photo; // initiales affichées dans l'avatar
  final double note;
  final int nombreLivraisons;
  final int tarif; // en FCFA
  final bool disponible;
  final String tempsEstime;

  const Livreur({
    required this.id,
    required this.nom,
    required this.photo,
    required this.note,
    required this.nombreLivraisons,
    required this.tarif,
    required this.disponible,
    required this.tempsEstime,
  });
}
