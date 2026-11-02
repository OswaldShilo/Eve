import 'row_parsing.dart';

/// Mirrors `PreferencesRow`. Table `preferences`, rowId = uid. Replaces the
/// four Firestore-era preference documents (goals, notifications, aiScope, theme).
class Preferences {
  const Preferences({
    this.selectedGoals = const [],
    this.dietType,
    this.foodAllergies = '',
    this.cuisines = const [],
    this.workoutPreference = const [],
    this.enabledReminders = const [],
    this.enabledHelpAreas = const [],
    this.selectedTheme = 'default',
  });

  final List<String> selectedGoals;
  final String? dietType;
  final String foodAllergies;
  final List<String> cuisines;
  final List<String> workoutPreference;
  final List<String> enabledReminders;
  final List<String> enabledHelpAreas;
  final String selectedTheme;

  factory Preferences.fromRow(Map<String, dynamic> data) => Preferences(
        selectedGoals: parseStringList(data['selectedGoals']),
        dietType: data['dietType'] as String?,
        foodAllergies: (data['foodAllergies'] as String?) ?? '',
        cuisines: parseStringList(data['cuisines']),
        workoutPreference: parseStringList(data['workoutPreference']),
        enabledReminders: parseStringList(data['enabledReminders']),
        enabledHelpAreas: parseStringList(data['enabledHelpAreas']),
        selectedTheme: (data['selectedTheme'] as String?) ?? 'default',
      );

  Map<String, dynamic> toRow() => {
        'selectedGoals': selectedGoals,
        'dietType': dietType,
        'foodAllergies': foodAllergies,
        'cuisines': cuisines,
        'workoutPreference': workoutPreference,
        'enabledReminders': enabledReminders,
        'enabledHelpAreas': enabledHelpAreas,
        'selectedTheme': selectedTheme,
      };
}
