import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'screens/customer/notifications_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initOneSignal() async {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose); // optional
  OneSignal.initialize('cc4'); // <- replace

  await OneSignal.Notifications.requestPermission(true);

  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid != null) {
    OneSignal.login(uid);
  }

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    // default behavior (no preventDefault) shows heads-up
  });

  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData ?? {};
    final route = data['route'] as String?;
    if (route != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(route);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bspvqggydpudjqbzislf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzcHZxZ2d5ZHB1ZGpxYnppc2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjEyNDUsImV4cCI6MjA2OTg5NzI0NX0.y0f7ukMaEIerJpMA8QZEbnMVBuSKw2GV2x-fe-2dr4s',
  );

  await initOneSignal();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiteBuddy',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color.fromARGB(255, 198, 210, 24), // pick your brand color
  ),
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
        '/notifications': (context) => const NotificationsScreen(),
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

        if (settings.name == '/customer/reservations') {
          // replace with your customer's reservations screen if you add one
          return MaterialPageRoute(builder: (_) => const HomeScreen());
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
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = client.auth.onAuthStateChange.listen((state) {
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        OneSignal.login(uid);
      } else {
        OneSignal.logout();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading profile: ${snapshot.error}'),
            ),
          );
        }

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
