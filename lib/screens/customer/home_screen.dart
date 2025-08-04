import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/preferences_popup.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _checkAndPromptPreferences(context));
  }

  Future<void> _checkAndPromptPreferences(BuildContext context) async {
    final uid = _auth.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = userDoc.data();
    if (data != null && !(data['preferencesSet'] ?? false)) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PreferencesPopup(
          onSubmit: (prefs) async {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({
              'preferences': prefs,
              'preferencesSet': true,
            });
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null, // ❌ Removed welcome text
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search,
                color: Color.fromARGB(255, 13, 13, 13)),
            label: const Text('Search',
                style: TextStyle(color: Color.fromARGB(255, 10, 10, 10))),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications,
                color: Color.fromARGB(255, 14, 14, 14)),
            label: const Text('Alerts',
                style: TextStyle(color: Color.fromARGB(255, 4, 4, 4))),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(Icons.feed, color: Color.fromARGB(255, 7, 7, 7)),
            label: const Text('Feed',
                style: TextStyle(color: Color.fromARGB(255, 11, 11, 11))),
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
                'BiteBuddy',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile & Contact'),
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Preferences'),
              onTap: () {
                Navigator.pushNamed(context, '/preferences');
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pushNamed(context, '/favorites');
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              // child: Text('Logout', style: TextStyle(fontSize: 16)),
            ),
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
