import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound_models/compound_models.dart';
import 'package:intl/intl.dart';

/// The display text for a workout and its sets, shared by the history and
/// the session detail. Every number goes through [AppFormat]; `locale` is
/// for tests, as there.
abstract final class WorkoutText {
  /// The app_ui unit for a stored exercise unit.
  static AppWeightUnit weightUnit(ExerciseWeightUnit unit) => switch (unit) {
    ExerciseWeightUnit.kilograms => AppWeightUnit.kilograms,
    ExerciseWeightUnit.pounds => AppWeightUnit.pounds,
  };

  /// The app_ui unit for a profile's weight preference, kilograms when unset.
  static AppWeightUnit preferredWeightUnit(WeightUnitPreference? preference) =>
      preference == WeightUnitPreference.pounds
      ? AppWeightUnit.pounds
      : AppWeightUnit.kilograms;

  /// The app_ui unit for a profile's distance preference, kilometres when
  /// unset.
  static AppDistanceUnit preferredDistanceUnit(
    DistanceUnitPreference? preference,
  ) => preference == DistanceUnitPreference.miles
      ? AppDistanceUnit.miles
      : AppDistanceUnit.kilometers;

  /// A history row's volume, in the unit the author lifted in; null when
  /// nothing was lifted. Tonnes from 1,000 kg up; a pound total stays in
  /// pounds.
  static String? sessionVolume(WorkoutSessionModel session, {String? locale}) {
    final kilograms = session.loggedVolumeKg;
    if (kilograms <= 0) return null;
    final unit = session.authorWeightUnit;
    if (kilograms >= 1000 && unit == ExerciseWeightUnit.kilograms) {
      // ponytail: tonnes have no AppFormat function; add one if a second
      // screen needs them.
      final tonnes = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 1,
      ).format(kilograms / 1000);
      return '$tonnes t';
    }
    return AppFormat.weight(kilograms, weightUnit(unit), locale: locale);
  }

  /// A history row's line for one exercise: "3 × 8 @ 80 kg", from its first
  /// logged working set, pairs counted once.
  static String exerciseSets(
    AppLocalizations l10n,
    WorkoutExerciseModel exercise,
    WorkoutSessionModel session, {
    String? locale,
  }) {
    final first = exercise.loggedWorkingSets.firstOrNull;
    if (first == null) return l10n.setCount(exercise.setTargets.length);
    final count = exercise.loggedSetCount;
    final unit =
        first.weightUnit ?? exercise.weightUnit ?? session.authorWeightUnit;
    final detail = _firstSetDetail(first, exercise.trackingMode, unit, locale);
    if (detail == null) return l10n.setCount(count);
    return '${AppFormat.number(count, locale: locale)} × $detail';
  }

  static String? _firstSetDetail(
    WorkoutSetModel set,
    TrackingMode mode,
    ExerciseWeightUnit unit,
    String? locale,
  ) {
    String number(int value) => AppFormat.number(value, locale: locale);
    switch (mode) {
      case TrackingMode.weightReps:
        final reps = set.reps;
        if (reps == null) return null;
        final load = set.loadKg;
        if (load == null) return number(reps);
        final weight = AppFormat.weight(load, weightUnit(unit), locale: locale);
        return '${number(reps)} @ $weight';
      case TrackingMode.repsOnly:
        return set.reps == null ? null : number(set.reps!);
      case TrackingMode.timeOnly:
        final seconds = set.durationSec;
        return seconds == null
            ? null
            : AppFormat.duration(Duration(seconds: seconds));
      case TrackingMode.distanceTime:
        final meters = set.distanceMeters;
        return meters == null
            ? null
            : AppFormat.distance(
                meters,
                AppDistanceUnit.kilometers,
                locale: locale,
              );
    }
  }

  /// A record as the set reads: "100 kg × 5", "12 reps", "1:30", "5.2 km".
  static String recordDetail(
    AppLocalizations l10n,
    PersonalRecord record, {
    String? locale,
  }) {
    final unit = weightUnit(record.weightUnit);
    return switch (record.trackingMode) {
      TrackingMode.weightReps =>
        '${AppFormat.weight(record.value, unit, locale: locale)}'
            ' × ${AppFormat.number(record.reps, locale: locale)}',
      TrackingMode.repsOnly => l10n.repCount(record.value.round()),
      TrackingMode.timeOnly => AppFormat.duration(
        Duration(seconds: record.value.round()),
      ),
      TrackingMode.distanceTime => AppFormat.distance(
        record.value,
        AppDistanceUnit.kilometers,
        locale: locale,
      ),
    };
  }

  /// "3rd workout of the week", from the second one on: a first is not news.
  static String? weeklyWorkout(AppLocalizations l10n, int number) {
    if (number < 2) return null;
    return l10n.highlightWeeklyWorkout(number, _englishOrdinal(number));
  }

  /// "6-week streak", from two weeks on; absent on sessions finished before
  /// weekly streaks.
  static String? streak(AppLocalizations l10n, int? weeks) {
    if (weeks == null || weeks <= 1) return null;
    return l10n.highlightStreak(weeks);
  }

  /// CLDR's English ordinal category, which selects the suffix in the ARB
  /// message: 1st, 2nd, 3rd, 4th, 11th, 21st.
  static String _englishOrdinal(int number) {
    if (number % 100 case 11 || 12 || 13) return 'other';
    return switch (number % 10) {
      1 => 'one',
      2 => 'two',
      3 => 'few',
      _ => 'other',
    };
  }

  /// A set's figures in its exercise's terms: "80 kg × 8 reps", "12 reps",
  /// "0:45", "2 km in 7:45". Null when the set holds nothing its tracking
  /// mode shows.
  static String? setValue(
    AppLocalizations l10n,
    WorkoutSetModel set,
    TrackingMode mode, {
    required ExerciseWeightUnit weightUnit,
    required AppDistanceUnit distanceUnit,
    String? locale,
  }) {
    final duration = set.durationSec == null
        ? null
        : AppFormat.duration(Duration(seconds: set.durationSec!));
    switch (mode) {
      case TrackingMode.weightReps:
        final load = set.loadKg;
        final reps = set.reps;
        if (load == null || reps == null) return null;
        final weight = AppFormat.weight(
          load,
          WorkoutText.weightUnit(weightUnit),
          locale: locale,
        );
        return '$weight × ${l10n.repCount(reps)}';
      case TrackingMode.repsOnly:
        return set.reps == null ? null : l10n.repCount(set.reps!);
      case TrackingMode.timeOnly:
        return duration;
      case TrackingMode.distanceTime:
        final distance = set.distanceMeters == null
            ? null
            : AppFormat.distance(
                set.distanceMeters!,
                distanceUnit,
                locale: locale,
              );
        if (distance != null && duration != null) {
          return l10n.setDistanceInDuration(distance, duration);
        }
        return distance ?? duration;
    }
  }

  /// A set kind's name; null for a standard set.
  static String? setKind(AppLocalizations l10n, SetKind kind) => switch (kind) {
    SetKind.standard => null,
    SetKind.drop => l10n.setKindDrop,
    SetKind.amrap => l10n.setKindAmrap,
    SetKind.myo => l10n.setKindMyo,
    SetKind.restPause => l10n.setKindRestPause,
    SetKind.cluster => l10n.setKindCluster,
    SetKind.partials => l10n.setKindPartials,
    SetKind.stretch => l10n.setKindStretch,
    SetKind.hold => l10n.setKindHold,
  };

  /// An exercise's line on the session detail: "3 sets · 1,920 kg volume",
  /// in the exercise's own unit.
  static String exerciseSummary(
    AppLocalizations l10n,
    WorkoutExerciseModel exercise, {
    String? locale,
  }) {
    final sets = exercise.loggedWorkingSets;
    final volume = sets.fold<double>(
      0,
      (sum, set) => sum + (set.volumeKg ?? 0),
    );
    return l10n.exerciseSummary(
      l10n.setCount(sets.pairedSetCount),
      AppFormat.weight(
        volume,
        weightUnit(exercise.displayWeightUnit),
        locale: locale,
      ),
    );
  }
}
