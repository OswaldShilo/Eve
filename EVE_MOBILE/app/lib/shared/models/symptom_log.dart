import 'row_parsing.dart';

/// Mirrors `SymptomLogRow`. Table `symptom_logs`, rowId = ID.unique().
class SymptomLog {
  const SymptomLog({
    this.id,
    required this.userId,
    required this.date,
    this.symptoms = const [],
    this.mood,
    this.painLevel,
    this.notes = '',
  });

  final String? id;
  final String userId;
  final DateTime date;
  final List<String> symptoms;
  final String? mood; // great | good | okay | low | difficult
  final int? painLevel; // 0-10
  final String notes;

  factory SymptomLog.fromRow(Map<String, dynamic> data, {String? id}) => SymptomLog(
        id: id,
        userId: data['userId'] as String,
        date: parseDateTime(data['date'])!,
        symptoms: parseStringList(data['symptoms']),
        mood: data['mood'] as String?,
        painLevel: parseInt(data['painLevel']),
        notes: (data['notes'] as String?) ?? '',
      );

  Map<String, dynamic> toRow() => {
        'userId': userId,
        'date': formatDateTime(date),
        'symptoms': symptoms,
        'mood': mood,
        'painLevel': painLevel,
        'notes': notes,
      };
}
