import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitebuddy/screens/customer/reservation_screen.dart';
import 'package:bitebuddy/widgets/review/review_form.dart';
import 'package:bitebuddy/widgets/review/review_list.dart';
import 'package:bitebuddy/utils/directions_helper.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isFavorite = false;
  List<Map<String, dynamic>> _menuItems = [];
  String? _userType;

  bool get isSupabaseRestaurant => widget.restaurant.containsKey('owner_id');
  String get restaurantId =>
      widget.restaurant['id'] ?? widget.restaurant['place_id'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadUserType();
    if (isSupabaseRestaurant) _loadMenu();
    _checkFavorite();
  }

  Future<void> _loadUserType() async {
    final user = _supabase.auth.currentUser;
    setState(() {
      _userType = user?.userMetadata?['userType'];
    });
  }

  Future<void> _loadMenu() async {
    final result = await _supabase
        .from('menu_items')
        .select('id, name, image_url')
        .eq('restaurant_id', restaurantId)
        .order('name', ascending: true);

    setState(() {
      _menuItems = List<Map<String, dynamic>>.from(result);
    });
  }

  Future<void> _checkFavorite() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final response = await _supabase
        .from('favorites')
        .select()
        .eq('uid', uid)
        .eq('restaurant_id', restaurantId);

    setState(() {
      _isFavorite = response.isNotEmpty;
    });
  }

  Future<void> _toggleFavorite() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    if (_isFavorite) {
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

    setState(() => _isFavorite = !_isFavorite);
  }

  void _makeReservation() {
    if (isSupabaseRestaurant) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReservationScreen(restaurantId: restaurantId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Reservations only available for BiteBuddy partner restaurants.')),
      );
    }
  }

  Future<void> _launchDirections() async {
    try {
      final r = widget.restaurant;
      double? lat;
      double? lng;

      if (isSupabaseRestaurant) {
        lat = r['latitude'];
        lng = r['longitude'];
      } else {
        lat = r['geometry']?['location']?['lat'];
        lng = r['geometry']?['location']?['lng'];

        if ((lat == null || lng == null) && r['place_id'] != null) {
          final coords =
              await DirectionsHelper.fetchLatLngFromPlaceId(r['place_id']);
          if (coords != null) {
            lat = coords['lat'];
            lng = coords['lng'];
          }
        }
      }

      if (lat != null && lng != null) {
        await DirectionsHelper.openGoogleMapsDirections(lat, lng);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching directions: $e')),
      );
    }
  }

  void _openGallery(List<String> urls, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageGalleryScreen(urls: urls, initialIndex: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final name = r['name'] ?? 'Unnamed';
    final address = r['address'] ?? r['vicinity'] ?? 'Unknown';
    final rating = (r['rating'] ?? 0).toString();
    final description = r['description'] ?? 'No description available.';
    final imageUrl = r['imageUrl'] ??
        (r['photos'] != null
            ? 'https://maps.gomaps.pro/maps/api/place/photo'
                '?maxwidth=400&photoreference=${r['photos'][0]['photo_reference']}&key=AlzaSyRM3tIJP7LCerIthSbcle0QuQB3Yv87erR'
            : '');

    // Build a simple list of urls + titles for the horizontal gallery
    final menuUrls = _menuItems
        .map<String?>((m) => (m['image_url'] as String?))
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 20),
          Text(name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 20),
              const SizedBox(width: 4),
              Text('Rating: $rating'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 20),
              const SizedBox(width: 4),
              Expanded(child: Text(address)),
            ],
          ),
          const SizedBox(height: 16),
          Text(description),
          const SizedBox(height: 20),

          // MENU SECTION (Supabase restaurants)
          if (isSupabaseRestaurant) ...[
            const Text('Menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (_menuItems.isEmpty)
              const Text('No menu items available.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Horizontal scrollable image strip
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _menuItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final url = item['image_url'] as String?;
                        final title = (item['name'] as String?) ?? '';
                        if (url == null || url.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return InkWell(
                          onTap: () => _openGallery(menuUrls, index),
                          child: SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    height: 100,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 100,
                                      width: 120,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.book_online),
              label: const Text('Make Reservation'),
              onPressed: _makeReservation,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
              onPressed: _launchDirections,
            ),
            const SizedBox(height: 30),

            // Reviews (visible to all; form visible since you allowed all auth)
            ReviewForm(restaurantId: restaurantId),
            const SizedBox(height: 20),
            const Text("Customer Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ReviewList(restaurantId: restaurantId),
          ],
        ],
      ),
    );
  }
}

/// Fullscreen swipeable, zoomable gallery for menu images.
class ImageGalleryScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageGalleryScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu (${widget.initialIndex + 1}/${widget.urls.length})'),
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        itemBuilder: (_, index) {
          final url = widget.urls[index];
          return Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
