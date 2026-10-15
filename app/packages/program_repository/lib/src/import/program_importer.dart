import 'dart:convert';
import 'dart:math' as math;

import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/import/program_sheet.dart';
import 'package:program_repository/src/import/program_sheet_parser.dart';
import 'package:program_repository/src/import/sheet_readers.dart';
import 'package:program_repository/src/program_rules.dart';

/// A file read and parsed, before any name is matched (Swift
/// `ProgramFile`).
sealed class ProgramFile {
  const new();
}

/// A spreadsheet's program.
final class ProgramFileSheet extends ProgramFile {
  /// Creates a [ProgramFileSheet].
  const new(this.sheet);

  /// The program as the sheet wrote it.
  final ProgramSheet sheet;
}

/// The app's own mesocycles, from JSON.
final class ProgramFileMesocycles extends ProgramFile {
  /// Creates a [ProgramFileMesocycles].
  const new(this.mesocycles);

  /// The mesocycles as the file holds them.
  final List<Mesocycle> mesocycles;
}

/// Reads `.xlsx`, `.csv` or `.json` [bytes] by [extension], any case.
/// Throws a [ProgramImportError] when they are not a program.
ProgramFile readProgramFile(
  List<int> bytes,
  String extension, {
  ProgramSheetLabels labels = const ProgramSheetLabels(),
}) => switch (extension.toLowerCase()) {
  'xlsx' => ProgramFileSheet(
    parseProgramSheet(readXlsx(bytes), labels: labels),
  ),
  'csv' => ProgramFileSheet(
    parseProgramSheet(readCsvBytes(bytes), labels: labels),
  ),
  'json' => ProgramFileMesocycles(mesocyclesFromJson(bytes)),
  _ => throw const UnreadableFileError(),
};

/// A list of mesocycles, or a single one, in the Swift app's `Codable`
/// JSON, whose dates are seconds since 1 January 2001. Throws
/// [UnreadableFileError] for anything else.
List<Mesocycle> mesocyclesFromJson(List<int> bytes) {
  try {
    return switch (_swiftDates(jsonDecode(utf8.decode(bytes)))) {
      final List<Object?> list => [
        for (final mesocycle in list)
          Mesocycle.fromFirestore(mesocycle! as Map<String, Object?>),
      ],
      final mesocycle => [
        Mesocycle.fromFirestore(mesocycle! as Map<String, Object?>),
      ],
    };
  } on Object {
    throw const UnreadableFileError();
  }
}

final _swiftEpoch = DateTime.utc(2001);

/// [value] with every stored date, at any depth, as a [DateTime].
Object? _swiftDates(Object? value, [String? key]) => switch (value) {
  final num seconds when key == 'date_created' || key == 'date_modified' =>
    _swiftEpoch.add(Duration(microseconds: (seconds * 1e6).round())),
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      key: _swiftDates(value, key),
  },
  final List<Object?> list => [for (final item in list) _swiftDates(item)],
  _ => value,
};

/// How the importer names and draws what it creates.
class const ProgramImportStyle({
  /// The user who will own it.
  required final String authorId,

  /// The mesocycles' icon.
  required final String icon,

  /// The mesocycles' colour.
  required final String colour,
}) {
  /// Creates a [ProgramImportStyle].
  this;
}

/// A program built, to save in order: [newExercises], [mesocycles], then
/// [macrocycle].
class const ProgramImportResult({
  /// The macrocycle of the mesocycles, not started.
  required final Macrocycle macrocycle,

  /// One mesocycle per block.
  required final List<Mesocycle> mesocycles,

  /// Exercises a JSON program used that are neither built in nor in the
  /// library, copied under the user.
  final List<ExerciseModel> newExercises = const [],
}) {
  /// Creates a [ProgramImportResult].
  this;
}

