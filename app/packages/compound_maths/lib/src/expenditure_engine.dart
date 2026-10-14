/// Turns what the user logged into a day-by-day expenditure estimate
/// (`ExpenditureEngine.swift`, `ExpenditureWindowStats.swift`,
/// `ExpenditureEstimate` in `ExpenditureModels.swift`).
library;

import 'dart:math' as math;

import 'package:compound_maths/src/day_key.dart';
import 'package:compound_maths/src/energy_density.dart';
import 'package:compound_maths/src/expenditure_filter.dart';
import 'package:compound_maths/src/expenditure_samples.dart';
import 'package:compound_maths/src/weight_trend.dart';

/// Every tunable of the engine (`ExpenditureEngine.Constants`).
abstract final class ExpenditureConstants {
  /// The window the status counts, the logged fraction and the nowcast read.
  static const windowDays = 28;

  /// Design choice: calibrating until 21 days of data…
  static const minDays = 21;

  /// …14 weigh-ins…
  static const minWeighIns = 14;

  /// …an SD under 200 kcal…
  static const maxCalibratedSDKcal = 200.0;

  /// …and 80% of the window's days completely logged.
  static const calibratedLoggedFraction = 0.8;

  /// Design choice: a logged day below half the estimate is read as partly
  /// logged, unless a fast.
  static const partialDayFraction = 0.5;

  /// σ_I is the user's own SD of logged intake, held inside 300–500 kcal…
  static const intakeNoiseMinKcal = 300.0;

  /// …see [intakeNoiseMinKcal].
  static const intakeNoiseMaxKcal = 500.0;

  /// …400 until there are [intakeNoiseMinDays] logged days.
  static const intakeNoiseDefaultKcal = 400.0;

  /// See [intakeNoiseDefaultKcal].
  static const intakeNoiseMinDays = 7;

  /// Below 60% of days logged, σ_I is multiplied by [intakeNoiseInflation].
  static const inflatedNoiseBelowLoggedFraction = 0.6;

  /// See [inflatedNoiseBelowLoggedFraction].
  static const intakeNoiseInflation = 2.0;

  /// Guard only: the figure shown never leaves 60–160% of the formula.
  static const priorBoundLow = 0.6;

  /// See [priorBoundLow].
  static const priorBoundHigh = 1.6;

  /// Net walking cost (ACSM walking equation), kcal per step per kg.
  static const kcalPerStepPerKg = 0.0004;

  /// The step nowcast never moves the figure more than this.
  static const maxStepNowcastKcal = 300.0;

  /// The trailing window the nowcast compares against the whole window.
  static const nowcastRecentDays = 7;

  /// The adherence check averages this many days of complete logged intake.
  static const recentIntakeDays = 7;
}

/// Where an estimate came from (`ExpenditureEstimate.Source`).
enum ExpenditureSource {
  /// The formula, while the filter calibrates.
  prior,

  /// The filter.
  adaptive,

  /// The formula, held by the user's choice.
  fixed,
}

/// Whether the estimate adapts (`ExpenditureCalculationMode`).
enum ExpenditureCalculationMode { dynamic, fixed }

/// The settings the engine reads (from `NutritionStrategySettings`).
///
/// [calculationStartDay] restarts the replay from that day.
class const ExpenditureSettings({
  final ExpenditureCalculationMode calculationMode =
      ExpenditureCalculationMode.dynamic,
  final String? calculationStartDay,
  final bool stepInformedUpdates = false,
});

/// One day's estimate (`ExpenditureEstimate`).
class const ExpenditureEstimate({
  required final String day,
  required final double kcal,
  required final ExpenditureSource source,
  required final bool isProvisional,
  required final double? trendWeightKg,
  required final double? weeklyTrendChangeKg,

  /// Complete logged days in the window: logged, not excluded, not read as
  /// partial.
  required final int loggedDays,
  required final int weighInCount,

  /// Days in the window with a sample.
  required final int windowDays,
  required final double stepAdjustmentKcal,
  required final double? sdKcal,
  required final double? weeklyTrendChangeSDKg,

  /// Mean intake over the complete logged days of the last week, for the
  /// adherence check.
  required final double? recentIntakeKcal,
});

double _clamped(double value, double low, double high, double whenNotFinite) =>
    value.isFinite ? value.clamp(low, high) : whenNotFinite;

double _mean(Iterable<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

double _sampleSD(List<double> values) {
  final m = _mean(values);
  final squares = values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b);
  return math.sqrt(squares / (values.length - 1));
}

