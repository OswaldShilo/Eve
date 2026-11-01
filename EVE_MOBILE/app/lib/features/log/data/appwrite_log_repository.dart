import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/live_rows.dart';
import '../../../shared/models/symptom_log.dart';
import 'log_repository.dart';

class AppwriteLogRepository implements LogRepository {
  AppwriteLogRepository(this._appwrite);

  final AppwriteService _appwrite;

  @override
  Stream<List<SymptomLog>> watchLogs(String uid) => liveRows<SymptomLog>(
        appwrite: _appwrite,
        tableId: AppwriteIds.symptomLogs,
        ownerColumn: 'userId',
        ownerId: uid,
        orderColumn: 'date',
        fromRow: (data, id) => SymptomLog.fromRow(data, id: id),
        compare: (a, b) => a.date.compareTo(b.date),
      );

  /// Owner-only permissions are what lets the server functions trust this
  /// row's userId (Plan 5 assumption 7).
  @override
  Future<void> addLog(String uid, SymptomLog log) async {
    await _appwrite.tablesDb.createRow(
      databaseId: AppwriteIds.databaseId,
      tableId: AppwriteIds.symptomLogs,
      rowId: ID.unique(),
      data: log.toRow(),
      permissions: [
        Permission.read(Role.user(uid)),
        Permission.update(Role.user(uid)),
        Permission.delete(Role.user(uid)),
      ],
    );
  }
}
