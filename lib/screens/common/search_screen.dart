import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../widgets/restaurant_card.dart';
import '../customer/restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _supabaseRestaurants = [];
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
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final response = await _supabase
        .from('favorites')
        .select('restaurant_id')
        .eq('uid', uid);

    setState(() {
      _favoriteIds = List<String>.from(response.map((f) => f['restaurant_id']));
    });
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _isLoading = true;
      _placesRestaurants = [];
      _supabaseRestaurants = [];
    });

    try {
      final position = await _locationService.getCurrentLocation();

      // 🔎 Supabase filter
      String query = 'ilike(name, "%$keyword%")';
      if (_selectedCuisine.isNotEmpty) {
        query +=
            ' & tags.cs.{"$_selectedCuisine"}'; // tags contains selected cuisine
      }

      final restaurantResponse = await _supabase
          .from('restaurants')
          .select()
          .textSearch('name', keyword)
          .limit(50);

      final filteredSupabase =
          List<Map<String, dynamic>>.from(restaurantResponse);

      final placesResults = await _placesService.searchNearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        keyword: keyword,
        cuisine: _selectedCuisine,
        openNow: _openNow,
        radius: _radius,
      );

      setState(() {
        _supabaseRestaurants = filteredSupabase;
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
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final isFav = _favoriteIds.contains(restaurantId);
    if (isFav) {
      await _supabase
          .from('favorites')
          .delete()
          .match({'uid': uid, 'restaurant_id': restaurantId});
    } else {
      await _supabase.from('favorites').insert({
        'uid': uid,
        'restaurant_id': restaurantId,
      });
    }

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
      {bool fromSupabase = false}) {
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
            final id = fromSupabase ? r['id'] : r['place_id'] ?? r['name'];
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
                      'Top Picks from App', _supabaseRestaurants,
                      fromSupabase: true),
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
