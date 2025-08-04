// lib/widgets/preferences_popup.dart
import 'package:flutter/material.dart';

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
          onPressed: () {
            widget.onSubmit(_selected);
            Navigator.pop(context);
          },
          child: const Text('Done'),
        )
      ],
    );
  }
}
