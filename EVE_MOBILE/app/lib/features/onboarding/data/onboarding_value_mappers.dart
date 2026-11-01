import '../../../shared/models/life_stage_profile.dart';
import '../../../shared/models/preferences.dart';
import '../../../shared/models/user_profile.dart';
import '../domain/onboarding_state.dart';

// Onboarding screens (Plan 1) store the mock's display labels/values. The
// server reads canonical keys (design-spec §10) and several columns are
// Appwrite enums that reject anything else, so every enum-backed field is
// mapped here. Values that are already canonical pass through unchanged.

const _reminderKeys = {
  'Morning reminder': 'morning',
  'Medication reminder': 'medicine',
  'Workout reminder': 'workout',
  'Water intake reminder': 'water',
  'Sleep schedule reminder': 'sleep',
  'Cycle tracking reminder': 'cycle',
  'Appointment reminder': 'appointment',
  'Mood check-in reminder': 'mood',
  'Daily health insights': 'daily_tip',
};

const allHelpAreaKeys = [
  'healthQuestions',
  'nutrition',
  'workouts',
  'mentalWellbeing',
  'medicationReminders',
  'doctorPrep',
];

const _helpAreaKeys = {
  'Answer health questions': 'healthQuestions',
  'Nutrition': 'nutrition',
  'Workout': 'workouts',
  'Mental wellbeing': 'mentalWellbeing',
  'Medication reminders': 'medicationReminders',
  'Doctor prep': 'doctorPrep',
};

const _categoryKeys = {
  'Appointment reminders': 'appointmentReminders',
  'Pregnancy milestones': 'pregnancyMilestones',
  'Support suggestions': 'supportSuggestions',
  'Mood updates': 'moodUpdates',
};

const _themeKeys = {'Default': 'default', 'Light': 'light', 'Dark': 'dark'};

List<String> _mapKnown(List<String> values, Map<String, String> table) {
  final known = table.values.toSet();
  return [
    for (final value in values)
      if (table[value] != null) table[value]! else if (known.contains(value)) value,
  ];
}

List<String> reminderKeys(List<String> values) => _mapKnown(values, _reminderKeys);

List<String> helpAreaKeys(List<String> values) =>
    values.contains('Everything') ? List.of(allHelpAreaKeys) : _mapKnown(values, _helpAreaKeys);

List<String> categoryKeys(List<String> values) => _mapKnown(values, _categoryKeys);

String themeKey(String value) => _themeKeys[value] ?? (_themeKeys.containsValue(value) ? value : 'default');

String? relationshipKey(String value) => value.trim().isEmpty ? null : value.trim().toLowerCase();

String? _blankToNull(String value) => value.trim().isEmpty ? null : value.trim();

UserProfile profileFor(OnboardingState state) => UserProfile(
      name: state.name.trim(),
      age: int.tryParse(state.age),
      height: double.tryParse(state.height),
      weight: double.tryParse(state.weight),
      country: _blankToNull(state.country),
      lifeStage: state.lifeStage,
    );

LifeStageProfile lifeStageProfileFor(OnboardingState state) {
  switch (state.lifeStage) {
    case 'cycle':
      return CycleLifeStageProfile(
        cycleLength: int.tryParse(state.cycleLength),
        periodLength: int.tryParse(state.periodLength),
        flow: _blankToNull(state.flow),
        cycleSymptoms: state.cycleSymptoms,
        cycleGoals: state.cycleGoals,
        nutritionDiet: _blankToNull(state.nutritionDiet),
      );
    case 'pregnant':
      final due = DateTime.tryParse(state.dueDate);
      return PregnantLifeStageProfile(
        dueDate: due == null ? null : DateTime.utc(due.year, due.month, due.day),
        dueMethod: _blankToNull(state.dueMethod),
        highRisk: state.highRisk.isEmpty ? null : state.highRisk == 'Yes',
        pregnancyType: _blankToNull(state.pregnancyType),
        medications: _blankToNull(state.medications),
        allergies: _blankToNull(state.allergies),
        prenatalVitamins: state.prenatalVitamins.isEmpty ? null : state.prenatalVitamins == 'Yes',
        pregnantSymptoms: state.pregnantSymptoms,
      );
    case 'conceive':
    case 'postpartum':
    case 'menopause':
      return SimplifiedLifeStageProfile(
        type: state.lifeStage!,
        simplifiedSymptoms: state.simplifiedSymptoms,
        simplifiedGoals: state.simplifiedGoals,
      );
    default:
      return const EmptyLifeStageProfile();
  }
}

Preferences preferencesFor(OnboardingState state) => Preferences(
      selectedGoals: switch (state.lifeStage) {
        'cycle' => state.cycleGoals,
        'conceive' || 'postpartum' || 'menopause' => state.simplifiedGoals,
        _ => const <String>[],
      },
      dietType: _blankToNull(state.nutritionDiet),
      foodAllergies: state.foodAllergies,
      cuisines: state.cuisines,
      workoutPreference: state.workouts,
      enabledReminders: reminderKeys(state.notifications),
      enabledHelpAreas: helpAreaKeys(state.aiScope),
      selectedTheme: themeKey(state.theme),
    );
