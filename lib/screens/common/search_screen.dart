import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _supabase = Supabase.instance.client;
  final _placesService = PlacesService();
  final _locationService = LocationService();

  // UI + search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _initialSearched = false;
  String? _error;

  // Data
  List<Map<String, dynamic>> _supabaseRestaurants = [];
  List<Map<String, dynamic>> _placesRestaurants = [];
  List<String> _favoriteIds = [];

  // Filters
  String _selectedCuisine = '';
  bool _openNow = false; // (Google Places only)
  double _radius = 2.0; // km

  final List<String> _cuisineOptions = const [
    '',
    'Deshi',
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Vegan',
    'BBQ',
    'Café',
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Favorites ----------
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

  // ---------- Search ----------
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _initialSearched = true;
      _supabaseRestaurants = [];
      _placesRestaurants = [];
    });

    try {
      final position = await _locationService.getCurrentLocation();

      // Supabase query (chain filters in Dart)
      PostgrestFilterBuilder supabaseQuery =
          _supabase.from('restaurants').select();

      if (keyword.isNotEmpty) {
        supabaseQuery = supabaseQuery.ilike('name', '%$keyword%');
      }
      if (_selectedCuisine.isNotEmpty) {
        // tags is text[]; contains expects a JSON array argument
        supabaseQuery = supabaseQuery.contains('tags', [_selectedCuisine]);
      }

      final restaurantResponse = await supabaseQuery.limit(50);
      final supabaseList = List<Map<String, dynamic>>.from(restaurantResponse);

      // Google Places
      final placesResults = await _placesService.searchNearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        keyword: keyword,
        cuisine: _selectedCuisine,
        openNow: _openNow,
        radius: (_radius * 1000).toInt(),
      );

      setState(() {
        _supabaseRestaurants = supabaseList;
        _placesRestaurants = placesResults;
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI Helpers ----------
  String _resolveImageUrl(Map<String, dynamic> r,
      {required bool fromSupabase}) {
    final explicit = (r['image_url'] ?? r['imageUrl'])?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    if (!fromSupabase) {
      final photos = r['photos'];
      if (photos is List && photos.isNotEmpty) {
        final ref = photos.first['photo_reference']?.toString();
        if (ref != null && ref.isNotEmpty) {
          return _placesService.getPhotoUrl(ref);
        }
      }
    }
    return '';
  }

  String _resolveId(Map<String, dynamic> r, {required bool fromSupabase}) {
    if (fromSupabase) return (r['id'] ?? '').toString();
    return (r['place_id'] ?? r['name'] ?? '').toString();
  }

  double _toDoubleRating(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final d = double.tryParse(v);
      if (d != null) return d;
    }
    return 0.0;
  }

  // ---------- Sliver UI ----------
  Widget _buildHeader() {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: true,
      title: const Text('Find your next bite'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _search(v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name, dish, or keyword',
                prefixIcon: const Icon(Icons.search),

                // STABLE suffix subtree
                suffixIcon: _SearchSuffix(
                  controller: _searchController,
                  onClear: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                  onOpenFilters: _openFiltersSheet,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                  minWidth: kMinInteractiveDimension,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFiltersRow() {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Open now'),
              selected: _openNow,
              onSelected: (v) => setState(() {
                _openNow = v;
                _search(_searchController.text.trim());
              }),
            ),
            const SizedBox(width: 8),
            InputChip(
              label: Text(
                _radius >= 1 ? '${_radius.toStringAsFixed(1)} km' : 'Radius',
              ),
              avatar: const Icon(Icons.my_location, size: 18),
              onPressed: _openFiltersSheet,
            ),
            const SizedBox(width: 8),
            InputChip(
              label:
                  Text(_selectedCuisine.isEmpty ? 'Cuisine' : _selectedCuisine),
              avatar: const Icon(Icons.restaurant_menu, size: 18),
              onPressed: _openFiltersSheet,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('($count)', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverList _buildSectionList(
    List<Map<String, dynamic>> items, {
    required bool fromSupabase,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final r = items[index];
          final id = _resolveId(r, fromSupabase: fromSupabase);
          final img = _resolveImageUrl(r, fromSupabase: fromSupabase);

          return RestaurantCard(
            key: ValueKey('${fromSupabase ? 'sup' : 'plc'}_$id'), // stable key
            name: (r['name'] ?? 'Unnamed').toString(),
            address: (r['address'] ?? r['vicinity'] ?? '').toString(),
            rating: _toDoubleRating(r['rating']),
            imageUrl: img,
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
        childCount: items.length,
      ),
    );
  }

  SliverToBoxAdapter _buildEmpty() {
    if (!_initialSearched) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 48.0),
          child: Column(
            children: [
              const Icon(Icons.restaurant, size: 56),
              const SizedBox(height: 12),
              Text('Search for restaurants',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Try “pizza”, “Deshi”, or “coffee”.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 48.0),
        child: Column(
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 56),
            const SizedBox(height: 12),
            Text('No results found',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Try widening the radius or removing filters.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        String tempCuisine = _selectedCuisine;
        bool tempOpenNow = _openNow;
        double tempRadius = _radius;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cuisine',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cuisineOptions.map((c) {
                      final label = c.isEmpty ? 'All' : c;
                      final selected = tempCuisine == c;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => setModal(() => tempCuisine = c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: tempOpenNow,
                    onChanged: (v) => setModal(() => tempOpenNow = v),
                    title: const Text('Open now (nearby)'),
                    subtitle: const Text('Uses Google Places'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Search radius'),
                    subtitle: Slider(
                      value: tempRadius,
                      onChanged: (v) => setModal(() => tempRadius = v),
                      min: 0.5,
                      max: 5.0,
                      divisions: 9,
                      label: '${tempRadius.toStringAsFixed(1)} km',
                    ),
                    trailing: Text('${tempRadius.toStringAsFixed(1)} km'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          onPressed: () {
                            setModal(() {
                              tempCuisine = '';
                              tempOpenNow = false;
                              tempRadius = 2.0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedCuisine = tempCuisine;
                              _openNow = tempOpenNow;
                              _radius = tempRadius;
                            });
                            _search(_searchController.text.trim());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    await _search(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            _buildQuickFiltersRow(),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: MaterialBanner(
                    content: Text('Error: $_error'),
                    actions: [
                      TextButton(
                        onPressed: () => _search(_searchController.text.trim()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!_isLoading &&
                _supabaseRestaurants.isEmpty &&
                _placesRestaurants.isEmpty)
              _buildEmpty(),
            if (_supabaseRestaurants.isNotEmpty) ...[
              _buildSectionHeader(
                  'Top Picks from App', _supabaseRestaurants.length),
              _buildSectionList(_supabaseRestaurants, fromSupabase: true),
            ],
            if (_placesRestaurants.isNotEmpty) ...[
              _buildSectionHeader(
                  'Nearby Restaurants', _placesRestaurants.length),
              _buildSectionList(_placesRestaurants, fromSupabase: false),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// Stable suffix widget for the TextField to avoid element swaps.
class _SearchSuffix extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onOpenFilters;

  const _SearchSuffix({
    required this.controller,
    required this.onClear,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinInteractiveDimension,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filters',
                onPressed: onOpenFilters,
              ),
            ],
          );
        },
      ),
    );
  }
}
