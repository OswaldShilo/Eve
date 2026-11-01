import 'dart:async';

import 'package:eve_app/features/chat/data/chat_repository.dart';
import 'package:eve_app/features/home/data/home_repository.dart';
import 'package:eve_app/features/log/data/log_repository.dart';
import 'package:eve_app/features/onboarding/data/onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:eve_app/shared/models/symptom_log.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  final List<(String, OnboardingState)> saved = [];

  String? inviteCodeToReturn;

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    saved.add((uid, state));
    return state.partnerInvite ? inviteCodeToReturn : null;
  }
}

class HomeDashboardDataFixture {
  const HomeDashboardDataFixture();

  HomeDashboardData get data =>
      const HomeDashboardData(greetingName: 'Priya', phaseBadge: 'Cycle Tracking Active', lifeStage: 'cycle');
}

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository(this.data);

  final HomeDashboardData data;

  @override
  Future<HomeDashboardData> loadDashboard(String uid) async => data;
}

class FakeChatRepository implements ChatRepository {
  final _messages = <ChatMessage>[];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  @override
  Future<String> threadIdFor(String uid) async => uid;

  @override
  Stream<List<ChatMessage>> watchThread(String threadUserId) async* {
    yield List.unmodifiable(_messages);
    yield* _controller.stream;
  }

  @override
  Future<void> sendMessage(String threadUserId, String text) async {
    _messages.add(ChatMessage(
      threadUserId: threadUserId,
      senderRole: 'her',
      senderUserId: threadUserId,
      messageText: text,
      sentAt: DateTime.now().toUtc(),
      type: 'text',
    ));
    _controller.add(List.unmodifiable(_messages));
  }
}

class FakeLogRepository implements LogRepository {
  final _logs = <SymptomLog>[];
  final _controller = StreamController<List<SymptomLog>>.broadcast();

  @override
  Stream<List<SymptomLog>> watchLogs(String uid) async* {
    yield List.unmodifiable(_logs);
    yield* _controller.stream;
  }

  @override
  Future<void> addLog(String uid, SymptomLog log) async {
    _logs.add(log);
    _controller.add(List.unmodifiable(_logs));
  }
}
