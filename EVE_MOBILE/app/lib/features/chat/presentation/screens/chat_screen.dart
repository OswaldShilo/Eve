import 'package:flutter/material.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

const _defaultThread = [
  ChatMessageData(sender: ChatSender.wife, text: 'I have completed my daily health check-in.'),
  ChatMessageData(sender: ChatSender.partner, text: 'Great to hear. How are you feeling today?'),
  ChatMessageData(sender: ChatSender.wife, text: 'I am feeling slightly low on energy and experiencing mild cramps.'),
  ChatMessageData(
    sender: ChatSender.eveSystem,
    text: 'Eve: Maya recorded low energy and mild cramps today. Consider offering support.',
  ),
  ChatMessageData(sender: ChatSender.partner, text: 'I am bringing dinner home and preparing a warm compress for you.'),
  ChatMessageData(sender: ChatSender.wife, text: 'Thank you, I appreciate it.'),
];

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    this.partnerName = 'Ryan',
    this.partnerStatus = 'Partner • Active today',
    this.thread = _defaultThread,
    this.onSendMessage,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
  });

  final String partnerName;
  final String partnerStatus;
  final List<ChatMessageData> thread;
  final void Function(String text)? onSendMessage;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;

  static const _quickReplies = ['Sending support', 'You are doing great', 'Do you need anything?'];

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(partnerName.substring(0, 1))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partnerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(partnerStatus, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final m in thread) ChatBubble(message: m)],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final reply in _quickReplies)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(reply),
                      onPressed: () => onSendMessage?.call(reply),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input-field'),
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      onSendMessage?.call(controller.text.trim());
                      controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.chat,
        onHomeTap: () => onNavigateHome?.call(),
        onChatTap: () => onNavigateChat?.call(),
        onLogTap: () => onNavigateLog?.call(),
      ),
    );
  }
}
