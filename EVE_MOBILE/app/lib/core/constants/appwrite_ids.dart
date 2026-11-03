/// Canonical Appwrite IDs — must match design-spec §10 and
/// functions/shared/src/ids.ts exactly. Replaces FirestorePaths.
class AppwriteIds {
  AppwriteIds._();

  static const String databaseId = 'eve';

  static const String profiles = 'profiles';
  static const String lifeStageProfiles = 'life_stage_profiles';
  static const String symptomLogs = 'symptom_logs';
  static const String preferences = 'preferences';
  static const String partnerLinks = 'partner_links';
  static const String partnerPermissions = 'partner_permissions';
  static const String partnerViews = 'partner_views';
  static const String partnerLookups = 'partner_lookups';
  static const String chatMessages = 'chat_messages';

  /// The one function the app executes (the free Cloud plan allows two
  /// functions); the constants below are its `route` values.
  static const String fnApi = 'eveApi';

  static const String fnPartnerInvites = 'partnerInvites';
  static const String fnSendChatMessage = 'sendChatMessage';
  static const String fnAiProxy = 'aiProxy';

  /// Realtime channel for every chat row the subscriber can read.
  static const String chatMessagesChannel = 'tablesdb.$databaseId.tables.$chatMessages.rows';
}
