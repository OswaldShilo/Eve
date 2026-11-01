import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/home/data/appwrite_home_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  late MockTablesDB tables;
  late AppwriteHomeRepository repo;

  void stubRow(String tableId, Map<String, dynamic>? data) {
    if (data == null) {
      when(() => tables.getRow(databaseId: 'eve', tableId: tableId, rowId: 'u1'))
          .thenThrow(AppwriteException('Row not found', 404));
      return;
    }
    // Stub the row before starting the getRow stub: mocktail forbids nested when().
    final row = MockRow();
    when(() => row.data).thenReturn(data);
    when(() => tables.getRow(databaseId: 'eve', tableId: tableId, rowId: 'u1')).thenAnswer((_) async => row);
  }

  setUp(() {
    tables = MockTablesDB();
    final appwrite = MockAppwriteService();
    when(() => appwrite.tablesDb).thenReturn(tables);
    repo = AppwriteHomeRepository(appwrite);
  });

  test('reads the real name and a per-life-stage badge', () async {
    stubRow('profiles', {'name': 'Priya'});
    stubRow('life_stage_profiles', {'type': 'menopause'});
    final data = await repo.loadDashboard('u1');
    expect(data.greetingName, 'Priya');
    expect(data.phaseBadge, 'Menopause Tracking Active');
  });

  test('falls back to a generic greeting and badge when rows are missing or empty', () async {
    stubRow('profiles', null);
    stubRow('life_stage_profiles', {'type': null});
    final data = await repo.loadDashboard('u1');
    expect(data.greetingName, 'there');
    expect(data.phaseBadge, 'Welcome to EVE');
  });
}
