import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  final info = MethodInfo.weightTrend(
    lookupAppLocalizations(const Locale('en')),
  );

  // The sheet's own list, not the formula's selectable text.
  final sheetList = find.byType(Scrollable).first;

  group(Citation, () {
    test('links by DOI, else by address', () {
      expect(Citation.rauch1965.linkText, 'doi:10.2514/3.3166');
      expect(Citation.walker.linkText, startsWith('https://fourmilab.ch'));
      expect(const Citation(reference: 'A book').linkText, isNull);
    });
  });

  group(MethodInfoButton, () {
    testWidgets('is labelled for a screen reader', (tester) async {
      await tester.pumpApp(Scaffold(body: MethodInfoButton(info)));
      expect(find.byTooltip('How Weight Trend is calculated'), findsOneWidget);
    });

    testWidgets('opens the method, its formula and its sources', (
      tester,
    ) async {
      await tester.pumpApp(Scaffold(body: MethodInfoButton(info)));
      await tester.tap(find.byType(MethodInfoButton));
      await tester.pumpAndSettle();
      expect(find.byType(MethodInfoSheet), findsOneWidget);
      expect(find.text('Weight Trend'), findsOneWidget);
      expect(find.text(info.summary), findsOneWidget);
      for (final heading in [
        'Formula',
        'Limitations',
        "Compound's own choices",
        'Sources',
      ]) {
        await tester.scrollUntilVisible(
          find.text(heading),
          200,
          scrollable: sheetList,
        );
        expect(find.text(heading), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Not peer reviewed'),
        200,
        scrollable: sheetList,
      );
      expect(find.text('Not peer reviewed'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('doi:10.2514/3.3166'),
        200,
        scrollable: sheetList,
      );
      expect(find.text('doi:10.2514/3.3166'), findsOneWidget);
    });

    testWidgets('leaves out the sections a method does not have', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          body: MethodInfoSheet(
            info: MethodInfo(
              title: 'Plain',
              summary: 'Just a summary.',
              citations: [Citation(reference: 'A book')],
            ),
          ),
        ),
      );
      expect(find.text('Formula'), findsNothing);
      expect(find.text('Limitations'), findsNothing);
      expect(find.text("Compound's own choices"), findsNothing);
      expect(find.text('A book'), findsOneWidget);
    });
  });
}
