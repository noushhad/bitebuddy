// lib/screens/customer/notifications_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _posts = [];
  List<_NearbyRestaurant> _nearby = [];

  final double _nearbyRadiusKm = 4.0;
  final int _recentDays = 7;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not signed in.');
      }

      // 1) Reservations for this user
      final resRows = await _sb
          .from('reservations')
          .select('id, status, date, time, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _reservations = (resRows as List).cast<Map<String, dynamic>>();

      // 2) Posts from favorite restaurants
      List<Map<String, dynamic>> posts = [];
      try {
        final favRows = await _sb
            .from('favorites')
            .select('restaurant_id')
            .eq('uid', userId);
        final favIds = (favRows as List)
            .map((e) => e['restaurant_id']?.toString())
            .whereType<String>()
            .toSet();

        if (favIds.isNotEmpty) {
          final postRows = await _sb
              .from('posts')
              .select('id, title, image_url, created_at, restaurant_id')
              .inFilter('restaurant_id', favIds.toList())
              .order('created_at', ascending: false);
          posts = (postRows as List).cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('Posts query failed: $e');
      }
      _posts = posts;

      // 3) New restaurants nearby
      Position? pos;
      try {
        final ok = await _ensureLocationPermission();
        if (ok) pos = await Geolocator.getCurrentPosition();
      } catch (_) {}
      _nearby = [];
      if (pos != null) {
        final sinceIso = DateTime.now()
            .subtract(Duration(days: _recentDays))
            .toUtc()
            .toIso8601String();

        final restRows = await _sb
            .from('restaurants')
            .select('id, name, latitude, longitude, updated_at')
            .gte('updated_at', sinceIso)
            .order('updated_at', ascending: false)
            .limit(100);

        final List<_NearbyRestaurant> candidates = [];
        for (final r in (restRows as List)) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lng = (r['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final dKm = _haversineKm(pos.latitude, pos.longitude, lat, lng);
          if (dKm <= _nearbyRadiusKm) {
            candidates.add(
              _NearbyRestaurant(
                id: r['id']?.toString() ?? '',
                name: (r['name']?.toString() ?? '').trim().isEmpty
                    ? 'New restaurant'
                    : r['name'].toString(),
                distanceKm: dKm,
                updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
              ),
            );
          }
        }
        candidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        _nearby = candidates;
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    children: [
                      _SectionHeader(
                        icon: Icons.event_available,
                        title: 'Reservation updates',
                      ),
                      if (_reservations.isEmpty)
                        const _EmptyRow(text: 'No reservation updates yet.')
                      else
                        ..._reservations.map(_buildReservationTile),
                      const Divider(height: 24),
                      _SectionHeader(
                        icon: Icons.campaign,
                        title: 'Updates from favorites',
                      ),
                      if (_posts.isEmpty)
                        const _EmptyRow(
                            text:
                                'No new posts from your favorite restaurants.')
                      else
                        ..._posts.map(_buildPostTile),
                      const Divider(height: 24),
                      _SectionHeader(
                        icon: Icons.location_on,
                        title: 'New restaurants nearby',
                      ),
                      if (_nearby.isEmpty)
                        _EmptyRow(
                            text:
                                'No new places within ~${_nearbyRadiusKm.toStringAsFixed(0)} km in the last $_recentDays days.')
                      else
                        ..._nearby.map(_buildNearbyTile),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  // Tiles
  Widget _buildReservationTile(Map<String, dynamic> r) {
    final status = (r['status']?.toString() ?? '').toLowerCase();
    final title = status == 'confirmed'
        ? 'Reservation Confirmed'
        : status == 'rejected'
            ? 'Reservation Rejected'
            : 'Reservation Updated';
    final sub = [
      if ((r['date'] ?? '').toString().isNotEmpty) 'Date: ${r['date']}',
      if ((r['time'] ?? '').toString().isNotEmpty) 'Time: ${r['time']}',
      'Status: ${r['status'] ?? '-'}',
    ].join(' • ');
    final icon = status == 'confirmed'
        ? Icons.check_circle
        : status == 'rejected'
            ? Icons.cancel
            : Icons.info;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(sub),
      trailing: _whenText(r['created_at']),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> p) {
    final String? raw = p['image_url']?.toString();
    final String? thumbUrl = _postImageUrl(raw);

    return ListTile(
      leading: thumbUrl == null
          ? const Icon(Icons.campaign)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                thumbUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.campaign),
              ),
            ),
      title: Text(p['title']?.toString() ?? 'New update'),
      subtitle: const Text('From one of your favorite restaurants'),
      trailing: _whenText(p['created_at']),
      onTap: () {
        // TODO: navigate to post/restaurant detail if you want
      },
    );
  }

  Widget _buildNearbyTile(_NearbyRestaurant n) {
    return ListTile(
      leading: const Icon(Icons.restaurant),
      title: Text(n.name),
      subtitle: Text('${n.distanceKm.toStringAsFixed(1)} km away'),
      trailing: _whenText(n.updatedAt?.toIso8601String()),
    );
  }

  // Helpers
  Widget _whenText(dynamic iso) {
    if (iso == null) return const SizedBox.shrink();
    DateTime? dt;
    if (iso is String) dt = DateTime.tryParse(iso);
    if (iso is DateTime) dt = iso;
    if (dt == null) return const SizedBox.shrink();
    return Text(_friendlyTime(dt),
        style: const TextStyle(fontSize: 12, color: Colors.grey));
  }

  String _friendlyTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lat2 - lat1 == 0 ? 0 : (lon2 - lon1));
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin((lon2 - lon1) * pi / 360) *
            sin((lon2 - lon1) * pi / 360);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  /// If image_url is full URL, return as-is; if path, build public URL from post-images bucket.
  String? _postImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final v = imageUrl.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    try {
      return _sb.storage.from('post-images').getPublicUrl(v);
    } catch (_) {
      return null;
    }
  }
}

// small widgets
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title, super.key});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow({required this.text, super.key});
  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(text, style: const TextStyle(color: Colors.grey)));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _NearbyRestaurant {
  final String id;
  final String name;
  final double distanceKm;
  final DateTime? updatedAt;
  _NearbyRestaurant({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.updatedAt,
  });
}
