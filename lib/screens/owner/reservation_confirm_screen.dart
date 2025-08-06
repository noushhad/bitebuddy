import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationConfirmScreen extends StatefulWidget {
  const ReservationConfirmScreen({super.key});

  @override
  State<ReservationConfirmScreen> createState() =>
      _ReservationConfirmScreenState();
}

class _ReservationConfirmScreenState extends State<ReservationConfirmScreen> {
  final _supabase = Supabase.instance.client;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _loadRestaurantId();
  }

  Future<void> _loadRestaurantId() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final response = await _supabase
        .from('restaurants')
        .select('id')
        .eq('owner_id', uid)
        .maybeSingle();

    if (response != null && response['id'] != null) {
      setState(() {
        _restaurantId = response['id'] as String;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReservations() async {
    if (_restaurantId == null) return [];

    final result = await _supabase
        .from('reservations')
        .select()
        .eq('restaurant_id', _restaurantId!)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> _updateStatus(String reservationId, String status) async {
    await _supabase
        .from('reservations')
        .update({'status': status}).eq('id', reservationId);

    // Refresh after update
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Requests')),
      body: _restaurantId == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchReservations(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reservations = snapshot.data!;
                if (reservations.isEmpty) {
                  return const Center(child: Text('No pending reservations.'));
                }

                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final reservation = reservations[index];

                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(
                          'Guests: ${reservation['guests']} at ${reservation['time']}',
                        ),
                        subtitle: Text('Date: ${reservation['date']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () =>
                                  _updateStatus(reservation['id'], 'confirmed'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  _updateStatus(reservation['id'], 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
