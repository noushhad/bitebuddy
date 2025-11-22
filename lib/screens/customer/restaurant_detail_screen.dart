// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:bitebuddy/screens/customer/reservation_screen.dart';
// import 'package:bitebuddy/widgets/review/review_form.dart';
// import 'package:bitebuddy/widgets/review/review_list.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:bitebuddy/screens/common/map_screen.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class RestaurantDetailScreen extends StatefulWidget {
//   final Map<String, dynamic> restaurant;

//   const RestaurantDetailScreen({super.key, required this.restaurant});

//   @override
//   State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
// }

// class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
//   final _supabase = Supabase.instance.client;

//   bool _isFavorite = false;
//   List<Map<String, dynamic>> _menuItems = [];

//   double? _avgRating;
//   int _ratingCount = 0;
//   String? _coverUrl;
//   String? _ownerContact;
//   int? _supabasePriceLevel; // at the top with your other fields

//   // Google Places details
//   List<String> _placePhotoUrls = [];
//   List<Map<String, dynamic>> _placeReviews = [];
//   String? _placePhone;
//   String? _placeWebsite;
//   int? _placePriceLevel;
//   String? _menuUrl;
//   double? _placeLat;
//   double? _placeLng;

//   bool get isSupabaseRestaurant => widget.restaurant.containsKey('owner_id');
//   String get restaurantId =>
//       widget.restaurant['id'] ?? widget.restaurant['place_id'] ?? '';

//   String get placeId =>
//       isSupabaseRestaurant ? '' : (widget.restaurant['place_id'] ?? '');

//   String formatTruncate(double value) {
//     final truncated = (value * 10).floor() / 10.0;
//     return truncated.toStringAsFixed(1);
//   }

