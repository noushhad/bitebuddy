import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:bitebuddy/widgets/logout_button.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _notificationsReady = false;

  int reservationsToday = 0;
  double avgRating = 0.0;
  List<Map<String, dynamic>> upcomingReservations = [];

  @override
  void initState() {
    super.initState();
    _initOwnerNotifications();
    _loadDashboardData();
  }

  Future<void> _initOwnerNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize('cc41662b-1795-432b-9ced-8f69d487a56a');
      await OneSignal.Notifications.requestPermission(true);
      await OneSignal.User.pushSubscription.optIn();

      final rows = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', user.id)
          .limit(1);

      String? restaurantId;
      if (rows.isNotEmpty && rows.first['id'] != null) {
        restaurantId = rows.first['id'].toString();
      }

      await OneSignal.login(user.id);
      await OneSignal.User.addTags({"user_type": "owner"});

      if (restaurantId != null && restaurantId.isNotEmpty) {
        await OneSignal.User.addTags({"restaurant_id": restaurantId});
      } else {
        await OneSignal.User.removeTags(["restaurant_id"]);
      }

      if (mounted) setState(() => _notificationsReady = true);
    } catch (e) {
      debugPrint('Owner OneSignal init failed: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final restaurantRows = await _supabase
        .from('restaurants')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1);

    if (restaurantRows.isEmpty) return;
    final restaurantId = restaurantRows.first['id'];

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final resRows = await _supabase
        .from('reservations')
        .select('*')
        .eq('restaurant_id', restaurantId)
        .eq('date', todayStr);

    final reviewsRows = await _supabase
        .from('reviews')
        .select('rating')
        .eq('restaurant_id', restaurantId);

    double totalRating = 0;
    for (var r in reviewsRows) {
      totalRating += r['rating'] ?? 0;
    }

    final allUpcoming = await _supabase
        .from('reservations')
        .select('*')
        .eq('restaurant_id', restaurantId)
        .order('date', ascending: true);

    upcomingReservations = allUpcoming.take(5).toList();

    setState(() {
      reservationsToday = resRows.length;
      avgRating = reviewsRows.isNotEmpty ? totalRating / reviewsRows.length : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/owner/reservations'),
            icon: const Icon(Icons.event_note),
            label: const Text('Reservations'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(Icons.feed),
            label: const Text('Feed'),
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
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Restaurant Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/owner/restaurantDetails');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Manager Profile'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Promotion'),
              onTap: () => Navigator.pushNamed(context, '/owner/addPost'),
            ),
            ListTile(
              leading: const Icon(Icons.menu),
              title: const Text('Edit Menu'),
              onTap: () => Navigator.pushNamed(context, '/owner/menu'),
            ),
            const Divider(),
            const LogoutButton(),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DashboardCard(
                  title: 'Reservations Today',
                  value: reservationsToday.toString(),
                  icon: Icons.event,
                ),
                _DashboardCard(
                  title: 'Avg Rating',
                  value: avgRating.toStringAsFixed(1),
                  icon: Icons.star,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Upcoming Reservations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: upcomingReservations.length,
                itemBuilder: (context, index) {
                  final r = upcomingReservations[index];
                  final guestCount = r['guests'] ?? 1;
                  final date = r['date'] ?? '';
                  final time = r['time'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$guestCount Guests',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Date: $date'),
                          Text('Time: $time'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _ActionButton(
                    title: 'Edit Menu', icon: Icons.menu, route: '/owner/menu'),
                _ActionButton(
                    title: 'Add Promotion',
                    icon: Icons.add,
                    route: '/owner/addPost'),
                _ActionButton(
                    title: 'View Feed', icon: Icons.feed, route: '/feed'),
                _ActionButton(
                    title: 'Restaurant Details',
                    icon: Icons.store,
                    route: '/owner/restaurantDetails'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _DashboardCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.deepOrange),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title, route;
  final IconData icon;
  const _ActionButton(
      {required this.title, required this.icon, required this.route});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    );
  }
}