/// Every exercise and substitution name [resolve] cannot match, once each,
/// in sheet order.
List<String> unmatchedProgramNames(
  ProgramSheet sheet,
  ExerciseModel? Function(String) resolve,
) {
  final seen = <String>{};
  return [
    for (final block in sheet.blocks)
      for (final week in block.weeks)
        for (final day in week.days)
          for (final row in day.rows)
            for (final name in [row.exerciseName, ...row.substitutions])
              if (seen.add(name) && resolve(name) == null) name,
  ];
}

/// Whether [sheet] counts [exerciseName]'s reps per side anywhere.
bool isPerSideInSheet(ProgramSheet sheet, String exerciseName) =>
    sheet.blocks.any(
      (block) => block.weeks.any(
        (week) => week.days.any(
          (day) => day.rows.any(
            (row) => row.exerciseName == exerciseName && row.perSide,
          ),
        ),
      ),
    );

/// [sheet] as mesocycles in a macrocycle not started (Swift
/// `ProgramImporter.build`):
///
/// - each block is a mesocycle of its weeks, with no deload; its days, in
///   week 1's order, are the templates, a rest day empty and named "Rest";
/// - week 1's targets are the base, and a later week adds an override only
///   where an exercise's targets differ from the week before;
/// - every week must have week 1's days with week 1's exercises;
/// - rows sharing a superset tag on a day share a group;
/// - every name must [resolve] before anything is built.
ProgramImportResult buildProgramFromSheet(
  ProgramSheet sheet, {
  required ProgramImportStyle style,
  required ExerciseModel? Function(String) resolve,
  required DateTime now,
  String Function() newId = newUuid,
}) {
  final unmatched = unmatchedProgramNames(sheet, resolve);
  if (unmatched.isNotEmpty) throw UnmatchedExercisesError(unmatched);

  final mesocycles = [
    for (final block in sheet.blocks)
      if (block.weeks.isNotEmpty)
        Mesocycle(
          id: newId(),
          authorId: style.authorId,
          name: _validated(block).name,
          icon: style.icon,
          colour: style.colour,
          numMicrocycles: block.weeks.length,
          workoutTemplates: [
            for (var day = 0; day < block.weeks.first.days.length; day++)
              _template(day, block, style.authorId, resolve, now, newId),
          ],
          dateCreated: now,
          dateModified: now,
        ),
  ];
  if (mesocycles.isEmpty) throw const NoExercisesError();
  return ProgramImportResult(
    macrocycle: _notStarted(
      sheet.title ?? mesocycles.first.name,
      mesocycles,
      style,
      now,
      newId,
    ),
    mesocycles: mesocycles,
  );
}

Macrocycle _notStarted(
  String name,
  List<Mesocycle> mesocycles,
  ProgramImportStyle style,
  DateTime now,
  String Function() newId,
) => Macrocycle(
  id: newId(),
  authorId: style.authorId,
  name: name,
  mesocycleIds: [for (final mesocycle in mesocycles) mesocycle.id],
  status: MacrocycleStatus.notStarted,
  mesocycleStartedAt: now,
  dateCreated: now,
  dateModified: now,
);

ProgramSheetBlock _validated(ProgramSheetBlock block) {
  final base = block.weeks.first;
  for (final week in block.weeks.skip(1)) {
    if (!_sameNames(
      week.days.map((d) => d.name),
      base.days.map((d) => d.name),
    )) {
      throw DaysDifferError(week.label, week.days.firstOrNull?.sourceRow ?? 0);
    }
    for (var index = 0; index < week.days.length; index++) {
      final day = week.days[index];
      if (!_sameNames(
        day.rows.map((r) => r.exerciseName),
        base.days[index].rows.map((r) => r.exerciseName),
      )) {
        throw ExercisesDifferError(week.label, day.name, day.sourceRow);
      }
    }
  }
  return block;
}

bool _sameNames(Iterable<String> a, Iterable<String> b) =>
    a.join('\u0000') == b.join('\u0000') && a.length == b.length;

