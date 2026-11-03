/// Build-time configuration, set with --dart-define (see app/README.md).
/// Defaults target the Appwrite Cloud project `eve-dev`. The endpoint and
/// project ID are public identifiers, not secrets. For the local Docker
/// Appwrite pass e.g. `--dart-define=APPWRITE_ENDPOINT=http://10.0.2.2/v1
/// --dart-define=APPWRITE_PROJECT_ID=eve-local`.
class AppEnv {
  AppEnv._();

  static const String endpoint =
      String.fromEnvironment('APPWRITE_ENDPOINT', defaultValue: 'https://sgp.cloud.appwrite.io/v1');

  static const String projectId =
      String.fromEnvironment('APPWRITE_PROJECT_ID', defaultValue: '6ae966a5002293c1e5c3');

  /// Only for a self-hosted instance with a self-signed certificate.
  static const bool selfSigned = bool.fromEnvironment('APPWRITE_SELF_SIGNED');
}
