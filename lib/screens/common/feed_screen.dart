import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../widgets/restaurant_card.dart';
import '../customer/restaurant_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  final _placesService = PlacesService();
  final _locationService = LocationService();

  List<Map<String, dynamic>> _topRestaurants = [];
  List<Map<String, dynamic>> _postSections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final position = await _locationService.getCurrentLocation();

    // 🔁 Load restaurants from Supabase
    final supabaseRestaurants = await _supabase
        .from('restaurants')
        .select()
        .limit(20); // limit for performance

    final supabaseList = List<Map<String, dynamic>>.from(supabaseRestaurants);

    // 🌐 Load from Google Places
    final placesList = await _placesService.searchNearbyRestaurants(
      lat: position.latitude,
      lng: position.longitude,
      keyword: '',
    );

    // 🔀 Mix top 5
    final allRestaurants = [...supabaseList, ...placesList];

    allRestaurants.shuffle();
    final topCombined = allRestaurants.take(5).toList();

    // 📣 Load latest posts from Supabase
    final postsQuery = await _supabase
        .from('posts')
        .select('*, restaurants(*)')
        .order('created_at', ascending: false)
        .limit(20);

    final posts = List<Map<String, dynamic>>.from(postsQuery);

    // Add parent restaurant into each post
    final formattedPosts = posts.map((p) {
      return {
        ...p,
        'restaurant': p['restaurants'],
      };
    }).toList();

    setState(() {
      _topRestaurants = topCombined;
      _postSections = formattedPosts;
      _isLoading = false;
    });
  }

  void _goToDetails(Map<String, dynamic> restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('🍽 Recommended Restaurants',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._topRestaurants.map((r) => RestaurantCard(
                      name: r['name'] ?? '',
                      address: r['address'] ?? r['vicinity'] ?? '',
                      rating: (r['rating'] ?? 0).toDouble(),
                      imageUrl: r['imageUrl'] ??
                          (r['photos'] != null
                              ? _placesService.getPhotoUrl(
                                  r['photos'][0]['photo_reference'])
                              : ''),
                      isFavorite: false,
                      onTap: () => _goToDetails(r),
                    )),
                const Divider(height: 32),
                const Text('📢 Latest Promotions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._postSections.map((p) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: p['image_url'] != null
                            ? Image.network(
                                p['image_url'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.local_offer),
                        title: Text(p['title'] ?? ''),
                        subtitle: Text(p['description'] ?? ''),
                        onTap: () => _goToDetails(p['restaurant']),
                      ),
                    )),
              ],
            ),
    );
  }
}