//   String priceLabel(int? priceLevel) {
//     switch (priceLevel) {
//       case 0:
//         return '৳ (Free)';
//       case 1:
//         return '৳ (Inexpensive)';
//       case 2:
//         return '৳৳ (Moderate)';
//       case 3:
//         return '৳৳৳ (Expensive)';
//       case 4:
//         return '৳৳৳৳ (Very Expensive)';
//       default:
//         return 'No price info';
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (isSupabaseRestaurant) {
//       _loadMenu();
//       _loadAggregates();
//       _loadOwnerContact();
//     } else {
//       _loadRandomMenuImagesFromSupabase()
//           .then((_) => _fetchGooglePlaceDetails());
//     }
//     _checkFavorite();
//     _prepareCoverImage();
//   }

//   Future<List<String>> _listAllFilePaths(String bucket,
//       [String prefix = '']) async {
//     List<String> allPaths = [];
//     final items = await _supabase.storage.from(bucket).list(path: prefix);
//     for (final item in items) {
//       if (item.name.endsWith('/')) {
//         // It's a folder; recurse!
//         final subfolder = prefix.isEmpty ? item.name : '$prefix/${item.name}';
//         final subitems = await _listAllFilePaths(bucket, subfolder);
//         allPaths.addAll(subitems);
//       } else {
//         // It's a file!
//         final filePath = prefix.isEmpty ? item.name : '$prefix/${item.name}';
//         print('Found menu image file: $filePath'); // DEBUG
//         allPaths.add(filePath);
//       }
//     }
//     return allPaths;
//   }

//   Future<void> _loadRandomMenuImagesFromSupabase() async {
//     try {
//       final filePaths = await _listAllFilePaths('menu-images');
//       final realFiles = filePaths
//           .where((name) => name.contains('.') && !name.endsWith('/'))
//           .toList();
//       print('All found files: $realFiles'); // DEBUG
//       if (realFiles.isEmpty) return;
//       realFiles.shuffle();
//       final selected = realFiles.take(1).toList();
//       for (final path in selected) {
//         print('Random menu file selected: $path');
//       }
//       final urls = selected
//           .map((path) =>
//               _supabase.storage.from('menu-images').getPublicUrl(path))
//           .toList();

//       setState(() {
//         _placePhotoUrls = urls;
//       });
//       print('Menu image URLs: $_placePhotoUrls');
//     } catch (e) {
//       print('Failed to load random menu images from Supabase: $e');
//     }
//   }

//   String _publicUrl(String bucket, String path) {
//     if (path.startsWith('http://') || path.startsWith('https://')) {
//       return path;
//     }
//     return _supabase.storage.from(bucket).getPublicUrl(path);
//   }

//   String? _googlePlacesPhotoUrl(Map r, [int index = 0]) {
//     final photos = r['photos'];
//     if (photos is List && photos.isNotEmpty && index < photos.length) {
//       final ref = photos[index]['photo_reference'];
//       if (ref != null && ref.toString().isNotEmpty) {
//         const apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';
//         return 'https://maps.googleapis.com/maps/api/place/photo'
//             '?maxwidth=1200&photo_reference=$ref&key=$apiKey';
//       }
//     }
//     return null;
//   }

//   Future<void> _prepareCoverImage() async {
//     final r = widget.restaurant;
//     if (isSupabaseRestaurant) {
//       final dynamic raw = r['image_url'] ??
//           r['image_path'] ??
//           r['cover_image'] ??
//           r['imageUrl'];
//       if (raw != null) {
//         final path = raw.toString();
//         if (path.isNotEmpty) {
//           setState(() => _coverUrl = _publicUrl('restaurant-images', path));
//           return;
//         }
//       }
//       return;
//     } else {
//       if (_placePhotoUrls.isNotEmpty) {
//         setState(() => _coverUrl = _placePhotoUrls[0]);
//         return;
//       }
//       final url = _googlePlacesPhotoUrl(r);
//       if (url != null) setState(() => _coverUrl = url);
//     }
//   }

//   Future<void> _fetchGooglePlaceDetails() async {
//     final r = widget.restaurant;
//     final placeId = r['place_id'];
//     if (placeId == null) return;

//     const String apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';
//     final url = 'https://maps.googleapis.com/maps/api/place/details/json'
//         '?place_id=$placeId'
//         '&fields=name,photos,formatted_phone_number,website,price_level,reviews,editorial_summary,geometry'
//         '&key=$apiKey';

//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final detail = json.decode(response.body);
//       final result = detail['result'] ?? {};
//       final List photos = result['photos'] ?? [];
//       final List<String> photoUrls = List<String>.from(
//           _placePhotoUrls); // keep existing random images first

//       for (var i = 0; i < photos.length && i < 10; i++) {
//         final ref = photos[i]['photo_reference'];
//         if (ref != null) {
//           photoUrls.add(
//             'https://maps.googleapis.com/maps/api/place/photo'
//             '?maxwidth=1200&photo_reference=$ref&key=$apiKey',
//           );
//         }
//       }

//       final List placeReviews = result['reviews'] ?? [];
//       final List<Map<String, dynamic>> reviews = [];
//       for (var i = 0; i < placeReviews.length && i < 5; i++) {
//         reviews.add(Map<String, dynamic>.from(placeReviews[i]));
//       }
//       final location = result['geometry']?['location'];
//       setState(() {
//         _placePhotoUrls = photoUrls;
//         _placeReviews = reviews;
//         _placePhone = result['formatted_phone_number'];
//         _placeWebsite = result['website'];
//         _placePriceLevel = result['price_level'];
//         _menuUrl = result['menu'];
//         if (location != null) {
//           _placeLat = (location['lat'] as num?)?.toDouble();
//           _placeLng = (location['lng'] as num?)?.toDouble();
//         }
//         _coverUrl ??= photoUrls.isNotEmpty ? photoUrls[0] : null;
//       });
//       print('Combined menu + Place images: $_placePhotoUrls');
//     }
//   }

//   Future<void> _loadMenu() async {
//     if (!isSupabaseRestaurant) return;
//     final result = await _supabase
//         .from('menu_items')
//         .select('id, name, image_url')
//         .eq('restaurant_id', restaurantId)
//         .order('name', ascending: true);

//     final items = <Map<String, dynamic>>[];
//     for (final raw in result) {
//       final m = Map<String, dynamic>.from(raw);
//       final path = m['image_url'] as String?;
//       if (path != null && path.isNotEmpty) {
//         m['image_url'] = _publicUrl('menu-images', path);
//       }
//       items.add(m);
//     }
//     setState(() => _menuItems = items);
//   }

//   Future<void> _loadAggregates() async {
//     if (!isSupabaseRestaurant) return;
//     final row = await _supabase
//         .from('restaurants')
//         .select('rating, rating_count, price_level')
//         .eq('id', restaurantId)
//         .maybeSingle();

//     setState(() {
//       _avgRating = (row?['rating'] as num?)?.toDouble();
//       _ratingCount = (row?['rating_count'] as int?) ?? 0;
//       _supabasePriceLevel = row?['price_level'] as int?;
//     });
//   }

//   Future<void> _loadOwnerContact() async {
//     if (!isSupabaseRestaurant) return;
//     final ownerId = widget.restaurant['owner_id'];
//     if (ownerId == null) return;
//     final row = await _supabase
//         .from('users')
//         .select('contact')
//         .eq('uid', ownerId)
//         .maybeSingle();

//     setState(() {
//       _ownerContact = (row?['contact'] as String?)?.trim();
//     });
//   }

//   Future<void> _checkFavorite() async {
//     if (!isSupabaseRestaurant) return;
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;
//     final response = await _supabase
//         .from('favorites')
//         .select()
//         .eq('uid', uid)
//         .eq('restaurant_id', restaurantId);

//     setState(() {
//       _isFavorite = response.isNotEmpty;
//     });
//   }

//   void _toggleFavorite() async {
//     if (!isSupabaseRestaurant) return;
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;
//     if (_isFavorite) {
//       await _supabase
//           .from('favorites')
//           .delete()
//           .match({'uid': uid, 'restaurant_id': restaurantId});
//     } else {
//       await _supabase.from('favorites').insert({
//         'uid': uid,
//         'restaurant_id': restaurantId,
//       });
//     }
//     setState(() => _isFavorite = !_isFavorite);
//   }

//   void _makeReservation() {
//     if (isSupabaseRestaurant) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ReservationScreen(restaurantId: restaurantId),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text(
//                 'Reservations only available for BiteBuddy partner restaurants.')),
//       );
//     }
//   }

//   void _openMap() {
//     double? lat, lng;
//     String? name;

//     if (isSupabaseRestaurant) {
//       lat = widget.restaurant['latitude'] as double?;
//       lng = widget.restaurant['longitude'] as double?;
//       name = widget.restaurant['name'] as String?;
//     } else {
//       lat = _placeLat;
//       lng = _placeLng;
//       name = widget.restaurant['name'] as String?;
//     }

//     if (lat != null && lng != null) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => MapScreen(
//             destination: LatLng(lat!, lng!), // Use ! to assert non-null
//             title: name,
//             showRoute: true,
//           ),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Location not available')));
//     }
//   }

//   void _openGallery(List<String> urls, int initial) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ImageGalleryScreen(urls: urls, initialIndex: initial),
//       ),
//     );
//   }

//   Future<void> _launchDialer(String number) async {
//     final Uri uri = Uri(scheme: 'tel', path: number);
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri);
//     } else if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Could not open dialer')),
//       );
//     }
//   }

