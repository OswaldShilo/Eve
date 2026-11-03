import 'package:flutter/material.dart';

import 'package:eve_app/core/config/app_env.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

/// Debug-only control that calls `client.ping()` so a developer can confirm
/// the app reaches the configured Appwrite project. The result (success or
/// the error) is shown in a snack bar together with the endpoint and project.
class AppwritePingButton extends StatefulWidget {
  const AppwritePingButton({super.key, required this.ping});

  final Future<String> Function() ping;

  @override
  State<AppwritePingButton> createState() => _AppwritePingButtonState();
}

class _AppwritePingButtonState extends State<AppwritePingButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    String message;
    var ok = false;
    try {
      final reply = await widget.ping();
      ok = true;
      message = 'Appwrite connected: $reply';
    } catch (e) {
      message = 'Appwrite ping failed: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: Key(ok ? 'appwrite-ping-ok' : 'appwrite-ping-failed'),
        backgroundColor: ok ? EveColors.fertileTeal : EveColors.rubyMain,
        content: Text('$message\n${AppEnv.endpoint} · ${AppEnv.projectId}'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ping Appwrite',
      child: EveChip(
        key: const Key('appwrite-ping'),
        label: _busy ? 'Pinging…' : 'Ping Appwrite',
        onTap: _run,
      ),
    );
  }
}
