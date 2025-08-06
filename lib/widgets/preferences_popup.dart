import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreferencesPopup extends StatefulWidget {
  final void Function(List<String>) onSubmit;
  const PreferencesPopup({super.key, required this.onSubmit});

  @override
  State<PreferencesPopup> createState() => _PreferencesPopupState();
}

class _PreferencesPopupState extends State<PreferencesPopup> {
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
  final List<String> _selected = [];

  Future<void> _saveAndRedirect() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Save preferences in Supabase
    await Supabase.instance.client.from('users').update({
      'preferences': _selected,
      'preferencesSet': true,
    }).eq('uid', user.id);

    widget.onSubmit(_selected); // still trigger parent callback
    if (context.mounted) {
      Navigator.pop(context); // close dialog
      await _redirectBasedOnRole(context); // go to correct home
    }
  }

  Future<void> _redirectBasedOnRole(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    final data = await Supabase.instance.client
        .from('users')
        .select('user_type')
        .eq('uid', user.id)
        .maybeSingle();

    final type = data?['user_type'];

    if (type == 'owner') {
      Navigator.pushNamedAndRemoveUntil(
          context, '/owner/dashboard', (r) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, '/customer/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Your Preferences'),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          children: _allOptions.map((option) {
            final isSelected = _selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  isSelected ? _selected.remove(option) : _selected.add(option);
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saveAndRedirect,
          child: const Text('Done'),
        )
      ],
    );
  }
}
