import 'dart:convert';

import 'package:appwrite/appwrite.dart';

/// Appwrite native push (no FCM/APNs). Subscribing with `null` topics
/// listens on the signed-in user's own channel, which is what the server's
/// `messaging.createPush(users: [uid])` targets. Call [start] after sign-in
/// and [stop] on sign-out.
class PushService {
  PushService(this._push);

  final Push _push;
  PushSubscription? _subscription;

  Future<void> start({required void Function(Map<String, dynamic> data) onMessage}) async {
    _subscription ??= await _push.subscribe(
      null,
      (message) => onMessage(_decode(message.data)),
      background: true,
      title: 'Eve',
    );
  }

  Future<void> stop() async {
    _subscription?.unsubscribe();
    _subscription = null;
    _push.close();
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {'body': raw};
    } on FormatException {
      return {'body': raw};
    }
  }
}
