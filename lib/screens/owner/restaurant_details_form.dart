import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantDetailsForm extends StatefulWidget {
  const RestaurantDetailsForm({super.key});

  @override
  State<RestaurantDetailsForm> createState() => _RestaurantDetailsFormState();
}

class _RestaurantDetailsFormState extends State<RestaurantDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _selectedCuisines = [];
  final List<String> _cuisines = [
    'Chinese',
    'Indian',
    'Italian',
    'Vegan',
    'BBQ',
    'Deshi',
    'Mexican',
    'Café',
    'Fine Dining',
  ];

  File? _selectedImage;
  bool _isLoading = false;
  String? _restaurantId;
  LatLng? _selectedLatLng;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final restaurant = await _supabase
        .from('restaurants')
        .select()
        .eq('owner_id', uid)
        .maybeSingle();

    if (restaurant != null) {
      _restaurantId = restaurant['id'];
      _nameController.text = restaurant['name'] ?? '';
      _addressController.text = restaurant['address'] ?? '';
      _descriptionController.text = restaurant['description'] ?? '';
      _selectedCuisines = List<String>.from(restaurant['tags'] ?? []);

      if (restaurant['latitude'] != null && restaurant['longitude'] != null) {
        _selectedLatLng = LatLng(
          restaurant['latitude'],
          restaurant['longitude'],
        );
      }
    }
  }

  Future<String> _uploadImage(File file) async {
    final uid = _supabase.auth.currentUser?.id;
    final ext = file.path.split('.').last;
    final path = '$uid-${DateTime.now().millisecondsSinceEpoch}.$ext';

    final bytes = await file.readAsBytes();

    await _supabase.storage.from('restaurant-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('restaurant-images').getPublicUrl(path);
  }

  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your location on map")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    String imageUrl = '';
    if (_selectedImage != null) {
      try {
        imageUrl = await _uploadImage(_selectedImage!);
      } catch (e) {
        print("Image upload failed: $e");
      }
    }

    final data = {
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tags': _selectedCuisines,
      'owner_id': uid,
      'latitude': _selectedLatLng!.latitude,
      'longitude': _selectedLatLng!.longitude,
      'updated_at': DateTime.now().toIso8601String(),
      if (imageUrl.isNotEmpty) 'image_url': imageUrl,
    };

    try {
      if (_restaurantId != null) {
        await _supabase
            .from('restaurants')
            .update(data)
            .eq('id', _restaurantId!);
      } else {
        final inserted =
            await _supabase.from('restaurants').insert(data).select().single();
        _restaurantId = inserted['id'];
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant saved successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (val) => val!.isEmpty ? 'Enter address' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              const Text('Select Cuisine Types'),
              Wrap(
                spacing: 8,
                children: _cuisines.map((cuisine) {
                  final selected = _selectedCuisines.contains(cuisine);
                  return FilterChip(
                    label: Text(cuisine),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        value
                            ? _selectedCuisines.add(cuisine)
                            : _selectedCuisines.remove(cuisine);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text("Tap below to select location on map:"),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text("Pick Location"),
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/pick-location',
                    arguments: _selectedLatLng,
                  );

                  if (result is LatLng) {
                    setState(() => _selectedLatLng = result);
                  }
                },
              ),
              if (_selectedLatLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Selected: (${_selectedLatLng!.latitude.toStringAsFixed(5)}, ${_selectedLatLng!.longitude.toStringAsFixed(5)})",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick Image'),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.file(
                    _selectedImage!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveRestaurant,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Restaurant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
