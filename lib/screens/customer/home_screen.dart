import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/restaurant_card.dart';
import '../customer/restaurant_detail_screen.dart';
import '../common/search_screen.dart';
import '../customer/favorites_screen.dart';
import '../common/feed_screen.dart';
import '../../widgets/logout_button.dart';

/// Generic vertical card for top-rated, offers, and favorites
class VerticalCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final double? rating; // null for offers
  final VoidCallback? onTap;

  const VerticalCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(rating!.toStringAsFixed(1)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  List<Map<String, dynamic>> _topRated = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadTopRated(),
      _loadOffers(),
      _loadFavorites(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadTopRated() async {
    final response = await _supabase
        .from('restaurants')
        .select()
        .order('rating', ascending: false)
        .limit(10);

    _topRated = List<Map<String, dynamic>>.from(response);
  }

  Future<void> _loadOffers() async {
    final postsQuery =
        await _supabase.from('posts').select('*, restaurants(*)').limit(10);

    final posts = List<Map<String, dynamic>>.from(postsQuery);

    // Keep parent restaurant under 'restaurant'
    _offers = posts.map((p) {
      return {
        'id': p['id'],
        'title': p['title'] ?? '',
        'image_url': p['image_url'] ?? '',
        'restaurant': p['restaurants'], // nested restaurant object
      };
    }).toList();
  }

  Future<void> _loadFavorites() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final favRows = await _supabase
        .from('favorites')
        .select('restaurant_id')
        .eq('uid', uid);

    final favIds = List<String>.from(favRows.map((e) => e['restaurant_id']));

    if (favIds.isEmpty) {
      _favorites = [];
      return;
    }

    final restaurantRows =
        await _supabase.from('restaurants').select().inFilter('id', favIds);

    _favorites = List<Map<String, dynamic>>.from(restaurantRows);
  }

  void _goToDetails(Map<String, dynamic> restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  Widget _sectionVertical(
      String title, List<Map<String, dynamic>> items, bool isOffer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: items.isEmpty
              ? const Center(child: Text("Nothing to show"))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final r = items[i];

                    if (isOffer) {
                      final restaurant = r['restaurant'] ?? {};
                      return VerticalCard(
                        title: "${r['title']}\n${restaurant['name'] ?? ''}",
                        imageUrl:
                            r['image_url'] ?? restaurant['image_url'] ?? '',
                        rating: null,
                        onTap: () {
                          if (restaurant.isNotEmpty) _goToDetails(restaurant);
                        },
                      );
                    } else {
                      return VerticalCard(
                        title: r['name'] ?? '',
                        imageUrl: r['image_url'] ?? '',
                        rating: r['rating']?.toDouble(),
                        onTap: () => _goToDetails(r),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50], // 🟠 light orange background
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                "BiteBuddy Profile",
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile & Contact'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Preferences'),
              onTap: () => Navigator.pushNamed(context, '/preferences'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () => Navigator.pushNamed(context, '/favorites'),
            ),
            const Divider(),
            const LogoutButton(),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text("BiteBuddy"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rss_feed),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _sectionVertical("Top Rated Nearby", _topRated, false),
                    _sectionVertical("Offers & Discounts", _offers, true),
                    _sectionVertical("Your Favorites", _favorites, false),
                  ],
                ),
              ),
            ),
    );
  }
}
