// lib/screens/customer/search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../widgets/restaurant_card.dart';
import 'restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _firestoreRestaurants = [];
  List<Map<String, dynamic>> _placesRestaurants = [];
  List<String> _favoriteIds = [];
  bool _isLoading = false;

  // Filter state
  String _selectedCuisine = '';
  bool _openNow = false;
  int _radius = 2000;

  final List<String> _cuisineOptions = [
    '',
    'Deshi',
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Vegan',
    'BBQ',
    'Café'
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final favorites = List<String>.from(userDoc.data()?['favorites'] ?? []);
    setState(() {
      _favoriteIds = favorites;
    });
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _isLoading = true;
      _placesRestaurants = [];
      _firestoreRestaurants = [];
    });

    try {
      final position = await _locationService.getCurrentLocation();

      // Firestore filter by cuisine tag and keyword
      final firestoreQuery = _firestore.collection('restaurants');
      QuerySnapshot querySnapshot;
      if (_selectedCuisine.isNotEmpty) {
        querySnapshot = await firestoreQuery
            .where('tags', arrayContains: _selectedCuisine)
            .get();
      } else {
        querySnapshot = await firestoreQuery.get();
      }

      final filteredFirestore = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((r) => r['name']
              .toString()
              .toLowerCase()
              .contains(keyword.toLowerCase()))
          .toList();

      final placesResults = await _placesService.searchNearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        keyword: keyword,
        cuisine: _selectedCuisine,
        openNow: _openNow,
        radius: _radius,
      );

      setState(() {
        _firestoreRestaurants = filteredFirestore;
        _placesRestaurants = placesResults;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during search: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    final uid = _auth.currentUser?.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final isFav = _favoriteIds.contains(restaurantId);
    await userRef.update({
      'favorites': isFav
          ? FieldValue.arrayRemove([restaurantId])
          : FieldValue.arrayUnion([restaurantId])
    });
    await _loadFavorites();
  }

  Widget _buildFilters() {
    return ExpansionTile(
      title: const Text('Filters'),
      children: [
        DropdownButton<String>(
          value: _selectedCuisine,
          hint: const Text('Cuisine'),
          items: _cuisineOptions
              .map((c) => DropdownMenuItem(
                  value: c, child: Text(c.isEmpty ? 'All' : c)))
              .toList(),
          onChanged: (val) => setState(() => _selectedCuisine = val ?? ''),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Search Radius:'),
            DropdownButton<int>(
              value: _radius,
              items: [1000, 2000, 3000, 5000]
                  .map((r) => DropdownMenuItem(value: r, child: Text('$r m')))
                  .toList(),
              onChanged: (val) => setState(() => _radius = val ?? 2000),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Open Now'),
            Switch(
              value: _openNow,
              onChanged: (val) => setState(() => _openNow = val),
            ),
          ],
        ),
        ElevatedButton(
          onPressed: () => _search(_searchController.text.trim()),
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildRestaurantSection(String title, List<Map<String, dynamic>> list,
      {bool fromFirestore = false}) {
    if (list.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final r = list[index];
            final id = fromFirestore ? r['id'] : r['place_id'] ?? r['name'];
            return RestaurantCard(
              name: r['name'] ?? 'Unnamed',
              address: r['address'] ?? r['vicinity'] ?? '',
              rating: (r['rating'] ?? 0).toDouble(),
              imageUrl: r['imageUrl'] ??
                  (r['photos'] != null
                      ? _placesService
                          .getPhotoUrl(r['photos'][0]['photo_reference'])
                      : ''),
              isFavorite: _favoriteIds.contains(id),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantDetailScreen(restaurant: r),
                  ),
                );
              },
              onFavoriteToggle: () => _toggleFavorite(id),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Restaurants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or keyword',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text.trim()),
                ),
              ),
            ),
          ),
          _buildFilters(),
          if (_isLoading) const CircularProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildRestaurantSection(
                      'Top Picks from App', _firestoreRestaurants,
                      fromFirestore: true),
                  _buildRestaurantSection(
                      'Nearby Restaurants', _placesRestaurants),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
