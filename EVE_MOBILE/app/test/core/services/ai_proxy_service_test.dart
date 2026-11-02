// EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart
import 'package:eve_app/core/services/ai_proxy_service.dart';
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test('generateDoctorSummary calls aiProxy with feature doctorSummary and returns the text', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson('aiProxy', {'feature': 'doctorSummary', 'days': 90}))
        .thenAnswer((_) async => {'summary': 'Overview: mild cramps recorded once.', 'provider': 'gemini', 'logCount': 1});

    expect(await AiProxyService(appwrite).generateDoctorSummary(), 'Overview: mild cramps recorded once.');
  });

  test('throws StateError when the response has no summary', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson(any(), any())).thenAnswer((_) async => <String, dynamic>{});
    expect(() => AiProxyService(appwrite).generateDoctorSummary(), throwsStateError);
  });

  test('checkIn returns the reply', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson('aiProxy', {'feature': 'checkIn', 'message': 'I slept badly.'}))
        .thenAnswer((_) async => {'reply': 'Thank you for telling me.', 'provider': 'openrouter'});
    expect(await AiProxyService(appwrite).checkIn('I slept badly.'), 'Thank you for telling me.');
  });
}
