import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors the mock's `surveyState` object field-for-field
/// (plans/00-design-spec.md §6), including its types: every field is the raw
/// string/list/bool value an HTML form input would produce — never parsed
/// into int/double/enum at this layer. `lifeStage` holds the raw selector
/// value ('cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause'),
/// matching `mockv4.html`'s `selectLifeStage()` calls exactly.
class OnboardingState {
  const OnboardingState({
    this.name = '',
    this.age = '',
    this.height = '',
    this.weight = '',
    this.country = '',
    this.lifeStage,
    this.cycleLength = '',
    this.periodLength = '',
    this.flow = '',
    this.cycleSymptoms = const [],
    this.cycleGoals = const [],
    this.nutritionDiet = '',
    this.dueDate = '',
    this.dueMethod = '',
    this.highRisk = '',
    this.pregnancyType = '',
    this.medications = '',
    this.allergies = '',
    this.prenatalVitamins = '',
    this.pregnantSymptoms = const [],
    this.foodAllergies = '',
    this.cuisines = const [],
    this.workouts = const [],
    this.notifications = const [],
    this.aiScope = const [],
    this.partnerInvite = false,
    this.partnerRelation = '',
    this.partnerPermissions = const [],
    this.onlyApproveMaster = false,
    this.theme = '',
    this.simplifiedSymptoms = const [],
    this.simplifiedGoals = const [],
  });

  final String name, age, height, weight, country;
  final String? lifeStage;
  final String cycleLength, periodLength, flow;
  final List<String> cycleSymptoms, cycleGoals;
  final String nutritionDiet;
  final String dueDate,
      dueMethod,
      highRisk,
      pregnancyType,
      medications,
      allergies,
      prenatalVitamins;
  final List<String> pregnantSymptoms;
  final String foodAllergies;
  final List<String> cuisines, workouts, notifications, aiScope;
  final bool partnerInvite;
  final String partnerRelation;
  final List<String> partnerPermissions;
  final bool onlyApproveMaster;
  final String theme;
  final List<String> simplifiedSymptoms, simplifiedGoals;

  OnboardingState copyWith({
    String? name,
    String? age,
    String? height,
    String? weight,
    String? country,
    String? lifeStage,
    String? cycleLength,
    String? periodLength,
    String? flow,
    List<String>? cycleSymptoms,
    List<String>? cycleGoals,
    String? nutritionDiet,
    String? dueDate,
    String? dueMethod,
    String? highRisk,
    String? pregnancyType,
    String? medications,
    String? allergies,
    String? prenatalVitamins,
    List<String>? pregnantSymptoms,
    String? foodAllergies,
    List<String>? cuisines,
    List<String>? workouts,
    List<String>? notifications,
    List<String>? aiScope,
    bool? partnerInvite,
    String? partnerRelation,
    List<String>? partnerPermissions,
    bool? onlyApproveMaster,
    String? theme,
    List<String>? simplifiedSymptoms,
    List<String>? simplifiedGoals,
  }) {
    return OnboardingState(
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      country: country ?? this.country,
      lifeStage: lifeStage ?? this.lifeStage,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      flow: flow ?? this.flow,
      cycleSymptoms: cycleSymptoms ?? this.cycleSymptoms,
      cycleGoals: cycleGoals ?? this.cycleGoals,
      nutritionDiet: nutritionDiet ?? this.nutritionDiet,
      dueDate: dueDate ?? this.dueDate,
      dueMethod: dueMethod ?? this.dueMethod,
      highRisk: highRisk ?? this.highRisk,
      pregnancyType: pregnancyType ?? this.pregnancyType,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      prenatalVitamins: prenatalVitamins ?? this.prenatalVitamins,
      pregnantSymptoms: pregnantSymptoms ?? this.pregnantSymptoms,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      cuisines: cuisines ?? this.cuisines,
      workouts: workouts ?? this.workouts,
      notifications: notifications ?? this.notifications,
      aiScope: aiScope ?? this.aiScope,
      partnerInvite: partnerInvite ?? this.partnerInvite,
      partnerRelation: partnerRelation ?? this.partnerRelation,
      partnerPermissions: partnerPermissions ?? this.partnerPermissions,
      onlyApproveMaster: onlyApproveMaster ?? this.onlyApproveMaster,
      theme: theme ?? this.theme,
      simplifiedSymptoms: simplifiedSymptoms ?? this.simplifiedSymptoms,
      simplifiedGoals: simplifiedGoals ?? this.simplifiedGoals,
    );
  }
}

/// Field names accepted by [OnboardingNotifier.setField] — every scalar
/// (`String`/`bool`) field in [OnboardingState]. Kept as a constant so a
/// typo in a screen's `setField('lifeStag', ...)` call fails loudly via
/// `ArgumentError` instead of silently no-op-ing.
const _scalarFields = {
  'name',
  'age',
  'height',
  'weight',
  'country',
  'lifeStage',
  'cycleLength',
  'periodLength',
  'flow',
  'nutritionDiet',
  'dueDate',
  'dueMethod',
  'highRisk',
  'pregnancyType',
  'medications',
  'allergies',
  'prenatalVitamins',
  'foodAllergies',
  'partnerInvite',
  'partnerRelation',
  'onlyApproveMaster',
  'theme',
};

