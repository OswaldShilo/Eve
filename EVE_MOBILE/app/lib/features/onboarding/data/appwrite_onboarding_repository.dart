import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../shared/models/partner_permissions.dart';
import '../domain/onboarding_state.dart';
import 'onboarding_repository.dart';
import 'onboarding_value_mappers.dart';

/// Saves the completed survey into the singleton rows `onUserCreate`
/// (Plan 5 Task 5) created at sign-up. Uses updateRow, not upsert: clients
/// have no create permission on these tables by design.
class AppwriteOnboardingRepository implements OnboardingRepository {
  AppwriteOnboardingRepository(this._appwrite);

  final AppwriteService _appwrite;

  Future<void> _update(String tableId, String uid, Map<String, dynamic> data) => _appwrite.tablesDb.updateRow(
        databaseId: AppwriteIds.databaseId,
        tableId: tableId,
        rowId: uid,
        data: data,
      );

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    await _update(AppwriteIds.profiles, uid, profileFor(state).toRow());
    await _update(AppwriteIds.lifeStageProfiles, uid, lifeStageProfileFor(state).toRow());
    await _update(AppwriteIds.preferences, uid, preferencesFor(state).toRow());

    if (!state.partnerInvite) return null;

    await _update(
      AppwriteIds.partnerPermissions,
      uid,
      PartnerPermissions(
        approvedCategories: categoryKeys(state.partnerPermissions),
        onlyApproveMode: state.onlyApproveMaster,
      ).toRow(),
    );
    final result = await _appwrite.executeJson(AppwriteIds.fnPartnerInvites, {
      'action': 'createInvite',
      'relationshipType': relationshipKey(state.partnerRelation),
    });
    return result['inviteCode'] as String?;
  }
}
