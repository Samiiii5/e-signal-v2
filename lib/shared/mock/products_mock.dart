class Product {
  final String id;
  final String name;
  final int price;
  final String category;
  final String emoji;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.emoji,
  });
}

final mockProducts = <Product>[
  Product(id: 'prod_001', name: 'Robe Ankara taille M',      price: 15000, category: 'Vêtement femme',       emoji: '👗'),
  Product(id: 'prod_002', name: 'Chemise Kente homme',        price: 12000, category: 'Vêtement homme',       emoji: '👔'),
  Product(id: 'prod_003', name: 'Sac cuir marron',            price: 25000, category: 'Accessoire',           emoji: '👜'),
  Product(id: 'prod_004', name: 'Sandales en cuir',           price: 8000,  category: 'Chaussures',           emoji: '👡'),
  Product(id: 'prod_005', name: 'Boubou brodé',               price: 35000, category: 'Vêtement traditionnel',emoji: '🥻'),
  Product(id: 'prod_006', name: 'Collier perles africaines',  price: 5500,  category: 'Bijou',                emoji: '📿'),
  Product(id: 'prod_007', name: 'Tissu bogolan 6m',           price: 18000, category: 'Tissu',                emoji: '🎨'),
  Product(id: 'prod_008', name: 'Bracelet wax coloré',        price: 3500,  category: 'Bijou',                emoji: '💛'),
  Product(id: 'prod_009', name: 'Ensemble 2 pièces femme',    price: 28000, category: 'Vêtement femme',       emoji: '👘'),
  Product(id: 'prod_010', name: 'Chèche en coton',            price: 7000,  category: 'Accessoire',           emoji: '🧣'),
];
