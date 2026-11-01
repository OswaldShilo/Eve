import '../../../shared/models/chat_message.dart';

/// One thread per couple, keyed by the primary user's uid. Sending goes
/// through the sendChatMessage function — the client never writes rows.
abstract class ChatRepository {
  /// Her own uid when she is the primary user; the primary user's uid when
  /// the signed-in user is a linked partner.
  Future<String> threadIdFor(String uid);

  Stream<List<ChatMessage>> watchThread(String threadUserId);

  Future<void> sendMessage(String threadUserId, String text);
}
