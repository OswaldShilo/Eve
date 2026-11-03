import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/onboarding/data/appwrite_onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  late MockAppwriteService appwrite;
  late MockTablesDB tables;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    appwrite = MockAppwriteService();
    tables = MockTablesDB();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => tables.updateRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async => MockRow());
  });

  List<String> updatedTables() => verify(() => tables.updateRow(
        databaseId: 'eve',
        tableId: captureAny(named: 'tableId'),
        rowId: 'u1',
        data: any(named: 'data'),
      )).captured.cast<String>();

  test('without a partner: updates profile, life stage and preferences only, returns null', () async {
    final code = await AppwriteOnboardingRepository(appwrite).saveOnboarding(
      'u1',
      const OnboardingState(name: 'Asha', lifeStage: 'cycle', notifications: ['Morning reminder'], partnerInvite: false),
    );

    expect(code, isNull);
    expect(updatedTables(), ['profiles', 'life_stage_profiles', 'preferences']);
    verifyNever(() => appwrite.executeJson(any(), any()));
  });

  test('with a partner: saves permissions with category keys and creates the invite', () async {
    when(() => appwrite.executeJson('partnerInvites', any())).thenAnswer((_) async => {'inviteCode': 'ABC234'});

    final code = await AppwriteOnboardingRepository(appwrite).saveOnboarding(
      'u1',
      const OnboardingState(
        lifeStage: 'pregnant',
        partnerInvite: true,
        partnerRelation: 'Husband',
        partnerPermissions: ['Mood updates'],
        onlyApproveMaster: true,
      ),
    );

    expect(code, 'ABC234');
    // One verify capturing tableId and data together: mocktail marks calls as
    // verified, so a second verify over the same calls would match nothing.
    final captured = verify(() => tables.updateRow(
          databaseId: 'eve',
          tableId: captureAny(named: 'tableId'),
          rowId: 'u1',
          data: captureAny(named: 'data'),
        )).captured;
    final tablesInOrder = [for (var i = 0; i < captured.length; i += 2) captured[i] as String];
    expect(tablesInOrder, ['profiles', 'life_stage_profiles', 'preferences', 'partner_permissions']);
    final permissionsData = captured[tablesInOrder.indexOf('partner_permissions') * 2 + 1] as Map;
    expect(permissionsData['approvedCategories'], ['moodUpdates']);
    verify(() => appwrite.executeJson('partnerInvites', {'action': 'createInvite', 'relationshipType': 'husband'})).called(1);
  });

  test('a missing database (404 database_not_found) propagates and stops before later tables', () async {
    when(() => tables.updateRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async =>
        throw AppwriteException("Database with the requested ID 'eve' could not be found.", 404, 'database_not_found'));

    await expectLater(
      AppwriteOnboardingRepository(appwrite).saveOnboarding('u1', const OnboardingState(name: 'Asha', partnerInvite: true)),
      throwsA(isA<AppwriteException>().having((e) => e.type, 'type', 'database_not_found')),
    );
    expect(updatedTables(), ['profiles']);
    verifyNever(() => appwrite.executeJson(any(), any()));
  });
}
