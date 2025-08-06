import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationScreen extends StatefulWidget {
  final String restaurantId;

  const ReservationScreen({super.key, required this.restaurantId});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('reservations').insert({
        'user_id': userId,
        'restaurant_id': widget.restaurantId,
        'guests': int.parse(_guestsController.text.trim()),
        'date': _dateController.text.trim(),
        'time': _timeController.text.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation submitted')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make Reservation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _guestsController,
                decoration:
                    const InputDecoration(labelText: 'Number of Guests'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter guest count' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration:
                    const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter date' : null,
              ),
              TextFormField(
                controller: _timeController,
                decoration:
                    const InputDecoration(labelText: 'Time (e.g. 7:00 PM)'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter time' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReservation,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
