import '../../../shared/models/symptom_log.dart';

abstract class LogRepository {
  /// Her logs, oldest first, updating live.
  Stream<List<SymptomLog>> watchLogs(String uid);

  Future<void> addLog(String uid, SymptomLog log);
}
