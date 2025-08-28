import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:bitebuddy/screens/owner/restaurant_details_form.dart';
import '../../widgets/logout_button.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _notificationsReady = false;

  @override
  void initState() {
    super.initState();
    _initOwnerNotifications();
  }

  Future<void> _initOwnerNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1) Initialize OneSignal (same App ID as customer side)
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize('cc41662b-1795-432b-9ced-8f69d487a56a');

      // 2) Request permission (iOS/Android 13+)
      await OneSignal.Notifications.requestPermission(true);

      // 3) Ensure subscription is opted-in
      await OneSignal.User.pushSubscription.optIn();

      // 4) Load the owner’s restaurant_id (adjust if your schema differs)
      final rows = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', user.id)
          .limit(1);

      String? restaurantId;
      if (rows.isNotEmpty && rows.first['id'] != null) {
        restaurantId = rows.first['id'].toString();
      }

      // 5) Log this device into OneSignal as the owner and tag it
      await OneSignal.login(user.id);

      // Add required tags using 5.x API
      await OneSignal.User.addTags({"user_type": "owner"});

      if (restaurantId != null && restaurantId.isNotEmpty) {
        await OneSignal.User.addTags({"restaurant_id": restaurantId});
      } else {
        // Clear stale tag if no restaurant found / switching roles
        await OneSignal.User.removeTags(["restaurant_id"]);
      }

      if (mounted) setState(() => _notificationsReady = true);
    } catch (e) {
      debugPrint('Owner OneSignal init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/owner/reservations'),
            icon: const Icon(Icons.event_note),
            label: const Text('Reservations'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(Icons.feed),
            label: const Text('Feed'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Restaurant Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/owner/restaurantDetails');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Manager Profile'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Promotion'),
              onTap: () => Navigator.pushNamed(context, '/owner/addPost'),
            ),
            ListTile(
              leading: const Icon(Icons.menu),
              title: const Text('Edit Menu'),
              onTap: () => Navigator.pushNamed(context, '/owner/menu'),
            ),
            const Divider(),
            const LogoutButton(),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome to your Dashboard!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
