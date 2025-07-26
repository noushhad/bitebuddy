class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String ownerId;
  final String cuisine;
  final String imageUrl;
  final double averageRating;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
    required this.cuisine,
    required this.imageUrl,
    required this.averageRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'ownerId': ownerId,
      'cuisine': cuisine,
      'imageUrl': imageUrl,
      'averageRating': averageRating,
    };
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    return RestaurantModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      ownerId: map['ownerId'] ?? '',
      cuisine: map['cuisine'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      averageRating: map['averageRating']?.toDouble() ?? 0.0,
    );
  }
}
