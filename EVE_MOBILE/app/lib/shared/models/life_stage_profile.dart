import 'row_parsing.dart';

/// Mirrors `LifeStageProfileRow`. Table `life_stage_profiles`, rowId = uid.
/// One flattened row; `toRow()` always emits every column so saving one
/// branch clears the columns of the others.
abstract class LifeStageProfile {
  const LifeStageProfile();

  String? get type;

  factory LifeStageProfile.fromRow(Map<String, dynamic> data) {
    switch (data['type'] as String?) {
      case 'cycle':
        return CycleLifeStageProfile(
          cycleLength: parseInt(data['cycleLength']),
          periodLength: parseInt(data['periodLength']),
          flow: data['flow'] as String?,
          cycleSymptoms: parseStringList(data['cycleSymptoms']),
          cycleGoals: parseStringList(data['cycleGoals']),
          nutritionDiet: data['nutritionDiet'] as String?,
        );
      case 'pregnant':
        return PregnantLifeStageProfile(
          dueDate: parseDateTime(data['dueDate']),
          dueMethod: data['dueMethod'] as String?,
          highRisk: data['highRisk'] as bool?,
          pregnancyType: data['pregnancyType'] as String?,
          medications: data['medications'] as String?,
          allergies: data['allergies'] as String?,
          prenatalVitamins: data['prenatalVitamins'] as bool?,
          pregnantSymptoms: parseStringList(data['pregnantSymptoms']),
          currentWeek: parseInt(data['currentWeek']),
          nextAppointmentLabel: data['nextAppointmentLabel'] as String?,
          nextAppointmentAt: parseDateTime(data['nextAppointmentAt']),
          latestMilestone: data['latestMilestone'] as String?,
        );
      case 'conceive':
      case 'postpartum':
      case 'menopause':
        return SimplifiedLifeStageProfile(
          type: data['type'] as String,
          simplifiedSymptoms: parseStringList(data['simplifiedSymptoms']),
          simplifiedGoals: parseStringList(data['simplifiedGoals']),
        );
      default:
        return const EmptyLifeStageProfile();
    }
  }

  /// Branch-specific columns; merged over [blankRow] by [toRow].
  Map<String, dynamic> branchColumns();

  Map<String, dynamic> toRow() => {...blankRow(), 'type': type, ...branchColumns()};

  static Map<String, dynamic> blankRow() => {
        'type': null,
        'cycleLength': null,
        'periodLength': null,
        'flow': null,
        'cycleSymptoms': <String>[],
        'cycleGoals': <String>[],
        'nutritionDiet': null,
        'dueDate': null,
        'dueMethod': null,
        'highRisk': null,
        'pregnancyType': null,
        'medications': null,
        'allergies': null,
        'prenatalVitamins': null,
        'pregnantSymptoms': <String>[],
        'currentWeek': null,
        'nextAppointmentLabel': null,
        'nextAppointmentAt': null,
        'latestMilestone': null,
        'simplifiedSymptoms': <String>[],
        'simplifiedGoals': <String>[],
      };
}

class EmptyLifeStageProfile extends LifeStageProfile {
  const EmptyLifeStageProfile();

  @override
  String? get type => null;

  @override
  Map<String, dynamic> branchColumns() => const {};
}

class CycleLifeStageProfile extends LifeStageProfile {
  const CycleLifeStageProfile({
    this.cycleLength,
    this.periodLength,
    this.flow,
    this.cycleSymptoms = const [],
    this.cycleGoals = const [],
    this.nutritionDiet,
  });

  final int? cycleLength;
  final int? periodLength;
  final String? flow;
  final List<String> cycleSymptoms;
  final List<String> cycleGoals;
  final String? nutritionDiet;

  @override
  String get type => 'cycle';

  @override
  Map<String, dynamic> branchColumns() => {
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'flow': flow,
        'cycleSymptoms': cycleSymptoms,
        'cycleGoals': cycleGoals,
        'nutritionDiet': nutritionDiet,
      };
}

class PregnantLifeStageProfile extends LifeStageProfile {
  const PregnantLifeStageProfile({
    this.dueDate,
    this.dueMethod,
    this.highRisk,
    this.pregnancyType,
    this.medications,
    this.allergies,
    this.prenatalVitamins,
    this.pregnantSymptoms = const [],
    this.currentWeek,
    this.nextAppointmentLabel,
    this.nextAppointmentAt,
    this.latestMilestone,
  });

  final DateTime? dueDate;
  final String? dueMethod;
  final bool? highRisk;
  final String? pregnancyType;
  final String? medications;
  final String? allergies;
  final bool? prenatalVitamins;
  final List<String> pregnantSymptoms;
  final int? currentWeek;
  final String? nextAppointmentLabel;
  final DateTime? nextAppointmentAt;
  final String? latestMilestone;

  @override
  String get type => 'pregnant';

  @override
  Map<String, dynamic> branchColumns() => {
        'dueDate': formatDateTime(dueDate),
        'dueMethod': dueMethod,
        'highRisk': highRisk,
        'pregnancyType': pregnancyType,
        'medications': medications,
        'allergies': allergies,
        'prenatalVitamins': prenatalVitamins,
        'pregnantSymptoms': pregnantSymptoms,
        'currentWeek': currentWeek,
        'nextAppointmentLabel': nextAppointmentLabel,
        'nextAppointmentAt': formatDateTime(nextAppointmentAt),
        'latestMilestone': latestMilestone,
      };
}

class SimplifiedLifeStageProfile extends LifeStageProfile {
  const SimplifiedLifeStageProfile({
    required this.type,
    this.simplifiedSymptoms = const [],
    this.simplifiedGoals = const [],
  });

  @override
  final String type; // 'conceive' | 'postpartum' | 'menopause'
  final List<String> simplifiedSymptoms;
  final List<String> simplifiedGoals;

  @override
  Map<String, dynamic> branchColumns() => {
        'simplifiedSymptoms': simplifiedSymptoms,
        'simplifiedGoals': simplifiedGoals,
      };
}
