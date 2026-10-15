/// A finished workout in Strava's JSON strength format, the file
/// `POST /uploads` takes with `data_type=json`, and the description sent
/// with it (Swift `StravaStrengthFile.swift`). Strava turns the sets into
/// the activity's exercise list and muscle map.
/// https://developers.strava.com/docs/uploads/
library;

import 'dart:math' as math;

import 'package:compound_models/compound_models.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:strava_repository/src/strava_exercise_type.dart';

/// One set in the file.
@immutable
class const StravaStrengthSet({
  /// Strava's `exercise_type`.
  required final String exerciseType,

  /// Reps, when the set has them.
  final int? repetitions,

  /// Kilograms, as the set was logged: per side for an exercise logged per
  /// side. Absent for a bodyweight set rather than sent as 0.
  final double? weight,

  /// Seconds, for a timed set.
  final int? duration,
}) {
  /// Creates a [StravaStrengthSet].
  this;

  /// Strava's keys; a missing measure is left out, not sent as null.
  Map<String, Object?> toJson() => {
    'exercise_type': exerciseType,
    'repetitions': ?repetitions,
    'weight': ?weight,
    'duration': ?duration,
  };

  @override
  bool operator ==(Object other) =>
      other is StravaStrengthSet &&
      other.exerciseType == exerciseType &&
      other.repetitions == repetitions &&
      other.weight == weight &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(exerciseType, repetitions, weight, duration);

  @override
  String toString() =>
      'StravaStrengthSet($exerciseType, $repetitions, $weight, $duration)';
}

/// The seconds east of UTC the device's time zone was at [date] (Swift
/// `TimeZone.current.secondsFromGMT(for:)`).
int localUtcOffset(DateTime date) => date.toLocal().timeZoneOffset.inSeconds;

/// The workout as Strava's strength file.
class const StravaStrengthFile._({
  /// When it started, ISO 8601 in UTC to the second.
  required final String startTime,

  /// The device's offset from UTC at the start, in seconds.
  required final int utcOffset,

  /// Seconds from start to finish, truncated.
  required final int elapsedTime,

  /// Seconds under way, pauses left out, truncated.
  required final int activeTime,

  /// The sets Strava can place.
  required final List<StravaStrengthSet> sets,
}) {
  /// The file for [session], or `null` for a workout with nothing Strava can
  /// take: unfinished, or no completed working set it can place. Strava
  /// refuses a file without a set. [utcOffsetAt] is for tests.
  static StravaStrengthFile? from(
    WorkoutSessionModel session,
    List<ExerciseModel> library, {
    int Function(DateTime date) utcOffsetAt = localUtcOffset,
  }) {
    final endedAt = session.endedAt;
    if (endedAt == null) return null;
    final sets = [
      for (final exercise in session.exercises)
        if (stravaExerciseType(exercise.templateId, library) case final type?)
          for (final row in stravaUploadedRows(exercise.sets))
            StravaStrengthSet(
              exerciseType: type,
              repetitions: row.reps,
              // As the set reads in Compound: a machine base kept out of the
              // load stays out.
              weight: switch (_loadKg(row)) {
                final load? when load > 0 => load,
                _ => null,
              },
              duration: row.durationSec,
            ),
    ];
    if (sets.isEmpty) return null;
    final elapsed =
        endedAt.difference(session.dateCreated).inMicroseconds /
        Duration.microsecondsPerSecond;
    return StravaStrengthFile._(
      startTime: _isoSeconds(session.dateCreated),
      utcOffset: utcOffsetAt(session.dateCreated),
      elapsedTime: elapsed.truncate(),
      activeTime: math
          .max(0, elapsed - (session.pausedSeconds ?? 0))
          .truncate(),
      sets: sets,
    );
  }

  /// Strava's JSON: snake_case keys and a fixed version.
  Map<String, Object?> toJson() => {
    'version': '1.0',
    'start_time': startTime,
    'utc_offset': utcOffset,
    'elapsed_time': elapsedTime,
    'active_time': activeTime,
    'creator': {'name': 'Compound'},
    'sets': [for (final set in sets) set.toJson()],
  };

  /// `2023-11-14T22:13:20Z`, as Swift's `ISO8601DateFormatter` writes it.
  static String _isoSeconds(DateTime date) {
    final utc = date.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }
}

