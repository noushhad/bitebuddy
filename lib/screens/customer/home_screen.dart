import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/logout_button.dart';
import '../../services/notification_service.dart'; // <-- add this

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _notificationsReady = false;

  @override
  void initState() {
    super.initState();
    _initNotifications(); // <-- add this
  }

  Future<void> _initNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await NotificationService.instance.init(
        oneSignalAppId: 'cc41662b-1795-432b-9ced-8f69d487a56a', // <-- replace
        userId: user.id,
        loadFavoriteRestaurantIds: () async {
          final rows = await _supabase
              .from('favorites')
              .select('restaurant_id')
              .eq('user_id', user.id);
          return rows.map<String>((r) => r['restaurant_id'].toString()).toSet();
        },
        nearbyRadiusKm: 3.0,
      );

      setState(() => _notificationsReady = true);
    } catch (e) {
      // Optional: surface a silent error or log
      debugPrint('Notification init failed: $e');
    }
  }

  /// Call this after user toggles a favorite anywhere in the app.
  Future<void> refreshFavoriteTags() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final rows = await _supabase
        .from('favorites')
        .select('restaurant_id')
        .eq('user_id', user.id);
    await NotificationService.instance.refreshFavoriteTags(
      rows.map<String>((r) => r['restaurant_id'].toString()).toSet(),
    );
  }

  @override
  void dispose() {
    // Clean up Realtime channels when leaving the screen
    NotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search, color: Colors.black),
            label: const Text('Search', style: TextStyle(color: Colors.black)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications, color: Colors.black),
            label: const Text('Alerts', style: TextStyle(color: Colors.black)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(Icons.feed, color: Colors.black),
            label: const Text('Feed', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text('BiteBuddy',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your personalized restaurant feed will appear here!',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_notificationsReady)
              const Text('🔔 Notifications active',
                  style: TextStyle(fontSize: 12))
            else
              const Text('…initializing notifications',
                  style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
