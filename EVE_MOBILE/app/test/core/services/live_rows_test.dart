import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/core/services/live_rows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRowList extends Mock implements models.RowList {}

class MockRow extends Mock implements models.Row {}

models.Row row(String id, Map<String, dynamic> data) {
  final r = MockRow();
  when(() => r.$id).thenReturn(id);
  when(() => r.data).thenReturn({...data, r'$id': id});
  return r;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Object>[]);
    registerFallbackValue(<String>[]);
  });

  test('emits the initial page, then applies realtime creates and deletes for the owner only', () async {
    final appwrite = MockAppwriteService();
    final tables = MockTablesDB();
    final realtime = MockRealtime();
    final events = StreamController<RealtimeMessage>();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => appwrite.realtime).thenReturn(realtime);
    when(() => realtime.subscribe(any(), queries: any(named: 'queries'))).thenReturn(RealtimeSubscription(
      close: () async {},
      unsubscribe: () async => events.close(),
      update: ({channels, queries}) async {},
      channels: const ['tablesdb.eve.tables.symptom_logs.rows'],
      queries: const [],
      controller: events,
    ));
    final page = MockRowList();
    final first = row('a', {'userId': 'u1', 'n': 1}); // built outside when(): mocktail forbids nested stubbing
    when(() => page.rows).thenReturn([first]);
    when(() => tables.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          queries: any(named: 'queries'),
        )).thenAnswer((_) async => page);

    final stream = liveRows<int>(
      appwrite: appwrite,
      tableId: 'symptom_logs',
      ownerColumn: 'userId',
      ownerId: 'u1',
      orderColumn: 'n',
      fromRow: (data, id) => data['n'] as int,
      compare: (a, b) => a.compareTo(b),
    );
    final emissions = <List<int>>[];
    final sub = stream.listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, [1]);

    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.b.create'],
      payload: const {r'$id': 'b', 'userId': 'u1', 'n': 2},
      channels: const [],
      timestamp: '',
    ));
    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.x.create'],
      payload: const {r'$id': 'x', 'userId': 'someone-else', 'n': 9},
      channels: const [],
      timestamp: '',
    ));
    await pumpEventQueue();
    expect(emissions.last, [1, 2]);

    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.a.delete'],
      payload: const {r'$id': 'a', 'userId': 'u1', 'n': 1},
      channels: const [],
      timestamp: '',
    ));
    await pumpEventQueue();
    expect(emissions.last, [2]);

    await sub.cancel();
  });
}
