import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/customer/home_screen.dart';
import 'screens/owner/dashboard_screen.dart';
import 'screens/customer/favorites_screen.dart';
import 'screens/owner/reservation_confirm_screen.dart';
import 'screens/owner/menu_editor_screen.dart';
import 'screens/common/search_screen.dart';
import 'screens/common/preferences_screen.dart';
import 'screens/customer/profile_screen.dart';
import 'screens/owner/add_post_screen.dart';
import 'screens/common/feed_screen.dart';
import 'screens/owner/restaurant_details_form.dart';
import 'screens/customer/reservation_screen.dart';
import 'screens/owner/location_picker_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://bspvqggydpudjqbzislf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzcHZxZ2d5ZHB1ZGpxYnppc2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjEyNDUsImV4cCI6MjA2OTg5NzI0NX0.y0f7ukMaEIerJpMA8QZEbnMVBuSKw2GV2x-fe-2dr4s',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiteBuddy',
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/customer/home': (_) => const HomeScreen(),
        '/owner/dashboard': (_) => const OwnerDashboardScreen(),
        '/favorites': (_) => const FavoritesScreen(),
        '/owner/reservations': (_) => const ReservationConfirmScreen(),
        '/owner/menu': (_) => const MenuEditorScreen(),
        '/owner/addPost': (_) => const AddPostScreen(),
        '/search': (_) => const SearchScreen(),
        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/preferences': (_) => const PreferencesScreen(),
        '/owner/restaurantDetails': (_) => const RestaurantDetailsForm(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/customer/reserve') {
          final restaurantId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ReservationScreen(restaurantId: restaurantId),
          );
        }

        if (settings.name == '/pick-location') {
          return MaterialPageRoute(
            builder: (_) => const LocationPickerScreen(),
          );
        }

        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
      },
      home: const SupabaseAuthListener(),
    );
  }
}

class SupabaseAuthListener extends StatefulWidget {
  const SupabaseAuthListener({super.key});

  @override
  State<SupabaseAuthListener> createState() => _SupabaseAuthListenerState();
}

class _SupabaseAuthListenerState extends State<SupabaseAuthListener> {
  final client = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final session = client.auth.currentSession;
    final user = session?.user;

    if (user == null) {
      return const LoginScreen();
    }

    return FutureBuilder(
      future: client.from('users').select().eq('uid', user.id).maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data as Map<String, dynamic>?;
        final userType = userData?['user_type'];

        if (userType == 'owner') {
          return const OwnerDashboardScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
