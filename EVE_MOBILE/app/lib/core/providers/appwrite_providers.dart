import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_service.dart';

/// Overridden in main.dart with the instance built from AppEnv, and in
/// tests with an AppwriteService made of mocks.
final appwriteServiceProvider = Provider<AppwriteService>((ref) => AppwriteService.fromEnv());

/// The signed-in user's id. Seeded in main.dart from the existing session
/// and set by the Auth screen after signInWithGoogle(); null when signed out.
final currentUidProvider = StateProvider<String?>((ref) => null);
