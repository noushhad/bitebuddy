import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MenuEditorScreen extends StatefulWidget {
  const MenuEditorScreen({super.key});

  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  final _supabase = Supabase.instance.client;

  static const String menuBucket = 'menu-images'; // your storage bucket
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();

  String? _restaurantId;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _menuItems = [];
  File? _pickedImage; // used in dialog

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadRestaurantId();
    await _fetchMenuItems();
    setState(() => _loading = false);
  }

  Future<void> _loadRestaurantId() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final restaurant = await _supabase
        .from('restaurants')
        .select('id')
        .eq('owner_id', uid)
        .maybeSingle();

    if (restaurant == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No restaurant found for this user.')),
        );
      }
      return;
    }
    _restaurantId = restaurant['id'] as String?;
  }

  Future<void> _fetchMenuItems() async {
    if (_restaurantId == null) return;
    final data = await _supabase
        .from('menu_items')
        .select('id, name, image_url')
        .eq('restaurant_id', _restaurantId!)
        .order('name', ascending: true);
    setState(() {
      _menuItems = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) {
      setState(() => _pickedImage = File(x.path));
    }
  }

  Future<String> _uploadImage(String itemId, File imageFile) async {
    // storage path: <restaurantId>/<itemId>/<uuid>.<ext>
    final ext = p.extension(imageFile.path);
    final fileName = const Uuid().v4() + ext;
    final storagePath = '${_restaurantId!}/$itemId/$fileName';

    final bytes = await imageFile.readAsBytes();
    await _supabase.storage.from(menuBucket).uploadBinary(storagePath, bytes,
        fileOptions: const FileOptions(upsert: true));

    final publicUrl =
        _supabase.storage.from(menuBucket).getPublicUrl(storagePath);
    return publicUrl;
  }

  void _openItemDialog({Map<String, dynamic>? item}) {
    _pickedImage = null;
    _titleCtrl.text = item?['name'] ?? '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> onSave() async {
            if (_restaurantId == null) return;
            if (!_formKey.currentState!.validate()) return;

            setLocal(() => _saving = true);
            try {
              if (item == null) {
                // CREATE (require image)
                if (_pickedImage == null) {
                  throw 'Please select an image.';
                }
                final id = const Uuid().v4();
                final url = await _uploadImage(id, _pickedImage!);

                await _supabase.from('menu_items').insert({
                  'id': id,
                  'restaurant_id': _restaurantId,
                  'name': _titleCtrl.text.trim(),
                  'image_url': url,
                  // description/price/category remain null/unused
                });
              } else {
                // UPDATE (title and optional image replace)
                final String itemId = item['id'];
                String imageUrl = item['image_url'] ?? '';

                if (_pickedImage != null) {
                  imageUrl = await _uploadImage(itemId, _pickedImage!);
                  // NOTE: without image_path we can't delete the old file
                }

                await _supabase.from('menu_items').update({
                  'name': _titleCtrl.text.trim(),
                  'image_url': imageUrl,
                }).eq('id', itemId);
              }

              if (mounted) Navigator.pop(context);
              await _fetchMenuItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(item == null ? 'Menu added' : 'Menu updated')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            } finally {
              setLocal(() => _saving = false);
            }
          }

          return AlertDialog(
            title: Text(item == null ? 'Add Menu' : 'Edit Menu'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter title'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Pick Image'),
                        ),
                        const SizedBox(width: 12),
                        if (_pickedImage == null && item?['image_url'] != null)
                          const Text('Current image used')
                        else if (_pickedImage != null)
                          const Text('New image selected'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_pickedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_pickedImage!,
                            width: 160, height: 160, fit: BoxFit.cover),
                      )
                    else if (item?['image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(item!['image_url'],
                            width: 160, height: 160, fit: BoxFit.cover),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: _saving ? null : onSave,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {
      await _supabase.from('menu_items').delete().eq('id', item['id']);
      // Without image_path we can't delete the storage file reliably.
      await _fetchMenuItems();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Menu deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openItemDialog(),
            tooltip: 'Add Menu',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _menuItems.isEmpty
              ? const Center(child: Text('No menu yet. Tap + to add.'))
              : ListView.builder(
                  itemCount: _menuItems.length,
                  itemBuilder: (context, i) {
                    final item = _menuItems[i];
                    final title = item['name'] ?? '';
                    final imageUrl = item['image_url'] as String?;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(imageUrl,
                                    width: 56, height: 56, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.image_not_supported),
                        title: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon:
                                  const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _openItemDialog(item: item),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
