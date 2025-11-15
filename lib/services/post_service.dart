import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

class PostService {
  final _db = Supabase.instance.client;

  Future<List<Post>> fetchPosts() async {
    final res = await _db
        .from('posts')
        .select('*')
        .order('created_at', ascending: false);

    if (res == null) return [];

    return (res as List).map((e) => Post.fromJson(e)).toList();
  }
}
