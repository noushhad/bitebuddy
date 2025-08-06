// lib/router/app_routes.dart
import 'package:flutter/material.dart';
import '../screens/customer/reservation_screen.dart';
import '../screens/owner/location_picker_screen.dart';

class AppRoutes {
  static const String reservation = '/customer/reserve';
  static const String pickLocation = '/pick-location';

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case reservation:
        final args = settings.arguments as Map<String, dynamic>?;
        final restaurantId = args?['restaurantId'];
        if (restaurantId == null) {
          return _errorRoute("Missing restaurant ID");
        }
        return MaterialPageRoute(
          builder: (_) => ReservationScreen(restaurantId: restaurantId),
        );

      case pickLocation:
        return MaterialPageRoute(
          builder: (_) => const LocationPickerScreen(),
        );

      default:
        return _errorRoute("Route not found");
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
