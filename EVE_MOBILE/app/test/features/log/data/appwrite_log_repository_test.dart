import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/log/data/appwrite_log_repository.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test('addLog creates an owner-only row with a unique id', () async {
    final appwrite = MockAppwriteService();
    final tables = MockTablesDB();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => tables.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
          permissions: any(named: 'permissions'),
        )).thenAnswer((_) async => MockRow());

    await AppwriteLogRepository(appwrite).addLog(
      'u1',
      SymptomLog(userId: 'u1', date: DateTime.utc(2026, 3, 14), mood: 'low', painLevel: 3),
    );

    final captured = verify(() => tables.createRow(
          databaseId: 'eve',
          tableId: 'symptom_logs',
          rowId: captureAny(named: 'rowId'),
          data: captureAny(named: 'data'),
          permissions: captureAny(named: 'permissions'),
        )).captured;
    expect(captured[0], isNot('u1')); // ID.unique(), not a fixed id
    expect((captured[1] as Map)['mood'], 'low');
    expect(captured[2], ['read("user:u1")', 'update("user:u1")', 'delete("user:u1")']);
  });
}
