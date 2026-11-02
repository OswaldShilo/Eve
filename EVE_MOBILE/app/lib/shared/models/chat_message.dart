import 'row_parsing.dart';

/// Mirrors `ChatMessageRow`. Table `chat_messages`. Read-only on the client:
/// messages are sent through the `sendChatMessage` function.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.threadUserId,
    required this.senderRole,
    this.senderUserId,
    required this.messageText,
    required this.sentAt,
    required this.type,
    this.category,
    this.sourceLogId,
  });

  final String? id;
  final String threadUserId;
  final String senderRole; // her | partner | system
  final String? senderUserId;
  final String messageText;
  final DateTime sentAt;
  final String type; // text | system
  final String? category;
  final String? sourceLogId;

  factory ChatMessage.fromRow(Map<String, dynamic> data, {String? id}) => ChatMessage(
        id: id,
        threadUserId: data['threadUserId'] as String,
        senderRole: data['senderRole'] as String,
        senderUserId: data['senderUserId'] as String?,
        messageText: data['messageText'] as String,
        sentAt: parseDateTime(data['sentAt'])!,
        type: data['type'] as String,
        category: data['category'] as String?,
        sourceLogId: data['sourceLogId'] as String?,
      );
}