/// One estimate per day from the first usable sample through [today]
/// (`ExpenditureEngine.history`).
///
/// [priorKcal] is the formula expenditure; [kcalPerKg] the energy in a kilogram
/// of change (`energyDensityKcalPerKg`). Samples on or after [today], or before
/// the settings' start day, are ignored. With none left, the result is the
/// prior for [today] alone.
List<ExpenditureEstimate> expenditureHistory({
  required List<DailySample> samples,
  required double priorKcal,
  required String today,
  ExpenditureSettings settings = const ExpenditureSettings(),
  double kcalPerKg = EnergyDensity.conventionalKcalPerKg,
}) {
  final prior = priorKcal.isFinite ? priorKcal : 0.0;
  final rho = kcalPerKg.isFinite && kcalPerKg > 0
      ? kcalPerKg
      : EnergyDensity.conventionalKcalPerKg;
  final fixed = settings.calculationMode == ExpenditureCalculationMode.fixed;
  final start = settings.calculationStartDay;
  final usable =
      samples.indexed
          .where(
            (e) =>
                e.$2.day.compareTo(today) < 0 &&
                (start == null || e.$2.day.compareTo(start) >= 0),
          )
          .toList()
        // Stable, as the JavaScript's sort is.
        ..sort((a, b) {
          final order = a.$2.day.compareTo(b.$2.day);
          return order != 0 ? order : a.$1.compareTo(b.$1);
        });
  if (usable.isEmpty) {
    return [
      ExpenditureEstimate(
        day: today,
        kcal: prior.roundToDouble(),
        source: fixed ? ExpenditureSource.fixed : ExpenditureSource.prior,
        isProvisional: !fixed,
        trendWeightKg: null,
        weeklyTrendChangeKg: null,
        loggedDays: 0,
        weighInCount: 0,
        windowDays: 0,
        stepAdjustmentKcal: 0,
        sdKcal: null,
        weeklyTrendChangeSDKg: null,
        recentIntakeKcal: null,
      ),
    ];
  }

  final byDay = {for (final (_, s) in usable) s.day: s};
  final firstDay = usable.first.$2.day;
  final seed = median(
    [
      for (final (_, s) in usable)
        if (s.weightKg != null) s.weightKg!,
    ].take(WeighInNoise.seedWeighIns).toList(),
  );
  return _Replay(
    byDay: byDay,
    firstDay: firstDay,
    seed: seed,
    prior: prior,
    rho: rho,
    fixed: fixed,
    stepInformed: settings.stepInformedUpdates,
  ).run(today);
}

