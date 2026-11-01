import 'package:eve_app/features/log/presentation/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collects mood, symptoms, pain and notes and returns canonical keys', (tester) async {
    QuickLogResult? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuickLogSheet(onSave: (result) async => saved = result)),
    ));

    await tester.tap(find.text('Difficult'));
    await tester.tap(find.text('Cramps'));
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.enterText(find.byType(TextField), 'Long day.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved!.mood, 'difficult');
    expect(saved!.symptoms, ['Cramps']);
    expect(saved!.painLevel, 10);
    expect(saved!.notes, 'Long day.');
  });
}
