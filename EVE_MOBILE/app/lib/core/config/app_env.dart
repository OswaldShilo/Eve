/// Build-time configuration, set with --dart-define (see app/README.md).
/// Defaults target the local Docker Appwrite as seen from an Android
/// emulator (10.0.2.2 is the host machine).
class AppEnv {
  AppEnv._();

  static const String endpoint =
      String.fromEnvironment('APPWRITE_ENDPOINT', defaultValue: 'http://10.0.2.2/v1');

  static const String projectId =
      String.fromEnvironment('APPWRITE_PROJECT_ID', defaultValue: 'eve-local');

  /// Only for a self-hosted instance with a self-signed certificate.
  static const bool selfSigned = bool.fromEnvironment('APPWRITE_SELF_SIGNED');
}
