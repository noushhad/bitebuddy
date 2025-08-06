import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/logout_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Removed preference popup logic
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
      body: const Center(
        child: Text(
          'Your personalized restaurant feed will appear here!',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
