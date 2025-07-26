import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/customer/home_screen.dart';
import 'screens/owner/dashboard_screen.dart';

import 'services/auth_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return MaterialApp(
      title: 'BiteBuddy',
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/customer/home': (_) => const HomeScreen(),
        '/owner/dashboard': (_) => const DashboardScreen(),
        // Add more routes here as needed
      },
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!userSnapshot.hasData) {
            return const LoginScreen();
          }

          return FutureBuilder<UserModel?>(
            future: _authService.getUserDetails(userSnapshot.data!.uid),
            builder: (context, modelSnapshot) {
              if (!modelSnapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final userModel = modelSnapshot.data!;
              if (userModel.userType == 'customer') {
                return const HomeScreen();
              } else {
                return const DashboardScreen();
              }
            },
          );
        },
      ),
    );
  }
}
