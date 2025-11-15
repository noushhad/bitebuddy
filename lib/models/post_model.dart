class Post {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String restaurantId;

  Post({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.restaurantId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      restaurantId: json['restaurant_id'],
    );
  }
}
