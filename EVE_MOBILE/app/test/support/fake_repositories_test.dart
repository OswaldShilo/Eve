import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repositories.dart';

void main() {
  test('FakeOnboardingRepository records saves', () async {
    final repo = FakeOnboardingRepository();
    await repo.saveOnboarding('u1', const OnboardingState(name: 'Asha'));
    expect(repo.saved.single.$1, 'u1');
    expect(repo.saved.single.$2.name, 'Asha');
  });

  test('FakeChatRepository streams sent messages as her', () async {
    final repo = FakeChatRepository();
    final stream = repo.watchThread('u1');
    await repo.sendMessage('u1', 'Hello');
    final messages = await stream.firstWhere((m) => m.isNotEmpty);
    expect(messages.single.senderRole, 'her');
    expect(messages.single.messageText, 'Hello');
  });

  test('FakeLogRepository streams added logs', () async {
    final repo = FakeLogRepository();
    await repo.addLog('u1', SymptomLog(userId: 'u1', date: DateTime.utc(2026, 3, 14), mood: 'low'));
    final logs = await repo.watchLogs('u1').first;
    expect(logs.single.mood, 'low');
  });

  test('FakeHomeRepository returns its configured dashboard', () async {
    final repo = FakeHomeRepository(const HomeDashboardDataFixture().data);
    expect((await repo.loadDashboard('u1')).greetingName, 'Priya');
  });
}
