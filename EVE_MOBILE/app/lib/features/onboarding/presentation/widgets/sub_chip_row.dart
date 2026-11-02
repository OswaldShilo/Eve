import 'package:flutter/material.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

/// `.sub-choice-container` of `.sub-chip`s: a single-choice row of small
/// outlined chips; wraps onto a new line when it does not fit.
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
      runSpacing: 6,
      children: options.map((opt) {
        return EveChip(
          key: Key('chip-$opt'),
          label: opt,
          selected: opt == selected,
          onTap: () => onSelect(opt),
        );
      }).toList(),
    );
  }
}
