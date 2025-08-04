class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String ownerId;
  final List<String>
      cuisines; // Change to List<String> to allow multiple cuisines
  final String imageUrl;
  final double averageRating;
  final double priceRange;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
    required this.cuisines,
    required this.imageUrl,
    required this.averageRating,
    required this.priceRange,
  });

  // Convert RestaurantModel instance to Firestore-friendly Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'ownerId': ownerId,
      'cuisines': cuisines, // Save cuisines as a list
      'imageUrl': imageUrl,
      'averageRating': averageRating,
      'priceRange': priceRange,
    };
  }

  // Convert Firestore data into a RestaurantModel object
  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    return RestaurantModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      ownerId: map['ownerId'] ?? '',
      cuisines: List<String>.from(map['cuisines'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      averageRating: map['averageRating']?.toDouble() ?? 0.0,
      priceRange: map['priceRange']?.toDouble() ?? 0.0,
    );
  }
}
