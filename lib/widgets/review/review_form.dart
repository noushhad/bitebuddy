import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReviewForm extends StatefulWidget {
  final String restaurantId;
  const ReviewForm({super.key, required this.restaurantId});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  int _rating = 0;
  String _review = '';
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    final user = _supabase.auth.currentUser;
    final userType = user?.userMetadata?['userType'];

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only customers can submit reviews.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final id = const Uuid().v4();
    try {
      await _supabase.from('reviews').insert({
        'id': id,
        'restaurant_id': widget.restaurantId,
        'customer_id': user.id,
        'rating': _rating,
        'review_text': _review,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted!")),
      );
      setState(() {
        _rating = 0;
        _review = '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Leave a review", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: "Rating"),
          value: _rating > 0 ? _rating : null,
          items: List.generate(5, (index) {
            final star = index + 1;
            return DropdownMenuItem(value: star, child: Text("$star Star"));
          }),
          onChanged: (val) => setState(() => _rating = val ?? 0),
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(labelText: "Write a review"),
          maxLines: 3,
          onChanged: (val) => _review = val,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: const Text("Submit"),
        ),
      ],
    );
  }
}
