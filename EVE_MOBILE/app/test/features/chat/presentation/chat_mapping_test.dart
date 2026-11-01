import 'package:eve_app/features/chat/presentation/chat_mapping.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('senderRole maps to the Plan 1 bubble types', () {
    ChatMessage message(String role) => ChatMessage(
          threadUserId: 'her', senderRole: role, messageText: role, sentAt: DateTime.utc(2026), type: 'text',
        );
    expect(chatMessageDataFor(message('her')).sender, ChatSender.wife);
    expect(chatMessageDataFor(message('partner')).sender, ChatSender.partner);
    expect(chatMessageDataFor(message('system')).sender, ChatSender.eveSystem);
    expect(chatMessageDataFor(message('her')).text, 'her');
  });
}
