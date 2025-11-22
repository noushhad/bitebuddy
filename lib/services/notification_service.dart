// // lib/services/notification_service.dart
// import 'dart:async';
// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class NotificationService {
//   NotificationService._();
//   static final NotificationService instance = NotificationService._();

//   final _sb = Supabase.instance.client;

//   final FlutterLocalNotificationsPlugin _local =
//       FlutterLocalNotificationsPlugin();

//   RealtimeChannel? _resSub;
//   RealtimeChannel? _postSub;
//   RealtimeChannel? _restoSub;

//   bool _initialized = false;
//   String? _userId;
//   Set<String> _favoriteIds = {};

//   Future<void> init({
//     required String oneSignalAppId,
//     required String userId,
//     Future<Set<String>> Function()? loadFavoriteRestaurantIds,
//     double nearbyRadiusKm = 3.0,
//   }) async {
//     if (_initialized) return;
//     _userId = userId;

//     // Local notifications
//     const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosInit = DarwinInitializationSettings();
//     await _local.initialize(const InitializationSettings(
//       android: androidInit,
//       iOS: iosInit,
//     ));

//     // OneSignal
//     OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
//     OneSignal.initialize(oneSignalAppId);
//     OneSignal.Notifications.requestPermission(true);
//     await OneSignal.login(userId);
//     OneSignal.Notifications.addForegroundWillDisplayListener((_) {});
//     OneSignal.Notifications.addClickListener((e) {
//       debugPrint('Notification opened: ${e.notification.title}');
//     });

//     // Favorites → OneSignal tags
//     if (loadFavoriteRestaurantIds != null) {
//       _favoriteIds = await loadFavoriteRestaurantIds();
//     } else {
//       try {
//         final rows = await _sb
//             .from('favorites')
//             .select('restaurant_id')
//             .eq('uid', userId);
//         _favoriteIds =
//             rows.map<String>((r) => r['restaurant_id'].toString()).toSet();
//       } catch (_) {
//         _favoriteIds = {};
//       }
//     }
//     await _syncFavoriteTags(_favoriteIds);

//     // Foreground realtime listeners
//     _listenReservationStatus(userId); // reservations.user_id
//     _listenFavoritePosts(); // posts.restaurant_id
//     await _listenNewRestaurantsNearby(nearbyRadiusKm);

//     _initialized = true;
//   }

//   Future<void> refreshFavoriteTags(Set<String> newFavoriteIds) async {
//     _favoriteIds = newFavoriteIds;
//     await _syncFavoriteTags(newFavoriteIds);
//   }

//   Future<void> dispose() async {
//     await _resSub?.unsubscribe();
//     await _postSub?.unsubscribe();
//     await _restoSub?.unsubscribe();
//     _resSub = null;
//     _postSub = null;
//     _restoSub = null;
//     _initialized = false;
//   }

//   // ---- private ----
//   Future<void> _syncFavoriteTags(Set<String> favs) async {
//     final tags = await OneSignal.User.getTags();
//     final existing = tags ?? const <String, String>{};
//     final keysToRemove =
//         existing.keys.where((k) => k.startsWith('fav_')).toList();
//     if (keysToRemove.isNotEmpty) {
//       await OneSignal.User.removeTags(keysToRemove);
//     }
//     if (favs.isNotEmpty) {
//       await OneSignal.User.addTags({for (final id in favs) 'fav_$id': 'true'});
//     }
//   }

//   void _listenReservationStatus(String userId) {
//     _resSub = _sb.channel('reservations-status-$userId')
//       ..onPostgresChanges(
//         event: PostgresChangeEvent.update,
//         schema: 'public',
//         table: 'reservations',
//         filter: PostgresChangeFilter(
//           type: PostgresChangeFilterType.eq,
//           column: 'user_id',
//           value: userId,
//         ),
//         callback: (payload) async {
//           final record = payload.newRecord;
//           final old = payload.oldRecord;
//           if (record == null) return;
//           final status = record['status']?.toString();
//           final prev = old?['status']?.toString();
//           if (status != null && status != prev) {
//             final title = status == 'confirmed'
//                 ? 'Reservation Confirmed'
//                 : status == 'rejected'
//                     ? 'Reservation Rejected'
//                     : 'Reservation Updated';
//             final body = status == 'confirmed'
//                 ? 'Your reservation is confirmed.'
//                 : status == 'rejected'
//                     ? 'Sorry, your reservation was rejected.'
//                     : 'Your reservation status changed to $status.';
//             await _showLocal(
//               title: title,
//               body: body,
//               payload: {
//                 'type': 'reservation',
//                 'reservation_id': record['id']?.toString() ?? '',
//               },
//             );
//           }
//         },
//       )
//       ..subscribe();
//   }

