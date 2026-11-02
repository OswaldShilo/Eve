import '../domain/onboarding_state.dart';

/// Persists the completed onboarding survey. Implemented against Appwrite by
/// AppwriteOnboardingRepository (roadmap M14).
abstract class OnboardingRepository {
  /// Returns the partner invite code when she chose to invite a partner,
  /// otherwise null.
  Future<String?> saveOnboarding(String uid, OnboardingState state);
}
