import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppIconSwap, () {
    Widget swap({required bool on}) => Center(
      child: AppIconSwap(
        value: on,
        child: Icon(
          on ? AppSymbols.choiceSelected : AppSymbols.choiceUnselected,
        ),
      ),
    );

    double scaleOf(WidgetTester tester, IconData icon) => tester
        .widget<ScaleTransition>(
          find
              .ancestor(
                of: find.byIcon(icon),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    testWidgets('grows the new icon in while the old one shrinks away', (
      tester,
    ) async {
      await tester.pumpApp(swap(on: false), disableAnimations: false);
      await tester.pumpApp(swap(on: true), disableAnimations: false);
      await tester.pump(AppMotion.quick.duration ~/ 4);
      expect(find.byIcon(AppSymbols.choiceSelected), findsOneWidget);
      expect(find.byIcon(AppSymbols.choiceUnselected), findsOneWidget);
      expect(
        scaleOf(tester, AppSymbols.choiceSelected),
        allOf(greaterThan(AppIconSwap.hiddenScale), lessThan(1)),
      );
      expect(scaleOf(tester, AppSymbols.choiceUnselected), lessThan(1));
      // Both sit in the same spot.
      expect(
        tester.getCenter(find.byIcon(AppSymbols.choiceSelected)),
        tester.getCenter(find.byIcon(AppSymbols.choiceUnselected)),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(AppSymbols.choiceUnselected), findsNothing);
      expect(scaleOf(tester, AppSymbols.choiceSelected), 1);
    });

    testWidgets('the old icon leaves a quarter quicker than the new one '
        'arrives', (tester) async {
      await tester.pumpApp(swap(on: false), disableAnimations: false);
      await tester.pumpApp(swap(on: true), disableAnimations: false);
      await tester.pump();
      await tester.pump(AppMotion.quick.duration * AppMotion.exitFactor);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byIcon(AppSymbols.choiceUnselected), findsNothing);
      expect(scaleOf(tester, AppSymbols.choiceSelected), lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the same icon when the value is unchanged', (
      tester,
    ) async {
      await tester.pumpApp(swap(on: true), disableAnimations: false);
      await tester.pumpApp(swap(on: true), disableAnimations: false);
      await tester.pump();
      expect(find.byIcon(AppSymbols.choiceSelected), findsOneWidget);
      expect(scaleOf(tester, AppSymbols.choiceSelected), 1);
    });

    testWidgets('simply replaces the icon under reduced motion', (
      tester,
    ) async {
      await tester.pumpApp(swap(on: false));
      await tester.pumpApp(swap(on: true));
      expect(find.byIcon(AppSymbols.choiceUnselected), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppIconSwap),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
    });
  });
}
