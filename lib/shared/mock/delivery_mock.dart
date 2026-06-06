class Deliverer {
  final String id;
  final String name;
  final double rating;
  final int reviewCount;
  final int feeEstimate; // en FCFA
  final String zone;

  const Deliverer({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.feeEstimate,
    required this.zone,
  });
}

const mockDeliverers = [
  Deliverer(
    id: 'del_001',
    name: 'Yao Express',
    rating: 4.8,
    reviewCount: 132,
    feeEstimate: 1500,
    zone: 'Abidjan & banlieue',
  ),
  Deliverer(
    id: 'del_002',
    name: 'Rapid Livraison CI',
    rating: 4.5,
    reviewCount: 87,
    feeEstimate: 1000,
    zone: 'Abidjan centre',
  ),
  Deliverer(
    id: 'del_003',
    name: 'Moto Flash',
    rating: 4.2,
    reviewCount: 54,
    feeEstimate: 700,
    zone: 'Cocody / Plateau',
  ),
];
