/// "Adjusts based on your progress": a suggestion, per muscle, for the next
/// two to three weeks' hard sets (`VolumeRecommendation.swift`). It changes
/// nothing on its own.
///
/// The direction is from the literature (Scarpelli 2022, Camargo 2026,
/// Spiering 2021); every threshold is Compound's own.
library;

import 'package:compound_maths/src/muscle_volume.dart';
import 'package:compound_maths/src/one_rep_max.dart';
import 'package:compound_maths/src/weight_trend.dart' show median;
import 'package:compound_maths/src/workout.dart';

/// What the suggestion says.
enum VolumeAction {
  /// Progressing: keep the current volume.
  keep,

  /// Flat strength with steady effort: add 10–20%.
  add,

  /// Strength falling or effort rising at the same load: take 20–33% off.
  reduce,

  /// Fewer than 80% of the planned sets were done.
  beConsistent,

  /// Not enough logged to judge.
  needsMoreData,
}

/// What [recommendVolume] reads.
class const VolumeInputs({
  /// Weekly hard sets for the muscle, oldest first; the last
  /// [VolumeRecommendation.windowWeeks] are read.
  required final List<double> weeklySets,

  /// Strength change on the exercises that train the muscle directly, % a
  /// week.
  final double? trendPercentPerWeek,

  /// The share of planned sets done.
  final double? adherence,

  /// The rise in RPE at an unchanged load.
  final double? rpeDrift,

  /// The user's age in years.
  final int? age,
});

/// The suggestion and the figures it rests on.
class const VolumeSuggestion({
  required final VolumeAction action,

  /// Median weekly hard sets over the window.
  required final double baselineSets,

  /// The suggested weekly hard sets, in whole sets; null with nothing to
  /// suggest.
  required final ({double low, double high})? suggestedSets,
  final double? trendPercentPerWeek,
  final double? adherence,
  final double? rpeDrift,
}) {
  /// The baseline is above 20 sets a week: worth a word.
  bool get isHighVolume => baselineSets > VolumeTier.productiveHigh;
}

/// One logged set's effort at its load, for [rpeDrift].
typedef EffortSample = ({DateTime at, double weightKg, double rpe});

/// Compound's own constants.
abstract final class VolumeRecommendation {
  /// Weeks of history the baseline and trend are read from.
  static const windowWeeks = 4;

  /// A trend within this many percent a week either way is flat.
  static const flatTrendPercentPerWeek = 0.5;

  /// Below this share of planned sets done, consistency comes first.
  static const minimumAdherence = 0.8;

  /// A rise in RPE at the same load of at least this much is fatigue.
  static const rpeDriftThreshold = 1.0;

  /// The step up, as fractions of the baseline.
  static const increaseLow = 0.10;
  static const increaseHigh = 0.20;

  /// The step down, as fractions of the baseline.
  static const decreaseLow = 0.20;
  static const decreaseHigh = 0.33;

  /// The floor, and the floor from [olderAdultAge].
  static const floorSets = 4.0;
  static const olderAdultFloorSets = 6.0;
  static const olderAdultAge = 60;

  /// A trend needs this many sessions over at least this many days.
  static const minimumTrendPoints = 3;
  static const minimumTrendSpanDays = 7.0;
}

/// The suggestion for [inputs] (`VolumeRecommendation.recommend`).
VolumeSuggestion recommendVolume(VolumeInputs inputs) {
  final weeks = inputs.weeklySets;
  final window = weeks.length > VolumeRecommendation.windowWeeks
      ? weeks.sublist(weeks.length - VolumeRecommendation.windowWeeks)
      : weeks;
  final trainedWeeks = window.where((sets) => sets > 0).length;
  final baseline = median(window) ?? 0;
  final minimum = (inputs.age ?? 0) >= VolumeRecommendation.olderAdultAge
      ? VolumeRecommendation.olderAdultFloorSets
      : VolumeRecommendation.floorSets;

  VolumeSuggestion result(VolumeAction action, [(double, double)? range]) =>
      VolumeSuggestion(
        action: action,
        baselineSets: baseline,
        suggestedSets: range == null
            ? null
            : _wholeSets(range.$1, range.$2, minimum),
        trendPercentPerWeek: inputs.trendPercentPerWeek,
        adherence: inputs.adherence,
        rpeDrift: inputs.rpeDrift,
      );

  if (trainedWeeks < 2) return result(VolumeAction.needsMoreData);
  // A new user, without a full window behind them, starts from the
  // productive band.
  final base = trainedWeeks < VolumeRecommendation.windowWeeks
      ? baseline.clamp(VolumeTier.productiveLow, VolumeTier.productiveHigh)
      : baseline;

  final adherence = inputs.adherence;
  if (adherence != null && adherence < VolumeRecommendation.minimumAdherence) {
    return result(VolumeAction.beConsistent, (base, base));
  }
  final trend = inputs.trendPercentPerWeek;
  if (trend == null) return result(VolumeAction.needsMoreData);
  final effortRising =
      (inputs.rpeDrift ?? 0) >= VolumeRecommendation.rpeDriftThreshold;
  if (trend < -VolumeRecommendation.flatTrendPercentPerWeek || effortRising) {
    return result(VolumeAction.reduce, (
      base * (1 - VolumeRecommendation.decreaseHigh),
      base * (1 - VolumeRecommendation.decreaseLow),
    ));
  }
  if (trend > VolumeRecommendation.flatTrendPercentPerWeek) {
    return result(VolumeAction.keep, (base, base));
  }
  final low = _max(base * (1 + VolumeRecommendation.increaseLow), base + 1);
  final high = _max(base * (1 + VolumeRecommendation.increaseHigh), low);
  return result(VolumeAction.add, (low, high));
}

