import 'row_parsing.dart';

/// Mirrors functions/shared/src/types.ts `ProfileRow`. Table `profiles`, rowId = uid.
class UserProfile {
  const UserProfile({
    required this.name,
    this.age,
    this.height,
    this.weight,
    this.country,
    this.lifeStage,
  });

  final String name;
  final int? age;
  final double? height; // centimeters
  final double? weight; // kilograms
  final String? country;
  final String? lifeStage;

  factory UserProfile.fromRow(Map<String, dynamic> data) => UserProfile(
        name: (data['name'] as String?) ?? '',
        age: parseInt(data['age']),
        height: parseDouble(data['height']),
        weight: parseDouble(data['weight']),
        country: data['country'] as String?,
        lifeStage: data['lifeStage'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'name': name,
        'age': age,
        'height': height,
        'weight': weight,
        'country': country,
        'lifeStage': lifeStage,
      };
}
