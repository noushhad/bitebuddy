// class ReviewModel {
//   final String id;
//   final String userId;
//   final String userName;
//   final String comment;
//   final double rating;
//   final DateTime createdAt;

//   ReviewModel({
//     required this.id,
//     required this.userId,
//     required this.userName,
//     required this.comment,
//     required this.rating,
//     required this.createdAt,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'userId': userId,
//       'userName': userName,
//       'comment': comment,
//       'rating': rating,
//       'createdAt': createdAt.toIso8601String(),
//     };
//   }

//   factory ReviewModel.fromMap(Map<String, dynamic> map) {
//     return ReviewModel(
//       id: map['id'] ?? '',
//       userId: map['userId'] ?? '',
//       userName: map['userName'] ?? '',
//       comment: map['comment'] ?? '',
//       rating: map['rating']?.toDouble() ?? 0.0,
//       createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
//     );
//   }
// }

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
