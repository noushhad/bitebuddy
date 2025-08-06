import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MenuEditorScreen extends StatefulWidget {
  const MenuEditorScreen({super.key});

  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _description = '';
  double _price = 0;
  String _category = 'Starters';

  final List<String> _categories = [
    'Starters',
    'Soups & Salads',
    'Main Course',
    'Desserts',
    'Beverages',
    'Specials'
  ];

  List<Map<String, dynamic>> _menuItems = [];
  String? _restaurantId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final restaurant = await _supabase
        .from('restaurants')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();

    if (restaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No restaurant found for this user.')),
      );
      return;
    }

    _restaurantId = restaurant['id'];

    final items = await _supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', _restaurantId!)
        .order('name', ascending: true);

    setState(() {
      _menuItems = List<Map<String, dynamic>>.from(items);
      _loading = false;
    });
  }

  Future<void> _addOrEditMenuItem([String? itemId]) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final data = {
      'name': _name,
      'description': _description,
      'price': _price,
      'category': _category,
      'restaurant_id': _restaurantId,
    };

    try {
      if (itemId != null) {
        await _supabase.from('menu_items').update(data).eq('id', itemId);
      } else {
        final id = const Uuid().v4();
        await _supabase.from('menu_items').insert({'id': id, ...data});
      }

      Navigator.pop(context);
      _fetchMenu();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  Future<void> _deleteMenuItem(String itemId) async {
    try {
      await _supabase.from('menu_items').delete().eq('id', itemId);

      _fetchMenu();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }

  void _showMenuItemForm([Map<String, dynamic>? item, String? id]) {
    _name = item?['name'] ?? '';
    _description = item?['description'] ?? '';
    _price = (item?['price'] ?? 0).toDouble();
    _category = item?['category'] ?? 'Starters';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id != null ? 'Edit Menu Item' : 'Add Menu Item'),
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
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _category = val ?? 'Starters'),
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
              onPressed: () => _addOrEditMenuItem(id),
              child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.black),
            label:
                const Text('Add Item', style: TextStyle(color: Colors.black)),
            onPressed: () => _showMenuItemForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _menuItems.isEmpty
              ? const Center(child: Text('No menu items yet.'))
              : ListView.builder(
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text(
                            '${item['description']}\nPrice: ${item['price']} Taka'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () =>
                                  _showMenuItemForm(item, item['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteMenuItem(item['id']),
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
