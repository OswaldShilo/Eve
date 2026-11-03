import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;

import '../config/app_env.dart';

/// Thrown when an Appwrite Function execution returns a 4xx/5xx status.
class FunctionCallException implements Exception {
  FunctionCallException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'FunctionCallException($statusCode): $message';
}

/// Thin, testable wrapper around the Appwrite SDK services the client uses.
/// Every service can be injected so tests never touch the network. Only
/// repositories (`features/*/data/appwrite_*_repository.dart`) and
/// `core/services/` may use this class — widgets depend on repository
/// interfaces instead (Task 9).
class AppwriteService {
  AppwriteService({
    required this.client,
    Account? account,
    TablesDB? tablesDb,
    Functions? functions,
    Realtime? realtime,
  })  : account = account ?? Account(client),
        tablesDb = tablesDb ?? TablesDB(client),
        functions = functions ?? Functions(client),
        realtime = realtime ?? Realtime(client);

  factory AppwriteService.fromEnv() {
    final client = Client().setEndpoint(AppEnv.endpoint).setProject(AppEnv.projectId);
    if (AppEnv.selfSigned) client.setSelfSigned();
    return AppwriteService(client: client);
  }

  final Client client;
  final Account account;
  final TablesDB tablesDb;
  final Functions functions;
  final Realtime realtime;

  /// Opens the Google consent screen; resolves once the session exists.
  Future<void> signInWithGoogle() => account.createOAuth2Session(provider: enums.OAuthProvider.google);

  /// "Continue as Guest": an anonymous Appwrite account (still a real user
  /// id, so onUserCreate initializes her rows). Can be upgraded later.
  Future<void> signInAsGuest() => account.createAnonymousSession();

  /// The signed-in user's id, or null when there is no session.
  Future<String?> currentUserId() async {
    try {
      return (await account.get()).$id;
    } on AppwriteException catch (e) {
      if (e.code == 401) return null;
      rethrow;
    }
  }

  Future<void> signOut() => account.deleteSession(sessionId: 'current');

  /// Checks the app can reach the configured Appwrite project; returns the
  /// server's reply ("Pong"). Throws [AppwriteException] when it cannot.
  Future<String> ping() => client.ping();

  /// Runs a function synchronously with a JSON body and returns its JSON
  /// response. Caller identity reaches the function as x-appwrite-user-id.
  Future<Map<String, dynamic>> executeJson(String functionId, Map<String, dynamic> body) async {
    final execution = await functions.createExecution(
      functionId: functionId,
      body: jsonEncode(body),
      xasync: false,
    );
    final decoded = execution.responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(execution.responseBody) as Map<String, dynamic>;
    if (execution.responseStatusCode >= 400) {
      throw FunctionCallException(
        execution.responseStatusCode,
        (decoded['error'] as String?) ?? 'Request failed.',
      );
    }
    return decoded;
  }
}
