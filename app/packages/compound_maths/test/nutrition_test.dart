// The nutrition rules the fixture cannot carry (values JSON has no spelling
// for, and the screens' small sums), worked by hand from the Swift.
import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

void main() {
  group('nutrition targets', () {
    test('an unusable height leaves total weight', () {
      for (final height in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(referenceWeightKg(weightKg: 130, heightCm: height), 130);
      }
    });

    test('an unusable goal weight is ignored', () {
      expect(
        referenceWeightKg(
          weightKg: 130,
          heightCm: 175,
          goalWeightKg: double.nan,
        ),
        closeTo(91.875, 1e-9),
      );
    });

    test('an unusable weight reads as 70 kg', () {
      final days = dietPlanDays(
        expenditureKcal: 2500,
        weightKg: double.nan,
        diet: PreferredDiet.balanced,
        distribution: CalorieDistribution.even,
        protein: ProteinIntake.low,
      );
      expect(days.first.proteinGrams, 112);
    });

    test('raw values parse, and anything else is null', () {
      expect(ProteinIntake.tryParse('veryHigh'), ProteinIntake.veryHigh);
      expect(PreferredDiet.tryParse('lowCarb'), PreferredDiet.lowCarb);
      expect(
        CalorieDistribution.tryParse('varied'),
        CalorieDistribution.varied,
      );
      expect(ProteinIntake.tryParse(null), isNull);
      expect(PreferredDiet.tryParse('paleo'), isNull);
      expect(CalorieDistribution.tryParse(''), isNull);
    });

    test('a varied week totals seven times the target', () {
      final week = dailyCalories(
        target: 2000,
        floor: 1200,
        distribution: CalorieDistribution.varied,
        trainingDaysPerWeek: 3,
      );
      expect(week.reduce((a, b) => a + b), closeTo(14000, 1e-9));
    });
  });

  group('target proposal', () {
    const estimate = ExpenditureEstimate(
      day: '2026-06-15',
      kcal: double.infinity,
      source: ExpenditureSource.adaptive,
      isProvisional: false,
      trendWeightKg: 80,
      weeklyTrendChangeKg: null,
      loggedDays: 24,
      weighInCount: 20,
      windowDays: 28,
      stepAdjustmentKcal: 0,
      sdKcal: 100,
      weeklyTrendChangeSDKg: null,
      recentIntakeKcal: null,
    );

    test('a figure that is not finite moves nothing', () {
      final proposal = proposeTarget(
        estimate: estimate,
        plan: (dayCalories: List.filled(7, 2000), createdDay: '2026-05-01'),
      );
      expect(proposal?.proposedTargetKcal, 2000);
    });

    test('a dismissal is kept per account', () {
      expect(dismissedProposalKey(null), 'dismissedTargetProposalKcal');
      expect(dismissedProposalKey(''), 'dismissedTargetProposalKcal');
      expect(dismissedProposalKey('u1'), 'dismissedTargetProposalKcal.u1');
    });
  });

  group('check-in schedule', () {
    test('the week starts on Monday', () {
      expect(checkInWeekStart('2026-09-27'), '2026-09-21');
      expect(dayOffsetInWeek(1), 6);
      expect(dayOffsetInWeek(2), 0);
    });
  });

  group('daily macros', () {
    const meal = (
      calories: 500.0,
      proteinGrams: 30.0,
      carbGrams: 60.0,
      fatGrams: 15.0,
    );

    test('totals are a plain sum', () {
      expect(sumMacros([]), zeroMacros);
      expect(sumMacros([meal, meal]), (
        calories: 1000.0,
        proteinGrams: 60.0,
        carbGrams: 120.0,
        fatGrams: 30.0,
      ));
    });

    test('progress is held to 0–1 and is 0 without a target', () {
      expect(macroProgress(50, 200), 0.25);
      expect(macroProgress(300, 200), 1);
      expect(macroProgress(-5, 200), 0);
      expect(macroProgress(50, 0), 0);
    });

    test('the share is unclamped and 0 without a target', () {
      expect(macroShare(2400, 2000), 1.2);
      expect(macroShare(2400, null), 0);
      expect(macroShare(2400, 0), 0);
    });

    test("a plan's day is found by weekday, Monday first", () {
      final week = [
        for (var i = 0; i < 7; i++)
          (
            calories: 2000.0 + i,
            proteinGrams: 0.0,
            carbGrams: 0.0,
            fatGrams: 0.0,
          ),
      ];
      expect(planDayTarget(week, '2026-09-21')?.calories, 2000);
      expect(planDayTarget(week, '2026-09-27')?.calories, 2006);
      expect(planDayTarget(week.sublist(0, 3), '2026-09-27'), isNull);
    });
  });
}
