// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:bitebuddy/screens/owner/restaurant_details_form.dart';

// import '../../widgets/logout_button.dart';

// class OwnerDashboardScreen extends StatefulWidget {
//   const OwnerDashboardScreen({super.key});

//   @override
//   State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
// }

// class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _supabase = Supabase.instance.client;

//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   File? _selectedImage;

//   bool _isLoading = false;
//   List<String> _selectedCuisines = [];

//   final ImagePicker _picker = ImagePicker();

//   final List<String> _cuisines = [
//     'Deshi',
//     'Chinese',
//     'Indian',
//     'Italian',
//     'Mexican',
//     'Vegan',
//     'BBQ',
//     'Café',
//     'Fine Dining',
//   ];

//   String? _restaurantId;

//   @override
//   void initState() {
//     super.initState();
//     _loadRestaurant();
//   }

//   Future<void> _loadRestaurant() async {
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;

//     final restaurant = await _supabase
//         .from('restaurants')
//         .select()
//         .eq('owner_id', uid)
//         .maybeSingle();

//     if (restaurant != null) {
//       _restaurantId = restaurant['id'];
//       _nameController.text = restaurant['name'] ?? '';
//       _addressController.text = restaurant['address'] ?? '';
//       _descriptionController.text = restaurant['description'] ?? '';
//       _selectedCuisines = List<String>.from(restaurant['tags'] ?? []);
//     }
//   }

//   Future<String> _uploadImage(File file) async {
//     final uid = _supabase.auth.currentUser?.id;
//     final fileExt = file.path.split('.').last;
//     final filePath = '$uid-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

//     final bytes = await file.readAsBytes();
//     await _supabase.storage.from('restaurant-images').uploadBinary(
//         filePath, bytes,
//         fileOptions: const FileOptions(upsert: true));

//     final publicUrl =
//         _supabase.storage.from('restaurant-images').getPublicUrl(filePath);
//     return publicUrl;
//   }

//   Future<void> _saveRestaurant() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);
//     final uid = _supabase.auth.currentUser?.id;
//     if (uid == null) return;

//     String imageUrl = '';
//     if (_selectedImage != null) {
//       try {
//         imageUrl = await _uploadImage(_selectedImage!);
//       } catch (e) {
//         print("Image upload failed: $e");
//       }
//     }

//     final data = {
//       'name': _nameController.text.trim(),
//       'address': _addressController.text.trim(),
//       'description': _descriptionController.text.trim(),
//       'tags': _selectedCuisines,
//       'owner_id': uid,
//       'updated_at': DateTime.now().toIso8601String(),
//       if (imageUrl.isNotEmpty) 'image_url': imageUrl,
//     };

//     try {
//       if (_restaurantId != null) {
//         await _supabase
//             .from('restaurants')
//             .update(data)
//             .eq('id', _restaurantId!);
//       } else {
//         final inserted =
//             await _supabase.from('restaurants').insert(data).select().single();
//         _restaurantId = inserted['id'];
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Restaurant info saved!')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error saving restaurant: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _selectedImage = File(pickedFile.path);
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: null,
//         actions: [
//           TextButton.icon(
//             onPressed: () => Navigator.pushNamed(context, '/search'),
//             icon: const Icon(Icons.search),
//             label: const Text('Search'),
//           ),
//           TextButton.icon(
//             onPressed: () =>
//                 Navigator.pushNamed(context, '/owner/reservations'),
//             icon: const Icon(Icons.notifications),
//             label: const Text('Alerts'),
//           ),
//           TextButton.icon(
//             onPressed: () => Navigator.pushNamed(context, '/feed'),
//             icon: const Icon(Icons.feed),
//             label: const Text('Feed'),
//           ),
//         ],
//       ),
//       drawer: Drawer(
//         child: ListView(
//           padding: EdgeInsets.zero,
//           children: [
//             const DrawerHeader(
//               decoration: BoxDecoration(color: Colors.deepOrange),
//               child: Text('Dashboard',
//                   style: TextStyle(color: Colors.white, fontSize: 24)),
//             ),
//             ListTile(
//               leading: const Icon(Icons.store),
//               title: const Text('Restaurant Details'),
//               onTap: () async {
//                 Navigator.pop(context);
//                 await showDialog(
//                   context: context,
//                   builder: (_) => const RestaurantDetailsForm(),
//                 );
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.add),
//               title: const Text('Add Promotion'),
//               onTap: () => Navigator.pushNamed(context, '/owner/addPost'),
//             ),
//             ListTile(
//               leading: const Icon(Icons.menu),
//               title: const Text('Edit Menu'),
//               onTap: () => Navigator.pushNamed(context, '/owner/menu'),
//             ),
//             ListTile(
//               leading: const Icon(Icons.favorite),
//               title: const Text('Favorites'),
//               onTap: () => Navigator.pushNamed(context, '/favorites'),
//             ),
//             ListTile(
//               leading: const Icon(Icons.settings),
//               title: const Text('Preferences'),
//               onTap: () => Navigator.pushNamed(context, '/preferences'),
//             ),
//             const Divider(),
//             const LogoutButton(),
//           ],
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(labelText: 'Restaurant Name'),
//                 validator: (val) => val!.isEmpty ? 'Enter name' : null,
//               ),
//               TextFormField(
//                 controller: _addressController,
//                 decoration: const InputDecoration(labelText: 'Address'),
//                 validator: (val) => val!.isEmpty ? 'Enter address' : null,
//               ),
//               TextFormField(
//                 controller: _descriptionController,
//                 decoration: const InputDecoration(labelText: 'Description'),
//                 maxLines: 3,
//               ),
//               const SizedBox(height: 10),
//               const Text('Select Cuisine Types'),
//               Wrap(
//                 spacing: 8,
//                 children: _cuisines.map((cuisine) {
//                   final isSelected = _selectedCuisines.contains(cuisine);
//                   return FilterChip(
//                     label: Text(cuisine),
//                     selected: isSelected,
//                     onSelected: (selected) {
//                       setState(() {
//                         if (selected && !_selectedCuisines.contains(cuisine)) {
//                           _selectedCuisines.add(cuisine);
//                         } else {
//                           _selectedCuisines.remove(cuisine);
//                         }
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//               const SizedBox(height: 10),
//               Center(
//                 child: Column(
//                   children: [
//                     ElevatedButton(
//                       onPressed: _pickImage,
//                       child: const Text('Pick Image'),
//                     ),
//                     if (_selectedImage != null)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 12.0),
//                         child: Image.file(
//                           _selectedImage!,
//                           width: 100,
//                           height: 100,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _saveRestaurant,
//                 child: _isLoading
//                     ? const CircularProgressIndicator()
//                     : const Text('Save'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitebuddy/screens/owner/restaurant_details_form.dart';

import '../../widgets/logout_button.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

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
                Navigator.pop(context);
                Navigator.pushNamed(context, '/owner/restaurantDetails');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Manager Profile'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Promotion'),
              onTap: () => Navigator.pushNamed(context, '/owner/addPost'),
            ),
            ListTile(
              leading: const Icon(Icons.menu),
              title: const Text('Edit Menu'),
              onTap: () => Navigator.pushNamed(context, '/owner/menu'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () => Navigator.pushNamed(context, '/favorites'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Preferences'),
              onTap: () => Navigator.pushNamed(context, '/preferences'),
            ),
            const Divider(),
            const LogoutButton(),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome to your Dashboard!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
