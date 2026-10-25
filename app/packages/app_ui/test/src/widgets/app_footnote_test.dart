import 'package:app_ui/app_ui.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppFootnote', () {
    testWidgets('ends a line with an ⓘ that opens its explanation', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpApp(
        AppFootnote(
          lines: [
            AppFootnoteLine(
              'Calories count as on target within 10%.',
              infoLabel: 'About the band',
              onInfo: () => opened++,
            ),
            const AppFootnoteLine('No sources here.'),
          ],
        ),
      );
      final text = tester.widget<RichText>(find.byType(RichText)).text;
      final spans = <TextSpan>[];
      text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      final link = spans.singleWhere((span) => span.recognizer != null);
      expect(link.semanticsLabel, 'About the band');
      expect(link.style?.color, AppColors.light.accentInk);
      (link.recognizer! as TapGestureRecognizer).onTap!();
      expect(opened, 1);
      expect(text.toPlainText(), contains('10%.'));
    });

    testWidgets('lets its recognizers go when it goes', (tester) async {
      await tester.pumpApp(
        AppFootnote(lines: [AppFootnoteLine('A', onInfo: () {})]),
      );
      await tester.pumpApp(const SizedBox.shrink());
      expect(find.byType(AppFootnote), findsNothing);
    });
  });

  group('AppFootnote golden', () {
    goldenStates('app_footnote', [
      (
        'Three lines, two with info',
        AppFootnote(
          lines: [
            AppFootnoteLine(
              'Calories count as on target within 10% either side.',
              infoLabel: 'About',
              onInfo: () {},
            ),
            AppFootnoteLine(
              'Step goal: 8,000 a day.',
              infoLabel: 'About',
              onInfo: () {},
            ),
            const AppFootnoteLine('A note without a source.'),
          ],
        ),
      ),
    ]);
  });
}
