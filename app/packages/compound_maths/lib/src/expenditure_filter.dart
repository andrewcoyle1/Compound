/// The `[L, E, T]` Kalman filter behind the expenditure estimate
/// (`ExpenditureFilter.swift`).
library;

import 'dart:math' as math;

import 'package:compound_maths/src/weight_trend.dart';

/// One Kalman filter, run a day at a time, whose state is the trend weight L
/// (kg), habitual intake E and expenditure T (kcal/day on the scale the user
/// logs). Weigh-ins observe L, complete logged days observe E, and L moves by
/// (E − T)/ρ a day.
///
/// Starts at a trend weight of `levelKg`, with E and T both at the formula
/// prior `priorKcal`.
class ExpenditureFilter(double levelKg, double priorKcal) {
  /// Design choice: q_E, intake drift per day.
  static const intakeDriftKcalPerDay = 30.0;

  /// Design choice: q_T, expenditure drift per day.
  static const expenditureDriftKcalPerDay = 13.0;

  /// The prior on T has SD the larger of this fraction and [priorSDFloorKcal].
  static const priorSDFraction = 0.15;

  /// NASEM 2023's RMSE.
  static const priorSDFloorKcal = 340.0;

  /// Design choice: E starts at the prior with this SD.
  static const initialIntakeSDKcal = 500.0;

  /// `[L, E, T]`.
  List<double> state = [levelKg, priorKcal, priorKcal];

  /// Row-major 3×3 covariance.
  List<double> covariance = _initialCovariance(levelKg, priorKcal);

  /// A gross weigh-in waiting for the next one to confirm it, as its
  /// innovation.
  double? heldInnovation;

  static List<double> _initialCovariance(double levelKg, double priorKcal) {
    final priorSD = math.max(priorSDFloorKcal, priorSDFraction * priorKcal);
    return [
      WeighInNoise.variance(levelKg), 0, 0, //
      0, initialIntakeSDKcal * initialIntakeSDKcal, 0, //
      0, 0, priorSD * priorSD,
    ];
  }

  /// The trend weight, kg.
  double get levelKg => state[0];

  /// Habitual intake, kcal/day.
  double get intakeKcal => state[1];

  /// Expenditure, kcal/day.
  double get expenditureKcal => state[2];

  /// The SD of [expenditureKcal].
  double get expenditureSD => math.sqrt(math.max(0, covariance[8]));

  /// One day forward: L += (E − T)/ρ, E and T carried, each gaining its process
  /// noise.
  void predictOneDay(double kcalPerKg) {
    final step = 1 / kcalPerKg;
    final transition = [1.0, step, -step, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
    final next = _multiply(
      _multiply(transition, covariance),
      _transpose(transition),
    );
    next[0] +=
        WeighInNoise.levelNoiseKgPerDay * WeighInNoise.levelNoiseKgPerDay;
    next[4] += intakeDriftKcalPerDay * intakeDriftKcalPerDay;
    next[8] += expenditureDriftKcalPerDay * expenditureDriftKcalPerDay;
    state = [state[0] + (state[1] - state[2]) * step, state[1], state[2]];
    covariance = next;
  }

  /// A weigh-in. Returns `false` when the reading is held as a probable error
  /// rather than used.
  ///
  /// The same rules as the trend line: a Huber-weighted update, and a reading
  /// more than max(3 kg, 4%) from the trend waits for the next weigh-in to
  /// agree before it counts.
  bool observeWeighIn(double weightKg) {
    final level = state[0];
    final innovation = weightKg - level;
    if (!WeighInNoise.isGrossError(innovation, level)) {
      heldInnovation = null;
      _observe(
        0,
        weightKg,
        WeighInNoise.robustVariance(innovation, covariance[0], level),
      );
      return true;
    }
    final held = heldInnovation;
    if (held != null && (held > 0) == (innovation > 0)) {
      heldInnovation = null;
      covariance[0] += innovation * innovation;
      _observe(0, weightKg, WeighInNoise.variance(level));
      return true;
    }
    heldInnovation = innovation;
    return false;
  }

  /// A complete logged day's intake, with its noise SD.
  void observeIntake(double intakeKcal, double sdKcal) =>
      _observe(1, intakeKcal, sdKcal * sdKcal);

  void _observe(int index, double value, double variance) {
    final innovation = value - state[index];
    final total = covariance[index * 4] + variance;
    if (!(total > 0) || !total.isFinite) return;
    final gain = [
      covariance[index] / total,
      covariance[3 + index] / total,
      covariance[6 + index] / total,
    ];
    final previous = covariance;
    state = [for (var i = 0; i < 3; i++) state[i] + gain[i] * innovation];
    covariance = [
      for (var i = 0; i < 9; i++)
        previous[i] - gain[i ~/ 3] * previous[index * 3 + i % 3],
    ];
  }

  static List<double> _multiply(List<double> a, List<double> b) => [
    for (var i = 0; i < 9; i++)
      a[(i ~/ 3) * 3] * b[i % 3] +
          a[(i ~/ 3) * 3 + 1] * b[3 + i % 3] +
          a[(i ~/ 3) * 3 + 2] * b[6 + i % 3],
  ];

  static List<double> _transpose(List<double> m) => [
    m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8], //
  ];
}
