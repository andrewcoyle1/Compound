import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

ChartSeries _series(String label, Color color, ChartMark mark) =>
    ChartSeries(label: label, color: color, mark: mark, points: const []);

final List<ChartSeries> _macros = [
  _series('Protein', const Color(0xFFFF3B30), ChartMark.bar),
  _series('Carbs', const Color(0xFF34C759), ChartMark.bar),
  _series('Fat', const Color(0xFFFF9500), ChartMark.bar),
  _series('Target', const Color(0xFF007AFF), ChartMark.line),
];

final List<ChartSeries> _weight = [
  _series('Scale Weight', const Color(0xFFAF52DE), ChartMark.dot),
  _series('Trend Weight', const Color(0xFFFF2D55), ChartMark.area),
];

void main() {
  group(ChartLegend, () {
    testWidgets('names each series beside its swatch', (tester) async {
      await tester.pumpApp(ChartLegend(series: _macros));
      expect(find.byType(ChartSwatch), findsNWidgets(4));
      expect(find.text('Target'), findsOneWidget);
    });

    testWidgets('wraps when the names do not fit', (tester) async {
      await tester.pumpApp(
        Center(
          child: SizedBox(width: 120, child: ChartLegend(series: _macros)),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Target')).dy,
        greaterThan(tester.getTopLeft(find.text('Protein')).dy),
      );
    });
  });

  group(ChartSwatch, () {
    testWidgets('is shaped like its mark', (tester) async {
      ShapeBorder shape(ChartMark mark) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is ChartSwatch && w.mark == mark,
            ),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as ShapeDecoration).shape;
      }

      await tester.pumpApp(
        Column(
          children: [
            for (final mark in ChartMark.values)
              ChartSwatch(mark: mark, color: const Color(0xFF000000)),
          ],
        ),
      );
      expect(shape(ChartMark.line), isA<StadiumBorder>());
      expect(shape(ChartMark.area), isA<StadiumBorder>());
      expect(shape(ChartMark.bar), isA<RoundedSuperellipseBorder>());
      expect(shape(ChartMark.dot), isA<CircleBorder>());
    });
  });

  group('goldens', () {
    goldenStates('chart_legend', [
      ('stacked bars and a line', ChartLegend(series: _macros)),
      ('dots and an area', ChartLegend(series: _weight)),
      (
        'every swatch',
        Row(
          spacing: AppSpacing.s,
          children: [
            for (final mark in ChartMark.values)
              ChartSwatch(mark: mark, color: const Color(0xFF007AFF)),
          ],
        ),
      ),
    ]);
  });
}
