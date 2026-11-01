import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../services/appwrite_service.dart';
import '../services/push_service.dart';

/// Overridden in main.dart with the instance built from AppEnv, and in
/// tests with an AppwriteService made of mocks.
final appwriteServiceProvider = Provider<AppwriteService>((ref) => AppwriteService.fromEnv());

/// The signed-in user's id. Seeded in main.dart from the existing session
/// and set by the Auth screen after signInWithGoogle(); null when signed out.
final currentUidProvider = StateProvider<String?>((ref) => null);

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(Push(ref.watch(appwriteServiceProvider).client));
  ref.onDispose(service.stop);
  return service;
});

/// Keeps push subscribed exactly while someone is signed in. Watched by
/// EveApp, so it also runs for the uid seeded in main.dart (WidgetRef.listen
/// has no fireImmediately in Riverpod 2).
final pushLifecycleProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  ref.watch(currentUidProvider) == null ? push.stop() : push.start(onMessage: (_) {});
});
