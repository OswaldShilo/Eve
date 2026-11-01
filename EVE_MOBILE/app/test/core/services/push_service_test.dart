import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:eve_app/core/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPush extends Mock implements Push {}

class MockPushSubscription extends Mock implements PushSubscription {}

void main() {
  setUpAll(() => registerFallbackValue((PushMessage _) {}));

  test('start subscribes to her own user channel with background delivery and decodes JSON data', () async {
    final push = MockPush();
    final subscription = MockPushSubscription();
    PushCallback? captured;
    when(() => push.subscribe(any(that: isNull), any(), background: any(named: 'background', that: isTrue), title: any(named: 'title', that: equals('Eve')))).thenAnswer((invocation) async {
      captured = invocation.positionalArguments[1] as PushCallback;
      return subscription;
    });

    final received = <Map<String, dynamic>>[];
    final service = PushService(push);
    await service.start(onMessage: received.add);
    captured!(PushMessage(
      topic: 'user/u1',
      payload: Uint8List.fromList(utf8.encode('{"notificationType":"morning"}')),
      qos: 1,
    ));

    expect(received.single['notificationType'], 'morning');
  });

  test('stop unsubscribes and closes the connection', () async {
    final push = MockPush();
    final subscription = MockPushSubscription();
    when(() => push.subscribe(any(that: isNull), any(), background: any(named: 'background', that: isTrue), title: any(named: 'title', that: equals('Eve')))).thenAnswer((_) async => subscription);

    final service = PushService(push);
    await service.start(onMessage: (_) {});
    await service.stop();

    verify(() => subscription.unsubscribe()).called(1);
    verify(() => push.close()).called(1);
  });
}
