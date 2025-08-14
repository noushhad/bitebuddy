import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<String> _favoriteIds = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadFavorites();
      await _loadFeed(); // load restaurants + posts (with graceful fallbacks)
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _favoriteIds = [];
      return;
    }

    try {
      final res = await _supabase
          .from('favorites')
          .select('restaurant_id')
          .eq('uid', uid);
      _favoriteIds = List<String>.from(res.map((f) => f['restaurant_id']));
    } catch (e) {
      // don’t block the feed on favorites failure
      _favoriteIds = [];
      debugPrint('Favorites load failed: $e');
    }
  }

  Future<void> _loadFeed() async {
    Map<String, dynamic>? position;
    try {
      final p = await _locationService.getCurrentLocation();
      position = {'lat': p.latitude, 'lng': p.longitude};
    } catch (e) {
      // No location? We’ll just skip Places results.
      position = null;
      debugPrint('Location failed: $e');
    }

    // 1) Supabase restaurants (always try)
    List<Map<String, dynamic>> supabaseList = [];
    try {
      final data = await _supabase.from('restaurants').select().limit(20);
      supabaseList = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase restaurants failed: $e');
    }

    // 2) Google Places (only if we have location)
    List<Map<String, dynamic>> placesList = [];
    if (position != null) {
      try {
        placesList = await _placesService.searchNearbyRestaurants(
          lat: position['lat'] as double,
          lng: position['lng'] as double,
          keyword: '',
        );
      } catch (e) {
        debugPrint('Places fetch failed: $e');
      }
    }

    // Mix top 5 (prefer Supabase first)
    final all = [...supabaseList, ...placesList]..shuffle();
    final topCombined = all.take(5).toList();

    // 3) Posts from Supabase
    List<Map<String, dynamic>> formattedPosts = [];
    try {
      final postsQuery = await _supabase
          .from('posts')
          .select('*, restaurants(*)')
          .order('created_at', ascending: false)
          .limit(20);

      final posts = List<Map<String, dynamic>>.from(postsQuery);
      formattedPosts = posts
          .map((p) => {
                ...p,
                'restaurant': p['restaurants'],
              })
          .toList();
    } catch (e) {
      debugPrint('Posts load failed: $e');
      // keep formattedPosts empty if it fails
    }

    if (!mounted) return;
    setState(() {
      _topRestaurants = topCombined;
      _postSections = formattedPosts;
    });
  }

  String _resolveId(Map<String, dynamic> r) {
    return (r['id'] ?? r['place_id'] ?? r['name'] ?? '').toString();
  }

  String _resolveImage(Map<String, dynamic> r) {
    final explicit = (r['image_url'] ?? r['imageUrl'])?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    // Try Places photo
    final photos = r['photos'];
    if (photos is List && photos.isNotEmpty) {
      final ref = photos.first['photo_reference']?.toString();
      if (ref != null && ref.isNotEmpty) {
        return _placesService.getPhotoUrl(ref);
      }
    }
    return '';
  }

  void _goToDetails(Map<String, dynamic> restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return; // must be logged in

    final isFav = _favoriteIds.contains(restaurantId);
    try {
      if (isFav) {
        await _supabase
            .from('favorites')
            .delete()
            .match({'uid': uid, 'restaurant_id': restaurantId});
      } else {
        await _supabase
            .from('favorites')
            .insert({'uid': uid, 'restaurant_id': restaurantId});
      }
      setState(() {
        if (isFav) {
          _favoriteIds.remove(restaurantId);
        } else {
          _favoriteIds.add(restaurantId);
        }
      });
    } catch (e) {
      debugPrint('Toggle favorite failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update favorite.')),
        );
      }
    }
  }

  Widget _emptyRestaurants() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.restaurant, size: 48),
            const SizedBox(height: 8),
            Text(
              'No recommendations yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Try enabling location or adding restaurants.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _emptyPosts() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Icon(Icons.campaign, size: 40),
            const SizedBox(height: 6),
            Text('No posts yet',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MaterialBanner(
                        content: Text('Error: $_error'),
                        actions: [
                          TextButton(
                            onPressed: _loadAll,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),

                  // Recommended
                  const Text('🍽 Recommended Restaurants',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_topRestaurants.isEmpty) _emptyRestaurants(),
                  ..._topRestaurants.map((r) {
                    final id = _resolveId(r);
                    final rating = (r['rating'] is num)
                        ? (r['rating'] as num).toDouble()
                        : double.tryParse('${r['rating']}') ?? 0.0;

                    return RestaurantCard(
                      key: ValueKey('feed_$id'),
                      name: (r['name'] ?? '').toString(),
                      address: (r['address'] ?? r['vicinity'] ?? '').toString(),
                      rating: rating,
                      imageUrl: _resolveImage(r),
                      isFavorite: _favoriteIds.contains(id),
                      onTap: () => _goToDetails(r),
                      onFavoriteToggle: () => _toggleFavorite(id),
                    );
                  }),

                  const Divider(height: 32),

                  // Posts
                  const Text('📢 Latest Promotions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_postSections.isEmpty) _emptyPosts(),
                  ..._postSections.map((p) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: (p['image_url'] is String) &&
                                  (p['image_url'] as String).isNotEmpty
                              ? Image.network(
                                  p['image_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.local_offer),
                          title: Text(p['title'] ?? ''),
                          subtitle: Text(p['description'] ?? ''),
                          onTap: () => _goToDetails(
                            (p['restaurant'] is Map<String, dynamic>)
                                ? p['restaurant'] as Map<String, dynamic>
                                : {},
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}
