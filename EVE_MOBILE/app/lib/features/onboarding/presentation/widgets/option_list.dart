import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

enum OptionSelectionMode { single, multi }

class OptionListItem {
  const OptionListItem(this.label, this.value);
  final String label;
  final String value;
}

/// `.survey-options` of `.option-card`s: outlined cards with a
/// `.radio-circle` (single) or `.check-box-icon` (multi) on the right.
/// Selected cards turn `--ruby-blush` and lift 2px.
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

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final single = mode == OptionSelectionMode.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        final selected = selectedValues.contains(item.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            selected: selected,
            inMutuallyExclusiveGroup: single,
            child: Transform.translate(
              offset: Offset(0, selected ? -2 : 0),
              child: EveCard(
                key: Key('option-${item.value}'),
                color: selected ? EveColors.rubyBlush : tokens.card,
                radius: 20,
                shadow: selected ? 7 : 5,
                onTap: () => onToggle(item.value),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: selected ? EveColors.outline : tokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    single
                        ? _radioCircle(Key('radio-${item.value}'), selected)
                        : _checkBox(Key('check-${item.value}'), selected),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// `.radio-circle`
Widget _radioCircle(Key key, bool selected) => Container(
  key: key,
  width: 22,
  height: 22,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: selected ? EveColors.outline : Colors.white,
    border: Border.all(color: EveColors.outline, width: 3.5),
  ),
);

/// `.check-box-icon`
Widget _checkBox(Key key, bool selected) => Container(
  key: key,
  width: 22,
  height: 22,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(7),
    color: selected ? EveColors.outline : Colors.white,
    border: Border.all(color: EveColors.outline, width: 3.5),
  ),
  alignment: Alignment.center,
  child: selected
      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
      : null,
);