WorkoutTemplateModel _template(
  int index,
  ProgramSheetBlock block,
  String authorId,
  ExerciseModel? Function(String) resolve,
  DateTime now,
  String Function() newId,
) {
  final day = block.weeks.first.days[index];
  if (day.isRest) return _restDay(authorId, now, newId);
  final groupIds = {
    for (final tag in {for (final row in day.rows) ?row.supersetTag})
      tag: newId(),
  };
  return WorkoutTemplateModel(
    workoutId: newId(),
    authorId: authorId,
    name: day.name,
    dateCreated: now,
    dateModified: now,
    exercises: [
      for (var rowIndex = 0; rowIndex < day.rows.length; rowIndex++)
        if (resolve(day.rows[rowIndex].exerciseName) case final exercise?)
          _exercise(block, index, rowIndex, exercise, groupIds, resolve, newId),
    ],
  );
}

WorkoutTemplateExercise _exercise(
  ProgramSheetBlock block,
  int day,
  int rowIndex,
  ExerciseModel exercise,
  Map<String, String> groupIds,
  ExerciseModel? Function(String) resolve,
  String Function() newId,
) {
  final row = block.weeks.first.days[day].rows[rowIndex];
  final base = programSetTargets(row, newId: newId);
  var previous = base;
  final overrides = <MicrocycleSetTargets>[];
  for (var week = 1; week < block.weeks.length; week++) {
    final targets = programSetTargets(
      block.weeks[week].days[day].rows[rowIndex],
      newId: newId,
    );
    if (_withoutIds(targets) != _withoutIds(previous)) {
      overrides.add(
        MicrocycleSetTargets(fromMicrocycle: week + 1, setTargets: targets),
      );
    }
    previous = targets;
  }
  return WorkoutTemplateExercise(
    id: newId(),
    exercise: exercise,
    setTargets: base,
    setRestTimers: false,
    notes: row.notes,
    warmupSetCount: programWarmupSetCount(row),
    restSeconds: programRestSeconds(row),
    substituteExerciseIds: [
      for (final name in row.substitutions) ?resolve(name)?.id,
    ],
    supersetGroupId: groupIds[row.supersetTag],
    linkUrl: row.linkUrl,
    setTargetsByMicrocycle: overrides,
  );
}

/// The targets as JSON with their ids left out, which are new on every
/// build.
String _withoutIds(List<SetTarget> targets) => jsonEncode([
  for (final target in targets) target.toFirestore()..remove(SetTargetKeys.id),
]);

WorkoutTemplateModel _restDay(
  String authorId,
  DateTime now,
  String Function() newId,
) => WorkoutTemplateModel(
  workoutId: newId(),
  authorId: authorId,
  name: 'Rest',
  dateCreated: now,
  dateModified: now,
  exercises: const [],
);

// MARK: - Targets

/// [row]'s working sets: reps, effort and, on the last set, the technique
/// (Swift `ProgramImporter.setTargets(for:)`). Per-set RIR columns win over
/// RPE; early RPE sets every set but the last, last RPE the last.
List<SetTarget> programSetTargets(
  ProgramSheetRow row, {
  String Function() newId = newUuid,
}) {
  final count = math.max(row.workingSets, 1);
  final hasRirColumns = row.rirPerSet.any((rir) => rir != null);
  return [
    for (var number = 1; number <= count; number++)
      _target(
        id: newId(),
        number: number,
        row: row,
        rir: hasRirColumns
            ? (number - 1 < row.rirPerSet.length
                  ? row.rirPerSet[number - 1]
                  : null)
            : switch (number == count ? row.lastRpe : row.earlyRpe) {
                final rpe? => rirFromRpe(rpe),
                null => null,
              },
        technique: number == count ? row.technique : null,
      ),
  ];
}

