import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenTap() {}

void main() {
  group('AppPlanCard', () {
    tearDown(() => AppHaptics.debugPlay = null);

    testWidgets('is a selected button with a selection haptic', (tester) async {
      final played = <AppHaptic>[];
      AppHaptics.debugPlay = played.add;
      var taps = 0;
      await tester.pumpApp(
        AppPlanCard(
          title: 'Pro Annual',
          price: '£29.99',
          period: '/ 1 year',
          detail: 'Everything included.',
          selected: true,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(AppPlanCard));
      expect(taps, 1);
      expect(played, [AppHaptic.selection]);
      expect(find.byType(AppDoneMark), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppPlanCard)),
        isSemantics(
          label: 'Pro Annual',
          value: '£29.99 / 1 year, Everything included.',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('unselected, it shows an empty circle; without a period, '
        'the price alone', (tester) async {
      await tester.pumpApp(
        const AppPlanCard(
          title: 'Lifetime',
          price: '£99.99',
          selected: false,
          onPressed: null,
        ),
      );
      expect(find.byIcon(AppSymbols.choiceUnselected), findsOneWidget);
      expect(find.byType(AppDoneMark), findsNothing);
      expect(
        tester.getSemantics(find.byType(AppPlanCard)),
        isSemantics(
          label: 'Lifetime',
          value: '£99.99',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
        ),
      );
    });
  });

  group('AppPlanCard golden', () {
    goldenStates('app_plan_card', [
      (
        'Selected',
        const AppPlanCard(
          title: 'Pro Annual',
          price: '£29.99',
          period: '/ 1 year',
          detail: 'Unlock workout, AI nutrition, and weight tracking.',
          selected: true,
          onPressed: _goldenTap,
        ),
      ),
      (
        'Unselected',
        const AppPlanCard(
          title: 'Pro Monthly',
          price: '£4.99',
          period: '/ 1 month',
          selected: false,
          onPressed: _goldenTap,
        ),
      ),
    ]);
  });
}
