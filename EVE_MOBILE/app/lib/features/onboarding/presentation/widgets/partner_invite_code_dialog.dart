import 'package:flutter/material.dart';

class PartnerInviteCodeDialog extends StatelessWidget {
  const PartnerInviteCodeDialog({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your partner invite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share this code with your partner so they can join you in EVE. '
            'They will only ever see what you have chosen to share.',
          ),
          const SizedBox(height: 16),
          SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
    );
  }
}
