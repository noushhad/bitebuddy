import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReservationScreen extends StatefulWidget {
  final String restaurantId;
  const ReservationScreen({super.key, required this.restaurantId});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _guestsController = TextEditingController(text: '2');
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _submitting = false;

  @override
  void dispose() {
    _guestsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
      helpText: 'Select reservation date',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Select reservation time',
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime? get _combined {
    if (_selectedDate == null || _selectedTime == null) return null;
    final d = _selectedDate!;
    final t = _selectedTime!;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Pick a date' : DateFormat('EEE, MMM d, yyyy').format(d);
  String _fmtTime(TimeOfDay? t) {
    if (t == null) return 'Pick a time';
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String? _validateGuests(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter guest count';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 1) return 'At least 1 guest';
    if (n > 20) return 'Please contact the restaurant for large parties';
    return null;
  }

  String? _validateDateTime() {
    if (_selectedDate == null) return 'Select a date';
    if (_selectedTime == null) return 'Select a time';
    final dt = _combined;
    if (dt != null && dt.isBefore(DateTime.now()))
      return 'Choose a future time';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    final dt = _combined!;
    final dateStr = DateFormat('yyyy-MM-dd').format(dt);
    final timeStr =
        DateFormat('HH:mm').format(dt); // 24h to match typical SQL time

    setState(() => _submitting = true);
    try {
      await _supabase.from('reservations').insert({
        'user_id': uid,
        'restaurant_id': widget.restaurantId,
        'guests': int.parse(_guestsController.text.trim()),
        'date': dateStr,
        'time': timeStr,
        'status': 'pending',
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation submitted ✅')),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dtError = _validateDateTime();

    return Scaffold(
      appBar: AppBar(title: const Text('Make Reservation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                TextFormField(
                  controller: _guestsController,
                  decoration: const InputDecoration(
                    labelText: 'Number of guests',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateGuests,
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    errorText: _selectedDate == null ? 'Select a date' : null,
                    border: const OutlineInputBorder(),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_fmtDate(_selectedDate)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Time',
                    prefixIcon: const Icon(Icons.access_time),
                    errorText: _selectedTime == null ? 'Select a time' : null,
                    border: const OutlineInputBorder(),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_fmtTime(_selectedTime)),
                    trailing: const Icon(Icons.schedule),
                    onTap: _pickTime,
                  ),
                ),
                if (dtError != null &&
                    _selectedDate != null &&
                    _selectedTime != null) ...[
                  const SizedBox(height: 8),
                  Text(dtError,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Allergies, occasion, seating preference…',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_submitting ? 'Submitting…' : 'Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
