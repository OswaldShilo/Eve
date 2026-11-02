/// Helpers shared by every model in this directory. Appwrite returns
/// datetimes as ISO 8601 strings (e.g. `2026-03-14T00:00:00.000+00:00`),
/// numbers as int or double, and arrays as `List<dynamic>`.
DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.parse(value as String).toUtc();
}

String? formatDateTime(DateTime? value) => value?.toUtc().toIso8601String();

List<String> parseStringList(Object? value) =>
    value == null ? const [] : List<String>.from(value as List);

int? parseInt(Object? value) => value == null ? null : (value as num).toInt();

double? parseDouble(Object? value) => value == null ? null : (value as num).toDouble();
