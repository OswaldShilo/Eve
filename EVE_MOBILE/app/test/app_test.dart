import 'package:eve_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('EveApp boots to the onboarding welcome placeholder',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EveApp()));
    await tester.pumpAndSettle();

    expect(find.text('onboarding-welcome'), findsOneWidget);
  });
}
