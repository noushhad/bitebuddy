import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isFavorite = false;
  List<Map<String, dynamic>> _menuItems = [];

  bool get isFirestoreRestaurant => widget.restaurant.containsKey('ownerId');
  String get restaurantId =>
      widget.restaurant['id'] ?? widget.restaurant['place_id'] ?? '';

  @override
  void initState() {
    super.initState();
    if (isFirestoreRestaurant) _loadMenu();
    _checkFavorite();
  }

  Future<void> _loadMenu() async {
    final query = await _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
        .get();

    setState(() {
      _menuItems = query.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _checkFavorite() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final favs = List<String>.from(doc['favorites'] ?? []);
    setState(() {
      _isFavorite = favs.contains(restaurantId);
    });
  }

  Future<void> _toggleFavorite() async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection('users').doc(uid);
    await ref.update({
      'favorites': _isFavorite
          ? FieldValue.arrayRemove([restaurantId])
          : FieldValue.arrayUnion([restaurantId])
    });
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _makeReservation() {
    // You can replace this with actual reservation screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reservation feature coming soon!')),
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
          if (isFirestoreRestaurant) ...[
            const Text('Menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_menuItems.isEmpty)
              const Text('No menu items available.')
            else
              ..._menuItems.map((item) => ListTile(
                    leading: item['imageUrl'] != null
                        ? Image.network(item['imageUrl'],
                            width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.fastfood),
                    title: Text(item['name'] ?? ''),
                    subtitle: Text(item['description'] ?? ''),
                    trailing: Text('\$${item['price'].toString()}'),
                  )),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.book_online),
              label: const Text('Make Reservation'),
              onPressed: _makeReservation,
            ),
          ],
        ],
      ),
    );
  }
}
