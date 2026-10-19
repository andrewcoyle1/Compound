import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const _green = Color(0xFF34C759);
const _blue = Color(0xFF007AFF);
const _orange = Color(0xFFFF9500);
const _red = Color(0xFFFF3B30);

final _weekStart = DateTime(2026, 10, 12);
final _weekEnd = DateTime(2026, 10, 19);

List<ChartPoint> _daily(DateTime start, List<double> values) => [
  for (final (i, y) in values.indexed)
    (x: DateTime(start.year, start.month, start.day + i), y: y),
];

ChartData _week(List<ChartSeries> series, {ChartYFit yFit = ChartYFit.tight}) =>
    ChartData(series: series, start: _weekStart, end: _weekEnd, yFit: yFit);

final ChartSeries _weight = ChartSeries(
  label: 'Weight',
  color: _green,
  points: _daily(_weekStart, [73.1, 72.8, 72.9, 72.4, 72.5, 72.1, 72]),
);

final ChartData _line = _week([_weight]);

final ChartData _area = ChartData(
  start: DateTime(2026, 9, 16),
  end: DateTime(2026, 10, 16),
  series: [
    ChartSeries(
      label: 'Steps',
      color: _blue,
      mark: ChartMark.area,
      points: _daily(DateTime(2026, 9, 16), [
        for (var i = 0; i < 30; i++) 8000 + 2500 * math.sin(i / 4) + i * 60,
      ]),
    ),
  ],
);

final ChartData _bars = _week([
  ChartSeries(
    label: 'Sets',
    color: _blue,
    mark: ChartMark.bar,
    points: _daily(_weekStart, [12, 0, 18, 9, 0, 22, 15]),
  ),
], yFit: ChartYFit.zero);

final ChartData _stacked = _week([
  for (final (label, color, values) in [
    ('Protein', _red, <double>[700, 640, 720, 690, 600, 750, 710]),
    ('Carbs', _green, <double>[900, 1000, 850, 950, 1100, 800, 940]),
    ('Fat', _orange, <double>[600, 520, 650, 580, 700, 560, 610]),
  ])
    ChartSeries(
      label: label,
      color: color,
      mark: ChartMark.bar,
      points: _daily(_weekStart, values),
    ),
  ChartSeries(
    label: 'Target',
    color: _blue,
    points: _daily(_weekStart, [2300, 2300, 2280, 2260, 2250, 2250, 2240]),
  ),
], yFit: ChartYFit.zero);

final ChartData _dots = ChartData(
  start: DateTime(2025, 10),
  end: DateTime(2026, 10),
  bucketDays: 365 / 12,
  series: [
    ChartSeries(
      label: 'Body Fat',
      color: _orange,
      mark: ChartMark.dot,
      points: [
        for (final (i, y) in <double>[21.4, 21, 20.6, 20.9, 20.1, 19.8].indexed)
          (x: DateTime(2025, 10 + i * 2), y: y),
      ],
    ),
  ],
);

final ChartData _empty = _week(const []);

void main() {
  group(CartesianChart, () {
    testWidgets('picks the bucket under a held finger, then lets go', (
      tester,
    ) async {
      final picked = <DateTime?>[];
      await tester.pumpApp(
        Center(
          child: CartesianChart(data: _line, onSelected: picked.add),
        ),
      );
      final chart = tester.getRect(find.byType(CartesianChart));
      final gesture = await tester.startGesture(chart.centerLeft);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(picked, [DateTime(2026, 10, 12)]);

      await gesture.moveTo(chart.centerRight);
      await tester.pump();
      expect(picked.last, DateTime(2026, 10, 18));

      await gesture.up();
      await tester.pump();
      expect(picked.last, isNull);
    });

    testWidgets('does not pick the bucket already picked', (tester) async {
      final picked = <DateTime?>[];
      await tester.pumpApp(
        Center(
          child: CartesianChart(
            data: _line,
            selected: DateTime(2026, 10, 12),
            onSelected: picked.add,
          ),
        ),
      );
      await tester.longPressAt(
        tester.getRect(find.byType(CartesianChart)).centerLeft,
      );
      expect(picked, [null]);
    });

    testWidgets('has nothing to pick when empty', (tester) async {
      final picked = <DateTime?>[];
      await tester.pumpApp(
        Center(
          child: CartesianChart(data: _empty, onSelected: picked.add),
        ),
      );
      await tester.longPress(find.byType(CartesianChart));
      expect(picked, [null]);
    });

    testWidgets('shows the callout over the bucket picked', (tester) async {
      await tester.pumpApp(
        Center(
          child: CartesianChart(
            data: _line,
            selected: DateTime(2026, 10, 15),
            onSelected: (_) {},
            callout: const Text('72.4 kg'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.getRect(find.byType(CartesianChart));
      final callout = tester.getRect(find.text('72.4 kg'));
      expect(callout.bottom, lessThan(chart.top));
      // Thursday is the middle of the week's seven days.
      expect(callout.center.dx, lessThan(chart.center.dx));
      expect(callout.center.dx, greaterThan(chart.left + chart.width / 4));
    });

    testWidgets('takes no long press without onSelected', (tester) async {
      await tester.pumpApp(CartesianChart(data: _line));
      final detector = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(CartesianChart),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(detector.onLongPressStart, isNull);
    });

    testWidgets('repaints for a new theme, text size or window', (
      tester,
    ) async {
      await tester.pumpApp(CartesianChart(data: _line));
      await tester.pumpApp(CartesianChart(data: _line));
      await tester.pumpApp(CartesianChart(data: _bars), textScale: 2);
      await tester.pumpApp(CartesianChart(data: _area), theme: AppTheme.dark);
      await tester.pumpApp(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    goldenStates('cartesian_chart', [
      ('line, a week of weigh-ins', CartesianChart(data: _line)),
      ('area, a month of steps', CartesianChart(data: _area)),
      ('bars from zero', CartesianChart(data: _bars)),
      ('stacked bars and a line', CartesianChart(data: _stacked)),
      ('dots, a year by month', CartesianChart(data: _dots)),
      (
        'a bucket picked',
        CartesianChart(data: _line, selected: DateTime(2026, 10, 15)),
      ),
      ('empty', CartesianChart(data: _empty)),
    ]);
  });
}
