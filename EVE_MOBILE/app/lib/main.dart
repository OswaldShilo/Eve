import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/appwrite_providers.dart';
import 'core/services/appwrite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appwrite = AppwriteService.fromEnv();
  String? uid;
  try {
    uid = await appwrite.currentUserId();
  } on AppwriteException {
    uid = null; // offline or server unreachable: start signed-out, retry at sign-in
  }
  runApp(ProviderScope(
    overrides: [
      appwriteServiceProvider.overrideWithValue(appwrite),
      currentUidProvider.overrideWith((ref) => uid),
    ],
    child: const EveApp(),
  ));
}
