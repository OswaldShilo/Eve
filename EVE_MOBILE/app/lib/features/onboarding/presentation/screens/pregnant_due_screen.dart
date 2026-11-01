import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class PregnantDueScreen extends ConsumerWidget {
  const PregnantDueScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 38,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _methodItems = [
    OptionListItem('Expected due date', 'Expected due date'),
    OptionListItem('First day of last period', 'First day of last period'),
    OptionListItem("Doctor's estimated week", "Doctor's estimated week"),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText:
          'Enter your timeline details to calculate key pregnancy milestones.',
      title: 'Pregnancy Timeline',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EveFormLabel('Calculation method'),
          OptionList(
            items: _methodItems,
            mode: OptionSelectionMode.single,
            selectedValues: state.dueMethod.isEmpty
                ? const {}
                : {state.dueMethod},
            onToggle: (v) => notifier.setField('dueMethod', v),
          ),
          const SizedBox(height: 8),
          const EveFormLabel('Target Date'),
          _DateField(
            key: const Key('pregnant-due-date-field'),
            value: state.dueDate,
            onPicked: (v) => notifier.setField('dueDate', v),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EveFormLabel('High-risk pregnancy?'),
                    SubChipRow(
                      options: const ['No', 'Yes'],
                      selected: state.highRisk,
                      onSelect: (v) => notifier.setField('highRisk', v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EveFormLabel('Pregnancy Type'),
                    SubChipRow(
                      options: const ['Single', 'Twins'],
                      selected: state.pregnancyType,
                      onSelect: (v) => notifier.setField('pregnancyType', v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The mock's `<input type="date" class="form-input">`: an outlined field
/// that opens the platform date picker. Stores `YYYY-MM-DD` in
/// `OnboardingState.dueDate`, the format the onboarding mapper parses.
class _DateField extends StatelessWidget {
  const _DateField({super.key, required this.value, required this.onPicked});

  final String value;
  final ValueChanged<String> onPicked;

  Future<void> _pick(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = DateTime.tryParse(value);
    final first = today.subtract(const Duration(days: 300));
    final last = today.add(const Duration(days: 300));
    final initial = current != null && !current.isBefore(first) && !current.isAfter(last)
        ? current
        : today.add(const Duration(days: 140));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Target Date',
    );
    if (picked != null) onPicked(DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme.bodyMedium!;
    final parsed = DateTime.tryParse(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        label: 'Target Date',
        value: parsed == null ? 'Not set' : DateFormat.yMMMMd().format(parsed),
        child: GestureDetector(
          onTap: () => _pick(context),
          child: Container(
            decoration: eveOutlined(color: tokens.card, radius: 18, shadow: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    parsed == null ? 'Select a date' : DateFormat.yMMMd().format(parsed),
                    style: text.copyWith(color: parsed == null ? tokens.muted : tokens.ink),
                  ),
                ),
                Icon(Icons.calendar_today_rounded, size: 18, color: tokens.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
