import '../../../shared/models/chat_message.dart';
import 'widgets/chat_bubble.dart';

ChatMessageData chatMessageDataFor(ChatMessage message) => ChatMessageData(
      sender: switch (message.senderRole) {
        'partner' => ChatSender.partner,
        'system' => ChatSender.eveSystem,
        _ => ChatSender.wife,
      },
      text: message.messageText,
    );
