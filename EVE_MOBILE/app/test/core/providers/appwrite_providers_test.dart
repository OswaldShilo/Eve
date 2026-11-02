import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentUidProvider defaults to null and can be set after sign-in', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(currentUidProvider), isNull);
    container.read(currentUidProvider.notifier).state = 'u1';
    expect(container.read(currentUidProvider), 'u1');
  });
}
