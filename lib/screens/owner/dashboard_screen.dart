import 'package:flutter/material.dart';
import '../../widgets/logout_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BiteBuddy – Owner Dashboard"),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome, Restaurant Owner 👨‍🍳"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/menu_editor'),
              child: const Text("Edit Menu 📋"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/reservations_confirm'),
              child: const Text("Manage Reservations ✅"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/promotions'),
              child: const Text("Add Promotions 💥"),
            ),
          ],
        ),
      ),
    );
  }
}
