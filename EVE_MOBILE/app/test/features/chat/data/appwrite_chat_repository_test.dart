import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/chat/data/appwrite_chat_repository.dart';
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
  });

  test('threadIdFor: her own uid when she has no partner lookup row', () async {
    when(() => tables.getRow(databaseId: 'eve', tableId: 'partner_lookups', rowId: 'her'))
        .thenThrow(AppwriteException('Row not found', 404));
    expect(await AppwriteChatRepository(appwrite).threadIdFor('her'), 'her');
  });

  test('threadIdFor: the primary user when the caller is a linked partner', () async {
    final row = MockRow();
    when(() => row.data).thenReturn({'primaryUserId': 'her'});
    when(() => tables.getRow(databaseId: 'eve', tableId: 'partner_lookups', rowId: 'him')).thenAnswer((_) async => row);
    expect(await AppwriteChatRepository(appwrite).threadIdFor('him'), 'her');
  });

  test('sendMessage goes through the sendChatMessage function, never a direct row write', () async {
    when(() => appwrite.executeJson('sendChatMessage', any())).thenAnswer((_) async => {'messageId': 'm1'});
    await AppwriteChatRepository(appwrite).sendMessage('her', 'On my way.');
    verify(() => appwrite.executeJson('sendChatMessage', {'threadUserId': 'her', 'text': 'On my way.'})).called(1);
    verifyNever(() => tables.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ));
  });
}