//   /// Listen to new posts; notify if restaurant_id ∈ favorites
//   void _listenFavoritePosts() {
//     _postSub = _sb.channel('posts-stream')
//       ..onPostgresChanges(
//         event: PostgresChangeEvent.insert,
//         schema: 'public',
//         table: 'posts',
//         callback: (payload) async {
//           final record = payload.newRecord;
//           if (record == null) return;
//           final restaurantId = record['restaurant_id']?.toString();
//           if (restaurantId == null) return;
//           if (_favoriteIds.contains(restaurantId)) {
//             final title = record['title']?.toString() ?? 'New post';
//             await _showLocal(
//               title: title,
//               body: 'New update from one of your favorites.',
//               payload: {
//                 'type': 'post',
//                 'post_id': record['id']?.toString() ?? '',
//                 'restaurant_id': restaurantId,
//               },
//             );
//           }
//         },
//       )
//       ..subscribe();
//   }

//   Future<void> _listenNewRestaurantsNearby(double radiusKm) async {
//     try {
//       final ok = await _ensureLocationPermission();
//       if (!ok) return;
//     } catch (_) {
//       return;
//     }
//     Position? pos;
//     try {
//       pos = await Geolocator.getCurrentPosition();
//     } catch (_) {
//       return;
//     }
//     if (pos == null) return;

//     final lat = pos.latitude;
//     final lng = pos.longitude;

//     _restoSub = _sb.channel('restaurants-nearby')
//       ..onPostgresChanges(
//         event: PostgresChangeEvent.insert,
//         schema: 'public',
//         table: 'restaurants',
//         callback: (payload) async {
//           final r = payload.newRecord;
//           if (r == null) return;
//           final rLat = (r['latitude'] as num?)?.toDouble();
//           final rLng = (r['longitude'] as num?)?.toDouble();
//           if (rLat == null || rLng == null) return;
//           final dKm = _haversineKm(lat, lng, rLat, rLng);
//           if (dKm <= radiusKm) {
//             final name = (r['name']?.toString() ?? '').trim();
//             final label = name.isEmpty ? 'A new restaurant' : name;
//             await _showLocal(
//               title: 'New restaurant nearby',
//               body: '$label just opened • ${dKm.toStringAsFixed(1)} km away.',
//               payload: {
//                 'type': 'new_restaurant',
//                 'restaurant_id': r['id']?.toString() ?? '',
//               },
//             );
//           }
//         },
//       )
//       ..subscribe();
//   }

//   Future<void> _showLocal({
//     required String title,
//     required String body,
//     Map<String, String>? payload,
//   }) async {
//     final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
//     const android = AndroidNotificationDetails(
//       'bb_foreground',
//       'BiteBuddy Alerts',
//       channelDescription: 'Foreground notifications for BiteBuddy',
//       importance: Importance.high,
//       priority: Priority.high,
//       enableVibration: true,
//     );
//     const ios = DarwinNotificationDetails();
//     await _local.show(
//       id,
//       title,
//       body,
//       const NotificationDetails(android: android, iOS: ios),
//       payload: payload == null
//           ? null
//           : payload.entries.map((e) => '${e.key}=${e.value}').join('&'),
//     );
//   }

//   // utils
//   double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371.0;
//     final dLat = _deg2rad(lat2 - lat1);
//     final dLon = _deg2rad(lon2 - lon1);
//     final a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(_deg2rad(lat1)) *
//             cos(_deg2rad(lat2)) *
//             sin(dLon / 2) *
//             sin(dLon / 2);
//     final c = 2 * atan2(sqrt(1 - a), sqrt(a));
//     return R * c;
//   }

//   double _deg2rad(double deg) => deg * (pi / 180.0);

//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission == LocationPermission.whileInUse ||
//         permission == LocationPermission.always;
//   }
// }

