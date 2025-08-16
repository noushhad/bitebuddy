import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReviewForm extends StatefulWidget {
  final String restaurantId;
  final VoidCallback? onSubmitted; // notify parent to refresh aggregates

  const ReviewForm({
    super.key,
    required this.restaurantId,
    this.onSubmitted,
  });

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _reviewCtrl = TextEditingController();
  int? _rating; // null until chosen
  bool _isSubmitting = false;
  bool _expanded = false; // controls dropdown open/close

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  /// Reads user_type from your public.users table
  Future<String?> _fetchUserType(String uid) async {
    final row = await _supabase
        .from('users')
        .select('user_type')
        .eq('uid', uid)
        .maybeSingle();
    return row?['user_type'] as String?;
  }

  Future<void> _submitReview() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to submit a review.")),
      );
      return;
    }

    // ✅ Check role from users table (not auth metadata)
    final userType = await _fetchUserType(user.id);
    final isCustomer = userType == 'customer';

    if (!isCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only customers can submit reviews.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // close keyboard
    setState(() => _isSubmitting = true);

    try {
      await _supabase.from('reviews').insert({
        'id': const Uuid().v4(),
        'restaurant_id': widget.restaurantId,
        'customer_id': user.id,
        'rating': _rating,
        'review_text': _reviewCtrl.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted!")),
      );

      // Reset inputs + collapse
      setState(() {
        _rating = null;
        _reviewCtrl.clear();
        _expanded = false; // close the dropdown
      });

      widget.onSubmitted?.call(); // let parent refresh averages
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionPanelList(
          elevation: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          expansionCallback: (_, isOpen) {
            setState(() => _expanded = !isOpen);
          },
          children: [
            ExpansionPanel(
              isExpanded: _expanded,
              canTapOnHeader: false, // handle taps via InkWell
              headerBuilder: (_, __) => InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    "Leave a review",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text("Share your rating and thoughts"),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: "Rating",
                          border: OutlineInputBorder(),
                        ),
                        value: _rating,
                        items: List.generate(5, (i) {
                          final star = i + 1;
                          return DropdownMenuItem(
                            value: star,
                            child: Text("$star Star${star > 1 ? 's' : ''}"),
                          );
                        }),
                        onChanged: (val) => setState(() => _rating = val),
                        validator: (val) =>
                            (val == null) ? "Please select a rating" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reviewCtrl,
                        decoration: const InputDecoration(
                          labelText: "Write a review",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? "Review can’t be empty"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Submit"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
