import 'package:eve_app/core/constants/appwrite_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database, table and function IDs match design-spec §10', () {
    expect(AppwriteIds.databaseId, 'eve');
    expect(AppwriteIds.profiles, 'profiles');
    expect(AppwriteIds.lifeStageProfiles, 'life_stage_profiles');
    expect(AppwriteIds.symptomLogs, 'symptom_logs');
    expect(AppwriteIds.preferences, 'preferences');
    expect(AppwriteIds.partnerLinks, 'partner_links');
    expect(AppwriteIds.partnerPermissions, 'partner_permissions');
    expect(AppwriteIds.partnerViews, 'partner_views');
    expect(AppwriteIds.partnerLookups, 'partner_lookups');
    expect(AppwriteIds.chatMessages, 'chat_messages');
    expect(AppwriteIds.fnPartnerInvites, 'partnerInvites');
    expect(AppwriteIds.fnSendChatMessage, 'sendChatMessage');
    expect(AppwriteIds.fnAiProxy, 'aiProxy');
  });

  test('chat realtime channel', () {
    expect(AppwriteIds.chatMessagesChannel, 'tablesdb.eve.tables.chat_messages.rows');
  });
}