//   Widget _buildStars(double value) {
//     final full = value.floor();
//     final frac = value - full;
//     final hasHalf = frac >= 0.25 && frac < 0.75;
//     final empty = 5 - full - (hasHalf ? 1 : 0);

//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         for (int i = 0; i < full; i++)
//           const Icon(Icons.star, size: 18, color: Colors.orange),
//         if (hasHalf)
//           const Icon(Icons.star_half, size: 18, color: Colors.orange),
//         for (int i = 0; i < empty; i++)
//           const Icon(Icons.star_border, size: 18, color: Colors.orange),
//       ],
//     );
//   }

//   List<String> _extractTags(Map r) {
//     final t = r['tags'];
//     if (t == null) return const [];
//     if (t is List) {
//       return t
//           .map((e) => e?.toString() ?? '')
//           .map((s) => s.trim())
//           .where((s) => s.isNotEmpty)
//           .toList();
//     }
//     if (t is String) {
//       return t
//           .split(',')
//           .map((s) => s.trim())
//           .where((s) => s.isNotEmpty)
//           .toList();
//     }
//     return const [];
//   }

//   @override
//   Widget build(BuildContext context) {
//     final r = widget.restaurant;
//     final name = r['name'] ?? 'Unnamed';
//     final address = r['address'] ?? r['vicinity'] ?? 'Unknown';
//     final googleRating = (r['rating'] as num?)?.toDouble();
//     final menuUrls = _menuItems
//         .map<String?>((m) => (m['image_url'] as String?))
//         .where((u) => u != null && u.isNotEmpty)
//         .cast<String>()
//         .toList();
//     final tags = isSupabaseRestaurant ? _extractTags(r) : const <String>[];

