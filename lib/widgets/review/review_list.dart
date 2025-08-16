import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewList extends StatefulWidget {
  /// MUST be the Supabase restaurants.id (UUID), not a Google place_id.
  final String restaurantId;
  const ReviewList({super.key, required this.restaurantId});

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  final _supabase = Supabase.instance.client;

  RealtimeChannel? _channel;
  Future<List<Map<String, dynamic>>>? _future;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _supabase.channel('reviews-restaurant-${widget.restaurantId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (_) {
            setState(() => _future = _load());
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    setState(() => _error = null);
    try {
      // 1) Load reviews (no join)
      final rows = await _supabase
          .from('reviews')
          .select('id, rating, review_text, created_at, customer_id')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      final reviews = List<Map<String, dynamic>>.from(rows);

      // 2) Collect unique customer ids
      final ids = reviews
          .map((r) => r['customer_id'])
          .where((v) => v != null && (v as String).isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      // 3) Fetch user names in one batch (using inFilter for older SDKs)
      final Map<String, String> nameByUid = {};
      if (ids.isNotEmpty) {
        final users = await _supabase
            .from('users')
            .select('uid, name')
            .inFilter('uid', ids); // <- use inFilter instead of in_()

        for (final u in users) {
          final uid = u['uid'] as String?;
          final name = (u['name'] as String?)?.trim();
          if (uid != null) {
            nameByUid[uid] =
                (name == null || name.isEmpty) ? 'Anonymous' : name;
          }
        }
      }

      // 4) Attach writerName to each review
      for (final r in reviews) {
        final uid = r['customer_id'] as String?;
        r['writer_name'] =
            uid != null ? (nameByUid[uid] ?? 'Anonymous') : 'Anonymous';
      }

      return reviews;
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
      return [];
    } catch (e) {
      setState(() => _error = e.toString());
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Couldn’t load reviews: $_error",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final reviews = snap.data ?? const [];
        if (reviews.isEmpty) return const Text("No reviews yet.");

        return Column(
          children: reviews.map((review) {
            final rating = (review['rating'] as num?)?.toInt() ?? 0;
            final name = (review['writer_name'] as String?) ?? 'Anonymous';
            final date =
                review['created_at']?.toString().split('T').first ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        rating.clamp(0, 5),
                        (_) => const Icon(Icons.star,
                            size: 16, color: Colors.amber),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (review['review_text'] ?? '').toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                subtitle: Text("By $name"),
                trailing: Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
