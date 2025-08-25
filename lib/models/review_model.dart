class Review {
  final String id;
  final String restaurantId;
  final String customerId;
  final int rating;
  final String reviewText;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.restaurantId,
    required this.customerId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'],
      restaurantId: map['restaurant_id'],
      customerId: map['customer_id'],
      rating: map['rating'],
      reviewText: map['review_text'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
