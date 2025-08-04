import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widgets/logout_button.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;

  bool _isLoading = false;
  List<String> _selectedCuisines = [];

  final ImagePicker _picker = ImagePicker();

  // List of available cuisine types
  final List<String> _cuisines = [
    'Deshi',
    'Chinese',
    'Indian',
    'Italian',
    'Mexican',
    'Vegan',
    'BBQ',
    'Café',
    'Fine Dining',
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  // Function to load the restaurant data (when the screen is first opened)
  Future<void> _loadRestaurant() async {
    final uid = _auth.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _addressController.text = data['address'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _selectedCuisines =
          List<String>.from(data['cuisines'] ?? []); // Load cuisines
    }
  }

  // Function to upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('restaurant_images')
          .child(fileName);

      await storageRef.putFile(imageFile); // Upload the image

      // Get the download URL for the uploaded image
      String downloadURL = await storageRef.getDownloadURL();
      print("Image uploaded: $downloadURL");

      return downloadURL;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Error uploading image');
    }
  }

  // Save the restaurant information to Firestore
  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final uid = _auth.currentUser!.uid;

    String imageUrl = '';
    if (_selectedImage != null) {
      try {
        // Upload the image and get the URL
        imageUrl =
            await _uploadImage(_selectedImage!); // This is an async operation
        print("Image uploaded: $imageUrl");
      } catch (e) {
        print("Error uploading image: $e");
      }
    }

    try {
      // Save restaurant details to Firestore
      await FirebaseFirestore.instance.collection('restaurants').doc(uid).set({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'cuisines': _selectedCuisines, // Save cuisines list
        'ownerId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("Restaurant saved successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant info saved!')),
      );
    } catch (e) {
      print("Error saving restaurant: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving restaurant: $e')),
      );
    } finally {
      setState(() => _isLoading = false); // Ensure loading is turned off
    }
  }

  // Pick an image from the device (gallery)
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/owner/reservations'),
            icon: const Icon(Icons.notifications),
            label: const Text('Alerts'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(Icons.feed),
            label: const Text('Feed'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text('Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Restaurant Details'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Promotion'),
              onTap: () {
                Navigator.pushNamed(context, '/owner/addPost');
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu),
              title: const Text('Edit Menu'),
              onTap: () {
                Navigator.pushNamed(context, '/owner/menu'); // Open Menu Editor
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pushNamed(context, '/favorites');
              },
            ),
            const Divider(),
            const LogoutButton(),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Restaurant Name'),
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
              // Cuisine selection: Multiple cuisines allowed
              const Text('Select Cuisine Types'),
              Wrap(
                spacing: 8,
                children: _cuisines.map((cuisine) {
                  final isSelected = _selectedCuisines.contains(cuisine);
                  return FilterChip(
                    label: Text(cuisine),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCuisines.add(cuisine);
                        } else {
                          _selectedCuisines.remove(cuisine);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Center the Pick Image button
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Pick Image'),
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Image.file(
                          _selectedImage!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveRestaurant,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
