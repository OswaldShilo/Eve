import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets('NotificationsScreen renders all nine reminder options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: NotificationsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Notification Preferences'), findsOneWidget);
    for (final label in const [
      'Morning reminder', 'Medication reminder', 'Workout reminder', 'Water intake reminder',
      'Sleep schedule reminder', 'Cycle tracking reminder', 'Appointment reminder',
      'Mood check-in reminder', 'Daily health insights',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