class _Replay({
  required final Map<String, DailySample> byDay,
  required final String firstDay,
  required final double? seed,
  required final double prior,
  required final double rho,
  required final bool fixed,
  required final bool stepInformed,
}) {
  final Set<String> usedIntake = {};
  ExpenditureFilter? filter;
  int weighInsUsed = 0;

  List<ExpenditureEstimate> run(String today) {
    final estimates = <ExpenditureEstimate>[];
    for (var day = firstDay; day.compareTo(today) <= 0; day = addDays(day, 1)) {
      estimates.add(estimateFor(day));
      if (day.compareTo(today) < 0) process(day);
    }
    return estimates;
  }

  void process(String day) {
    final sample = byDay[day];
    var isFirstFilterDay = false;
    final current = filter;
    if (current != null) {
      current.predictOneDay(rho);
    } else if (sample?.weightKg != null) {
      // The filter starts on the first weigh-in, at the median of the first
      // few.
      filter = ExpenditureFilter(seed!, prior);
      weighInsUsed = 1;
      isFirstFilterDay = true;
    }
    if (sample == null) return;
    final f = filter;
    final weight = sample.weightKg;
    if (f != null && !isFirstFilterDay && weight != null) {
      if (f.observeWeighIn(weight)) weighInsUsed += 1;
    }

    final intake = sample.intakeKcal;
    if (intake == null || sample.isExcluded) return;
    // A logged day far below what the body spends is read as partly logged,
    // unless a fast.
    final expenditure = f?.expenditureKcal ?? prior;
    if (!sample.isFastingDay &&
        intake < ExpenditureConstants.partialDayFraction * expenditure) {
      return;
    }
    usedIntake.add(day);
    f?.observeIntake(intake, intakeNoise(day));
  }

  /// σ_I for a logged day: the SD of the complete logged days in the 28 days
  /// ending on it, held inside 300–500 kcal, doubled when under 60% of those
  /// days are logged.
  double intakeNoise(String day) {
    final values = <double>[];
    var present = 0;
    for (
      var offset = 1 - ExpenditureConstants.windowDays;
      offset <= 0;
      offset++
    ) {
      final d = addDays(day, offset);
      final sample = byDay[d];
      if (sample == null) continue;
      present += 1;
      if (usedIntake.contains(d)) values.add(sample.intakeKcal!);
    }
    final sd = values.length >= ExpenditureConstants.intakeNoiseMinDays
        ? _clamped(
            _sampleSD(values),
            ExpenditureConstants.intakeNoiseMinKcal,
            ExpenditureConstants.intakeNoiseMaxKcal,
            ExpenditureConstants.intakeNoiseDefaultKcal,
          )
        : ExpenditureConstants.intakeNoiseDefaultKcal;
    return values.length <
            ExpenditureConstants.inflatedNoiseBelowLoggedFraction * present
        ? sd * ExpenditureConstants.intakeNoiseInflation
        : sd;
  }

  ExpenditureEstimate estimateFor(String day) {
    final window = <DailySample>[
      for (
        var offset = -ExpenditureConstants.windowDays;
        offset <= -1;
        offset++
      )
        ?byDay[addDays(day, offset)],
    ];
    final f = filter;
    final trendWeightKg = f?.levelKg;
    final loggedDays = window.where((s) => usedIntake.contains(s.day)).length;
    final daysPresent = window.length;
    final recent = [
      for (final s in window.skip(
        math.max(0, window.length - ExpenditureConstants.recentIntakeDays),
      ))
        if (usedIntake.contains(s.day)) s.intakeKcal!,
    ];

    final enoughWeighIns =
        f != null &&
        daysBetween(firstDay, day) >= ExpenditureConstants.minDays &&
        weighInsUsed >= ExpenditureConstants.minWeighIns;
    double? weeklyChange;
    double? weeklyChangeSD;
    if (enoughWeighIns) {
      final p = f.covariance;
      weeklyChange = (f.intakeKcal - f.expenditureKcal) * 7 / rho;
      weeklyChangeSD = math.sqrt(math.max(0, p[4] + p[8] - 2 * p[5])) * 7 / rho;
    }
    final sdKcal = f?.expenditureSD;

    ExpenditureEstimate estimate({
      required double kcal,
      required ExpenditureSource source,
      required bool isProvisional,
      required double? sd,
      double stepAdjustmentKcal = 0,
    }) => ExpenditureEstimate(
      day: day,
      kcal: kcal.roundToDouble(),
      source: source,
      isProvisional: isProvisional,
      trendWeightKg: trendWeightKg,
      weeklyTrendChangeKg: weeklyChange,
      loggedDays: loggedDays,
      weighInCount: window.where((s) => s.weightKg != null).length,
      windowDays: daysPresent,
      stepAdjustmentKcal: stepAdjustmentKcal,
      sdKcal: sd,
      weeklyTrendChangeSDKg: weeklyChangeSD,
      recentIntakeKcal: recent.isEmpty ? null : _mean(recent),
    );

    if (fixed) {
      return estimate(
        kcal: prior,
        source: ExpenditureSource.fixed,
        isProvisional: false,
        sd: null,
      );
    }
    final loggedFraction = daysPresent > 0 ? loggedDays / daysPresent : 0;
    final calibrated =
        enoughWeighIns &&
        sdKcal! < ExpenditureConstants.maxCalibratedSDKcal &&
        loggedFraction >= ExpenditureConstants.calibratedLoggedFraction;
    if (!calibrated) {
      return estimate(
        kcal: prior,
        source: ExpenditureSource.prior,
        isProvisional: true,
        sd: sdKcal,
      );
    }
    final bounded = prior > 0
        ? _clamped(
            f.expenditureKcal,
            prior * ExpenditureConstants.priorBoundLow,
            prior * ExpenditureConstants.priorBoundHigh,
            prior,
          )
        : f.expenditureKcal;
    final nowcast = stepInformed ? stepNowcast(window, trendWeightKg!) : 0.0;
    return estimate(
      kcal: bounded + nowcast,
      source: ExpenditureSource.adaptive,
      isProvisional: false,
      sd: sdKcal,
      stepAdjustmentKcal: nowcast,
    );
  }

  /// The step nowcast (`ExpenditureWindowStats`): the last week's mean steps
  /// against the window's, at the net walking cost, within ±300 kcal; nothing
  /// unless half the window's days have steps.
  double stepNowcast(List<DailySample> window, double trendWeightKg) {
    final stepDays = [
      for (final s in window)
        if (s.steps != null) s.steps!.toDouble(),
    ];
    if (stepDays.isEmpty || stepDays.length * 2 < window.length) return 0;
    final recent = stepDays.skip(
      math.max(0, stepDays.length - ExpenditureConstants.nowcastRecentDays),
    );
    final raw =
        (_mean(recent) - _mean(stepDays)) *
        ExpenditureConstants.kcalPerStepPerKg *
        trendWeightKg;
    return _clamped(
      raw,
      -ExpenditureConstants.maxStepNowcastKcal,
      ExpenditureConstants.maxStepNowcastKcal,
      0,
    );
  }
}
