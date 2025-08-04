import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/restaurant_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final favoriteIds = List<String>.from(userDoc.data()?['favorites'] ?? []);

    List<Map<String, dynamic>> results = [];
    for (String id in favoriteIds) {
      final doc = await _firestore.collection('restaurants').doc(id).get();
      if (doc.exists) {
        results.add({'id': doc.id, ...doc.data()!});
      }
    }

    setState(() {
      _favorites = results;
      _isLoading = false;
    });
  }

  void _toggleFavorite(String restaurantId) async {
    final uid = _auth.currentUser?.uid;
    final userRef = _firestore.collection('users').doc(uid);

    final userDoc = await userRef.get();
    final favorites = List<String>.from(userDoc.data()?['favorites'] ?? []);

    if (favorites.contains(restaurantId)) {
      await userRef.update({
        'favorites': FieldValue.arrayRemove([restaurantId])
      });
    } else {
      await userRef.update({
        'favorites': FieldValue.arrayUnion([restaurantId])
      });
    }

    _loadFavorites(); // refresh
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
                      imageUrl: r['imageUrl'] ?? '',
                      isFavorite: true,
                      onTap: () {
                        // Optionally: navigate to restaurant details
                      },
                      onFavoriteToggle: () => _toggleFavorite(r['id']),
                    );
                  },
                ),
    );
  }
}
