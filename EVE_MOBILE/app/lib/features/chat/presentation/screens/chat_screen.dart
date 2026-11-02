import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';
import 'package:eve_app/shared/widgets/eve_status_view.dart';

const _defaultThread = [
  ChatMessageData(
    sender: ChatSender.wife,
    text: 'I have completed my daily health check-in.',
  ),
  ChatMessageData(
    sender: ChatSender.partner,
    text: 'Great to hear. How are you feeling today?',
  ),
  ChatMessageData(
    sender: ChatSender.wife,
    text: 'I am feeling slightly low on energy and experiencing mild cramps.',
  ),
  ChatMessageData(
    sender: ChatSender.eveSystem,
    text:
        'Eve: Maya recorded low energy and mild cramps today. Consider offering support.',
  ),
  ChatMessageData(
    sender: ChatSender.partner,
    text: 'I am bringing dinner home and preparing a warm compress for you.',
  ),
  ChatMessageData(sender: ChatSender.wife, text: 'Thank you, I appreciate it.'),
];

class ChatScreen extends StatefulWidget {
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

  /// Sends one message. Completes when it has been sent; throws when it
  /// could not be, in which case the typed text stays in the input.
  final Future<void> Function(String text)? onSendMessage;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _quickReplies = [
    'Sending support',
    'You are doing great',
    'Do you need anything?',
  ];

  // Owned by the state so live thread updates (which rebuild the screen)
  // never wipe what she is typing.
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {required bool fromInput}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || widget.onSendMessage == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSendMessage!(trimmed);
      if (fromInput && mounted) _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your message was not sent. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    final initial = widget.partnerName.isEmpty
        ? '?'
        : widget.partnerName.substring(0, 1).toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              // `.chat-header`
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: EveColors.outline, width: 3.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: eveOutlined(
                        color: EveColors.partnerBlue,
                        shape: BoxShape.circle,
                        shadow: 4,
                      ),
                      child: Text(
                        initial,
                        style: text.titleMedium!.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partnerName,
                            style: text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.partnerStatus,
                            style: text.labelSmall!.copyWith(
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // `.chat-thread`: newest at the bottom, list starts scrolled
              // there and stays there as messages arrive.
              Expanded(
                child: widget.thread.isEmpty
                    ? const EveStatusView(
                        key: Key('chat-empty'),
                        emotion: EveEmotion.warm,
                        title: 'No messages yet',
                        message:
                            'When your partner joins with your invite code, your conversation and '
                            'Eve’s gentle nudges will appear here.',
                      )
                    : ListView.builder(
                        key: const Key('chat-thread'),
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.thread.length,
                        itemBuilder: (context, i) => ChatBubble(
                          message: widget.thread[widget.thread.length - 1 - i],
                        ),
                      ),
              ),
              // `.quick-replies`
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickReplies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Center(
                    child: EveChip(
                      label: _quickReplies[i],
                      size: EveChipSize.regular,
                      onTap: widget.onSendMessage == null || _sending
                          ? null
                          : () => _send(_quickReplies[i], fromInput: false),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // `.chat-input-bar`
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: eveOutlined(
                        color: tokens.card,
                        radius: 18,
                        shadow: 4,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        key: const Key('chat-input-field'),
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) => _send(v, fromInput: true),
                        style: text.bodyMedium!.copyWith(color: tokens.ink),
                        cursorColor: EveColors.rubyMain,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: text.bodyMedium!.copyWith(
                            color: tokens.muted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send',
                    child: GestureDetector(
                      key: const Key('chat-send-button'),
                      onTap: () => _send(_controller.text, fromInput: true),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: eveOutlined(
                          color: EveColors.rubyMain,
                          radius: 18,
                          shadow: 4,
                        ),
                        child: _sending
                            ? const SizedBox(
                                key: Key('chat-sending'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.chat,
        onHomeTap: () => widget.onNavigateHome?.call(),
        onChatTap: () => widget.onNavigateChat?.call(),
        onLogTap: () => widget.onNavigateLog?.call(),
      ),
    );
  }
}
