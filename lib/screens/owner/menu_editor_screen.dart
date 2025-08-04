import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuEditorScreen extends StatefulWidget {
  const MenuEditorScreen({super.key});

  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  final String restaurantId = 'your_restaurant_id'; // TODO: fetch dynamically
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  double _price = 0;
  String _category = 'Starters'; // Default category

  final List<String> _categories = [
    'Starters',
    'Soups & Salads',
    'Main Course',
    'Desserts',
    'Beverages',
    'Specials'
  ];

  // Add or edit a menu item
  Future<void> _addOrEditMenuItem([String? itemId]) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final data = {
      'name': _name,
      'description': _description,
      'price': _price,
      'category': _category, // Store the category for each item
    };

    try {
      final ref = _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems');

      if (itemId != null) {
        await ref.doc(itemId).update(data); // Update existing item
      } else {
        await ref.add(data); // Add a new item to the collection
      }

      Navigator.pop(context); // Close the dialog after saving
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving menu item: $e')),
      );
    }
  }

  // Delete a menu item
  Future<void> _deleteMenuItem(String itemId) async {
    try {
      await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .doc(itemId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item deleted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }

  // Show the form to add or edit a menu item
  void _showMenuItemForm([Map<String, dynamic>? existingItem, String? itemId]) {
    if (existingItem != null) {
      _name = existingItem['name'];
      _description = existingItem['description'];
      _price = (existingItem['price'] ?? 0).toDouble();
      _category = existingItem['category'] ?? 'Starters'; // Assign the category
    } else {
      _name = _description = '';
      _price = 0;
      _category = 'Starters'; // Default category
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(itemId != null ? 'Edit Menu Item' : 'Add Menu Item'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  onSaved: (val) => _name = val!,
                ),
                TextFormField(
                  initialValue: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onSaved: (val) => _description = val ?? '',
                ),
                TextFormField(
                  initialValue: _price.toString(),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Price (in Taka)'),
                  validator: (val) =>
                      val!.isEmpty || double.tryParse(val) == null
                          ? 'Enter valid price'
                          : null,
                  onSaved: (val) => _price = double.parse(val!),
                ),
                const SizedBox(height: 20),
                // Category dropdown
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addOrEditMenuItem(itemId),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: Color.fromARGB(255, 7, 7, 7)),
            label:
                const Text('Add Item', style: TextStyle(color: Colors.black)),
            onPressed: () => _showMenuItemForm(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final items = snapshot.data!.docs;

          if (items.isEmpty) {
            return const Center(child: Text('No menu items yet.'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final data = item.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                      '${data['description']}\nPrice: ${data['price']} Taka'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showMenuItemForm(data, item.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMenuItem(item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
