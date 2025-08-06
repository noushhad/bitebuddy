import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  String _title = '';
  String _description = '';
  File? _imageFile;
  bool _isLoading = false;

  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final restaurantData = await _supabase
        .from('restaurants')
        .select('id')
        .eq('owner_id', uid)
        .maybeSingle();

    if (restaurantData != null) {
      final restaurantId = restaurantData['id'];

      final posts = await _supabase
          .from('posts')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: false);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(posts);
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(String postId) async {
    final bytes = await _imageFile!.readAsBytes();
    final fileExt = _imageFile!.path.split('.').last;
    final filePath = '$postId.$fileExt';

    await _supabase.storage.from('post-images').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('post-images').getPublicUrl(filePath);
  }

  Future<void> _submitPost({String? existingPostId}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final ownerId = _supabase.auth.currentUser?.id;
      if (ownerId == null) throw 'User not logged in';

      final restaurantData = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (restaurantData == null) throw 'No restaurant found for user';
      final restaurantId = restaurantData['id'];
      final postId = existingPostId ?? const Uuid().v4();

      String imageUrl = '';
      if (_imageFile != null) {
        imageUrl = await _uploadImage(postId);
      }

      final data = {
        'id': postId,
        'title': _title,
        'description': _description,
        'restaurant_id': restaurantId,
        if (imageUrl.isNotEmpty) 'image_url': imageUrl,
      };

      if (existingPostId != null) {
        await _supabase.from('posts').update(data).eq('id', postId);
      } else {
        await _supabase.from('posts').insert(data);
      }

      _formKey.currentState!.reset();
      setState(() {
        _imageFile = null;
        _title = '';
        _description = '';
      });

      await _loadPosts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(existingPostId != null ? 'Post updated' : 'Post added')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editPost(Map<String, dynamic> post) {
    setState(() {
      _title = post['title'] ?? '';
      _description = post['description'] ?? '';
    });

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onSaved: (val) => _title = val!,
                ),
                TextFormField(
                  initialValue: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onSaved: (val) => _description = val ?? '',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _submitPost(existingPostId: post['id']);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
    await _loadPosts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Promotions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (val) => val!.isEmpty ? 'Enter title' : null,
                  onSaved: (val) => _title = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  onSaved: (val) => _description = val ?? '',
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Select Image'),
                ),
                if (_imageFile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Image.file(_imageFile!, height: 150),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _submitPost(),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Post'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text('Previous Posts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          ..._posts.map((post) => Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  leading: post['image_url'] != null
                      ? Image.network(post['image_url'],
                          width: 60, height: 60, fit: BoxFit.cover)
                      : const Icon(Icons.image),
                  title: Text(post['title'] ?? ''),
                  subtitle: Text(post['description'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editPost(post),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePost(post['id']),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
