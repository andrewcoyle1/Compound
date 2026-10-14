/// The weight trend: one Kalman filter for the chart and the engine
/// (`WeightTrendCalculator.swift`).
library;

import 'dart:math' as math;

import 'package:compound_maths/src/day_key.dart';

/// How a weigh-in is read, shared by the trend and the expenditure filter
/// (`WeighInNoise`).
abstract final class WeighInNoise {
  /// R_W = (0.5% of body weight)², from a 0.53% day-to-day SD (Schneditz 2023).
  static const noiseFraction = 0.005;

  /// Design choice: the noise never drops below (0.3 kg)².
  static const noiseFloorKg = 0.3;

  /// Design choice: q_L, real level shifts (water) per day.
  static const levelNoiseKgPerDay = 0.05;

  /// Design choice: Huber threshold in innovation SDs.
  static const huberThreshold = 2.5;

  /// Design choice: a reading this far from the trend waits for confirmation.
  static const grossErrorKg = 3.0;

  /// Design choice: …or this fraction of the trend, whichever is larger.
  static const grossErrorFraction = 0.04;

  /// The trend starts at the median of this many first weigh-ins.
  static const seedWeighIns = 3;

  /// A weigh-in's noise variance at [levelKg].
  static double variance(double levelKg) => math.max(
    math.pow(noiseFraction * levelKg, 2).toDouble(),
    noiseFloorKg * noiseFloorKg,
  );

  /// Whether [innovation] is far enough off to wait for a second reading.
  static bool isGrossError(double innovation, double levelKg) =>
      innovation.abs() > math.max(grossErrorKg, grossErrorFraction * levelKg);

  /// Huber-type robust update: an innovation beyond [huberThreshold] predicted
  /// SDs has its variance inflated by the square of how far beyond it is.
  static double robustVariance(
    double innovation,
    double predictedVariance,
    double levelKg,
  ) {
    final r = variance(levelKg);
    final ratio =
        innovation.abs() / (huberThreshold * math.sqrt(predictedVariance + r));
    return r * math.max(1, ratio * ratio);
  }
}

/// The median of [values], or `null` when there are none.
double? median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// The constants of the trend's slope.
abstract final class WeightTrend {
  /// Design choice: slope random walk, about (q_E + q_T)/ρ² of the engine.
  static const slopeNoiseKgPerDay = 0.004;

  /// The slope's starting SD.
  static const initialSlopeSDKgPerDay = 0.1;
}

typedef _State = ({double level, double slope, List<double> p});

/// The smoothed trend, one value per weigh-in (`WeightTrendCalculator.trend`).
///
/// A local-linear-trend Kalman filter (level and slope per day) over [values],
/// sorted by time, with the true gap in days between them, a robust update that
/// holds a gross error until a second reading confirms it, and a
/// Rauch-Tung-Striebel pass so past points use later data. [days] are the
/// values' day keys, or `null` for one a day. Only the first weigh-in of a day
/// updates the trend.
List<double> weightTrend(List<double> values, {List<String>? days}) {
  final n = values.length;
  if (n == 0) return [];
  int dayIndex(int i) => days == null ? i : daysBetween(days[0], days[i]);
  bool isFirstOfDay(int i) => i == 0 || dayIndex(i) != dayIndex(i - 1);

  final seed = <double>[];
  for (var i = 0; i < n && seed.length < WeighInNoise.seedWeighIns; i++) {
    if (isFirstOfDay(i)) seed.add(values[i]);
  }
  // The first value is always the first of its day, so the seed has one.
  var level = median(seed)!;
  var slope = 0.0;
  // [P_LL, P_Lb, P_bb]
  var p = [
    WeighInNoise.variance(level),
    0.0,
    WeightTrend.initialSlopeSDKgPerDay * WeightTrend.initialSlopeSDKgPerDay,
  ];
  const qb = WeightTrend.slopeNoiseKgPerDay * WeightTrend.slopeNoiseKgPerDay;
  const qL = WeighInNoise.levelNoiseKgPerDay * WeighInNoise.levelNoiseKgPerDay;

  final filtered = <_State>[];
  final predicted = <_State>[];
  final gaps = <int>[];
  double? held;
  var lastDay = dayIndex(0);
  for (var i = 0; i < n; i++) {
    final dt = dayIndex(i) - lastDay;
    lastDay = dayIndex(i);
    level += slope * dt;
    p = [
      p[0] + 2 * dt * p[1] + dt * dt * p[2] + qb * dt * dt * dt / 3 + qL * dt,
      p[1] + dt * p[2] + qb * dt * dt / 2,
      p[2] + qb * dt,
    ];
    predicted.add((level: level, slope: slope, p: p));
    gaps.add(dt);

    if (i > 0 && isFirstOfDay(i)) {
      final innovation = values[i] - level;
      double? r;
      if (!WeighInNoise.isGrossError(innovation, level)) {
        held = null;
        r = WeighInNoise.robustVariance(innovation, p[0], level);
      } else if (held != null && held.sign == innovation.sign) {
        // A second reading off the same way confirms a real shift: open the
        // level up to it, as process noise, so the smoother does not drag
        // earlier points across the step.
        held = null;
        p = [p[0] + innovation * innovation, p[1], p[2]];
        predicted[i] = (level: level, slope: slope, p: p);
        r = WeighInNoise.variance(level);
      } else {
        held = innovation;
      }
      if (r != null) {
        final s = p[0] + r;
        final k0 = p[0] / s;
        final k1 = p[1] / s;
        level += k0 * innovation;
        slope += k1 * innovation;
        p = [(1 - k0) * p[0], (1 - k0) * p[1], p[2] - k1 * p[1]];
      }
    }
    filtered.add((level: level, slope: slope, p: p));
  }

  final smoothed = [for (final f in filtered) f.level];
  var nextLevel = filtered[n - 1].level;
  var nextSlope = filtered[n - 1].slope;
  for (var i = n - 2; i >= 0; i--) {
    final f = filtered[i];
    final pr = predicted[i + 1];
    final dt = gaps[i + 1];
    // C = P_f Fᵀ P_pred⁻¹ with F = [[1, dt], [0, 1]].
    final a = [f.p[0] + dt * f.p[1], f.p[1], f.p[1] + dt * f.p[2], f.p[2]];
    final det = pr.p[0] * pr.p[2] - pr.p[1] * pr.p[1];
    if (!(det > 0)) {
      nextLevel = f.level;
      nextSlope = f.slope;
      continue;
    }
    final inv = [pr.p[2] / det, -pr.p[1] / det, -pr.p[1] / det, pr.p[0] / det];
    final c = [
      a[0] * inv[0] + a[1] * inv[2],
      a[0] * inv[1] + a[1] * inv[3],
      a[2] * inv[0] + a[3] * inv[2],
      a[2] * inv[1] + a[3] * inv[3],
    ];
    final dl = nextLevel - pr.level;
    final ds = nextSlope - pr.slope;
    nextLevel = f.level + c[0] * dl + c[1] * ds;
    nextSlope = f.slope + c[2] * dl + c[3] * ds;
    smoothed[i] = nextLevel;
  }
  return smoothed;
}
