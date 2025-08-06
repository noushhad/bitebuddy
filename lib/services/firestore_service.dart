import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<RestaurantModel>> getRecommendedRestaurants() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('restaurants')
          .orderBy('rating', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RestaurantModel.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Error fetching restaurants: $e');
    }
  }
}
