import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eve_app/core/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirebaseService', () {
    test('exposes the auth instance it was constructed with', () {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();

      final service = FirebaseService(
        auth: mockAuth,
        firestore: mockFirestore,
      );

      expect(service.auth, same(mockAuth));
    });

    test('exposes the firestore instance it was constructed with', () {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();

      final service = FirebaseService(
        auth: mockAuth,
        firestore: mockFirestore,
      );

      expect(service.firestore, same(mockFirestore));
    });
  });
}
