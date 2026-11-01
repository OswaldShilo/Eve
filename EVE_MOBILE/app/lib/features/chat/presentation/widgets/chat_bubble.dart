import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

enum ChatSender { wife, partner, eveSystem }

class ChatMessageData {
  const ChatMessageData({required this.sender, required this.text});
  final ChatSender sender;
  final String text;
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessageData message;

  @override
  Widget build(BuildContext context) {
    if (message.sender == ChatSender.eveSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const EveMascot(emotion: EveEmotion.caring, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(message.text)),
          ],
        ),
      );
    }

    final isWife = message.sender == ChatSender.wife;
    return Align(
      alignment: isWife ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isWife ? const Color(0xFFFF2A6D) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isWife ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
