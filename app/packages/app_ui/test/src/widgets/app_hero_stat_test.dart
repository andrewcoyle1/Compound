import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// A stand-in for a chart series' swatch from compound_charts.
const _swatch = SizedBox.square(
  dimension: 8,
  child: ColoredBox(color: Color(0xFFBF5AF2)),
);

void main() {
  group('AppHeroStat', () {
    testWidgets('reads as one element: label, value unit, delta, caption', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppHeroStat(
          label: 'Trend Weight',
          leading: _swatch,
          value: '82.4',
          unit: 'kg',
          delta: AppChip(label: '−0.4 kg', icon: AppSymbols.reduce),
          caption: 'Average, Oct 19 – Oct 25',
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppHeroStat)),
        matchesSemantics(
          label: 'Trend Weight',
          value: '82.4 kg, −0.4 kg, Average, Oct 19 – Oct 25',
        ),
      );
      expect(find.text('TREND WEIGHT'), findsOneWidget);
      expect(find.text('KG'), findsOneWidget);
    });

    testWidgets('reads only the number when that is all it has', (
      tester,
    ) async {
      await tester.pumpApp(const AppHeroStat(value: '6,240'));
      expect(
        tester.getSemantics(find.byType(AppHeroStat)),
        matchesSemantics(value: '6,240'),
      );
    });
  });

  group('AppHeroStat golden', () {
    goldenStates('app_hero_stat', [
      (
        'Label, unit, delta, caption',
        const AppHeroStat(
          label: 'Trend Weight',
          leading: _swatch,
          value: '82.4',
          unit: 'kg',
          delta: AppChip(
            label: '−0.4 kg vs. previous 7 days',
            icon: AppSymbols.reduce,
          ),
          caption: 'Average, Oct 19, 2026 – Oct 25, 2026',
        ),
      ),
      ('Number only', const AppHeroStat(value: '6,240')),
      (
        'Unit and caption',
        const AppHeroStat(
          value: '2,512',
          unit: 'kcal',
          caption: 'Daily Average, Sep 26 – Oct 25',
        ),
      ),
    ]);
  });
}