/// Completed working sets, a left/right pair sent once: the rule
/// `pairedSetCount` counts by (Swift `StravaStrengthFile.uploadedRows`).
/// Strava has no sides, and six rows for three sets of a single-arm row
/// would double them on the map. Warm-ups are left out for the same reason,
/// and so are drops, mini-sets and pieces: they are part of their set, and
/// as sets of their own a myo set would read as four.
List<WorkoutSetModel> stravaUploadedRows(List<WorkoutSetModel> rows) {
  final done = [
    for (final row in rows)
      if (!row.isWarmup && row.completedAt != null && row.parentSetId == null)
        row,
  ];
  return [
    for (final (index, row) in done.indexed)
      if (!(row.side == SetSide.right &&
          index > 0 &&
          done[index - 1].side == SetSide.left))
        row,
  ];
}

/// The activity's description: the session's notes, then a line per
/// exercise listing the sets that were uploaded, e.g. "Barbell Bench Press:
/// 100 kg × 8, 100 kg × 8, 95 kg × 7". `null` when there is neither (Swift
/// `StravaUpload.description`).
///
/// In English with en-US numbers, whatever the app's language: see the
/// slice's decisions.
String? stravaDescription(
  WorkoutSessionModel session, {
  required WeightUnitPreference weightUnit,
  required DistanceUnitPreference distanceUnit,
}) {
  final lines = [
    for (final exercise in session.exercises)
      if ([
            for (final row in stravaUploadedRows(exercise.sets))
              ?_summary(row, weightUnit, distanceUnit),
          ]
          case final sets when sets.isNotEmpty)
        '${exercise.name}: ${sets.join(', ')}',
  ];
  final parts = [
    session.notes?.trim(),
    if (lines.isNotEmpty) lines.join('\n'),
  ].whereType<String>().where((part) => part.isNotEmpty);
  return parts.isEmpty ? null : parts.join('\n\n');
}

double? _loadKg(WorkoutSetModel row) =>
    row.weightKg == null ? null : row.weightKg! - (row.machineBaseKg ?? 0);

String? _summary(
  WorkoutSetModel row,
  WeightUnitPreference weightUnit,
  DistanceUnitPreference distanceUnit,
) {
  // In the unit the set was lifted in, where it says.
  final weight = switch (_loadKg(row)) {
    final kg? when kg > 0 => _weight(
      kg,
      pounds: switch (row.weightUnit) {
        final unit? => unit == ExerciseWeightUnit.pounds,
        null => weightUnit == WeightUnitPreference.pounds,
      },
    ),
    _ => null,
  };
  return switch ((weight, row.reps, row.durationSec, row.distanceMeters)) {
    (final weight?, final reps?, _, _) => '$weight × $reps',
    (null, final reps?, _, _) => _reps(reps),
    (final weight?, null, final seconds?, _) =>
      '$weight × ${_duration(seconds)}',
    (_, null, _, final meters?) when meters > 0 => _distance(
      meters,
      distanceUnit,
    ),
    (_, null, final seconds?, _) => _duration(seconds),
    _ => weight,
  };
}

/// Swift `Format.weight`: up to one decimal, from kilograms.
String _weight(double kilograms, {required bool pounds}) =>
    pounds ? '${_number(kilograms * 2.20462)} lb' : '${_number(kilograms)} kg';

/// Swift `Format.reps`.
String _reps(int count) => count == 1 ? '1 rep' : '${_number(count)} reps';

/// Swift `Format.duration`: `4:30` under an hour, `1:05:30` from an hour.
String _duration(int seconds) {
  String two(int value) => value.toString().padLeft(2, '0');
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds % 60)}'
      : '$minutes:${two(seconds % 60)}';
}

/// Swift `Format.distance(meters:unit:)`: up to one decimal.
String _distance(double meters, DistanceUnitPreference unit) =>
    unit == DistanceUnitPreference.miles
    ? '${_number(meters * 0.000621371)} mi'
    : '${_number(meters / 1000)} km';

/// A number as Foundation's `FormatStyle` writes it in en-US with
/// `fractionLength(0...1)`: rounded half to even at one decimal, a trailing
/// `.0` dropped, thousands grouped with commas.
String _number(num value) {
  final scaled = value * 10;
  var tenths = scaled.round();
  if ((scaled - scaled.truncate()).abs() == 0.5 && tenths.isOdd) {
    tenths -= scaled.sign.toInt();
  }
  final negative = tenths < 0;
  final whole = tenths.abs() ~/ 10;
  final fraction = tenths.abs() % 10;
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}$grouped${fraction == 0 ? '' : '.$fraction'}';
}