/// "Failure" is an AMRAP at RIR 0; "LLP", "Lengthened" and "Extend" are
/// partials; "Myo" is three mini-sets; "Two Drop Sets (~25%)" is two 25 %
/// drops; "Static Stretch (30s)" and "Static Hold (20 sec)" are timed.
/// Anything else is a standard set. The specific techniques are checked
/// before "failure", which several of them mention.
SetTarget _target({
  required String id,
  required int number,
  required ProgramSheetRow row,
  required int? rir,
  required String? technique,
}) {
  final text = technique?.toLowerCase() ?? '';
  final seconds = _int(RegExp(r'(\d+)\s*(?:s\b|sec)').firstMatch(text));
  final (type, hold) = switch (text) {
    _ when technique == null => (SetTargetSetType.standard, null),
    _ when text.contains('drop') => (SetTargetSetType.drop, null),
    _ when text.contains('myo') => (SetTargetSetType.myo, null),
    _ when const ['llp', 'lengthened', 'extend'].any(text.contains) => (
      SetTargetSetType.partials,
      null,
    ),
    _ when text.contains('stretch') => (SetTargetSetType.stretch, seconds),
    _ when text.contains('hold') => (SetTargetSetType.hold, seconds),
    _ when text.contains('failure') => (SetTargetSetType.amrap, null),
    _ => (SetTargetSetType.standard, null),
  };
  final isDrop = type == SetTargetSetType.drop;
  return SetTarget(
    id: id,
    setNumber: number,
    minReps: row.reps?.low.round(),
    maxReps: row.reps?.high.round(),
    rirTarget: type == SetTargetSetType.amrap ? 0 : rir,
    setType: type,
    dropCount: isDrop ? _dropCount(text) : null,
    dropStepPercent: isDrop
        ? _int(RegExp(r'(\d+)\s*%').firstMatch(text))
        : null,
    miniSetCount: type == SetTargetSetType.myo ? 3 : null,
    holdSeconds: hold,
  );
}

int? _dropCount(String text) {
  const words = {'one': 1, 'two': 2, 'three': 3, 'four': 4};
  if (RegExp(r'\b(one|two|three|four)\b').firstMatch(text) case final word?) {
    return words[word[1]];
  }
  return _int(RegExp(r'(\d+)\s*(?:x\s*)?drop').firstMatch(text));
}

int? _int(RegExpMatch? match) => match == null ? null : int.parse(match[1]!);

/// RIR = 10 − the upper RPE, rounded down and kept to 0…5.
int rirFromRpe(ValueRange rpe) => (10 - rpe.high).floor().clamp(0, 5);

/// [row]'s rest: the midpoint in seconds, rounded to 15 s and at least
/// 15 s; null when it has none.
int? programRestSeconds(ProgramSheetRow row) {
  final rest = row.rest;
  if (rest == null) return null;
  final seconds =
      (rest.low + rest.high) / 2 * (row.restUnit == RestUnit.minutes ? 60 : 1);
  return math.max((seconds / 15).round() * 15, 15);
}

/// [row]'s warm-ups: the upper bound, so "0-1" is 1.
int? programWarmupSetCount(ProgramSheetRow row) => row.warmupSets?.high.round();

// MARK: - JSON

