import 'package:appwrite/appwrite.dart';

/// User-facing text for a failed save. Only a real network failure is
/// blamed on her connection; a missing database, table or row means the
/// server is not set up for this account, which retrying cannot fix.
/// [debug] appends the Appwrite code and type so a developer can see the
/// exact failure on a device without logcat.
String saveFailureMessage(Object error, {bool debug = false}) {
  final String text;
  if (error is AppwriteException && error.code == 404) {
    text = 'EVE could not save your answers because the server is not set up for your account yet.';
  } else if (error is AppwriteException && (error.code == 401 || error.code == 403)) {
    text = 'EVE could not save your answers because you are not signed in. Go back and sign in again.';
  } else {
    text = 'We could not save your answers. Please check your connection and try again.';
  }
  if (!debug) return text;
  final detail = error is AppwriteException ? '${error.code} ${error.type ?? ''}'.trim() : error.runtimeType.toString();
  return '$text\n[$detail]';
}
