/// How sure an expenditure estimate is (`ExpenditureEstimate.likelyRange`
/// and `.confidence`), and the energy balance built on it
/// (`EnergyBalanceSummary.swift`).
library;

import 'package:compound_maths/src/expenditure_engine.dart';

/// The two-sided 80% normal quantile: an 80% interval is the estimate ±
/// 1.28 SD (`ExpenditureEstimate.eightyPercentZ`).
const eightyPercentZ = 1.28;

/// How sure the estimate is, for a badge (`ExpenditureEstimate.Confidence`).
enum ExpenditureConfidence { calibrating, low, medium, high }

/// The interval and badge of an [ExpenditureEstimate].
extension ExpenditureEstimateCertainty on ExpenditureEstimate {
  /// The 80% interval, rounded, once the estimate is adaptive; null before,
  /// or when either figure is not finite.
  ({double low, double high})? get likelyRange {
    final sd = sdKcal;
    if (source != ExpenditureSource.adaptive ||
        sd == null ||
        !sd.isFinite ||
        !kcal.isFinite) {
      return null;
    }
    final half = eightyPercentZ * sd;
    return (
      low: (kcal - half).roundToDouble(),
      high: (kcal + half).roundToDouble(),
    );
  }

  /// High below 120 kcal SD, medium to 250, low above; calibrating until
  /// adaptive. A design choice, tuned by replay.
  ExpenditureConfidence get confidence {
    final sd = sdKcal;
    if (source != ExpenditureSource.adaptive || sd == null) {
      return ExpenditureConfidence.calibrating;
    }
    if (sd < 120) return ExpenditureConfidence.high;
    if (sd <= 250) return ExpenditureConfidence.medium;
    return ExpenditureConfidence.low;
  }
}

/// Each day's expenditure (`EnergyBalanceSummary.expenditureLookup`): the
/// estimate for that day where [history] has one, the last estimate after
/// it stops (a logging break freezes it there), and [formulaKcal] before it
/// starts. [history] is in day order.
double Function(String day) expenditureOn(
  List<ExpenditureEstimate> history,
  double formulaKcal,
) {
  final byDay = {for (final estimate in history) estimate.day: estimate.kcal};
  final last = history.isEmpty ? null : history.last;
  return (day) =>
      byDay[day] ??
      (last != null && day.compareTo(last.day) > 0 ? last.kcal : formulaKcal);
}

/// The mean intake and the mean comparison (an expenditure or a target)
/// over the days something was logged, or null when nothing was logged or
/// none of those days has a comparison: an unlogged day is not a day of
/// eating nothing (`ProgressCarouselMetrics.averages`).
({double intake, double comparison})? comparedAverages(
  Iterable<({double intake, double? comparison})> days,
) {
  final logged = [
    for (final day in days)
      if (day.intake > 0) day,
  ];
  final compared = [for (final day in logged) ?day.comparison];
  if (logged.isEmpty || compared.isEmpty) return null;
  return (
    intake: logged.map((d) => d.intake).reduce((a, b) => a + b) / logged.length,
    comparison: compared.reduce((a, b) => a + b) / compared.length,
  );
}

/// The mean of the logged days of [dailyCalories] (any calories at all) and
/// how many there were, or null when none was
/// (`EnergyBalanceSummary.loggedAverage`).
({double meanKcal, int days})? loggedAverage(Iterable<double> dailyCalories) {
  final logged = [
    for (final kcal in dailyCalories)
      if (kcal > 0) kcal,
  ];
  if (logged.isEmpty) return null;
  return (
    meanKcal: logged.reduce((a, b) => a + b) / logged.length,
    days: logged.length,
  );
}