/// The user's own copies of [mesocycles] in a macrocycle named [title] (or
/// the one mesocycle's name), as Swift's `SharedItemCopier` accepts a
/// shared mesocycle: new ids throughout and the style's author. An
/// exercise neither built in nor in [library] is copied once, under the
/// user, into `newExercises`.
ProgramImportResult buildProgramFromMesocycles(
  List<Mesocycle> mesocycles, {
  required String title,
  required ProgramImportStyle style,
  required List<ExerciseModel> library,
  required DateTime now,
  String Function() newId = newUuid,
}) {
  if (mesocycles.isEmpty) throw const NoExercisesError();
  final known = {for (final exercise in library) exercise.id};
  final copied = <String, ExerciseModel>{};
  final authorId = style.authorId;

  ExerciseModel copyExercise(ExerciseModel exercise) =>
      exercise.isSystemExercise || known.contains(exercise.id)
      ? exercise
      : copied.putIfAbsent(
          exercise.id,
          () => ExerciseModel.fromFirestore({
            ...exercise.toFirestore(),
            ExerciseModelKeys.id: newId(),
            ExerciseModelKeys.authorId: authorId,
            ExerciseModelKeys.dateCreated: now,
            ExerciseModelKeys.dateModified: now,
          }),
        );

  final copies = [
    for (final mesocycle in mesocycles)
      Mesocycle(
        id: newId(),
        authorId: authorId,
        name: mesocycle.name,
        icon: mesocycle.icon,
        colour: mesocycle.colour,
        numMicrocycles: mesocycle.numMicrocycles,
        deload: mesocycle.deload,
        periodisation: mesocycle.periodisation,
        // Swift's `Mesocycle` gives a mesocycle with no days one rest day.
        workoutTemplates: mesocycle.workoutTemplates.isEmpty
            ? [_restDay(authorId, now, newId)]
            : [
                for (final template in mesocycle.workoutTemplates)
                  WorkoutTemplateModel(
                    workoutId: newId(),
                    authorId: authorId,
                    name: template.name,
                    description: template.description,
                    imageUrl: template.imageUrl,
                    dateCreated: now,
                    dateModified: now,
                    exercises: [
                      for (final item in template.exercises)
                        WorkoutTemplateExercise.fromFirestore({
                          ...item.toFirestore(),
                          WorkoutTemplateExerciseKeys.id: newId(),
                          WorkoutTemplateExerciseKeys.exercise: copyExercise(
                            item.exercise,
                          ).toFirestore(),
                        }),
                    ],
                  ),
              ],
        dateCreated: now,
        dateModified: now,
      ),
  ];
  return ProgramImportResult(
    macrocycle: _notStarted(
      copies.length == 1 ? copies.first.name : title,
      copies,
      style,
      now,
      newId,
    ),
    mesocycles: copies,
    newExercises: copied.values.toList(),
  );
}

// MARK: - Summary

/// What a built program holds, for the import screen's summary (Swift
/// `ImportProgramPresenter.summary(of:)`).
class ProgramImportSummary {
  /// Summarises [mesocycles].
  factory of(List<Mesocycle> mesocycles) {
    final exercises = [
      for (final mesocycle in mesocycles)
        for (final template in mesocycle.workoutTemplates)
          ...template.exercises,
    ];
    final types = {
      for (final exercise in exercises) ...[
        for (final target in exercise.setTargets) target.setType,
        for (final week in exercise.setTargetsByMicrocycle)
          for (final target in week.setTargets) target.setType,
      ],
    }..remove(SetTargetSetType.standard);
    return ProgramImportSummary._(
      blocks: mesocycles.length,
      weeks: mesocycles.fold(0, (sum, m) => sum + m.numMicrocycles),
      days: [
        for (final mesocycle in mesocycles)
          for (final template in mesocycle.workoutTemplates)
            if (template.exercises.isNotEmpty) template,
      ].length,
      exercises: exercises.length,
      techniques: types.toList()..sort((a, b) => a.value.compareTo(b.value)),
      withWarmups: exercises.where((e) => e.warmupSetCount != null).length,
      withRest: exercises.where((e) => e.restSeconds != null).length,
    );
  }

  const new _({
    required this.blocks,
    required this.weeks,
    required this.days,
    required this.exercises,
    required this.techniques,
    required this.withWarmups,
    required this.withRest,
  });

  /// Mesocycles.
  final int blocks;

  /// Microcycles across them.
  final int weeks;

  /// Day plans with exercises.
  final int days;

  /// Exercise slots.
  final int exercises;

  /// The set types other than standard, by raw value.
  final List<SetTargetSetType> techniques;

  /// Slots with warm-ups.
  final int withWarmups;

  /// Slots with a rest time.
  final int withRest;
}
