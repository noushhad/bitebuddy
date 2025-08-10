import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitebuddy/screens/owner/restaurant_details_form.dart';

import '../../widgets/logout_button.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

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
              child: Text('Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
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
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () => Navigator.pushNamed(context, '/favorites'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Preferences'),
              onTap: () => Navigator.pushNamed(context, '/preferences'),
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
