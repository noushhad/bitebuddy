import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewList extends StatelessWidget {
  final String restaurantId;
  const ReviewList({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Supabase.instance.client
          .from('reviews')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const Text("No reviews yet.");
        }

        final reviews = snapshot.data as List<dynamic>;

        return Column(
          children: reviews.map((review) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Row(
                  children: List.generate(
                    review['rating'],
                    (_) =>
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                  ),
                ),
                subtitle: Text(review['review_text'] ?? ''),
                trailing:
                    Text(review['created_at'].toString().split('T').first),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
