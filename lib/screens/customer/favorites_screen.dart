import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/restaurant_card.dart';
import '../customer/restaurant_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);

    final favResponse = await _supabase
        .from('favorites')
        .select('restaurant_id')
        .eq('uid', uid);

    final favIds =
        List<String>.from(favResponse.map((f) => f['restaurant_id']));

    if (favIds.isEmpty) {
      setState(() {
        _favorites = [];
        _isLoading = false;
      });
      return;
    }

    final restaurantResponse =
        await _supabase.from('restaurants').select().inFilter('id', favIds);

    setState(() {
      _favorites = List<Map<String, dynamic>>.from(restaurantResponse);
      _isLoading = false;
    });
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final existing = await _supabase
        .from('favorites')
        .select()
        .eq('uid', uid)
        .eq('restaurant_id', restaurantId);

    if (existing.isNotEmpty) {
      await _supabase
          .from('favorites')
          .delete()
          .match({'uid': uid, 'restaurant_id': restaurantId});
    } else {
      await _supabase
          .from('favorites')
          .insert({'uid': uid, 'restaurant_id': restaurantId});
    }

    _loadFavorites();
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
      appBar: AppBar(title: const Text('Your Favorites')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(child: Text('No favorites yet.'))
              : ListView.builder(
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final r = _favorites[index];
                    return RestaurantCard(
                      name: r['name'] ?? 'Unnamed',
                      address: r['address'] ?? 'No address',
                      rating: (r['rating'] ?? 0).toDouble(),
                      imageUrl: r['image_url'] ?? '',
                      isFavorite: true,
                      onTap: () => _goToDetails(r),
                      onFavoriteToggle: () => _toggleFavorite(r['id']),
                    );
                  },
                ),
    );
  }
}
