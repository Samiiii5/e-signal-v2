import '../models/livreur_model.dart';
import '../models/lien_paiement_model.dart';
import '../mock/livreurs_mock.dart';

class CreateLienDto {
  final String contactNom;
  final String description;
  final int montantCommande;
  final String livreurId;
  final String livreurNom;
  final int fraisLivraison;
  final String destination;

  const CreateLienDto({
    required this.contactNom,
    required this.description,
    required this.montantCommande,
    required this.livreurId,
    required this.livreurNom,
    required this.fraisLivraison,
    required this.destination,
  });
}

abstract class LivreurService {
  /// GET /api/livreurs?depart=&destination=
  /// Retourne les livreurs disponibles pour une destination donnée.
  Future<List<Livreur>> getLivreursDisponibles(String destination);

  /// POST /api/paiements/liens
  /// Génère un lien de paiement avec livraison incluse.
  Future<LienPaiement> genererLienPaiement(CreateLienDto dto);
}

class MockLivreurService implements LivreurService {
  @override
  Future<List<Livreur>> getLivreursDisponibles(String destination) async {
    await Future.delayed(const Duration(seconds: 1));
    return mockLivreurs.where((l) => l.disponible).toList();
  }

  @override
  Future<LienPaiement> genererLienPaiement(CreateLienDto dto) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final id = 'lnk_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    return LienPaiement(
      id: id,
      contactNom: dto.contactNom,
      description: dto.description,
      montantCommande: dto.montantCommande,
      fraisLivraison: dto.fraisLivraison,
      montantTotal: dto.montantCommande + dto.fraisLivraison,
      statut: 'created',
      livreurNom: dto.livreurNom,
      createdAt: DateTime.now(),
      lienUrl: 'pay.esignal.ci/$id',
    );
  }
}

final livreurService = MockLivreurService();
