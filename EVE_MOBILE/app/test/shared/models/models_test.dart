import 'package:eve_app/shared/models/chat_message.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:eve_app/shared/models/partner_permissions.dart';
import 'package:eve_app/shared/models/partner_view.dart';
import 'package:eve_app/shared/models/preferences.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:eve_app/shared/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile round-trips and tolerates nulls', () {
    const profile = UserProfile(name: 'Priya', age: 29, height: 165, weight: 58, country: 'India', lifeStage: 'cycle');
    final back = UserProfile.fromRow(profile.toRow());
    expect(back.name, 'Priya');
    expect(back.age, 29);
    expect(back.lifeStage, 'cycle');
    expect(UserProfile.fromRow(const {'name': ''}).age, isNull);
  });

  test('LifeStageProfile.fromRow dispatches on type and toRow clears other branches', () {
    const cycle = CycleLifeStageProfile(
      cycleLength: 28, periodLength: 5, flow: 'moderate',
      cycleSymptoms: ['cramps'], cycleGoals: ['betterNutrition'], nutritionDiet: 'vegan',
    );
    final row = cycle.toRow();
    expect(row['type'], 'cycle');
    expect(row['dueDate'], isNull);
    expect(row['pregnantSymptoms'], isEmpty);
    expect(row['simplifiedGoals'], isEmpty);
    final back = LifeStageProfile.fromRow(row) as CycleLifeStageProfile;
    expect(back.cycleLength, 28);
    expect(back.nutritionDiet, 'vegan');

    final pregnant = PregnantLifeStageProfile(
      dueDate: DateTime.utc(2026, 6, 1), dueMethod: 'dueDate', highRisk: false, pregnancyType: 'single',
      medications: null, allergies: 'peanuts', prenatalVitamins: true, pregnantSymptoms: const ['swelling'],
    );
    final pregnantBack = LifeStageProfile.fromRow(pregnant.toRow()) as PregnantLifeStageProfile;
    expect(pregnantBack.dueDate, DateTime.utc(2026, 6, 1));
    expect(pregnantBack.prenatalVitamins, isTrue);

    const simplified = SimplifiedLifeStageProfile(type: 'menopause', simplifiedSymptoms: ['hotFlashes'], simplifiedGoals: []);
    expect(LifeStageProfile.fromRow(simplified.toRow()), isA<SimplifiedLifeStageProfile>());
    expect(LifeStageProfile.fromRow(const {'type': null}), isA<EmptyLifeStageProfile>());
  });

  test('SymptomLog parses Appwrite ISO datetimes with offsets', () {
    final log = SymptomLog.fromRow({
      'userId': 'u1',
      'date': '2026-03-14T00:00:00.000+00:00',
      'symptoms': ['cramps'],
      'mood': 'low',
      'painLevel': 6,
      'notes': '',
    }, id: 'log1');
    expect(log.id, 'log1');
    expect(log.date, DateTime.utc(2026, 3, 14));
    expect(log.toRow()['date'], '2026-03-14T00:00:00.000Z');
  });

  test('Preferences, PartnerPermissions, PartnerView and ChatMessage round-trip', () {
    const prefs = Preferences(
      selectedGoals: ['betterNutrition'], dietType: 'vegan', foodAllergies: '', cuisines: ['indian'],
      workoutPreference: ['yoga'], enabledReminders: ['morning'], enabledHelpAreas: ['nutrition'], selectedTheme: 'dark',
    );
    expect(Preferences.fromRow(prefs.toRow()).selectedTheme, 'dark');

    const perms = PartnerPermissions(approvedCategories: ['moodUpdates'], onlyApproveMode: true);
    expect(PartnerPermissions.fromRow(perms.toRow()).approvedCategories, ['moodUpdates']);

    final view = PartnerView.fromRow(const {
      'primaryUserId': 'u1', 'approvedCategories': ['moodUpdates'], 'recentMoodTrend': 'low',
      'supportSuggested': null, 'recomputedAt': '2026-03-14T10:00:00.000+00:00',
    });
    expect(view.recentMoodTrend, 'low');
    expect(view.supportSuggested, isNull);

    final message = ChatMessage.fromRow(const {
      'threadUserId': 'u1', 'senderRole': 'system', 'senderUserId': null, 'messageText': 'Eve: check in',
      'sentAt': '2026-03-14T10:00:00.000+00:00', 'type': 'system', 'category': 'moodUpdate', 'sourceLogId': 'log1',
    }, id: 'sys-log1');
    expect(message.id, 'sys-log1');
    expect(message.senderRole, 'system');
  });
}
