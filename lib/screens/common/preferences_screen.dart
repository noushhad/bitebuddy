import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<String> _allOptions = [
    'Deshi',
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Vegan',
    'BBQ',
    'Café',
    'Fine Dining'
  ];

  List<String> _selected = [];
  bool _loading = true;

  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _client
          .from('users')
          .select('preferences')
          .eq('uid', user.id)
          .single();

      if (mounted) {
        setState(() {
          _selected = List<String>.from(response['preferences'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _savePreferencesAndRedirect() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('users').update({
        'preferences': _selected,
      }).eq('uid', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );

      // Redirect based on role
      final data = await _client
          .from('users')
          .select('user_type')
          .eq('uid', user.id)
          .maybeSingle();

      final role = data?['user_type'];
      if (!mounted) return;

      if (role == 'owner') {
        Navigator.pushNamedAndRemoveUntil(
            context, '/owner/dashboard', (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, '/customer/home', (route) => false);
      }
    } catch (e) {
      print('Error saving: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    children: _allOptions.map((option) {
                      final isSelected = _selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            isSelected
                                ? _selected.remove(option)
                                : _selected.add(option);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _savePreferencesAndRedirect,
                    child: const Text('Save'),
                  )
                ],
              ),
            ),
    );
  }
}
