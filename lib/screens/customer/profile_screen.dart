import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final response = await _supabase
        .from('users')
        .select()
        .eq('uid', uid) // ✅ you're using uid, so this is correct
        .maybeSingle();

    if (response != null) {
      _nameController.text = response['name'] ?? '';
      _emailController.text =
          response['email'] ?? _supabase.auth.currentUser?.email ?? '';
      _contactController.text = response['contact'] ?? '';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    await _supabase.from('users').update({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'contact': _contactController.text.trim(),
    }).eq('uid', uid); // ✅ still using uid as your schema

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );

      // Optionally check user type here and redirect accordingly
      final userData = await _supabase
          .from('users')
          .select('user_type')
          .eq('uid', uid)
          .maybeSingle();

      final type = userData?['user_type'];
      final route = (type == 'owner') ? '/owner/dashboard' : '/customer/home';

      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter name' : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      readOnly: true,
                    ),
                    TextFormField(
                      controller: _contactController,
                      decoration:
                          const InputDecoration(labelText: 'Contact Number'),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter contact number'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
