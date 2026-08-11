/// Canonical Firestore path builders. Every path here matches
/// plans/00-design-spec.md §10 exactly — this is the single source of truth
/// other plans (1, 5, 7) read and write against. Do not invent new paths
/// elsewhere; add a builder here instead.
class FirestorePaths {
  FirestorePaths._();

  static String userDoc(String uid) => 'users/$uid';

  static String lifeStageProfile(String uid) =>
      'users/$uid/lifeStageProfile/current';

  static String logsCollection(String uid) => 'users/$uid/logs';

  static String log(String uid, String logId) => 'users/$uid/logs/$logId';

  static String goalsPreferences(String uid) => 'users/$uid/preferences/goals';

  static String notificationPreferences(String uid) =>
      'users/$uid/preferences/notifications';

  static String aiScope(String uid) => 'users/$uid/preferences/aiScope';

  static String theme(String uid) => 'users/$uid/preferences/theme';

  static String partnerLink(String uid) => 'users/$uid/partnerLink/current';

  static String partnerPermissions(String uid) =>
      'users/$uid/partnerPermissions/current';

  static String partnerView(String uid) => 'users/$uid/partnerView/current';

  static String partnerLinksReverse(String partnerUid) =>
      'partnerLinks/$partnerUid';

  static String chatCollection(String uid) => 'users/$uid/chat';

  static String chatMessage(String uid, String messageId) =>
      'users/$uid/chat/$messageId';
}
