import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReservationConfirmScreen extends StatefulWidget {
  const ReservationConfirmScreen({super.key});

  @override
  State<ReservationConfirmScreen> createState() =>
      _ReservationConfirmScreenState();
}

class _ReservationConfirmScreenState extends State<ReservationConfirmScreen> {
  final _firestore = FirebaseFirestore.instance;
  final String _restaurantId = "your_restaurant_id"; // TODO: fetch dynamically

  Future<void> _updateStatus(String reservationId, String status) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': status,
    });
  }

  Stream<QuerySnapshot> _getPendingReservations() {
    return _firestore
        .collection('reservations')
        .where('restaurantId', isEqualTo: _restaurantId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPendingReservations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reservations = snapshot.data?.docs ?? [];

          if (reservations.isEmpty) {
            return const Center(child: Text('No pending reservations.'));
          }

          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final data = reservations[index].data() as Map<String, dynamic>;
              final id = reservations[index].id;

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(
                      'Reservation for ${data['guests']} guests at ${data['time']}'),
                  subtitle: Text('Date: ${data['date']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateStatus(id, 'confirmed'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateStatus(id, 'rejected'),
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
