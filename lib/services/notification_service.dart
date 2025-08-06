// // lib/services/notification_service.dart
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/material.dart';

// class NotificationService {
//   static final _firebaseMessaging = FirebaseMessaging.instance;
//   static final _localNotifications = FlutterLocalNotificationsPlugin();

//   /// Call this on app startup
//   static Future<void> initialize(BuildContext context) async {
//     // Request permissions
//     await _firebaseMessaging.requestPermission();

//     // Init local notifications
//     const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosInit = DarwinInitializationSettings();
//     const initSettings =
//         InitializationSettings(android: androidInit, iOS: iosInit);

//     await _localNotifications.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (response) {
//         // Handle notification tap
//         debugPrint('Notification tapped: ${response.payload}');
//       },
//     );

//     // Foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       final notification = message.notification;
//       if (notification != null) {
//         _showLocalNotification(notification);
//       }
//     });

//     // Get and print the FCM token (use for testing or Firestore storage)
//     final token = await _firebaseMessaging.getToken();
//     debugPrint('FCM Token: $token');
//   }

//   static Future<void> _showLocalNotification(
//       RemoteNotification notification) async {
//     const androidDetails = AndroidNotificationDetails(
//       'channel_id',
//       'BiteBuddy Notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//     const iosDetails = DarwinNotificationDetails();
//     const details =
//         NotificationDetails(android: androidDetails, iOS: iosDetails);

//     await _localNotifications.show(
//       notification.hashCode,
//       notification.title,
//       notification.body,
//       details,
//     );
//   }
// }
