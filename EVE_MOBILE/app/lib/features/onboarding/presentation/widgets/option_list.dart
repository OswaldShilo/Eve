import 'package:flutter/material.dart';

enum OptionSelectionMode { single, multi }

class OptionListItem {
  const OptionListItem(this.label, this.value);
  final String label;
  final String value;
}

class OptionList extends StatelessWidget {
  const OptionList({
    super.key,
    required this.items,
    required this.mode,
    required this.selectedValues,
    required this.onToggle,
  });

  final List<OptionListItem> items;
  final OptionSelectionMode mode;
  final Set<String> selectedValues;
  final void Function(String value) onToggle;

  static const _ruby = Color(0xFFFF2A6D);
  static const _rubySoft = Color(0xFFFFF0F4);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final selected = selectedValues.contains(item.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            key: Key('option-${item.value}'),
            onTap: () => onToggle(item.value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? _ruby : const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(12),
                color: selected ? _rubySoft : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.label),
                  Icon(
                    mode == OptionSelectionMode.single
                        ? (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                        : (selected ? Icons.check_box : Icons.check_box_outline_blank),
                    color: selected ? _ruby : const Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
