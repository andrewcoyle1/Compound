import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Value equality over [props], lists compared element by element at any
/// depth, as Swift's synthesized `Equatable` compares.
@immutable
abstract class _Value {
  const new();

  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      other is _Value &&
      other.runtimeType == runtimeType &&
      _deepEquals(props, other.props);

  @override
  int get hashCode => Object.hashAll(props.map(_hash));

  static bool _deepEquals(Object? a, Object? b) => a is List && b is List
      ? a.length == b.length &&
            [for (var i = 0; i < a.length; i++) i]
                .every((i) => _deepEquals(a[i], b[i]))
      : a == b;

  static int _hash(Object? value) =>
      value is List ? Object.hashAll(value.map(_hash)) : value.hashCode;
}

/// One cell of a sheet (Swift `SheetCell`). [text] is what the cell shows;
/// [date] is set when it holds a date (Excel turns "6-8" typed into a cell
/// into 8 June), and [number] when it holds a number.
class const SheetCell(
  /// What the cell shows.
  final String text, {

  /// The date the cell holds.
  final DateTime? date,

  /// The number the cell holds.
  final double? number,

  /// The link on the cell.
  final String? hyperlink,
}) {
  /// Creates a [SheetCell].
  this;

  /// This cell with [hyperlink] as its link.
  SheetCell linked(String? hyperlink) =>
      SheetCell(text, date: date, number: number, hyperlink: hyperlink);
}

/// Rows of cells, top to bottom; a missing cell is null.
typedef SheetGrid = List<List<SheetCell?>>;

/// A low–high pair: "6-8" is 6…8, "20" is 20…20 (Swift `ValueRange`).
class ValueRange extends _Value {
  /// The range between [a] and [b], whichever is lower.
  new(double a, double b) : low = math.min(a, b), high = math.max(a, b);

  /// The range of [value] alone.
  new single(double value) : this(value, value);

  /// The lower bound.
  final double low;

  /// The upper bound.
  final double high;

  @override
  List<Object?> get props => [low, high];
}

/// A training program as read from a spreadsheet, before any exercise name
/// is matched (Swift `ProgramSheet`): blocks of weeks of days of rows.
class ProgramSheet extends _Value {
  /// Creates a [ProgramSheet].
  const new({required this.title, required this.blocks});

  /// The program's title, from the first line of its own.
  final String? title;

  /// Its blocks, each a mesocycle to be.
  final List<ProgramSheetBlock> blocks;

  @override
  List<Object?> get props => [title, blocks];
}

/// A block of weeks (Swift `ProgramSheet.Block`).
class ProgramSheetBlock extends _Value {
  /// Creates a [ProgramSheetBlock].
  const new({required this.name, required this.weeks});

  /// Its name.
  final String name;

  /// Its weeks.
  final List<ProgramSheetWeek> weeks;

  @override
  List<Object?> get props => [name, weeks];
}

/// A week of days (Swift `ProgramSheet.Week`).
class ProgramSheetWeek extends _Value {
  /// Creates a [ProgramSheetWeek].
  const new({required this.label, required this.days});

  /// "Week 1", "Deload Week".
  final String label;

  /// Its days.
  final List<ProgramSheetDay> days;

  @override
  List<Object?> get props => [label, days];
}

/// A day of rows (Swift `ProgramSheet.Day`).
class ProgramSheetDay extends _Value {
  /// Creates a [ProgramSheetDay].
  const new({
    required this.name,
    required this.isRest,
    required this.rows,
    required this.sourceRow,
  });

  /// Its name.
  final String name;

  /// Whether it is a rest day.
  final bool isRest;

  /// Its exercise rows.
  final List<ProgramSheetRow> rows;

  /// The sheet row the day starts on, from 1.
  final int sourceRow;

  @override
  List<Object?> get props => [name, isRest, rows, sourceRow];
}

/// The unit a rest column is written in.
enum RestUnit {
  /// Seconds.
  seconds,

  /// Minutes.
  minutes,
}

/// One exercise row, every value still as the sheet wrote it (Swift
/// `ProgramSheet.Row`).
class ProgramSheetRow extends _Value {
  /// Creates a [ProgramSheetRow].
  const new({
    required this.exerciseName,
    required this.workingSets,
    required this.sourceRow,
    this.supersetTag,
    this.technique,
    this.warmupSets,
    this.reps,
    this.perSide = false,
    this.earlyRpe,
    this.lastRpe,
    this.rirPerSet = const [],
    this.rest,
    this.restUnit = RestUnit.seconds,
    this.substitutions = const [],
    this.notes,
    this.linkUrl,
  });

