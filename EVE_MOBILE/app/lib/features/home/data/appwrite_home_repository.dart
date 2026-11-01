import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../shared/models/life_stage_profile.dart';
import '../../../shared/models/user_profile.dart';
import 'home_repository.dart';

class AppwriteHomeRepository implements HomeRepository {
  AppwriteHomeRepository(this._appwrite);

  final AppwriteService _appwrite;

  Future<Map<String, dynamic>?> _row(String tableId, String uid) async {
    try {
      final row = await _appwrite.tablesDb.getRow(databaseId: AppwriteIds.databaseId, tableId: tableId, rowId: uid);
      return row.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null; // onUserCreate not finished yet
      rethrow;
    }
  }

  @override
  Future<HomeDashboardData> loadDashboard(String uid) async {
    final profileData = await _row(AppwriteIds.profiles, uid);
    final lifeStageData = await _row(AppwriteIds.lifeStageProfiles, uid);

    final name = profileData == null ? '' : UserProfile.fromRow(profileData).name;
    final lifeStage = lifeStageData == null ? const EmptyLifeStageProfile() : LifeStageProfile.fromRow(lifeStageData);
    final type = lifeStage.type;
    final phaseBadge = switch (type) {
      null => 'Welcome to EVE',
      'pregnant' => 'Pregnancy Tracking Active',
      'cycle' => 'Cycle Tracking Active',
      _ => '${type[0].toUpperCase()}${type.substring(1)} Tracking Active',
    };
    return HomeDashboardData(greetingName: name.isEmpty ? 'there' : name, phaseBadge: phaseBadge);
  }
}
