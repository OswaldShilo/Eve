import 'package:flutter/material.dart';

class SubChipRow extends StatelessWidget {
  const SubChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final void Function(String value) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          key: Key('chip-$opt'),
          label: Text(opt),
          selected: isSelected,
          onSelected: (_) => onSelect(opt),
        );
      }).toList(),
    );
  }
}
