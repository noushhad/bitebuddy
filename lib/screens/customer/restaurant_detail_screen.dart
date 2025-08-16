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

  // Aggregated (denormalized via trigger) values read from restaurants table
  double? _avgRating; // restaurants.rating
  int _ratingCount = 0; // restaurants.rating_count

  // Resolved cover image URL (either Supabase public/signed or Google Places)
  String? _coverUrl;

  bool get isSupabaseRestaurant => widget.restaurant.containsKey('owner_id');
  String get restaurantId =>
      widget.restaurant['id'] ?? widget.restaurant['place_id'] ?? '';

  // ---------- Truncate helper: one decimal, rounds down ----------
  String formatTruncate(double value) {
    final truncated = (value * 10).floor() / 10.0; // keep exactly one decimal
    return truncated.toStringAsFixed(1);
  }
  // ---------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadUserType();
    if (isSupabaseRestaurant) {
      _loadMenu();
      _loadAggregates(); // read restaurants.rating & rating_count
    }
    _checkFavorite();
    _prepareCoverImage();
  }

  // ----------------- Helpers -----------------

  String _publicUrl(String bucket, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  String? _googlePlacesPhotoUrl(Map r) {
    final photos = r['photos'];
    if (photos is List && photos.isNotEmpty) {
      final ref = photos[0]['photo_reference'];
      if (ref != null && ref.toString().isNotEmpty) {
        const apiKey =
            'AlzaSyepTEHhsQBV6Uq8C8B67-sVj5SOdxmomAx'; // TODO: move to secure config
        return 'https://maps.gomaps.pro/maps/api/place/photo'
            '?maxwidth=1200'
            '&photo_reference=$ref'
            '&key=$apiKey';
      }
    }
    return null;
  }

  Future<void> _prepareCoverImage() async {
    final r = widget.restaurant;

    if (isSupabaseRestaurant) {
      // Accept either a relative path or a full public URL
      final dynamic raw = r['image_url'] ??
          r['image_path'] ??
          r['cover_image'] ??
          r['imageUrl'];
      if (raw != null) {
        final path = raw.toString();
        if (path.isNotEmpty) {
          setState(() => _coverUrl = _publicUrl('restaurant-images', path));
          return;
        }
      }
      return;
    } else {
      final url = _googlePlacesPhotoUrl(r);
      if (url != null) setState(() => _coverUrl = url);
    }
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

    final items = <Map<String, dynamic>>[];
    for (final raw in result) {
      final m = Map<String, dynamic>.from(raw);
      final path = m['image_url'] as String?;
      if (path != null && path.isNotEmpty) {
        // Your menu images are in the `menu-images` bucket
        m['image_url'] = _publicUrl('menu-images', path);
      }
      items.add(m);
    }

    setState(() => _menuItems = items);
  }

  // Load aggregated rating from restaurants (denormalized via trigger)
  Future<void> _loadAggregates() async {
    final row = await _supabase
        .from('restaurants')
        .select('rating, rating_count')
        .eq('id', restaurantId)
        .maybeSingle();

    setState(() {
      _avgRating = (row?['rating'] as num?)?.toDouble();
      _ratingCount = (row?['rating_count'] as int?) ?? 0;
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

  // Simple star row for a double value (supports halves)
  Widget _buildStars(double value) {
    final full = value.floor();
    final frac = value - full;
    final hasHalf = frac >= 0.25 && frac < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          const Icon(Icons.star, size: 18, color: Colors.amber),
        if (hasHalf) const Icon(Icons.star_half, size: 18, color: Colors.amber),
        for (int i = 0; i < empty; i++)
          const Icon(Icons.star_border, size: 18, color: Colors.amber),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final name = r['name'] ?? 'Unnamed';
    final address = r['address'] ?? r['vicinity'] ?? 'Unknown';

    // Google rating (for non-Supabase restaurants)
    final googleRating = (r['rating'] as num?)?.toDouble();

    // Build gallery URLs from loaded menu items
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
          if (_coverUrl != null && _coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _coverUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // ----------------- Rating Row -----------------
          Row(
            children: [
              if (isSupabaseRestaurant)
                if (_avgRating != null && _ratingCount > 0) ...[
                  _buildStars(_avgRating!),
                  const SizedBox(width: 8),
                  Text(
                    "${formatTruncate(_avgRating!)} ($_ratingCount)",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ] else
                  const Text(
                    "No ratings yet",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  )
              else if (googleRating != null) ...[
                _buildStars(googleRating),
                const SizedBox(width: 8),
                Text(
                  formatTruncate(googleRating),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ] else
                const Text(
                  "No ratings yet",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
            ],
          ),
          // ----------------------------------------------

          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 20),
              const SizedBox(width: 4),
              Expanded(child: Text(address)),
            ],
          ),
          const SizedBox(height: 16),
          Text(r['description'] ?? 'No description available.'),
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

            // Reviews + Form
            ReviewForm(
              restaurantId: restaurantId,
              onSubmitted: _loadAggregates, // refresh after new review
            ),
            const SizedBox(height: 20),
            const Text(
              "Customer Reviews",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
