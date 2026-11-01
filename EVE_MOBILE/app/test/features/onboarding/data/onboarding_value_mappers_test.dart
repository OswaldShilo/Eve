import 'package:eve_app/features/onboarding/data/onboarding_value_mappers.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder labels map to the nine canonical keys; unknown values are dropped', () {
    expect(
      reminderKeys(const [
        'Morning reminder', 'Medication reminder', 'Workout reminder', 'Water intake reminder',
        'Sleep schedule reminder', 'Cycle tracking reminder', 'Appointment reminder',
        'Mood check-in reminder', 'Daily health insights', 'Something else',
      ]),
      ['morning', 'medicine', 'workout', 'water', 'sleep', 'cycle', 'appointment', 'mood', 'daily_tip'],
    );
    expect(reminderKeys(const ['morning']), ['morning']);
  });

  test('AI scope values map to help-area keys and Everything expands to all six', () {
    expect(helpAreaKeys(const ['Nutrition', 'Doctor prep']), ['nutrition', 'doctorPrep']);
    expect(helpAreaKeys(const ['Everything']), [
      'healthQuestions', 'nutrition', 'workouts', 'mentalWellbeing', 'medicationReminders', 'doctorPrep',
    ]);
  });

  test('partner permission labels map to category keys', () {
    expect(
      categoryKeys(const ['Appointment reminders', 'Pregnancy milestones', 'Support suggestions', 'Mood updates']),
      ['appointmentReminders', 'pregnancyMilestones', 'supportSuggestions', 'moodUpdates'],
    );
  });

  test('theme and relationship', () {
    expect(themeKey('Dark'), 'dark');
    expect(themeKey('Default'), 'default');
    expect(themeKey(''), 'default');
    expect(relationshipKey('Husband'), 'husband');
    expect(relationshipKey(''), isNull);
  });

  test('profileFor parses numeric strings and nulls blanks', () {
    final profile = profileFor(const OnboardingState(name: 'Asha', age: '29', height: '165', weight: '', lifeStage: 'cycle'));
    expect(profile.age, 29);
    expect(profile.height, 165);
    expect(profile.weight, isNull);
    expect(profile.country, isNull);
    expect(profile.lifeStage, 'cycle');
  });

  test('lifeStageProfileFor builds the branch the user chose', () {
    final cycle = lifeStageProfileFor(const OnboardingState(
      lifeStage: 'cycle', cycleLength: '30', periodLength: '6', flow: 'Moderate', cycleGoals: ['Improve nutrition'], nutritionDiet: 'Vegan',
    )) as CycleLifeStageProfile;
    expect(cycle.cycleLength, 30);
    expect(cycle.nutritionDiet, 'Vegan');

    final pregnant = lifeStageProfileFor(const OnboardingState(
      lifeStage: 'pregnant', dueDate: '2026-06-01', highRisk: 'Yes', prenatalVitamins: 'No',
    )) as PregnantLifeStageProfile;
    expect(pregnant.dueDate, DateTime.utc(2026, 6, 1));
    expect(pregnant.highRisk, isTrue);
    expect(pregnant.prenatalVitamins, isFalse);

    expect(lifeStageProfileFor(const OnboardingState(lifeStage: 'menopause')), isA<SimplifiedLifeStageProfile>());
    expect(lifeStageProfileFor(const OnboardingState()), isA<EmptyLifeStageProfile>());
  });

  test('preferencesFor uses canonical keys and the branch goals', () {
    final prefs = preferencesFor(const OnboardingState(
      lifeStage: 'menopause',
      simplifiedGoals: ['Sleep better'],
      notifications: ['Morning reminder'],
      aiScope: ['Everything'],
      theme: 'Light',
      foodAllergies: 'peanuts',
    ));
    expect(prefs.selectedGoals, ['Sleep better']);
    expect(prefs.enabledReminders, ['morning']);
    expect(prefs.enabledHelpAreas, hasLength(6));
    expect(prefs.selectedTheme, 'light');
    expect(prefs.foodAllergies, 'peanuts');
  });
}
