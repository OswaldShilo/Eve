import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/live_rows.dart';
import '../../../shared/models/chat_message.dart';
import 'chat_repository.dart';

class AppwriteChatRepository implements ChatRepository {
  AppwriteChatRepository(this._appwrite);

  final AppwriteService _appwrite;

  @override
  Future<String> threadIdFor(String uid) async {
    try {
      final lookup = await _appwrite.tablesDb.getRow(
        databaseId: AppwriteIds.databaseId,
        tableId: AppwriteIds.partnerLookups,
        rowId: uid,
      );
      return lookup.data['primaryUserId'] as String;
    } on AppwriteException catch (e) {
      if (e.code == 404) return uid; // she is the primary user
      rethrow;
    }
  }

  @override
  Stream<List<ChatMessage>> watchThread(String threadUserId) => liveRows<ChatMessage>(
        appwrite: _appwrite,
        tableId: AppwriteIds.chatMessages,
        ownerColumn: 'threadUserId',
        ownerId: threadUserId,
        orderColumn: 'sentAt',
        fromRow: (data, id) => ChatMessage.fromRow(data, id: id),
        compare: (a, b) => a.sentAt.compareTo(b.sentAt),
      );

  @override
  Future<void> sendMessage(String threadUserId, String text) async {
    await _appwrite.executeJson(AppwriteIds.fnSendChatMessage, {'threadUserId': threadUserId, 'text': text});
  }
}