// lib/services/notification_service.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _sb = Supabase.instance.client;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _resSub;
  RealtimeChannel? _postSub;
  RealtimeChannel? _restoSub;

  bool _initialized = false;
  Set<String> _favoriteIds = {};

  Future<void> init({
    required String oneSignalAppId,
    required String userId,
    Future<Set<String>> Function()? loadFavoriteRestaurantIds,
    double nearbyRadiusKm = 3.0,
  }) async {
    if (_initialized) return;

    try {
      // ✅ FIX 1: Local notifications initialization
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _local.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Local notification tapped: ${response.payload}');
        },
      );

      // ✅ FIX 2: Enable verbose logging for debugging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // ✅ FIX 3: Initialize OneSignal BEFORE requesting permission
      OneSignal.initialize(oneSignalAppId);

      // ✅ FIX 4: Request permission ASYNCHRONOUSLY and check result
      final permissionResult =
          await OneSignal.Notifications.requestPermission(true);
      if (permissionResult == null || !permissionResult) {
        debugPrint(
            '⚠️ OneSignal: Notification permission denied or not granted');
      } else {
        debugPrint('✅ OneSignal: Notification permission granted');
      }

      // ✅ FIX 5: Login user AFTER initialization and permission
      if (userId.isNotEmpty) {
        await OneSignal.login(userId);
        debugPrint('✅ OneSignal: User logged in ($userId)');
      }

      // ✅ FIX 6: Foreground listener - DISPLAY notification, don't block it
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // ✅ CRITICAL: Don't call preventDefault() - it blocks notifications
        debugPrint(
            '📬 Foreground notification received: ${event.notification.title}');
      });

      // ✅ FIX 7: Click listener
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('👆 Notification opened: ${event.notification.title}');
        final data = event.notification.additionalData;
        if (data != null) {
          _handleNotificationRoute(data);
        }
      });

      // ✅ FIX 8: Favorites → OneSignal tags with error handling
      if (loadFavoriteRestaurantIds != null) {
        _favoriteIds = await loadFavoriteRestaurantIds();
      } else {
        try {
          final rows = await _sb
              .from('favorites')
              .select('restaurant_id')
              .eq('uid', userId);

          _favoriteIds =
              rows.map<String>((r) => r['restaurant_id'].toString()).toSet();
          debugPrint('✅ Loaded ${_favoriteIds.length} favorite restaurants');
        } catch (e) {
          debugPrint('⚠️ Failed to load favorites: $e');
          _favoriteIds = {};
        }
      }

      // ✅ FIX 9: Sync favorites with OneSignal tags
      await _syncFavoriteTags(_favoriteIds);

      // ✅ FIX 10: Subscribe to realtime listeners
      _listenReservationStatus(userId);
      _listenFavoritePosts();
      await _listenNewRestaurantsNearby(nearbyRadiusKm);

      _initialized = true;
      debugPrint('✅ NotificationService fully initialized');
    } catch (e) {
      debugPrint('❌ NotificationService init failed: $e');
      _initialized = false;
    }
  }

  Future<void> refreshFavoriteTags(Set<String> newFavoriteIds) async {
    _favoriteIds = newFavoriteIds;
    await _syncFavoriteTags(newFavoriteIds);
    debugPrint(
        '✅ Favorite tags refreshed (${newFavoriteIds.length} favorites)');
  }

  Future<void> dispose() async {
    try {
      await _resSub?.unsubscribe();
      await _postSub?.unsubscribe();
      await _restoSub?.unsubscribe();
    } catch (e) {
      debugPrint('⚠️ Error unsubscribing: $e');
    }
    _resSub = null;
    _postSub = null;
    _restoSub = null;
    _initialized = false;
    debugPrint('✅ NotificationService disposed');
  }

  // ---- private ----

  // ✅ FIX 11: Error handling in tag sync
  Future<void> _syncFavoriteTags(Set<String> favs) async {
    try {
      final tags = await OneSignal.User.getTags();
      final existing = tags ?? const <String, String>{};

      // Remove old favorite tags
      final keysToRemove =
          existing.keys.where((k) => k.startsWith('fav_')).toList();
      if (keysToRemove.isNotEmpty) {
        await OneSignal.User.removeTags(keysToRemove);
        debugPrint('✅ Removed ${keysToRemove.length} old favorite tags');
      }

      // Add new favorite tags
      if (favs.isNotEmpty) {
        await OneSignal.User.addTags(
            {for (final id in favs) 'fav_$id': 'true'});
        debugPrint('✅ Added ${favs.length} new favorite tags');
      }
    } catch (e) {
      debugPrint('❌ Tag sync failed: $e');
    }
  }

  // ✅ FIX 12: Reservation listener with detailed error handling
  void _listenReservationStatus(String userId) {
    try {
      _resSub = _sb.channel('reservations-status-$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              final record = payload.newRecord;
              final old = payload.oldRecord;
              if (record == null) return;

              final status = record['status']?.toString();
              final prev = old?['status']?.toString();

              if (status != null && status != prev) {
                final title = status == 'confirmed'
                    ? 'Reservation Confirmed'
                    : status == 'rejected'
                        ? 'Reservation Rejected'
                        : 'Reservation Updated';

                final body = status == 'confirmed'
                    ? 'Your reservation is confirmed.'
                    : status == 'rejected'
                        ? 'Sorry, your reservation was rejected.'
                        : 'Your reservation status changed to $status.';

                await _showLocal(
                  title: title,
                  body: body,
                  payload: {
                    'type': 'reservation',
                    'reservation_id': record['id']?.toString() ?? '',
                  },
                );
              }
            } catch (e) {
              debugPrint('❌ Reservation listener callback error: $e');
            }
          },
        )
        ..subscribe();
      debugPrint('✅ Subscribed to reservation updates');
    } catch (e) {
      debugPrint('❌ Reservation listener setup failed: $e');
    }
  }

  // ✅ FIX 13: Posts listener with error handling
  void _listenFavoritePosts() {
    try {
      _postSub = _sb.channel('posts-stream')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) async {
            try {
              final record = payload.newRecord;
              if (record == null) return;

              final restaurantId = record['restaurant_id']?.toString();
              if (restaurantId?.isEmpty != false) return;

              if (_favoriteIds.contains(restaurantId)) {
                final title = record['title']?.toString() ?? 'New post';
                await _showLocal(
                  title: title,
                  body: 'New update from one of your favorites.',
                  payload: {
                    'type': 'post',
                    'post_id': record['id']?.toString() ?? '',
                    'restaurant_id': restaurantId ?? '',
                  },
                );
              }
            } catch (e) {
              debugPrint('❌ Posts listener callback error: $e');
            }
          },
        )
        ..subscribe();
      debugPrint('✅ Subscribed to favorite posts');
    } catch (e) {
      debugPrint('❌ Posts listener setup failed: $e');
    }
  }

  // ✅ FIX 14: Nearby restaurants listener with location handling
  Future<void> _listenNewRestaurantsNearby(double radiusKm) async {
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        debugPrint(
            '⚠️ Location permission denied. Nearby restaurant notifications disabled.');
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('⚠️ Failed to get current position: $e');
        return;
      }

      if (pos == null) {
        debugPrint('⚠️ Current position is null');
        return;
      }

      final lat = pos.latitude;
      final lng = pos.longitude;

      _restoSub = _sb.channel('restaurants-nearby')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'restaurants',
          callback: (payload) async {
            try {
              final r = payload.newRecord;
              if (r == null) return;

              final rLat = (r['latitude'] as num?)?.toDouble();
              final rLng = (r['longitude'] as num?)?.toDouble();
              if (rLat == null || rLng == null) return;

              final dKm = _haversineKm(lat, lng, rLat, rLng);
              if (dKm <= radiusKm) {
                final name = (r['name']?.toString() ?? '').trim();
                final label = name.isEmpty ? 'A new restaurant' : name;

                await _showLocal(
                  title: 'New restaurant nearby',
                  body:
                      '$label just opened • ${dKm.toStringAsFixed(1)} km away.',
                  payload: {
                    'type': 'new_restaurant',
                    'restaurant_id': r['id']?.toString() ?? '',
                  },
                );
              }
            } catch (e) {
              debugPrint('❌ Nearby restaurants callback error: $e');
            }
          },
        )
        ..subscribe();
      debugPrint('✅ Subscribed to nearby restaurants within ${radiusKm}km');
    } catch (e) {
      debugPrint('❌ Nearby restaurants setup failed: $e');
    }
  }

  // ✅ FIX 15: Local notification display with channel setup
  // ✅ FIX: Changed color from int (0xFF2196F3) to Color
  Future<void> _showLocal({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final android = AndroidNotificationDetails(
        'bb_foreground',
        'BiteBuddy Alerts',
        channelDescription: 'Foreground notifications for BiteBuddy',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        color: const Color(0xFF2196F3),
      );

      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _local.show(
        id,
        title,
        body,
        NotificationDetails(android: android, iOS: ios),
        payload: payload == null
            ? null
            : payload.entries.map((e) => '${e.key}=${e.value}').join('&'),
      );

      debugPrint('✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Failed to show local notification: $e');
    }
  }

  // ✅ FIX 16: Handle notification routing
  void _handleNotificationRoute(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString();
      final restaurantId = data['restaurant_id']?.toString();

      debugPrint('📍 Notification route: type=$type, rid=$restaurantId');

      // You can add navigation logic here if needed
    } catch (e) {
      debugPrint('⚠️ Notification route error: $e');
    }
  }

  // ---- Utils ----

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ Location services disabled');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final granted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!granted) {
      debugPrint('⚠️ Location permission not granted: $permission');
    }

    return granted;
  }
}
