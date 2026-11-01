import '../../../shared/models/chat_message.dart';
import 'widgets/chat_bubble.dart';

/// Maps a stored message to a bubble. [viewerIsPartner] is true when the
/// signed-in user is the linked partner (not the thread owner): his own
/// messages then sit on the right and hers on the left. Colours still
/// follow who sent it (ruby = her, blue = partner).
ChatMessageData chatMessageDataFor(
  ChatMessage message, {
  bool viewerIsPartner = false,
}) {
  final sender = switch (message.senderRole) {
    'partner' => ChatSender.partner,
    'system' => ChatSender.eveSystem,
    _ => ChatSender.wife,
  };
  return ChatMessageData(
    sender: sender,
    text: message.messageText,
    mine: viewerIsPartner
        ? sender == ChatSender.partner
        : sender == ChatSender.wife,
  );
}
