import 'package:compound/metric_detail/metric_detail.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors Swift `MetricChartReadingsTests` (line charts; bar totals are not
/// ported), then the range windows QuickCharts' picker gives.
void main() {
  final today = DateTime(2026, 10, 15);

  /// A reading [daysAgo] days back, at midday so it cannot drift across a
  /// day boundary.
  MetricPoint at(int daysAgo, double value, {int hour = 12}) => (
    date: DateTime(today.year, today.month, today.day - daysAgo, hour),
    value: value,
  );

  group(MetricReadings, () {
    test('groups readings into days, oldest first', () {
      final readings = MetricReadings([at(2, 73), at(1, 72.6), at(0, 72.4)]);
      expect(readings.days.map((d) => d.value), [73.0, 72.6, 72.4]);
    });

    test('averages several readings in a day', () {
      final readings = MetricReadings([at(0, 72, hour: 7), at(0, 73)]);
      expect(readings.days, hasLength(1));
      expect(readings.days.single.value, 72.5);
    });

    test('gives no rows without readings', () {
      final readings = MetricReadings(const []);
      expect(readings.days, isEmpty);
      expect(readings.latest, isNull);
      expect(readings.highest, isNull);
      expect(readings.lowest, isNull);
      expect(readings.average, isNull);
    });

    test('latest is the most recent day', () {
      expect(MetricReadings([at(2, 73), at(0, 72.4)]).latest?.value, 72.4);
    });

    test('highest and lowest span the days', () {
      final readings = MetricReadings([
        at(3, 72),
        at(2, 74),
        at(1, 71),
        at(0, 73),
      ]);
      expect(readings.highest?.value, 74);
      expect(readings.lowest?.value, 71);
    });

    test('a tie goes to the more recent day', () {
      final readings = MetricReadings([at(5, 72), at(0, 72), at(2, 75)]);
      expect(readings.lowest?.date, DateTime(2026, 10, 15));
    });

    test('a flat metric, or one day, has no spread', () {
      expect(
        MetricReadings([at(2, 72), at(1, 72), at(0, 72)]).hasSpread,
        isFalse,
      );
      expect(MetricReadings([at(1, 72), at(0, 72.5)]).hasSpread, isTrue);
      expect(MetricReadings([at(0, 72)]).hasSpread, isFalse);
    });

    test('averages across days, not readings', () {
      // Two readings today and one yesterday: today counts once, as a day.
      final readings = MetricReadings([
        at(1, 70),
        at(0, 72, hour: 7),
        at(0, 74),
      ]);
      expect(readings.average, 71.5);
    });
  });

  group(MetricRange, () {
    final points = [for (var d = 400; d >= 0; d--) at(d, d.toDouble())];

    test('each window ends today and covers its days', () {
      for (final range in MetricRange.values) {
        expect(
          range.start(today),
          DateTime(2026, 10, 15 - range.days + 1),
          reason: range.name,
        );
        expect(
          range.visible(points, today).first.date,
          isNot(isBefore(range.start(today))),
        );
      }
    });

    test('a week and a month plot a point a day', () {
      expect(MetricRange.week.visible(points, today), hasLength(7));
      expect(MetricRange.month.visible(points, today), hasLength(30));
    });

    test('six months average into weeks from Monday', () {
      final visible = MetricRange.sixMonths.visible(points, today);
      // The window opens mid-week, so its first bucket is a part week.
      expect(visible.first.date, MetricRange.sixMonths.start(today));
      expect(
        visible.skip(1).every((p) => p.date.weekday == DateTime.monday),
        isTrue,
      );
      // Monday 12 to Thursday 15 October: 3, 2, 1 and 0 days ago.
      expect(visible.last, (date: DateTime(2026, 10, 12), value: 1.5));
    });

    test('a year averages into months', () {
      final visible = MetricRange.year.visible(points, today);
      expect(visible, hasLength(13));
      // 1 to 15 October: 14 down to 0 days ago.
      expect(visible.last, (date: DateTime(2026, 10), value: 7.0));
    });

    test('leaves out readings after today', () {
      final visible = MetricRange.week.visible([at(-1, 1), at(0, 2)], today);
      expect(visible.map((p) => p.value), [2.0]);
    });
  });
}

Matcher isBefore(DateTime date) =>
    predicate<DateTime>((value) => value.isBefore(date), 'before $date');
