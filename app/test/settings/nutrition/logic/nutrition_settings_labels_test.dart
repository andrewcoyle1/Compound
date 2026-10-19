import 'package:compound/settings/nutrition/logic/nutrition_settings_labels.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:flutter_test/flutter_test.dart';

maths.ExpenditureEstimate _estimate({
  double kcal = 2480,
  maths.ExpenditureSource source = maths.ExpenditureSource.adaptive,
  int loggedDays = 21,
  int windowDays = 28,
  double stepAdjustmentKcal = 0,
  double? sdKcal = 100,
}) => maths.ExpenditureEstimate(
  day: '2026-10-15',
  kcal: kcal,
  source: source,
  isProvisional: source == maths.ExpenditureSource.prior,
  trendWeightKg: null,
  weeklyTrendChangeKg: null,
  loggedDays: loggedDays,
  weighInCount: 14,
  windowDays: windowDays,
  stepAdjustmentKcal: stepAdjustmentKcal,
  sdKcal: sdKcal,
  weeklyTrendChangeSDKg: null,
  recentIntakeKcal: null,
);

void main() {
  group('weekdayName', () {
    test('counts from Sunday, as Swift does', () {
      expect(
        [for (var day = 1; day <= 7; day++) weekdayName(day, 'en_US')],
        [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ],
      );
    });

    test('reads anything out of range as Monday', () {
      expect(weekdayName(0, 'en_US'), 'Monday');
      expect(weekdayName(8, 'en_US'), 'Monday');
    });
  });

  group(ExpenditureStatus, () {
    test('an adaptive estimate says how much was logged', () {
      final status = ExpenditureStatus.of(_estimate());
      expect(
        status,
        isA<ExpenditureAdaptive>()
            .having((s) => s.loggedDays, 'loggedDays', 21)
            .having((s) => s.windowDays, 'windowDays', 28),
      );
    });

    test('a provisional estimate is still calibrating', () {
      expect(
        ExpenditureStatus.of(_estimate(source: maths.ExpenditureSource.prior)),
        isA<ExpenditureCalibrating>(),
      );
      expect(ExpenditureCalibrating.minDays, 21);
      expect(ExpenditureCalibrating.minWeighIns, 14);
    });

    test('a fixed estimate says fixed', () {
      expect(
        ExpenditureStatus.of(_estimate(source: maths.ExpenditureSource.fixed)),
        isA<ExpenditureFixed>(),
      );
    });
  });

  group('likelyRange', () {
    test('is the 80% interval, rounded, once adaptive', () {
      expect(likelyRange(_estimate()), (low: 2352, high: 2608));
    });

    test('is null otherwise', () {
      expect(
        likelyRange(_estimate(source: maths.ExpenditureSource.prior)),
        isNull,
      );
      expect(likelyRange(_estimate(sdKcal: null)), isNull);
      expect(likelyRange(_estimate(sdKcal: double.nan)), isNull);
      expect(likelyRange(_estimate(kcal: double.infinity)), isNull);
    });
  });

  group('stepAdjustment', () {
    test('is called out separately, and null when none applied', () {
      expect(stepAdjustment(_estimate(stepAdjustmentKcal: 120.4)), 120);
      expect(stepAdjustment(_estimate(stepAdjustmentKcal: -80)), -80);
      expect(stepAdjustment(_estimate(stepAdjustmentKcal: 0.3)), isNull);
    });
  });
}
