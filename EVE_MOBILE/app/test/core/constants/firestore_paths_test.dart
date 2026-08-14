import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestorePaths', () {
    test('userDoc returns users/{uid}', () {
      expect(FirestorePaths.userDoc('u1'), 'users/u1');
    });

    test('lifeStageProfile returns users/{uid}/lifeStageProfile/current', () {
      expect(
        FirestorePaths.lifeStageProfile('u1'),
        'users/u1/lifeStageProfile/current',
      );
    });

    test('logsCollection returns users/{uid}/logs', () {
      expect(FirestorePaths.logsCollection('u1'), 'users/u1/logs');
    });

    test('log returns users/{uid}/logs/{logId}', () {
      expect(FirestorePaths.log('u1', 'l1'), 'users/u1/logs/l1');
    });

    test('goalsPreferences returns users/{uid}/preferences/goals', () {
      expect(
        FirestorePaths.goalsPreferences('u1'),
        'users/u1/preferences/goals',
      );
    });

    test(
        'notificationPreferences returns '
        'users/{uid}/preferences/notifications', () {
      expect(
        FirestorePaths.notificationPreferences('u1'),
        'users/u1/preferences/notifications',
      );
    });

    test('aiScope returns users/{uid}/preferences/aiScope', () {
      expect(FirestorePaths.aiScope('u1'), 'users/u1/preferences/aiScope');
    });

    test('theme returns users/{uid}/preferences/theme', () {
      expect(FirestorePaths.theme('u1'), 'users/u1/preferences/theme');
    });

    test('partnerLink returns users/{uid}/partnerLink/current', () {
      expect(
        FirestorePaths.partnerLink('u1'),
        'users/u1/partnerLink/current',
      );
    });

    test(
        'partnerPermissions returns '
        'users/{uid}/partnerPermissions/current', () {
      expect(
        FirestorePaths.partnerPermissions('u1'),
        'users/u1/partnerPermissions/current',
      );
    });

    test('partnerView returns users/{uid}/partnerView/current', () {
      expect(
        FirestorePaths.partnerView('u1'),
        'users/u1/partnerView/current',
      );
    });

    test('partnerLinksReverse returns partnerLinks/{partnerUid}', () {
      expect(FirestorePaths.partnerLinksReverse('p1'), 'partnerLinks/p1');
    });

    test('chatCollection returns users/{uid}/chat', () {
      expect(FirestorePaths.chatCollection('u1'), 'users/u1/chat');
    });

    test('chatMessage returns users/{uid}/chat/{messageId}', () {
      expect(FirestorePaths.chatMessage('u1', 'm1'), 'users/u1/chat/m1');
    });
  });
}