  /// The exercise's name, superset prefix removed.
  final String exerciseName;

  /// "S1" from "S1: Incline Press": rows sharing a tag on one day are a
  /// superset.
  final String? supersetTag;

  /// The last set's intensity technique.
  final String? technique;

  /// Warm-up sets.
  final ValueRange? warmupSets;

  /// Working sets.
  final int workingSets;

  /// Reps.
  final ValueRange? reps;

  /// "10 per leg": the reps count each side.
  final bool perSide;

  /// The early sets' RPE.
  final ValueRange? earlyRpe;

  /// The last set's RPE.
  final ValueRange? lastRpe;

  /// "RIR (Set n)" columns, in set order; null where blank, "-" or "N/A".
  final List<int?> rirPerSet;

  /// Rest between sets.
  final ValueRange? rest;

  /// The unit [rest] is in.
  final RestUnit restUnit;

  /// Substitute exercises' names.
  final List<String> substitutions;

  /// Notes.
  final String? notes;

  /// The exercise cell's link.
  final String? linkUrl;

  /// The sheet row, from 1.
  final int sourceRow;

  /// This row with another [exerciseName], or with no link when
  /// [clearLink].
  ProgramSheetRow copyWith({String? exerciseName, bool clearLink = false}) =>
      ProgramSheetRow(
        exerciseName: exerciseName ?? this.exerciseName,
        supersetTag: supersetTag,
        technique: technique,
        warmupSets: warmupSets,
        workingSets: workingSets,
        reps: reps,
        perSide: perSide,
        earlyRpe: earlyRpe,
        lastRpe: lastRpe,
        rirPerSet: rirPerSet,
        rest: rest,
        restUnit: restUnit,
        substitutions: substitutions,
        notes: notes,
        linkUrl: clearLink ? null : linkUrl,
        sourceRow: sourceRow,
      );

  @override
  List<Object?> get props => [
    exerciseName,
    supersetTag,
    technique,
    warmupSets,
    workingSets,
    reps,
    perSide,
    earlyRpe,
    lastRpe,
    rirPerSet,
    rest,
    restUnit,
    substitutions,
    notes,
    linkUrl,
    sourceRow,
  ];
}

/// The names the parser gives what a sheet leaves unnamed, which Swift
/// localizes. The app passes its own.
class const ProgramSheetLabels({
  /// The week a sheet with no week lines is.
  final String firstWeek = 'Week 1',

  /// The day rows before any day name belong to.
  final String firstDay = 'Day 1',

  /// The block a sheet with no title or block lines is.
  final String untitled = 'Imported Program',
}) {
  /// Creates [ProgramSheetLabels].
  this;
}

/// Why a program file could not be imported (Swift `ProgramImportError`).
/// [row] is the 1-based sheet row where there is one. The app words it.
sealed class ProgramImportError extends _Value implements Exception {
  const new();

  /// The sheet row, from 1, where the error has one.
  int? get row => null;

  @override
  List<Object?> get props => [];
}

/// The file could not be read as a program.
final class UnreadableFileError extends ProgramImportError {
  /// Creates an [UnreadableFileError].
  const new();
}

/// No header row with an "Exercise" column.
final class NoHeaderRowError extends ProgramImportError {
  /// Creates a [NoHeaderRowError].
  const new();
}

/// The file has no exercises.
final class NoExercisesError extends ProgramImportError {
  /// Creates a [NoExercisesError].
  const new();
}

/// A row's working sets are missing or not a number.
final class MissingWorkingSetsError extends ProgramImportError {
  /// Creates a [MissingWorkingSetsError] on [row].
  const new(this.row);

  @override
  final int row;

  @override
  List<Object?> get props => [row];
}

/// [week] has different days from week 1.
final class DaysDifferError extends ProgramImportError {
  /// Creates a [DaysDifferError].
  const new(this.week, this.row);

  /// The week's label.
  final String week;

  @override
  final int row;

  @override
  List<Object?> get props => [week, row];
}

/// [day] of [week] has different exercises from week 1.
final class ExercisesDifferError extends ProgramImportError {
  /// Creates an [ExercisesDifferError].
  const new(this.week, this.day, this.row);

  /// The week's label.
  final String week;

  /// The day's name.
  final String day;

  @override
  final int row;

  @override
  List<Object?> get props => [week, day, row];
}

/// [names] must be matched first.
final class UnmatchedExercisesError extends ProgramImportError {
  /// Creates an [UnmatchedExercisesError].
  const new(this.names);

  /// The names no exercise matched.
  final List<String> names;

  @override
  List<Object?> get props => [names];
}
