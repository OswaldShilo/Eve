import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 77,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Morning reminder', 'Morning reminder'),
    OptionListItem('Medication reminder', 'Medication reminder'),
    OptionListItem('Workout reminder', 'Workout reminder'),
    OptionListItem('Water intake reminder', 'Water intake reminder'),
    OptionListItem('Sleep schedule reminder', 'Sleep schedule reminder'),
    OptionListItem('Cycle tracking reminder', 'Cycle tracking reminder'),
    OptionListItem('Appointment reminder', 'Appointment reminder'),
    OptionListItem('Mood check-in reminder', 'Mood check-in reminder'),
    OptionListItem('Daily health insights', 'Daily health insights'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Choose which reminders and updates you would like to receive.',
      title: 'Notification Preferences',
      subtitle: 'Choose what reminders EVE should send you.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.notifications.toSet(),
        onToggle: (v) => notifier.toggleListField('notifications', v),
      ),
    );
  }
}
