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

    final response = await _supabase.storage.from('post-images').uploadBinary(
        filePath, bytes,
        fileOptions: const FileOptions(upsert: true));

    final publicUrl =
        _supabase.storage.from('post-images').getPublicUrl(filePath);
    return publicUrl;
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please complete all fields & select an image.')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final ownerId = _supabase.auth.currentUser?.id;
      if (ownerId == null) throw 'User not logged in';

      // Get restaurant ID by owner
      final restaurantData = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (restaurantData == null) throw 'No restaurant found for user';
      final restaurantId = restaurantData['id'];

      final postId = const Uuid().v4();
      final imageUrl = await _uploadImage(postId);

      await _supabase.from('posts').insert({
        'id': postId,
        'title': _title,
        'description': _description,
        'image_url': imageUrl,
        'restaurant_id': restaurantId,
      });

      setState(() => _isLoading = false);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post added.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Promotion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val!.isEmpty ? 'Enter a title' : null,
                onSaved: (val) => _title = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onSaved: (val) => _description = val ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Select Image'),
              ),
              if (_imageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Image.file(_imageFile!, height: 200),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
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
