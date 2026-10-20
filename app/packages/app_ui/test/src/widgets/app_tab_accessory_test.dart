import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTabAccessory', () {
    testWidgets('is one button, with its trailing one beside it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      var skips = 0;
      await tester.pumpApp(
        AppTabAccessory(
          semanticLabel: 'Resume Push Day',
          onTap: () => taps++,
          trailing: AppToolbarButton(
            icon: AppSymbols.skip,
            semanticLabel: 'Skip Rest',
            onPressed: () => skips++,
          ),
          child: const Text('Push Day'),
        ),
      );
      expect(find.bySemanticsLabel('Resume Push Day'), findsOneWidget);
      expect(find.byTooltip('Skip Rest'), findsOneWidget);
      await tester.tap(find.text('Push Day'));
      await tester.tap(find.byType(AppToolbarButton));
      expect(taps, 1);
      expect(skips, 1);
      handle.dispose();
    });

    testWidgets('is at least a row tall, with a gap below its card', (
      tester,
    ) async {
      await tester.pumpApp(
        AppTabAccessory(
          semanticLabel: 'Meal',
          onTap: () {},
          child: const SizedBox.shrink(),
        ),
      );
      expect(tester.getSize(find.byType(AppCard)).height, AppControlSize.row);
      expect(
        tester.getSize(find.byType(AppTabAccessory)).height,
        AppControlSize.row + AppSpacing.s,
      );
    });
  });

  group('AppTabAccessory golden', () {
    goldenStates('app_tab_accessory', [
      (
        'Content',
        AppTabAccessory(
          semanticLabel: 'Continue draft meal, 2 items',
          onTap: () {},
          child: const Row(
            spacing: AppSpacing.m,
            children: [
              Icon(AppSymbols.meal),
              Expanded(child: Text('Unlogged meal')),
              Icon(AppSymbols.disclosure),
            ],
          ),
        ),
      ),
      (
        'A trailing button',
        AppTabAccessory(
          semanticLabel: 'Resume Push Day',
          onTap: () {},
          trailing: AppToolbarButton(
            icon: AppSymbols.skip,
            semanticLabel: 'Skip Rest',
            onPressed: () {},
          ),
          child: const Row(
            spacing: AppSpacing.m,
            children: [
              Icon(AppSymbols.workout),
              Expanded(child: Text('Push Day')),
              Text('1:30'),
            ],
          ),
        ),
      ),
    ]);
  });
}
