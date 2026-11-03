import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:eve_app/core/services/save_failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const connection = 'We could not save your answers. Please check your connection and try again.';

  test('a missing database, table or row says the server is not set up, not the connection', () {
    for (final type in ['database_not_found', 'table_not_found', 'row_not_found']) {
      final message = saveFailureMessage(AppwriteException('not found', 404, type));
      expect(message, contains('server is not set up'));
      expect(message, isNot(contains('connection')));
    }
  });

  test('401/403 asks her to sign in again', () {
    expect(
      saveFailureMessage(AppwriteException('missing scope', 401, 'general_unauthorized_scope')),
      contains('not signed in'),
    );
    expect(saveFailureMessage(AppwriteException('unauthorized', 403, 'user_unauthorized')), contains('not signed in'));
  });

  test('network and unknown failures keep the connection message', () {
    expect(saveFailureMessage(const SocketException('Failed host lookup')), connection);
    expect(saveFailureMessage(AppwriteException('timeout', 0)), connection);
    expect(saveFailureMessage(Exception('offline')), connection);
  });

  test('debug appends the Appwrite code and type; release does not', () {
    final e = AppwriteException('not found', 404, 'database_not_found');
    expect(saveFailureMessage(e, debug: true), endsWith('[404 database_not_found]'));
    expect(saveFailureMessage(e), isNot(contains('[')));
  });
}
