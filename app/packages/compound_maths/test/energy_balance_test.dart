// `ExpenditureEstimate.likelyRange` and `.confidence`, and
// `EnergyBalanceSummary`, as the Swift defines them (ExpenditureModels.swift,
// EnergyBalanceSummary.swift); expected values worked by hand.
import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

ExpenditureEstimate estimate({
  String day = '2026-03-01',
  double kcal = 2450,
  ExpenditureSource source = ExpenditureSource.adaptive,
  double? sdKcal = 110,
}) => ExpenditureEstimate(
  day: day,
  kcal: kcal,
  source: source,
  isProvisional: source != ExpenditureSource.adaptive,
  trendWeightKg: 80,
  weeklyTrendChangeKg: -0.4,
  loggedDays: 26,
  weighInCount: 24,
  windowDays: 28,
  stepAdjustmentKcal: 0,
  sdKcal: sdKcal,
  weeklyTrendChangeSDKg: null,
  recentIntakeKcal: null,
);

void main() {
  group('likely range', () {
    test('is the estimate ± 1.28 SD, rounded', () {
      final range = estimate().likelyRange!;
      expect(range.low, 2309); // 2450 − 140.8
      expect(range.high, 2591);
    });

    test('is null until adaptive, without an SD, or when not finite', () {
      expect(estimate(source: ExpenditureSource.prior).likelyRange, isNull);
      expect(estimate(source: ExpenditureSource.fixed).likelyRange, isNull);
      expect(estimate(sdKcal: null).likelyRange, isNull);
      expect(estimate(sdKcal: double.nan).likelyRange, isNull);
      expect(estimate(kcal: double.infinity).likelyRange, isNull);
    });
  });

  group('confidence', () {
    test('high below 120 kcal SD, medium to 250, low above', () {
      expect(estimate(sdKcal: 119.9).confidence, ExpenditureConfidence.high);
      expect(estimate(sdKcal: 120).confidence, ExpenditureConfidence.medium);
      expect(estimate(sdKcal: 250).confidence, ExpenditureConfidence.medium);
      expect(estimate(sdKcal: 250.1).confidence, ExpenditureConfidence.low);
    });

    test('calibrating until adaptive with an SD', () {
      expect(
        estimate(source: ExpenditureSource.prior).confidence,
        ExpenditureConfidence.calibrating,
      );
      expect(
        estimate(sdKcal: null).confidence,
        ExpenditureConfidence.calibrating,
      );
    });
  });

  group('expenditure on a day', () {
    test('the day estimate, the last after it, the formula before', () {
      final on = expenditureOn([
        estimate(day: '2026-03-02', kcal: 2400),
        estimate(day: '2026-03-03', kcal: 2500),
      ], 2200);
      expect(on('2026-03-01'), 2200);
      expect(on('2026-03-02'), 2400);
      expect(on('2026-03-03'), 2500);
      expect(on('2026-03-09'), 2500);
    });

    test('the formula every day with no history', () {
      expect(expenditureOn(const [], 2200)('2026-03-09'), 2200);
    });
  });

  group('logged average', () {
    test('averages only the days with calories', () {
      final average = loggedAverage([2000, 0, 2400, 0])!;
      expect(average.meanKcal, 2200);
      expect(average.days, 2);
    });

    test('is null with nothing logged', () {
      expect(loggedAverage([0, 0]), isNull);
    });
  });

  // ProgressCarouselMetricsTests.testAveragesSkipUnloggedDays.
  group('compared averages', () {
    const days = [
      (intake: 2000.0, expenditure: 2500.0, target: 2200.0),
      (intake: 0.0, expenditure: 3000.0, target: 2200.0),
      (intake: 2400.0, expenditure: 2700.0, target: null),
    ];

    test('averages only the logged days, each against its comparison', () {
      final expenditure = comparedAverages([
        for (final d in days) (intake: d.intake, comparison: d.expenditure),
      ])!;
      final targets = comparedAverages([
        for (final d in days) (intake: d.intake, comparison: d.target),
      ])!;
      expect(expenditure.intake, 2200);
      expect(expenditure.comparison, 2600);
      expect(targets.comparison, 2200);
    });

    test('is null with nothing logged or nothing to compare', () {
      expect(comparedAverages([(intake: 0, comparison: 3000)]), isNull);
      expect(comparedAverages([(intake: 2000, comparison: null)]), isNull);
    });
  });
}
