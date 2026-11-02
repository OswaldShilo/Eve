import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../constants/appwrite_ids.dart';
import 'appwrite_service.dart';

/// Live list of one table's rows where [ownerColumn] == [ownerId]: the
/// current page, then every realtime create/update/delete. Subscribes
/// BEFORE listing so nothing written in between is missed; rows are keyed
/// by id so the overlap never duplicates. Realtime only delivers rows the
/// signed-in user may read, and the owner check below filters the rest.
Stream<List<T>> liveRows<T>({
  required AppwriteService appwrite,
  required String tableId,
  required String ownerColumn,
  required String ownerId,
  required String orderColumn,
  required T Function(Map<String, dynamic> data, String id) fromRow,
  required int Function(T a, T b) compare,
}) {
  final items = <String, T>{};
  RealtimeSubscription? subscription;
  late final StreamController<List<T>> controller;
  List<T> snapshot() => items.values.toList()..sort(compare);

  controller = StreamController<List<T>>(
    onListen: () async {
      subscription = appwrite.realtime.subscribe(
        ['tablesdb.${AppwriteIds.databaseId}.tables.$tableId.rows'],
        queries: [Query.equal(ownerColumn, ownerId)],
      );
      subscription!.stream.listen((message) {
        final payload = message.payload;
        if (payload[ownerColumn] != ownerId) return;
        final id = payload[r'$id'] as String;
        if (message.events.any((event) => event.endsWith('.delete'))) {
          items.remove(id);
        } else {
          items[id] = fromRow(payload, id);
        }
        if (!controller.isClosed) controller.add(snapshot());
      });
      try {
        final page = await appwrite.tablesDb.listRows(
          databaseId: AppwriteIds.databaseId,
          tableId: tableId,
          queries: [Query.equal(ownerColumn, ownerId), Query.orderAsc(orderColumn), Query.limit(500)],
        );
        for (final row in page.rows) {
          items.putIfAbsent(row.$id, () => fromRow(row.data, row.$id));
        }
        if (!controller.isClosed) controller.add(snapshot());
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    },
    onCancel: () => subscription?.unsubscribe(),
  );
  return controller.stream;
}
