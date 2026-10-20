// The program-import fixtures in contracts/fixtures/programs
// (written by make-fixture.py) and a library holding every exercise the
// sample program names (Swift `ProgramFixtures`).
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:program_repository/program_repository.dart';

List<int> fixtureBytes(String name) =>
    File('../../../contracts/fixtures/programs/$name').readAsBytesSync();

ProgramSheet xlsxSheet() =>
    parseProgramSheet(readXlsx(fixtureBytes('sample-program.xlsx')));

ProgramSheet csvSheet() =>
    parseProgramSheet(readCsvBytes(fixtureBytes('sample-program.csv')));

ExerciseModel fixtureExercise(
  String name, {
  bool system = true,
  List<String> alternateNames = const [],
  String? id,
}) => ExerciseModel(
  id: id ?? 'ex-${name.toLowerCase().replaceAll(' ', '-')}',
  authorId: system ? 'official' : 'someone-else',
  name: name,
  trackableMetrics: const [
    TrackableExerciseMetric.weight,
    TrackableExerciseMetric.reps,
  ],
  laterality: Laterality.bilateral,
  muscleGroups: const {},
  isBodyweight: false,
  rangeOfMotion: 0,
  stability: 0,
  bodyWeightContribution: 0,
  alternateNames: alternateNames,
  isSystemExercise: system,
  dateCreated: DateTime.utc(2001),
  dateModified: DateTime.utc(2001),
);

/// Every name in the sample program. "DB Press" reaches "Dumbbell Press"
/// through the matcher's expansion; "Calf Raise" is someone else's
/// exercise, so a JSON import copies it.
final List<ExerciseModel> fixtureLibrary = [
  for (final name in [
    'Incline Press',
    'Row',
    'Lateral Raise',
    'Triceps Pushdown',
    'Squat',
    'Split Squat',
    'Leg Curl',
    'Machine Press',
    'Dumbbell Press',
    'Cable Row',
    'Hack Squat',
    'Leg Press',
  ])
    fixtureExercise(name),
  fixtureExercise('Calf Raise', system: false),
];

const fixtureStyle = ProgramImportStyle(
  authorId: 'user-1',
  icon: 'flag',
  colour: '#000000',
);

ExerciseModel? Function(String) fixtureResolve([
  List<ExerciseModel>? library,
]) => ExerciseNameMatcher(library ?? fixtureLibrary).match;
