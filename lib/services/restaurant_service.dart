// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../models/restaurant_model.dart';
// import 'location_service.dart';

// class RestaurantService {
//   final SupabaseClient _supabase = Supabase.instance.client;
//   final LocationService _locationService = LocationService();

//   // Fetch top-rated nearby restaurants (using Supabase + Google API later)
//   Future<List<RestaurantModel>> fetchNearbyTopRatedRestaurants() async {
//     final position = await _locationService.getCurrentLocation();

//     final response = await _supabase
//         .from('restaurants')
//         .select()
//         .gte('rating', 4.0)
//         .limit(10);

//     final data = response as List<dynamic>;

//     return data.map((e) => RestaurantModel.fromMap(e)).toList();
//   }

//   // Fetch user favorites
//   Future<List<RestaurantModel>> fetchFavorites(String userId) async {
//     final favorites = await _supabase
//         .from('favorites')
//         .select('restaurant_id')
//         .eq('uid', userId);

//     final favoriteIds = favorites.map((f) => f['restaurant_id']).toList();

//     if (favoriteIds.isEmpty) return [];

//     final restaurantData = await _supabase
//         .from('restaurants')
//         .select()
//         .inFilter('id', favoriteIds);

//     return (restaurantData as List<dynamic>)
//         .map((e) => RestaurantModel.fromMap(e))
//         .toList();
//   }

//   // Fetch posts (offers and discounts)
//   Future<List<Map<String, dynamic>>> fetchOffers() async {
//     final response = await _supabase
//         .from('posts')
//         .select()
//         .order('created_at', ascending: false);

//     return (response as List<dynamic>).cast<Map<String, dynamic>>();
//   }
// }

// // lib/services/restaurant_service.dart
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../models/restaurant_model.dart';

// class RestaurantService {
//   final SupabaseClient _supabase = Supabase.instance.client;

//   // Fetch top-rated nearby restaurants (rating >= 4.0)
//   Future<List<RestaurantModel>> fetchNearbyTopRatedRestaurants() async {
//     final response = await _supabase
//         .from('restaurants')
//         .select()
//         .gte('rating', 4.0)
//         .limit(10);

//     final data = response as List<dynamic>;

//     return data
//         .map((e) => RestaurantModel.fromMap(e as Map<String, dynamic>))
//         .toList();
//   }

//   // Fetch user favorites
//   Future<List<RestaurantModel>> fetchFavorites(String userId) async {
//     final favorites = await _supabase
//         .from('favorites')
//         .select('restaurant_id')
//         .eq('uid', userId);

//     final favoriteIds = (favorites as List<dynamic>)
//         .map((f) => f['restaurant_id'] as String)
//         .toList();

//     if (favoriteIds.isEmpty) return [];

//     final restaurantData = await _supabase
//         .from('restaurants')
//         .select()
//         .contains('id', favoriteIds); // Use contains instead of in/in_

//     return (restaurantData as List<dynamic>)
//         .map((e) => RestaurantModel.fromMap(e as Map<String, dynamic>))
//         .toList();
//   }

//   // Fetch posts (offers and discounts)
//   Future<List<Map<String, dynamic>>> fetchOffers() async {
//     final response = await _supabase
//         .from('posts')
//         .select()
//         .order('created_at', ascending: false);

//     return (response as List<dynamic>).cast<Map<String, dynamic>>();
//   }
// }

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant_model.dart';

class RestaurantService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch top-rated nearby restaurants
  Future<List<RestaurantModel>> fetchNearbyTopRatedRestaurants({
    double? userLat,
    double? userLng,
    double radiusKm = 5.0,
  }) async {
    final response = await _supabase
        .from('restaurants')
        .select()
        .gte('rating', 4.0)
        .limit(10);

    final data = response as List<dynamic>;
    List<RestaurantModel> restaurants =
        data.map((e) => RestaurantModel.fromMap(e)).toList();

    if (userLat != null && userLng != null) {
      // Approximate distance filter using sqrt from dart:math
      restaurants = restaurants.where((r) {
        final dLat = (r.latitude - userLat) * 111; // km per degree
        final dLng = (r.longitude - userLng) * 111;
        final distance = sqrt(dLat * dLat + dLng * dLng);
        return distance <= radiusKm;
      }).toList();
    }

    return restaurants;
  }

  // Fetch user favorites
  Future<List<RestaurantModel>> fetchFavorites(String userId) async {
    final favorites = await _supabase
        .from('favorites')
        .select('restaurant_id')
        .eq('uid', userId);

    final favoriteIds =
        (favorites as List<dynamic>).map((f) => f['restaurant_id']).toList();

    if (favoriteIds.isEmpty) return [];

    final restaurantData = await _supabase
        .from('restaurants')
        .select()
        .contains('id', favoriteIds);

    return (restaurantData as List<dynamic>)
        .map((e) => RestaurantModel.fromMap(e))
        .toList();
  }

  // Fetch posts (offers)
  Future<List<Map<String, dynamic>>> fetchOffers() async {
    final response = await _supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