//     final googleMenuUrl = _menuUrl ?? _placeWebsite;
//     final googlePhotos = _placePhotoUrls;
//     final googleReviews = _placeReviews;

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.orange,
//         title: Text(name),
//         actions: [
//           if (isSupabaseRestaurant)
//             IconButton(
//               icon: Icon(
//                 _isFavorite ? Icons.favorite : Icons.favorite_border,
//                 color: const Color.fromARGB(255, 230, 11, 11),
//               ),
//               onPressed: _toggleFavorite,
//             )
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           if (_coverUrl != null && _coverUrl!.isNotEmpty)
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.network(
//                 _coverUrl!,
//                 height: 200,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//                 errorBuilder: (_, __, ___) => Container(
//                   height: 200,
//                   color: Colors.grey.shade300,
//                   child: const Icon(Icons.broken_image),
//                 ),
//               ),
//             ),
//           const SizedBox(height: 20),
//           Text(name,
//               style:
//                   const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           // RATINGS
//           Row(
//             children: [
//               const Icon(Icons.thumb_up, size: 20, color: Colors.orange),
//               const SizedBox(width: 6),
//               if (isSupabaseRestaurant)
//                 (_avgRating != null && _ratingCount > 0)
//                     ? Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           _buildStars(_avgRating!),
//                           const SizedBox(width: 6),
//                           Text("${formatTruncate(_avgRating!)} ($_ratingCount)",
//                               style: const TextStyle(
//                                   fontSize: 13, color: Colors.black54)),
//                         ],
//                       )
//                     : const Text("No ratings yet",
//                         style: TextStyle(fontSize: 13, color: Colors.black54))
//               else
//                 (googleRating != null)
//                     ? Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           _buildStars(googleRating),
//                           const SizedBox(width: 6),
//                           Text(formatTruncate(googleRating),
//                               style: const TextStyle(
//                                   fontSize: 13, color: Colors.black54)),
//                         ],
//                       )
//                     : const Text("No ratings yet",
//                         style: TextStyle(fontSize: 13, color: Colors.black54)),
//             ],
//           ),

//           const SizedBox(height: 8),

// // LOCATION
//           Row(
//             children: [
//               const Icon(Icons.location_on, size: 20, color: Colors.orange),
//               const SizedBox(width: 6),
//               (address != null && address.isNotEmpty)
//                   ? Expanded(child: Text(address))
//                   : const Text("No location provided",
//                       style: TextStyle(fontSize: 14, color: Colors.black54)),
//             ],
//           ),

//           const SizedBox(height: 8),

// // PRICE RANGE
//           Row(
//             children: [
//               const Icon(Icons.attach_money, size: 20, color: Colors.orange),
//               const SizedBox(width: 6),
//               Text(
//                   priceLabel(isSupabaseRestaurant
//                       ? _supabasePriceLevel
//                       : _placePriceLevel),
//                   style: const TextStyle(fontSize: 15, color: Colors.black54)),
//             ],
//           ),

//           const SizedBox(height: 8),
//           // CONTACT / PHONE for both Place API and Supabase
//           Row(
//             children: [
//               const Icon(Icons.call, size: 20, color: Colors.orange),
//               const SizedBox(width: 6),
//               if (!isSupabaseRestaurant) ...[
//                 (_placePhone != null && _placePhone!.isNotEmpty)
//                     ? InkWell(
//                         onTap: () => _launchDialer(_placePhone!),
//                         child: Text(
//                           _placePhone!,
//                           style: const TextStyle(
//                               color: Colors.blue,
//                               decoration: TextDecoration.underline),
//                         ),
//                       )
//                     : const Text("No phone provided",
//                         style: TextStyle(fontSize: 14, color: Colors.black54)),
//               ] else ...[
//                 (_ownerContact != null && _ownerContact!.isNotEmpty)
//                     ? InkWell(
//                         onTap: () => _launchDialer(_ownerContact!),
//                         child: Text(
//                           _ownerContact!,
//                           style: const TextStyle(
//                               color: Colors.blue,
//                               decoration: TextDecoration.underline),
//                         ),
//                       )
//                     : const Text("No phone provided",
//                         style: TextStyle(fontSize: 14, color: Colors.black54)),
//               ]
//             ],
//           ),

//           const SizedBox(height: 8),

// // WEBSITE (only relevant for Place API)
//           // Row(
//           //   children: [
//           //     const Icon(Icons.language, size: 20, color: Colors.orange),
//           //     const SizedBox(width: 6),
//           //     (!isSupabaseRestaurant &&
//           //             _placeWebsite != null &&
//           //             _placeWebsite!.isNotEmpty)
//           //         ? InkWell(
//           //             onTap: () async {
//           //               final url = Uri.parse(_placeWebsite!);
//           //               if (await canLaunchUrl(url)) {
//           //                 await launchUrl(url);
//           //               }
//           //             },
//           //             child: Text(
//           //               _placeWebsite!,
//           //               style: const TextStyle(
//           //                   color: Colors.blue,
//           //                   decoration: TextDecoration.underline),
//           //             ),
//           //           )
//           //         : const Text("No website provided",
//           //             style: TextStyle(fontSize: 14, color: Colors.black54)),
//           //   ],
//           // ),
//           const SizedBox(height: 8),

// // DESCRIPTION
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Icon(Icons.info_outline, size: 20, color: Colors.orange),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: (r['description'] != null &&
//                         r['description'].toString().trim().isNotEmpty)
//                     ? Text(r['description'])
//                     : const Text("No description provided",
//                         style: TextStyle(fontSize: 14, color: Colors.black54)),
//               ),
//             ],
//           ),

//           const SizedBox(height: 16),

//           const SizedBox(height: 12),

//           if (tags.isNotEmpty) ...[
//             const Text('Cuisines',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: tags
//                   .map(
//                     (tag) => Chip(
//                       label: Text(tag),
//                       backgroundColor: Colors.orange.shade50,
//                       shape: StadiumBorder(
//                         side: BorderSide(color: Colors.orange.shade200),
//                       ),
//                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                     ),
//                   )
//                   .toList(),
//             ),
//             const SizedBox(height: 20),
//           ],

//           // Show random menu images loaded from Supabase + Place photos
//           if (_placePhotoUrls.isNotEmpty) ...[
//             const Text('Menu & Images',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 150,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _placePhotoUrls.length,
//                 separatorBuilder: (_, __) => const SizedBox(width: 12),
//                 itemBuilder: (_, index) {
//                   final url = _placePhotoUrls[index];
//                   return InkWell(
//                     onTap: () => _openGallery(_placePhotoUrls, index),
//                     child: SizedBox(
//                       width: 120,
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: Image.network(
//                           url,
//                           height: 100,
//                           width: 120,
//                           fit: BoxFit.cover,
//                           errorBuilder: (_, __, ___) => Container(
//                             height: 100,
//                             width: 120,
//                             color: Colors.grey.shade300,
//                             child: const Icon(Icons.broken_image),
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 20),
//           ],
//           // Add Directions for Place API results
//           if (!isSupabaseRestaurant) ...[
//             ElevatedButton.icon(
//               icon: const Icon(Icons.directions),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               label: const Text('Get Directions'),
//               onPressed: _openMap,
//             ),
//             Container(
//               width: double.infinity,
//               margin: const EdgeInsets.symmetric(vertical: 12.0),
//               padding: const EdgeInsets.all(16.0),
//               decoration: BoxDecoration(
//                 color: Colors.orange.shade100,
//                 borderRadius: BorderRadius.circular(8.0),
//               ),
//               child: const Text(
//                 "In-App Reservations available for BiteBuddy registered restaurants",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Color.fromARGB(255, 8, 8, 8),
//                 ),
//               ),
//             ),
//             if (_placeReviews.isNotEmpty) ...[
//               const Text(
//                 "Customer Reviews",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
//               Column(
//                   children: _placeReviews
//                       .map((rev) => Card(
//                             margin: const EdgeInsets.symmetric(vertical: 4),
//                             child: ListTile(
//                               leading: rev['profile_photo_url'] != null
//                                   ? CircleAvatar(
//                                       backgroundImage: NetworkImage(
//                                           rev['profile_photo_url']))
//                                   : null,
//                               title: Text(rev['author_name'] ?? ''),
//                               subtitle: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       _buildStars(
//                                           (rev['rating'] as num?)?.toDouble() ??
//                                               0),
//                                       const SizedBox(width: 8),
//                                       if (rev['relative_time_description'] !=
//                                           null)
//                                         Text(
//                                           rev['relative_time_description'],
//                                           style: const TextStyle(
//                                               fontSize: 12, color: Colors.grey),
//                                         )
//                                     ],
//                                   ),
//                                   if (rev['text'] != null)
//                                     Padding(
//                                       padding: const EdgeInsets.only(top: 4.0),
//                                       child: Text(rev['text']),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ))
//                       .toList()),
//               const SizedBox(height: 20),
//             ],

//             // In-App Reviews for Place API places
//             ReviewForm(
//               restaurantId: null,
//               placeId: placeId.isNotEmpty ? placeId : null,
//               onSubmitted: _fetchGooglePlaceDetails,
//             ),
//             const SizedBox(height: 20),
//             const Text("User Reviews",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             ReviewList(placeId: placeId.isNotEmpty ? placeId : null),
//           ],

//           // Supabase restaurant sections unchanged
//           if (isSupabaseRestaurant) ...[
//             const Text('Menu & Images',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             if (_menuItems.isEmpty)
//               const Text('No menu or image items available.')
//             else
//               SizedBox(
//                 height: 150,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: _menuItems.length,
//                   separatorBuilder: (_, __) => const SizedBox(width: 12),
//                   itemBuilder: (context, index) {
//                     final item = _menuItems[index];
//                     final url = item['image_url'] as String?;
//                     final title = (item['name'] as String?) ?? '';
//                     if (url == null || url.isEmpty)
//                       return const SizedBox.shrink();
//                     return InkWell(
//                       onTap: () => _openGallery(menuUrls, index),
//                       child: SizedBox(
//                         width: 120,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.network(
//                                 url,
//                                 height: 100,
//                                 width: 120,
//                                 fit: BoxFit.cover,
//                                 errorBuilder: (_, __, ___) => Container(
//                                   height: 100,
//                                   width: 120,
//                                   color: Colors.grey.shade300,
//                                   child: const Icon(Icons.broken_image),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               title,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(fontSize: 13),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.book_online),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               label: const Text('Make Reservation'),
//               onPressed: _makeReservation,
//             ),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.directions),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               label: const Text('Get Directions'),
//               onPressed: _openMap,
//             ),
//             const SizedBox(height: 30),
//             ReviewForm(
//               restaurantId: restaurantId,
//               placeId: null,
//               onSubmitted: _loadAggregates,
//             ),
//             const SizedBox(height: 20),
//             const Text("Customer Reviews",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             ReviewList(restaurantId: restaurantId, placeId: null),
//           ],
//         ],
//       ),
//     );
//   }
// }

// // The ImageGalleryScreen class remains unchanged

// /// GALLERY SCREEN REMAINS AS YOU HAD IT

// // For completeness here is ImageGalleryScreen unchanged:
// class ImageGalleryScreen extends StatefulWidget {
//   final List<String> urls;
//   final int initialIndex;

//   const ImageGalleryScreen({
//     super.key,
//     required this.urls,
//     this.initialIndex = 0,
//   });

//   @override
//   State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
// }

// class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
//   late final PageController _controller =
//       PageController(initialPage: widget.initialIndex);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.orange,
//         title: Text('Menu (${widget.initialIndex + 1}/${widget.urls.length})'),
//       ),
//       backgroundColor: Colors.black,
//       body: PageView.builder(
//         controller: _controller,
//         itemCount: widget.urls.length,
//         itemBuilder: (_, index) {
//           final url = widget.urls[index];
//           return Center(
//             child: InteractiveViewer(
//               minScale: 0.8,
//               maxScale: 4.0,
//               child: Image.network(
//                 url,
//                 fit: BoxFit.contain,
//                 errorBuilder: (_, __, ___) => const Icon(
//                   Icons.broken_image,
//                   size: 64,
//                   color: Colors.white70,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitebuddy/screens/customer/reservation_screen.dart';
import 'package:bitebuddy/widgets/review/review_form.dart';
import 'package:bitebuddy/widgets/review/review_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bitebuddy/screens/common/map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bitebuddy/services/foodpanda_menu_service.dart'; // ✅ Changed: Use Foodpanda instead

class RestaurantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _supabase = Supabase.instance.client;

  // ✅ Changed: Use only Foodpanda service
  late final FoodpandaMenuService _foodpandaService = FoodpandaMenuService();

  bool _isFavorite = false;
  List<Map<String, dynamic>> _menuItems = [];

  double? _avgRating;
  int _ratingCount = 0;
  String? _coverUrl;
  String? _ownerContact;
  int? _subabasePriceLevel;

  // Google Places details
  List<String> _placePhotoUrls = [];
  List<Map<String, dynamic>> _placeReviews = [];
  String? _placePhone;
  String? _placeWebsite;
  int? _placePriceLevel;
  String? _menuUrl;
  double? _placeLat;
  double? _placeLng;

  // ✅ Changed: Foodpanda menu items instead of scraped
  List<FoodpandaMenuItem> _foodpandaMenuItems = [];
  bool _isLoadingMenu = false;

  bool get isSupabaseRestaurant => widget.restaurant.containsKey('owner_id');
  String get restaurantId =>
      widget.restaurant['id'] ?? widget.restaurant['place_id'] ?? '';

  String get placeId =>
      isSupabaseRestaurant ? '' : (widget.restaurant['place_id'] ?? '');

  String formatTruncate(double value) {
    final truncated = (value * 10).floor() / 10.0;
    return truncated.toStringAsFixed(1);
  }

  String priceLabel(int? priceLevel) {
    switch (priceLevel) {
      case 0:
        return '৳ (Free)';
      case 1:
        return '৳ (Inexpensive)';
      case 2:
        return '৳৳ (Moderate)';
      case 3:
        return '৳৳৳ (Expensive)';
      case 4:
        return '৳৳৳৳ (Very Expensive)';
      default:
        return 'No price info';
    }
  }

  @override
  void initState() {
    super.initState();
    if (isSupabaseRestaurant) {
      _loadMenu();
      _loadAggregates();
      _loadOwnerContact();
    } else {
      _loadRandomMenuImagesFromSupabase()
          .then((_) => _fetchGooglePlaceDetailsWithFoodpanda());
    }
    _checkFavorite();
    _prepareCoverImage();
  }

  // ✅ Changed: Fetch Google Places + Foodpanda menu
  Future<void> _fetchGooglePlaceDetailsWithFoodpanda() async {
    await _fetchGooglePlaceDetails();

    // Fetch from Foodpanda using restaurant name
    final restaurantName = widget.restaurant['name'] ?? '';
    if (restaurantName.isNotEmpty) {
      await _fetchFoodpandaMenu(restaurantName);
    }
  }

  // ✅ New: Fetch menu from Foodpanda
  Future<void> _fetchFoodpandaMenu(String restaurantName) async {
    setState(() => _isLoadingMenu = true);

    try {
      // Search for restaurant on Foodpanda
      final fpRestaurant = await _foodpandaService.getFoodpandaRestaurant(
        restaurantName,
        city: 'Dhaka', // ✅ Can make this dynamic based on user location
      );

      if (fpRestaurant != null) {
        debugPrint('✅ Found on Foodpanda: ${fpRestaurant.name}');
        
        // Scrape menu from Foodpanda
        final items = await _foodpandaService.scrapeFoodpandaMenu(
          fpRestaurant.url,
        );

        setState(() {
          _foodpandaMenuItems = items;
        });

        debugPrint('✅ Scraped ${items.length} items from Foodpanda');
      } else {
        debugPrint('⚠️ Restaurant not found on Foodpanda');
      }
    } catch (e) {
      debugPrint('❌ Foodpanda scraping error: $e');
    } finally {
      setState(() => _isLoadingMenu = false);
    }
  }

  Future<List<String>> _listAllFilePaths(String bucket,
      [String prefix = '']) async {
    List<String> allPaths = [];
    final items = await _supabase.storage.from(bucket).list(path: prefix);
    for (final item in items) {
      if (item.name.endsWith('/')) {
        final subfolder = prefix.isEmpty ? item.name : '$prefix/${item.name}';
        final subitems = await _listAllFilePaths(bucket, subfolder);
        allPaths.addAll(subitems);
      } else {
        final filePath = prefix.isEmpty ? item.name : '$prefix/${item.name}';
        debugPrint('Found menu image file: $filePath');
        allPaths.add(filePath);
      }
    }
    return allPaths;
  }

  Future<void> _loadRandomMenuImagesFromSupabase() async {
    try {
      final filePaths = await _listAllFilePaths('menu-images');
      final realFiles = filePaths
          .where((name) => name.contains('.') && !name.endsWith('/'))
          .toList();
      debugPrint('All found files: $realFiles');
      if (realFiles.isEmpty) return;
      realFiles.shuffle();
      final selected = realFiles.take(1).toList();
      for (final path in selected) {
        debugPrint('Random menu file selected: $path');
      }
      final urls = selected
          .map((path) =>
              _supabase.storage.from('menu-images').getPublicUrl(path))
          .toList();

      setState(() {
        _placePhotoUrls = urls;
      });
      debugPrint('Menu image URLs: $_placePhotoUrls');
    } catch (e) {
      debugPrint('Failed to load random menu images from Supabase: $e');
    }
  }

  String _publicUrl(String bucket, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  String? _googlePlacesPhotoUrl(Map r, [int index = 0]) {
    final photos = r['photos'];
    if (photos is List && photos.isNotEmpty && index < photos.length) {
      final ref = photos[index]['photo_reference'];
      if (ref != null && ref.toString().isNotEmpty) {
        const apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';
        return 'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=1200&photo_reference=$ref&key=$apiKey';
      }
    }
    return null;
  }

  Future<void> _prepareCoverImage() async {
    final r = widget.restaurant;
    if (isSupabaseRestaurant) {
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
      if (_placePhotoUrls.isNotEmpty) {
        setState(() => _coverUrl = _placePhotoUrls[0]);
        return;
      }
      final url = _googlePlacesPhotoUrl(r);
      if (url != null) setState(() => _coverUrl = url);
    }
  }

  Future<void> _fetchGooglePlaceDetails() async {
    final r = widget.restaurant;
    final placeId = r['place_id'];
    if (placeId == null) return;

    const String apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,photos,formatted_phone_number,website,price_level,reviews,editorial_summary,geometry'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final detail = json.decode(response.body);
      final result = detail['result'] ?? {};
      final List photos = result['photos'] ?? [];
      final List<String> photoUrls = List<String>.from(_placePhotoUrls);

      for (var i = 0; i < photos.length && i < 10; i++) {
        final ref = photos[i]['photo_reference'];
        if (ref != null) {
          photoUrls.add(
            'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=1200&photo_reference=$ref&key=$apiKey',
          );
        }
      }

      final List placeReviews = result['reviews'] ?? [];
      final List<Map<String, dynamic>> reviews = [];
      for (var i = 0; i < placeReviews.length && i < 5; i++) {
        reviews.add(Map<String, dynamic>.from(placeReviews[i]));
      }
      final location = result['geometry']?['location'];
      setState(() {
        _placePhotoUrls = photoUrls;
        _placeReviews = reviews;
        _placePhone = result['formatted_phone_number'];
        _placeWebsite = result['website'];
        _menuUrl = result['menu'];
        if (location != null) {
          _placeLat = (location['lat'] as num?)?.toDouble();
          _placeLng = (location['lng'] as num?)?.toDouble();
        }
        _coverUrl ??= photoUrls.isNotEmpty ? photoUrls[0] : null;
      });
      debugPrint('Combined menu + Place images: $_placePhotoUrls');
    }
  }

  Future<void> _loadMenu() async {
    if (!isSupabaseRestaurant) return;
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
        m['image_url'] = _publicUrl('menu-images', path);
      }
      items.add(m);
    }
    setState(() => _menuItems = items);
  }

  Future<void> _loadAggregates() async {
    if (!isSupabaseRestaurant) return;
    final row = await _supabase
        .from('restaurants')
        .select('rating, rating_count, price_level')
        .eq('id', restaurantId)
        .maybeSingle();

    setState(() {
      _avgRating = (row?['rating'] as num?)?.toDouble();
      _ratingCount = (row?['rating_count'] as int?) ?? 0;
      _subabasePriceLevel = row?['price_level'] as int?;
    });
  }

  Future<void> _loadOwnerContact() async {
    if (!isSupabaseRestaurant) return;
    final ownerId = widget.restaurant['owner_id'];
    if (ownerId == null) return;
    final row = await _supabase
        .from('users')
        .select('contact')
        .eq('uid', ownerId)
        .maybeSingle();

    setState(() {
      _ownerContact = (row?['contact'] as String?)?.trim();
    });
  }

  Future<void> _checkFavorite() async {
    if (!isSupabaseRestaurant) return;
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

  void _toggleFavorite() async {
    if (!isSupabaseRestaurant) return;
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

  void _openMap() {
    double? lat, lng;
    String? name;

    if (isSupabaseRestaurant) {
      lat = widget.restaurant['latitude'] as double?;
      lng = widget.restaurant['longitude'] as double?;
      name = widget.restaurant['name'] as String?;
    } else {
      lat = _placeLat;
      lng = _placeLng;
      name = widget.restaurant['name'] as String?;
    }

    if (lat != null && lng != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(
            destination: LatLng(lat!, lng!),
            title: name,
            showRoute: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available')));
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

  Future<void> _launchDialer(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  Widget _buildStars(double value) {
    final full = value.floor();
    final frac = value - full;
    final hasHalf = frac >= 0.25 && frac < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          const Icon(Icons.star, size: 18, color: Colors.orange),
        if (hasHalf)
          const Icon(Icons.star_half, size: 18, color: Colors.orange),
        for (int i = 0; i < empty; i++)
          const Icon(Icons.star_border, size: 18, color: Colors.orange),
      ],
    );
  }

  List<String> _extractTags(Map r) {
    final t = r['tags'];
    if (t == null) return const [];
    if (t is List) {
      return t
          .map((e) => e?.toString() ?? '')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (t is String) {
      return t
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  // ✅ Changed: Display Foodpanda menu items instead of scraped website
  Widget _buildFoodpandaMenuSection() {
    if (_foodpandaMenuItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.store, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              '🍕 Foodpanda Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foodpandaMenuItems.length,
          itemBuilder: (context, index) {
            final item = _foodpandaMenuItems[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (item.category.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        item.price,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: item.imageUrl.isNotEmpty
                    ? SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final name = r['name'] ?? 'Unnamed';
    final address = r['address'] ?? r['vicinity'] ?? 'Unknown';
    final googleRating = (r['rating'] as num?)?.toDouble();
    final menuUrls = _menuItems
        .map<String?>((m) => (m['image_url'] as String?))
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    final tags = isSupabaseRestaurant ? _extractTags(r) : const <String>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(name),
        actions: [
          if (isSupabaseRestaurant)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: const Color.fromARGB(255, 230, 11, 11),
              ),
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
          // RATINGS
          Row(
            children: [
              const Icon(Icons.thumb_up, size: 20, color: Colors.orange),
              const SizedBox(width: 6),
              if (isSupabaseRestaurant)
                (_avgRating != null && _ratingCount > 0)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStars(_avgRating!),
                          const SizedBox(width: 6),
                          Text("${formatTruncate(_avgRating!)} ($_ratingCount)",
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                        ],
                      )
                    : const Text("No ratings yet",
                        style: TextStyle(fontSize: 13, color: Colors.black54))
              else
                (googleRating != null)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStars(googleRating),
                          const SizedBox(width: 6),
                          Text(formatTruncate(googleRating),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                        ],
                      )
                    : const Text("No ratings yet",
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          // LOCATION
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.orange),
              const SizedBox(width: 6),
              (address != null && address.isNotEmpty)
                  ? Expanded(child: Text(address))
                  : const Text("No location provided",
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          // PRICE RANGE
          Row(
            children: [
              const Icon(Icons.attach_money, size: 20, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                  priceLabel(isSupabaseRestaurant
                      ? _subabasePriceLevel
                      : _placePriceLevel),
                  style: const TextStyle(fontSize: 15, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          // CONTACT / PHONE
          Row(
            children: [
              const Icon(Icons.call, size: 20, color: Colors.orange),
              const SizedBox(width: 6),
              if (!isSupabaseRestaurant) ...[
                (_placePhone != null && _placePhone!.isNotEmpty)
                    ? InkWell(
                        onTap: () => _launchDialer(_placePhone!),
                        child: Text(
                          _placePhone!,
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
                      )
                    : const Text("No phone provided",
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
              ] else ...[
                (_ownerContact != null && _ownerContact!.isNotEmpty)
                    ? InkWell(
                        onTap: () => _launchDialer(_ownerContact!),
                        child: Text(
                          _ownerContact!,
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
                      )
                    : const Text("No phone provided",
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
              ]
            ],
          ),
          const SizedBox(height: 8),
          // DESCRIPTION
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 20, color: Colors.orange),
              const SizedBox(width: 6),
              Expanded(
                child: (r['description'] != null &&
                        r['description'].toString().trim().isNotEmpty)
                    ? Text(r['description'])
                    : const Text("No description provided",
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tags.isNotEmpty) ...[
            const Text('Cuisines',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.orange.shade50,
                      shape: StadiumBorder(
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          // Show random menu images loaded from Supabase + Place photos
          if (_placePhotoUrls.isNotEmpty) ...[
            const Text('Menu & Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _placePhotoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final url = _placePhotoUrls[index];
                  return InkWell(
                    onTap: () => _openGallery(_placePhotoUrls, index),
                    child: SizedBox(
                      width: 120,
                      child: ClipRRect(
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          // ✅ Changed: Show Foodpanda menu items (removed webscraping)
          if (_isLoadingMenu)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _buildFoodpandaMenuSection(),
          // Add Directions for Place API results
          if (!isSupabaseRestaurant) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.directions),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              label: const Text('Get Directions'),
              onPressed: _openMap,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                "In-App Reservations available for BiteBuddy registered restaurants",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 8, 8, 8),
                ),
              ),
            ),
            if (_placeReviews.isNotEmpty) ...[
              const Text(
                "Customer Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Column(
                  children: _placeReviews
                      .map((rev) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: rev['profile_photo_url'] != null
                                  ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                          rev['profile_photo_url']))
                                  : null,
                              title: Text(rev['author_name'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildStars(
                                          (rev['rating'] as num?)?.toDouble() ??
                                              0),
                                      const SizedBox(width: 8),
                                      if (rev['relative_time_description'] !=
                                          null)
                                        Text(
                                          rev['relative_time_description'],
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        )
                                    ],
                                  ),
                                  if (rev['text'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(rev['text']),
                                    ),
                                ],
                              ),
                            ),
                          ))
                      .toList()),
              const SizedBox(height: 20),
            ],
            // In-App Reviews for Place API places
            ReviewForm(
              restaurantId: null,
              placeId: placeId.isNotEmpty ? placeId : null,
              onSubmitted: _fetchGooglePlaceDetails,
            ),
            const SizedBox(height: 20),
            const Text("User Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ReviewList(placeId: placeId.isNotEmpty ? placeId : null),
          ],
          // Supabase restaurant sections
          if (isSupabaseRestaurant) ...[
            const Text('Menu & Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_menuItems.isEmpty)
              const Text('No menu or image items available.')
            else
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.book_online),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              label: const Text('Make Reservation'),
              onPressed: _makeReservation,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              label: const Text('Get Directions'),
              onPressed: _openMap,
            ),
            const SizedBox(height: 30),
            ReviewForm(
              restaurantId: restaurantId,
              placeId: null,
              onSubmitted: _loadAggregates,
            ),
            const SizedBox(height: 20),
            const Text("Customer Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ReviewList(restaurantId: restaurantId, placeId: null),
          ],
        ],
      ),
    );
  }
}

// ImageGalleryScreen
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
        backgroundColor: Colors.orange,
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