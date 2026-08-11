import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Thin, testable wrapper around the two Firebase SDKs this app's core
/// layer needs directly: Auth and Firestore. AI proxy calls and any
/// Cloud Functions invocation live in `ai_proxy_service.dart` (Plan 3),
/// not here.
///
/// Accepts optional `auth`/`firestore` instances so tests can inject
/// mocks instead of touching the real Firebase SDKs (which require
/// native platform initialization `flutter test` does not provide).
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  /// Initializes the Firebase app. Must be called once, before
  /// `runApp`, with `WidgetsFlutterBinding.ensureInitialized()` called
  /// first. Requires the native `google-services.json` /
  /// `GoogleService-Info.plist` config files Plan 3 sets up.
  static Future<void> initializeApp() => Firebase.initializeApp();
}
