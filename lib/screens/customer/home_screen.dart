import 'package:flutter/material.dart';
import '../../widgets/logout_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BiteBuddy – Home"),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome, Food Lover! 🍔"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/map'),
              child: const Text("Find Restaurants on Map"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/favorites'),
              child: const Text("View Favorites ❤️"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/reservations'),
              child: const Text("My Reservations 📅"),
            ),
          ],
        ),
      ),
    );
  }
}
