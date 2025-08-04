// lib/screens/common/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _firestore = FirebaseFirestore.instance;
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

    // Firestore restaurants
    final firestoreData = await _firestore.collection('restaurants').get();
    final firestoreList =
        firestoreData.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

    // Google Places restaurants
    final placesList = await _placesService.searchNearbyRestaurants(
      lat: position.latitude,
      lng: position.longitude,
      keyword: '',
    );

    // Mix up to 5 from both
    final allRestaurants = [...firestoreList, ...placesList];
    allRestaurants.shuffle();
    final topCombined = allRestaurants.take(5).toList();

    // Load promotions/posts from Firestore restaurants
    final List<Map<String, dynamic>> posts = [];
    for (final r in firestoreList) {
      final postQuery = await _firestore
          .collection('restaurants')
          .doc(r['id'])
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      final postList = postQuery.docs.map((d) => {
            ...d.data(),
            'restaurant': r,
          });

      posts.addAll(postList);
    }

    setState(() {
      _topRestaurants = topCombined;
      _postSections = posts;
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
                        leading: p['imageUrl'] != null
                            ? Image.network(
                                p['imageUrl'],
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
