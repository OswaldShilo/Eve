import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/appwrite_onboarding_repository.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import 'appwrite_providers.dart';

/// Widgets read repositories through these providers; tests override them
/// with the fakes from test/support/fake_repositories.dart.
final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => AppwriteOnboardingRepository(ref.watch(appwriteServiceProvider)));
