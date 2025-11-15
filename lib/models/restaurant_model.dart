class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String ownerId;
  final List<String> tags;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final String description;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
    required this.tags,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.description,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    return RestaurantModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      ownerId: map['owner_id'] ?? '',
      tags: (map['tags'] != null) ? List<String>.from(map['tags']) : <String>[],
      imageUrl: map['image_url'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      ratingCount: map['rating_count'] ?? 0,
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'owner_id': ownerId,
      'tags': tags,
      'image_url': imageUrl,
      'rating': rating,
      'rating_count': ratingCount,
      'description': description,
    };
  }
}
