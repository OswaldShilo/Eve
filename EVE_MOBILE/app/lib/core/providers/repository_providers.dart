import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/appwrite_chat_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/home/data/appwrite_home_repository.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/log/data/appwrite_log_repository.dart';
import '../../features/log/data/log_repository.dart';
import '../../features/onboarding/data/appwrite_onboarding_repository.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/symptom_log.dart';
import 'appwrite_providers.dart';

/// Widgets read repositories through these providers; tests override them
/// with the fakes from test/support/fake_repositories.dart.
final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => AppwriteOnboardingRepository(ref.watch(appwriteServiceProvider)));

final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => AppwriteHomeRepository(ref.watch(appwriteServiceProvider)));

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => AppwriteChatRepository(ref.watch(appwriteServiceProvider)));

final logRepositoryProvider =
    Provider<LogRepository>((ref) => AppwriteLogRepository(ref.watch(appwriteServiceProvider)));

final homeDashboardProvider = FutureProvider.family<HomeDashboardData, String>(
  (ref, uid) => ref.watch(homeRepositoryProvider).loadDashboard(uid),
);

final chatThreadIdProvider = FutureProvider.family<String, String>(
  (ref, uid) => ref.watch(chatRepositoryProvider).threadIdFor(uid),
);

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, threadUserId) => ref.watch(chatRepositoryProvider).watchThread(threadUserId),
);

final logsProvider = StreamProvider.family<List<SymptomLog>, String>(
  (ref, uid) => ref.watch(logRepositoryProvider).watchLogs(uid),
);
