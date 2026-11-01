import 'package:eve_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// `pumpAndSettle` never returns while an `EveMascot` is on screen (its idle
/// float repeats forever), so advance a bounded amount of time instead —
/// long enough for go_router's page transition to finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('EveApp boots to the real onboarding Welcome screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EveApp()));
    await _settle(tester);

    expect(find.text('Begin Setup'), findsOneWidget);
  });
}
