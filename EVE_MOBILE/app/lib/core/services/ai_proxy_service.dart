import '../constants/appwrite_ids.dart';
import 'appwrite_service.dart';

/// Client for the aiProxy Appwrite Function — the only way the app reaches
/// an AI model (EVE2_PRD §10.1). Keys never leave the server.
class AiProxyService {
  AiProxyService(this._appwrite);

  final AppwriteService _appwrite;

  Future<String> generateDoctorSummary({int days = 90}) async {
    final result = await _appwrite.executeJson(AppwriteIds.fnAiProxy, {'feature': 'doctorSummary', 'days': days});
    final summary = result['summary'] as String?;
    if (summary == null) throw StateError('aiProxy returned no summary text.');
    return summary;
  }

  Future<String> checkIn(String message) async {
    final result = await _appwrite.executeJson(AppwriteIds.fnAiProxy, {'feature': 'checkIn', 'message': message});
    final reply = result['reply'] as String?;
    if (reply == null) throw StateError('aiProxy returned no reply.');
    return reply;
  }
}