double _max(double a, double b) => a > b ? a : b;

/// Whole sets, never under [floor].
({double low, double high}) _wholeSets(double low, double high, double floor) {
  final lower = _max(low.roundToDouble(), floor);
  return (low: lower, high: _max(high.roundToDouble(), lower));
}

/// The least-squares slope of [points], as a percentage of their mean per
/// week; null with fewer than three positive points or a span under a week
/// (`VolumeRecommendation.trendPercentPerWeek`).
double? trendPercentPerWeek(List<({DateTime at, double value})> points) {
  final valid = [
    for (final point in points)
      if (point.value > 0) point,
  ];
  if (valid.length < VolumeRecommendation.minimumTrendPoints) return null;
  final first = valid.map((p) => p.at).reduce((a, b) => a.isBefore(b) ? a : b);
  double daysFromFirst(DateTime at) =>
      at.difference(first).inMicroseconds / Duration.microsecondsPerDay;
  final days = [for (final p in valid) daysFromFirst(p.at)];
  if (days.reduce(_max) < VolumeRecommendation.minimumTrendSpanDays) {
    return null;
  }
  final values = [for (final p in valid) p.value];
  final meanX = days.reduce((a, b) => a + b) / days.length;
  final meanY = values.reduce((a, b) => a + b) / values.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (var i = 0; i < days.length; i++) {
    covariance += (days[i] - meanX) * (values[i] - meanY);
    variance += (days[i] - meanX) * (days[i] - meanX);
  }
  return covariance / variance * 7 / meanY * 100;
}

/// The change in mean RPE at the load used most often on both sides of
/// [midpoint], later minus earlier; a tie goes to the larger change. Null
/// when no load was logged with RPE on both sides
/// (`VolumeRecommendation.rpeDrift`).
double? rpeDrift(List<EffortSample> sets, DateTime midpoint) {
  final byLoad = <double, List<EffortSample>>{};
  for (final set in sets) {
    byLoad.putIfAbsent((set.weightKg * 100).roundToDouble(), () => []).add(set);
  }
  ({int count, double drift})? best;
  for (final group in byLoad.values) {
    final before = [
      for (final s in group)
        if (s.at.isBefore(midpoint)) s.rpe,
    ];
    final after = [
      for (final s in group)
        if (!s.at.isBefore(midpoint)) s.rpe,
    ];
    if (before.isEmpty || after.isEmpty) continue;
    final drift = _mean(after) - _mean(before);
    if (best == null ||
        group.length > best.count ||
        (group.length == best.count && drift > best.drift)) {
      best = (count: group.length, drift: drift);
    }
  }
  return best?.drift;
}

double _mean(List<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

/// The inputs for [muscle] from finished [sessions]
/// (`VolumeRecommendation.inputs`). The window is the four weeks before
/// [end]'s day, [endDay] its key; [templates] maps a template id to the
/// muscles it trains.
///
/// The trend is the median of the e1RM trends of the exercises that train
/// the muscle directly; adherence the share of those exercises' planned sets
/// done, deload weeks aside; RPE drift the median of their [rpeDrift]s.
VolumeInputs volumeInputs(
  Muscle muscle, {
  required List<WorkoutSession> sessions,
  required Map<String, Map<Muscle, MuscleTarget>> templates,
  required DateTime end,
  required String endDay,
  int? age,
}) {
  const weeks = VolumeRecommendation.windowWeeks;
  final weekly = weeklyMuscleSets(
    sessions,
    templates,
    endDay,
    weeks: weeks,
  )[muscle]!;
  final windowStart = end.isUtc
      ? DateTime.utc(end.year, end.month, end.day - weeks * 7)
      : DateTime(end.year, end.month, end.day - weeks * 7);
  final recent = [
    for (final session in sessions)
      if (!session.at.isBefore(windowStart) && !session.at.isAfter(end))
        session,
  ];
  final primary = {
    for (final MapEntry(:key, :value) in templates.entries)
      if (value[muscle] == MuscleTarget.primary) key,
  };

  final trends = [
    for (final MapEntry(:key, :value) in exerciseOneRepMax(recent).entries)
      if (primary.contains(key))
        ?trendPercentPerWeek([
          for (final p in value.last7Workouts) (at: p.at, value: p.value),
        ]),
  ];

  var planned = 0;
  var done = 0;
  final effort = <String, List<EffortSample>>{};
  for (final session in recent) {
    for (final exercise in session.exercises) {
      if (!primary.contains(exercise.templateId)) continue;
      // A deload week asks for about half its targets; read against them it
      // would look like half the plan was skipped.
      if (exercise.plannedSets > 0 && !session.isDeload) {
        planned += exercise.plannedSets;
        final completed = completedWorkingSets(exercise);
        done += completed < exercise.plannedSets
            ? completed
            : exercise.plannedSets;
      }
      for (final set in exercise.sets) {
        if (set.isWarmup || set.isSubSet || !set.completed) continue;
        final rpe = set.rpe;
        final weight = set.weightKg;
        if (rpe == null || weight == null || weight <= 0) continue;
        effort.putIfAbsent(exercise.templateId, () => []).add((
          at: session.at,
          weightKg: weight,
          rpe: rpe,
        ));
      }
    }
  }
  final midpoint = windowStart.add(end.difference(windowStart) ~/ 2);
  return VolumeInputs(
    weeklySets: weekly,
    trendPercentPerWeek: median(trends),
    adherence: planned > 0 ? done / planned : null,
    rpeDrift: median([
      for (final samples in effort.values) ?rpeDrift(samples, midpoint),
    ]),
    age: age,
  );
}
