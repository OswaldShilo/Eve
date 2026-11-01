import 'package:flutter/material.dart';

class PartnerJoinScreen extends StatefulWidget {
  const PartnerJoinScreen({super.key, required this.onSubmit});

  /// Returns null on success, or a message to show.
  final Future<String?> Function(String code) onSubmit;

  @override
  State<PartnerJoinScreen> createState() => _PartnerJoinScreenState();
}

class _PartnerJoinScreenState extends State<PartnerJoinScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_code.text.trim().toUpperCase());
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join your partner')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the six-character code your partner shared with you. '
                'You will see only what she chooses to share.'),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Invite code'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _busy ? null : _submit, child: const Text('Join')),
          ],
        ),
      ),
    );
  }
}
