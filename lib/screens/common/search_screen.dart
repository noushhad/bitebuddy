// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// import '../../services/location_service.dart';
// import '../../services/places_service.dart';
// import '../../widgets/restaurant_card.dart';
// import '../customer/restaurant_detail_screen.dart';

// class SearchScreen extends StatefulWidget {
//   const SearchScreen({super.key});

//   @override
//   State<SearchScreen> createState() => _SearchScreenState();
// }

// class _SearchScreenState extends State<SearchScreen> {
//   final _placesService = PlacesService();
//   final _locationService = LocationService();
//   final _searchController = TextEditingController();
//   final _supabase = Supabase.instance.client;

//   List<Map<String, dynamic>> _supabaseRestaurants = [];
//   List<Map<String, dynamic>> _placesRestaurants = [];
//   List<String> _favoriteIds = [];
//   bool _isLoading = false;

//   String _selectedCuisine = '';
//   bool _openNow = false;
//   int _radius = 2000;

//   final List<String> _cuisineOptions = [
//     '',
//     'Children Friendly',
//     'Deshi',
//     'Italian',
//     'Chinese',
//     'Indian',
//     'Mexican',
//     'Vegan',
//     'BBQ',
//     'Café',
//     'Fine Dining',
//     'Fast Food',
//     'Seafood',
//     'Middle Eastern',
//     'Turkish',
//     'Thai',
//     'Japanese',
//     'Bakery/Dessert'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _loadFavorites();
//   }

//   Future<void> _loadFavorites() async {
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;

//     final response = await _supabase
//         .from('favorites')
//         .select('restaurant_id')
//         .eq('uid', uid);

//     setState(() {
//       _favoriteIds = List<String>.from(response.map((f) => f['restaurant_id']));
//     });
//   }

//   Future<void> _search(String keyword) async {
//     setState(() {
//       _isLoading = true;
//       _placesRestaurants = [];
//       _supabaseRestaurants = [];
//     });

//     try {
//       final position = await _locationService.getCurrentLocation();

//       // Supabase filter (kept your logic exactly)
//       String query = 'ilike(name, "%$keyword%")';
//       if (_selectedCuisine.isNotEmpty) {
//         query += ' & tags.cs.{"$_selectedCuisine"}';
//       }

//       final restaurantResponse = await _supabase
//           .from('restaurants')
//           .select()
//           .textSearch('name', keyword)
//           .limit(50);

//       final filteredSupabase =
//           List<Map<String, dynamic>>.from(restaurantResponse);

//       final placesResults = await _placesService.searchNearbyRestaurants(
//         lat: position.latitude,
//         lng: position.longitude,
//         keyword: keyword,
//         cuisine: _selectedCuisine,
//         openNow: _openNow,
//         radius: _radius,
//       );

//       setState(() {
//         _supabaseRestaurants = filteredSupabase;
//         _placesRestaurants = placesResults;
//       });
//     } catch (e) {
//       debugPrint('Search error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error during search: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _toggleFavorite(String restaurantId) async {
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;

//     final exists = _favoriteIds.contains(restaurantId);

//     if (exists) {
//       await _supabase
//           .from('favorites')
//           .delete()
//           .match({'uid': uid, 'restaurant_id': restaurantId});
//     } else {
//       await _supabase
//           .from('favorites')
//           .insert({'uid': uid, 'restaurant_id': restaurantId});
//     }

//     await _loadFavorites();
//   }

