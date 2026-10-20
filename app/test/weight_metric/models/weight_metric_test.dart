import 'package:body_repository/body_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// The shaping Swift `WeightTrendPresenterTests` checks: what is left out,
/// and how the trend behaves.
void main() {
  final start = DateTime(2026, 10, 15, 7);

  BodyMeasurementEntry entry(
    String id,
    double? weightKg,
    int daysAgo, {
    bool deleted = false,
  }) {
    final date = start.subtract(Duration(days: daysAgo));
    return BodyMeasurementEntry(
      id: id,
      authorId: 'author-1',
      weightKg: weightKg,
      waistCircumference: weightKg == null ? 81 : null,
      date: date,
      source: WeightSource.manual,
      dateCreated: date,
      deletedAt: deleted ? date : null,
    );
  }

  group(WeightMetric, () {
    test('names its routes and titles', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(WeightMetric.scaleWeight.path, 'scale-weight');
      expect(WeightMetric.weightTrend.dataRouteName, 'weightTrendData');
      expect(WeightMetric.scaleWeight.title(l10n), 'Scale Weight');
      expect(WeightMetric.weightTrend.title(l10n), 'Weight Trend');
    });
  });

  group('weighInsOf', () {
    test('leaves out deleted weigh-ins', () {
      final weighIns = weighInsOf([
        entry('e1', 73, 2),
        entry('gone', 99, 1, deleted: true),
        entry('e3', 72.4, 0),
      ]);
      expect(weighIns.map((e) => e.id), ['e1', 'e3']);
    });

    test('leaves out entries without a weight', () {
      final weighIns = weighInsOf([
        entry('e1', 73, 1),
        entry('waist', null, 0),
      ]);
      expect(weighIns.map((e) => e.id), ['e1']);
    });

    test('runs oldest first', () {
      final weighIns = weighInsOf([
        entry('e3', 72.4, 0),
        entry('e1', 73, 2),
        entry('e2', 72.6, 1),
      ]);
      expect(weighIns.map((e) => e.id), ['e1', 'e2', 'e3']);
    });
  });

  group('trendOf', () {
    test('has a point per weigh-in, at its date', () {
      final weighIns = [entry('e1', 73, 2), entry('e2', 72.6, 1)];
      expect(trendOf(weighIns).map((p) => p.date), [
        for (final e in weighIns) e.date,
      ]);
    });

    test('starts at the median of the first readings', () {
      final trend = trendOf([
        entry('e1', 80, 2),
        entry('e2', 70, 1),
        entry('e3', 70, 0),
      ]);
      expect((trend.first.value - 70).abs(), lessThan(0.5));
    });

    test('a spike barely moves the trend', () {
      final trend = trendOf([
        for (var d = 10; d >= 2; d--) entry('e$d', 72, d),
        entry('spike', 74.5, 0),
      ]);
      expect(trend.last.value, greaterThan(72));
      expect(trend.last.value, lessThan(73));
    });

    test('a wild reading is left out of the trend', () {
      final trend = trendOf([
        for (var d = 10; d >= 2; d--) entry('e$d', 72, d),
        entry('typo', 7.2, 0),
      ]);
      expect((trend.last.value - 72).abs(), lessThan(1e-9));
    });

    test('is empty without weigh-ins', () {
      expect(trendOf(const []), isEmpty);
    });
  });

  // GoalTimelineTests / NutritionTargetsTests: the weight goal progress is
  // measured from.
  group('latestTrendWeightKg', () {
    test('is null with no weigh-ins', () {
      expect(latestTrendWeightKg(const []), isNull);
      expect(latestTrendWeightKg([entry('waist', null, 0)]), isNull);
    });

    test('is the trend at the latest weigh-in', () {
      final entries = [for (var d = 10; d >= 0; d--) entry('e$d', 72, d)];
      expect(latestTrendWeightKg(entries), closeTo(72, 1e-9));
      expect(latestTrendWeightKg(entries), trendOf(entries).last.value);
    });

    test('leaves out deleted, zero and non-finite weights', () {
      final kept = [entry('a', 80, 2), entry('b', 80, 1)];
      expect(
        latestTrendWeightKg([
          ...kept,
          entry('gone', 60, 0, deleted: true),
          entry('zero', 0, 0),
          entry('nan', double.nan, 0),
        ]),
        latestTrendWeightKg(kept),
      );
    });
  });
}