/// Field names accepted by [OnboardingNotifier.toggleListField] — every
/// `List<String>` field in [OnboardingState].
const _listFields = {
  'cycleSymptoms',
  'cycleGoals',
  'pregnantSymptoms',
  'cuisines',
  'workouts',
  'notifications',
  'aiScope',
  'partnerPermissions',
  'simplifiedSymptoms',
  'simplifiedGoals',
};

/// Holds and mutates [OnboardingState] across every onboarding screen.
/// Mirrors the mock's dynamic `surveyState[key] = val` / `toggleMultiSelect`
/// pattern with two generic entry points rather than 32 individually-named
/// setters — e.g. the Life-Stage screen calls
/// `setField('lifeStage', 'pregnant')`, the Cycle Symptoms screen calls
/// `toggleListField('cycleSymptoms', 'cramps')`.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  /// Writes a single scalar (`String` or `bool`) field by name.
  void setField(String field, Object? value) {
    if (!_scalarFields.contains(field)) {
      throw ArgumentError.value(field, 'field', 'Not a known scalar field');
    }
    switch (field) {
      case 'name':
        state = state.copyWith(name: value as String);
      case 'age':
        state = state.copyWith(age: value as String);
      case 'height':
        state = state.copyWith(height: value as String);
      case 'weight':
        state = state.copyWith(weight: value as String);
      case 'country':
        state = state.copyWith(country: value as String);
      case 'lifeStage':
        state = state.copyWith(lifeStage: value as String);
      case 'cycleLength':
        state = state.copyWith(cycleLength: value as String);
      case 'periodLength':
        state = state.copyWith(periodLength: value as String);
      case 'flow':
        state = state.copyWith(flow: value as String);
      case 'nutritionDiet':
        state = state.copyWith(nutritionDiet: value as String);
      case 'dueDate':
        state = state.copyWith(dueDate: value as String);
      case 'dueMethod':
        state = state.copyWith(dueMethod: value as String);
      case 'highRisk':
        state = state.copyWith(highRisk: value as String);
      case 'pregnancyType':
        state = state.copyWith(pregnancyType: value as String);
      case 'medications':
        state = state.copyWith(medications: value as String);
      case 'allergies':
        state = state.copyWith(allergies: value as String);
      case 'prenatalVitamins':
        state = state.copyWith(prenatalVitamins: value as String);
      case 'foodAllergies':
        state = state.copyWith(foodAllergies: value as String);
      case 'partnerInvite':
        state = state.copyWith(partnerInvite: value as bool);
      case 'partnerRelation':
        state = state.copyWith(partnerRelation: value as String);
      case 'onlyApproveMaster':
        state = state.copyWith(onlyApproveMaster: value as bool);
      case 'theme':
        state = state.copyWith(theme: value as String);
    }
  }

  /// Toggles membership of [value] in the named `List<String>` field —
  /// adds it if absent, removes it if present. Mirrors the mock's
  /// `toggleMultiSelect(key, value, el)`.
  void toggleListField(String field, String value) {
    if (!_listFields.contains(field)) {
      throw ArgumentError.value(field, 'field', 'Not a known list field');
    }
    List<String> current;
    switch (field) {
      case 'cycleSymptoms':
        current = state.cycleSymptoms;
      case 'cycleGoals':
        current = state.cycleGoals;
      case 'pregnantSymptoms':
        current = state.pregnantSymptoms;
      case 'cuisines':
        current = state.cuisines;
      case 'workouts':
        current = state.workouts;
      case 'notifications':
        current = state.notifications;
      case 'aiScope':
        current = state.aiScope;
      case 'partnerPermissions':
        current = state.partnerPermissions;
      case 'simplifiedSymptoms':
        current = state.simplifiedSymptoms;
      case 'simplifiedGoals':
        current = state.simplifiedGoals;
      default:
        return;
    }
    final next = current.contains(value)
        ? (List<String>.from(current)..remove(value))
        : (List<String>.from(current)..add(value));
    switch (field) {
      case 'cycleSymptoms':
        state = state.copyWith(cycleSymptoms: next);
      case 'cycleGoals':
        state = state.copyWith(cycleGoals: next);
      case 'pregnantSymptoms':
        state = state.copyWith(pregnantSymptoms: next);
      case 'cuisines':
        state = state.copyWith(cuisines: next);
      case 'workouts':
        state = state.copyWith(workouts: next);
      case 'notifications':
        state = state.copyWith(notifications: next);
      case 'aiScope':
        state = state.copyWith(aiScope: next);
      case 'partnerPermissions':
        state = state.copyWith(partnerPermissions: next);
      case 'simplifiedSymptoms':
        state = state.copyWith(simplifiedSymptoms: next);
      case 'simplifiedGoals':
        state = state.copyWith(simplifiedGoals: next);
    }
  }

  /// Restores the initial empty state — used when a user restarts
  /// onboarding or signs out.
  void reset() => state = const OnboardingState();
}

/// The cross-plan state contract fixed by plans/00-design-spec.md §10.
final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
