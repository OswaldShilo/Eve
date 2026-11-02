import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

enum ChatSender { wife, partner, eveSystem }

class ChatMessageData {
  const ChatMessageData({required this.sender, required this.text, bool? mine})
    : mine = mine ?? sender == ChatSender.wife;
  final ChatSender sender;
  final String text;

  /// Sent by whoever is viewing the chat: drawn on the right. Defaults to
  /// "she sent it" (the primary user's view); a linked partner sees his own
  /// messages on the right instead.
  final bool mine;
}

/// `.chat-bubble`: outlined bubble, ruby for her messages and
/// `--partner-blue` for the partner's, with the tail corner squared off on
/// the sender's side; `.eve-system` messages are centred soft cards with a
/// mini Eve.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessageData message;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme.bodyMedium!;

    if (message.sender == ChatSender.eveSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.98,
            child: Container(
              key: const Key('chat-bubble-eve'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: eveOutlined(
                color: tokens.soft,
                radius: 18,
                shadow: 5,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: RepaintBoundary(
                      child: EveMascot(emotion: EveEmotion.caring, size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message.text,
                      style: text.copyWith(fontSize: 13.4, color: tokens.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hers = message.sender == ChatSender.wife;
    final mine = message.mine;
    const big = Radius.circular(20);
    const tail = Radius.circular(4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.82,
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              key: Key(hers ? 'chat-bubble-her' : 'chat-bubble-partner'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hers ? EveColors.rubyMain : EveColors.partnerBlue,
                borderRadius: BorderRadius.only(
                  topLeft: big,
                  topRight: big,
                  bottomLeft: mine ? big : tail,
                  bottomRight: mine ? tail : big,
                ),
                border: Border.all(color: EveColors.outline, width: 3.5),
                boxShadow: const [
                  BoxShadow(color: EveColors.outline, offset: Offset(0, 4)),
                ],
              ),
              child: Text(
                message.text,
                style: text.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