//   Widget _buildFilters() {
//     final cs = Theme.of(context).colorScheme;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: Card(
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//           side: BorderSide(color: cs.outlineVariant),
//         ),
//         child: ExpansionTile(
//           tilePadding: const EdgeInsets.symmetric(horizontal: 14),
//           childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
//           title: Row(
//             children: const [
//               Icon(Icons.tune_rounded, size: 20),
//               SizedBox(width: 8),
//               Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
//             ],
//           ),
//           subtitle: Text(
//             _selectedCuisine.isEmpty
//                 ? 'All cuisines • ${_radius ~/ 1000} km • ${_openNow ? "Open now" : "Any time"}'
//                 : '$_selectedCuisine • ${_radius ~/ 1000} km • ${_openNow ? "Open now" : "Any time"}',
//             style: TextStyle(color: cs.onSurfaceVariant),
//           ),
//           children: [
//             DropdownButtonFormField<String>(
//               value: _selectedCuisine,
//               decoration: InputDecoration(
//                 labelText: 'Cuisine',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               isExpanded: true,
//               items: _cuisineOptions
//                   .map(
//                     (c) => DropdownMenuItem(
//                       value: c,
//                       child: Text(c.isEmpty ? 'All' : c),
//                     ),
//                   )
//                   .toList(),
//               onChanged: (v) => setState(() => _selectedCuisine = v ?? ''),
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: DropdownButtonFormField<int>(
//                     value: _radius,
//                     decoration: InputDecoration(
//                       labelText: 'Radius',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     items: [1000, 2000, 3000, 5000]
//                         .map((r) => DropdownMenuItem(
//                               value: r,
//                               child: Text('${r ~/ 1000} km'),
//                             ))
//                         .toList(),
//                     onChanged: (v) => setState(() => _radius = v ?? 2000),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: cs.outlineVariant),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     height: 56,
//                     child: Row(
//                       children: [
//                         const Icon(Icons.access_time_rounded, size: 20),
//                         const SizedBox(width: 8),
//                         const Expanded(child: Text('Open now')),
//                         Switch(
//                           value: _openNow,
//                           onChanged: (v) => setState(() => _openNow = v),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: FilledButton.icon(
//                 onPressed: () => _search(_searchController.text.trim()),
//                 icon: const Icon(Icons.filter_alt_rounded),
//                 label: const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 12),
//                   child: Text('Apply Filters'),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRestaurantSection(
//     String title,
//     List<Map<String, dynamic>> list, {
//     bool fromSupabase = false,
//   }) {
//     if (list.isEmpty) return const SizedBox();
//     final cs = Theme.of(context).colorScheme;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 6),
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
//           child: Row(
//             children: [
//               Icon(
//                 fromSupabase ? Icons.store_rounded : Icons.near_me_rounded,
//                 size: 18,
//                 color: cs.onSurfaceVariant,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         ListView.separated(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: list.length,
//           separatorBuilder: (_, __) => const SizedBox(height: 8),
//           itemBuilder: (context, index) {
//             final r = list[index];
//             final id = fromSupabase ? r['id'] : r['place_id'] ?? r['name'];

//             return Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: Card(
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   side: BorderSide(color: cs.outlineVariant),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 6),
//                   child: RestaurantCard(
//                     name: r['name'] ?? 'Unnamed',
//                     address: r['address'] ?? r['vicinity'] ?? '',
//                     rating: (r['rating'] ?? 0).toDouble(),
//                     imageUrl: r['imageUrl'] ??
//                         (r['photos'] != null
//                             ? _placesService
//                                 .getPhotoUrl(r['photos'][0]['photo_reference'])
//                             : ''),
//                     isFavorite: _favoriteIds.contains(id),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => RestaurantDetailScreen(restaurant: r),
//                         ),
//                       );
//                     },
//                     onFavoriteToggle: () => _toggleFavorite(id),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Search Restaurants')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
//             child: TextField(
//               controller: _searchController,
//               textInputAction: TextInputAction.search,
//               onSubmitted: (v) => _search(_searchController.text.trim()),
//               decoration: InputDecoration(
//                 hintText: 'Search by name or keyword',
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.search_rounded),
//                   onPressed: () => _search(_searchController.text.trim()),
//                 ),
//                 filled: true,
//                 fillColor: cs.surfaceVariant.withOpacity(0.22),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   borderSide: BorderSide(color: cs.outlineVariant),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   borderSide: BorderSide(color: cs.primary, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//           _buildFilters(),
//           if (_isLoading)
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 16),
//               child: Column(
//                 children: const [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 8),
//                   Text('Searching…'),
//                 ],
//               ),
//             ),
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.only(bottom: 16),
//               child: Column(
//                 children: [
//                   _buildRestaurantSection(
//                     'Top Picks from App',
//                     _supabaseRestaurants,
//                     fromSupabase: true,
//                   ),
//                   _buildRestaurantSection(
//                     'Nearby Restaurants',
//                     _placesRestaurants,
//                   ),
//                   if (!_isLoading &&
//                       _supabaseRestaurants.isEmpty &&
//                       _placesRestaurants.isEmpty)
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
//                       child: Card(
//                         elevation: 0,
//                         color: cs.surfaceVariant.withOpacity(0.45),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: const Padding(
//                           padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
//                           child: Row(
//                             children: [
//                               Icon(Icons.search_off_rounded),
//                               SizedBox(width: 12),
//                               Expanded(
//                                 child: Text(
//                                   'No results yet. Try another keyword or adjust your filters.',
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _supabaseRestaurants = [];
  List<Map<String, dynamic>> _placesRestaurants = [];
  List<String> _favoriteIds = [];
  bool _isLoading = false;

  String _selectedCuisine = '';
  int _radius = 2000;

  int? _selectedPriceLevel; // <-- NEW

  // For expansion tile control
  final ValueNotifier<bool> _filtersExpanded = ValueNotifier<bool>(false);

  final List<String> _cuisineOptions = [
    '',
    'Children Friendly',
    'Deshi',
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Vegan',
    'BBQ',
    'Café',
    'Fine Dining',
    'Fast Food',
    'Seafood',
    'Middle Eastern',
    'Turkish',
    'Thai',
    'Japanese',
    'Bakery/Dessert'
  ];

  final List<Map<String, Object?>> _priceOptions = const [
    {'label': 'All', 'value': null},
    {'label': '৳ (Inexpensive)', 'value': 1},
    {'label': '৳৳ (Moderate)', 'value': 2},
    {'label': '৳৳৳ (Expensive)', 'value': 3},
    {'label': '৳৳৳৳ (Very Expensive)', 'value': 4},
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

      // Supabase filter (kept your logic exactly)
      final restaurantResponse = await _supabase
          .from('restaurants')
          .select()
          .textSearch('name', keyword)
          .limit(50);

      var filteredSupabase =
          List<Map<String, dynamic>>.from(restaurantResponse);

      if (_selectedCuisine.isNotEmpty) {
        filteredSupabase = filteredSupabase.where((r) {
          final tags = (r['tags'] as List?)?.cast<String>() ?? [];
          return tags.contains(_selectedCuisine);
        }).toList();
      }
      if (_selectedPriceLevel != null) {
        filteredSupabase = filteredSupabase
            .where((r) => r['price_level'] == _selectedPriceLevel)
            .toList();
      }

      // NOTE: No priceLevel parameter passed to places API unless your implementation supports it!
      final placesResults = await _placesService.searchNearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        keyword: keyword,
        cuisine: _selectedCuisine,
        // No openNow parameter, and don't send priceLevel unless your service supports it
        radius: _radius,
      );

      setState(() {
        _supabaseRestaurants = filteredSupabase;
        _placesRestaurants = placesResults;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during search: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final exists = _favoriteIds.contains(restaurantId);

    if (exists) {
      await _supabase
          .from('favorites')
          .delete()
          .match({'uid': uid, 'restaurant_id': restaurantId});
    } else {
      await _supabase
          .from('favorites')
          .insert({'uid': uid, 'restaurant_id': restaurantId});
    }

    await _loadFavorites();
  }

  Widget _buildFilters() {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: _filtersExpanded,
      builder: (context, expanded, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ExpansionTile(
              key: const PageStorageKey<String>('filters-tile'),
              initiallyExpanded: expanded,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: Row(
                children: const [
                  Icon(Icons.tune_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Filters',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              subtitle: Text(
                [
                  _selectedCuisine.isEmpty ? 'All cuisines' : _selectedCuisine,
                  '${_radius ~/ 1000} km',
                  (_selectedPriceLevel != null)
                      ? _priceOptions.firstWhere(
                          (p) => p['value'] == _selectedPriceLevel)['label']
                      : 'All prices'
                ].join(' • '),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              onExpansionChanged: (v) => _filtersExpanded.value = v,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCuisine,
                  decoration: InputDecoration(
                    labelText: 'Cuisine',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  isExpanded: true,
                  items: _cuisineOptions
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.isEmpty ? 'All' : c),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCuisine = v ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedPriceLevel,
                  decoration: InputDecoration(
                    labelText: 'Price Range',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  isExpanded: true,
                  items: _priceOptions
                      .map((option) => DropdownMenuItem<int>(
                            value: option['value'] as int?,
                            child: Text(option['label'] as String),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPriceLevel = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _radius,
                  decoration: InputDecoration(
                    labelText: 'Radius',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [1000, 2000, 3000, 5000]
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text('${r ~/ 1000} km'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _radius = v ?? 2000),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _filtersExpanded.value = false; // Collapse tile
                      _search(_searchController.text.trim());
                    },
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Apply Filters'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantSection(
    String title,
    List<Map<String, dynamic>> list, {
    bool fromSupabase = false,
  }) {
    if (list.isEmpty) return const SizedBox();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Icon(
                fromSupabase ? Icons.store_rounded : Icons.near_me_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final r = list[index];
            final id = fromSupabase ? r['id'] : r['place_id'] ?? r['name'];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: RestaurantCard(
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
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _filtersExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Restaurants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _search(_searchController.text.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name or keyword',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _search(_searchController.text.trim()),
                ),
                filled: true,
                fillColor:
                    cs.surfaceContainerHighest.withAlpha((0.22 * 255).toInt()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
          ),
          _buildFilters(),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Searching…'),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _buildRestaurantSection(
                    'Top Picks from App',
                    _supabaseRestaurants,
                    fromSupabase: true,
                  ),
                  _buildRestaurantSection(
                    'Nearby Restaurants',
                    _placesRestaurants,
                  ),
                  if (!_isLoading &&
                      _supabaseRestaurants.isEmpty &&
                      _placesRestaurants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: Card(
                        elevation: 0,
                        color: cs.surfaceContainerHighest
                            .withAlpha((0.45 * 255).toInt()),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
                          child: Row(
                            children: [
                              Icon(Icons.search_off_rounded),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No results yet. Try another keyword or adjust your filters.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
