import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bitebuddy/models/restaurant_model.dart';
// Import your RestaurantModel

class RestaurantDetailsForm extends StatefulWidget {
  @override
  _RestaurantDetailsFormState createState() => _RestaurantDetailsFormState();
}

class _RestaurantDetailsFormState extends State<RestaurantDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedCuisines = [];
  final List<String> _cuisines = [
    'Chinese',
    'Indian',
    'Italian',
    'Vegan',
    'BBQ'
  ];

  bool _isLoading = false;

  // Save restaurant details to Firestore
  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final uid = _auth.currentUser!.uid;

    // Create a restaurant model instance
    final restaurant = RestaurantModel(
      id: uid,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: 0.0, // Placeholder
      longitude: 0.0, // Placeholder
      ownerId: uid,
      cuisines: _selectedCuisines,
      imageUrl: "", // Placeholder
      averageRating: 0.0,
      priceRange: 0.0,
    );

    try {
      // Save restaurant to Firestore
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(uid)
          .set(restaurant.toMap());

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Restaurant details saved!')));
      Navigator.pop(context); // Close the form dialog
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Restaurant Details'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
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
              // Cuisine selection
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
              const SizedBox(height: 16),
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
