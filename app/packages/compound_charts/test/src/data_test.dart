import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ChartData, () {
    final data = ChartData(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 19),
      series: [
        ChartSeries(
          label: 'a',
          color: const Color(0xFF000000),
          points: [
            (x: DateTime(2026, 10, 14), y: 1),
            (x: DateTime(2026, 10, 12), y: 2),
          ],
        ),
        ChartSeries(
          label: 'b',
          color: const Color(0xFF000000),
          mark: ChartMark.bar,
          points: [(x: DateTime(2026, 10, 14), y: 3)],
        ),
      ],
    );

    test('draws a point in the middle of its bucket', () {
      expect(data.fraction(DateTime(2026, 10, 12)), closeTo(1 / 14, 1e-9));
      expect(data.fraction(DateTime(2026, 10, 18)), closeTo(13 / 14, 1e-9));
      // Beyond the window, as a point sliding out of it is.
      expect(data.fraction(DateTime(2026, 10, 19)), closeTo(15 / 14, 1e-9));
    });

    test('lists each bucket once, oldest first', () {
      expect(data.buckets, [DateTime(2026, 10, 12), DateTime(2026, 10, 14)]);
    });

    test('defaults to a line on a tight axis, a day a point', () {
      expect(data.series.first.mark, ChartMark.line);
      expect(data.yFit, ChartYFit.tight);
      expect(data.bucketDays, 1);
    });

    test('is equal to the same data, field by field', () {
      ChartData copy() => ChartData(
        start: DateTime(2026, 10, 12),
        end: DateTime(2026, 10, 19),
        series: [
          for (final s in data.series)
            ChartSeries(
              label: s.label,
              color: s.color,
              mark: s.mark,
              points: [...s.points],
            ),
        ],
      );
      expect(copy(), data);
      expect(copy().hashCode, data.hashCode);
      expect(
        ChartData(start: data.start, end: data.end, series: const []),
        isNot(data),
      );
      expect(
        const ChartSeries(
          label: 'a',
          color: Color(0xFF000000),
          points: [],
          showsPoints: true,
        ),
        isNot(
          const ChartSeries(label: 'a', color: Color(0xFF000000), points: []),
        ),
      );
    });
  });

  group('ChartData.lerp', () {
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final monday = DateTime(2026, 10, 12);
    DateTime day(int i) => DateTime(2026, 10, 12 + i);
    List<ChartPoint> days(Map<int, double> values) => [
      for (final MapEntry(:key, :value) in values.entries)
        (x: day(key), y: value),
    ];
    ChartData week(List<ChartSeries> series, {int shift = 0}) =>
        ChartData(start: day(shift), end: day(shift + 7), series: series);
    ChartSeries line(Map<int, double> values, {Color color = black}) =>
        ChartSeries(label: 'Weight', color: color, points: days(values));
    ChartSeries bars(Map<int, double> values, {String label = 'Sets'}) =>
        ChartSeries(
          label: label,
          color: black,
          mark: ChartMark.bar,
          points: days(values),
        );
    Map<DateTime, double> values(ChartData data, String label) => {
      for (final p in data.series.firstWhere((s) => s.label == label).points)
        p.x: p.y,
    };

    final a = week([
      line({0: 70, 2: 72, 4: 74}),
      bars({0: 10, 1: 20}),
    ]);
    final b = week([
      line({0: 80, 1: 81, 4: 84, 6: 86}, color: white),
      bars({3: 4}, label: 'Reps'),
    ], shift: 7);

    test('is the start at 0 and the end at 1', () {
      expect(ChartData.lerp(a, b, 0), same(a));
      expect(ChartData.lerp(a, b, 1), same(b));
    });

    test('moves the window, the colours and the values', () {
      final half = ChartData.lerp(a, b, 0.5);
      expect(half.start, DateTime(2026, 10, 15, 12));
      // Halfway in time, which a change of clocks moves off midday.
      expect(
        half.end.microsecondsSinceEpoch,
        (a.end.microsecondsSinceEpoch + b.end.microsecondsSinceEpoch) ~/ 2,
      );
      expect(half.yFit, b.yFit);
      final weight = half.series.firstWhere((s) => s.label == 'Weight');
      expect(weight.color, Color.lerp(black, white, 0.5));
      expect(values(half, 'Weight')[day(0)], 75);
      expect(values(half, 'Weight')[day(4)], 79);
    });

    test('starts a new point on the line as drawn, between neighbours', () {
      final weight = values(ChartData.lerp(a, b, 0.5), 'Weight');
      // From 71, halfway from Monday's 70 to Wednesday's 72, to 81.
      expect(weight[day(1)], 76);
      // Past the old line's end, level with it: from 74 to 86.
      expect(weight[day(6)], 80);
      expect(weight.keys, [day(0), day(1), day(2), day(4), day(6)]);
    });

    test('ends a removed point on the new line', () {
      // Wednesday's 72 goes to 82, between Tuesday's 81 and Friday's 84.
      expect(values(ChartData.lerp(a, b, 0.5), 'Weight')[day(2)], 77);
    });

    test('grows a new bar series from zero and shrinks a removed one', () {
      final half = ChartData.lerp(a, b, 0.5);
      expect(values(half, 'Reps'), {day(3): 2});
      expect(values(half, 'Sets'), {day(0): 5, day(1): 10});
      // The new series first, as the end has them; the removed after.
      expect(
        [for (final s in half.series) s.label],
        ['Weight', 'Reps', 'Sets'],
      );
      expect(ChartData.lerp(a, b, 1).series, hasLength(2));
    });

    test('grows a missing bar from zero within a series', () {
      final from = week([
        bars({0: 10}),
      ]);
      final to = week([
        bars({0: 10, 1: 6}),
      ]);
      expect(values(ChartData.lerp(from, to, 0.5), 'Sets'), {
        day(0): 10,
        day(1): 3,
      });
    });

    test('raises a new line from the lowest value, or zero', () {
      final empty = ChartData(start: monday, end: day(7), series: const []);
      final to = week([
        line({0: 70, 1: 60}),
      ]);
      expect(values(ChartData.lerp(empty, to, 0.5), 'Weight'), {
        day(0): 65,
        day(1): 60,
      });
      final zero = ChartData(
        start: monday,
        end: day(7),
        yFit: ChartYFit.zero,
        series: to.series,
      );
      expect(values(ChartData.lerp(empty, zero, 0.5), 'Weight'), {
        day(0): 35,
        day(1): 30,
      });
      // And sinks one that goes.
      expect(values(ChartData.lerp(to, empty, 0.5), 'Weight'), {
        day(0): 65,
        day(1): 60,
      });
    });

    test('raises the points of a series that had none from the baseline', () {
      final from = week([line({})]);
      final to = week([
        line({0: 70, 1: 60}),
      ]);
      expect(values(ChartData.lerp(from, to, 0.5), 'Weight'), {
        day(0): 65,
        day(1): 60,
      });
    });

    test('moves the bucket size', () {
      final year = ChartData(
        start: monday,
        end: day(7),
        bucketDays: 7,
        series: const [],
      );
      expect(ChartData.lerp(week(const []), year, 0.5).bucketDays, 4);
    });
  });
}
