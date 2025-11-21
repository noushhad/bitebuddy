import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewService {
  static final _client = Supabase.instance.client;

  // Fetch reviews for either a restaurant_id or place_id
  static Future<List<Map<String, dynamic>>> fetchReviews(
      {String? restaurantId, String? placeId}) async {
    var builder = _client.from('reviews').select('*');
    if (restaurantId != null) {
      builder = builder.eq('restaurant_id', restaurantId);
    } else if (placeId != null) {
      builder = builder.eq('place_id', placeId);
    }
    final result =
        await builder.order('created_at', ascending: false).limit(10);
    return List<Map<String, dynamic>>.from(result);
  }

  // Add a review
  static Future<void> addReview({
    String? restaurantId,
    String? placeId,
    required int rating,
    required String comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('reviews').insert({
      'user_id': userId,
      'restaurant_id': restaurantId,
      'place_id': placeId,
      'rating': rating,
      'comment': comment,
    });
  }
}
