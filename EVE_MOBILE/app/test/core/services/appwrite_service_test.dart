import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockAccount extends Mock implements Account {}

class MockTablesDB extends Mock implements TablesDB {}

class MockFunctions extends Mock implements Functions {}

class MockRealtime extends Mock implements Realtime {}

class MockUser extends Mock implements models.User {}

class MockExecution extends Mock implements models.Execution {}

void main() {
  late MockAccount account;
  late MockFunctions functions;
  late AppwriteService service;

  setUp(() {
    account = MockAccount();
    functions = MockFunctions();
    service = AppwriteService(
      client: MockClient(),
      account: account,
      tablesDb: MockTablesDB(),
      functions: functions,
      realtime: MockRealtime(),
    );
  });

  test('currentUserId returns the signed-in user id', () async {
    final user = MockUser();
    when(() => user.$id).thenReturn('u1');
    when(() => account.get()).thenAnswer((_) async => user);
    expect(await service.currentUserId(), 'u1');
  });

  test('currentUserId returns null when there is no session (401)', () async {
    when(() => account.get()).thenThrow(AppwriteException('missing scope', 401));
    expect(await service.currentUserId(), isNull);
  });

  test('executeJson sends a synchronous JSON execution and decodes the response', () async {
    final execution = MockExecution();
    when(() => execution.responseStatusCode).thenReturn(200);
    when(() => execution.responseBody).thenReturn('{"inviteCode":"ABC234"}');
    when(() => functions.createExecution(
          functionId: any(named: 'functionId'),
          body: any(named: 'body'),
          xasync: any(named: 'xasync'),
        )).thenAnswer((_) async => execution);

    final result = await service.executeJson('partnerInvites', {'action': 'createInvite'});

    expect(result, {'inviteCode': 'ABC234'});
    verify(() => functions.createExecution(
          functionId: 'partnerInvites',
          body: '{"action":"createInvite"}',
          xasync: false,
        )).called(1);
  });

  test('executeJson throws FunctionCallException with the server message on 4xx/5xx', () async {
    final execution = MockExecution();
    when(() => execution.responseStatusCode).thenReturn(403);
    when(() => execution.responseBody).thenReturn('{"error":"You are not part of this conversation."}');
    when(() => functions.createExecution(
          functionId: any(named: 'functionId'),
          body: any(named: 'body'),
          xasync: any(named: 'xasync'),
        )).thenAnswer((_) async => execution);

    expect(
      () => service.executeJson('sendChatMessage', {}),
      throwsA(isA<FunctionCallException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.message, 'message', 'You are not part of this conversation.')),
    );
  });
}
