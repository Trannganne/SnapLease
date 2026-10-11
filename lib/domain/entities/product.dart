class Product {
  final String id;
  final String name;
  final String image;
  final double rating;
  final int reviewCount;
  final String pricePerDay;
  final bool available;
  final String category;
  final List<String> branchIds;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.rating,
    required this.reviewCount,
    required this.pricePerDay,
    required this.available,
    this.category = 'Tất cả',
    this.branchIds = const ['Tất cả'],
  });
}
