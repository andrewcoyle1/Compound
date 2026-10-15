import 'dart:convert';
import 'dart:io';

import 'package:compound/programs/cubit/import_program_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

/// Records every save, in order, as "kind:name".
class _Library extends InMemoryTrainingLibraryRepository {
  new(this.saves);

  final List<String> saves;
  bool fails = false;

  @override
  Future<void> saveUserExercise(ExerciseModel exercise) async {
    if (fails) throw StateError('rejected');
    saves.add('exercise:${exercise.name}');
    await super.saveUserExercise(exercise);
  }
}

class _Programs extends InMemoryProgramRepository {
  new(this.saves);

  final List<String> saves;

  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) async {
    saves.add('mesocycle:${mesocycle.name}');
    await super.saveMesocycle(mesocycle);
  }

  @override
  Future<void> saveMacrocycle(Macrocycle macrocycle) async {
    saves.add('macrocycle:${macrocycle.name}');
    await super.saveMacrocycle(macrocycle);
  }
}

List<int> _fixture(String name) =>
    File('../CompoundUnitTests/Fixtures/programs/$name').readAsBytesSync();

ExerciseModel _exercise(String name, {bool system = true}) => ExerciseModel(
  id: 'ex-${name.toLowerCase().replaceAll(' ', '-')}',
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
  alternateNames: const [],
  isSystemExercise: system,
  dateCreated: DateTime.utc(2001),
  dateModified: DateTime.utc(2001),
);

/// Every name in the sample program; "Calf Raise" is someone else's.
final List<ExerciseModel> _library = [
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
    _exercise(name),
  _exercise('Calf Raise', system: false),
];

void main() {
  late List<String> saves;
  late _Library library;
  late _Programs programs;
  late AnalyticsRecorder analytics;

  /// The sample program's library without "Row" and "Leg Press" unless
  /// [exercises] is given, so two names need mapping.
  ImportProgramCubit build({List<ExerciseModel>? exercises}) {
    saves = [];
    library = _Library(saves);
    programs = _Programs(saves);
    analytics = AnalyticsRecorder();
    final cubit = ImportProgramCubit(
      uid: 'user-1',
      library:
          exercises ??
          [
            for (final e in _library)
              if (!['Row', 'Leg Press'].contains(e.name)) e,
          ],
      labels: const ProgramSheetLabels(),
      setup: TrainingSetupService(
        programs: programs,
        library: library,
        users: InMemoryUserRepository(),
      ),
      analytics: analytics,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('reading a sheet lists the unmatched names and summarises it', () {
    final cubit = build()
      ..fileChosen('sample-program.xlsx', _fixture('sample-program.xlsx'));
    final state = cubit.state;
    expect(state.error, isNull);
    expect(state.fileName, 'sample-program');
    expect(state.reviewNames, ['Row', 'Leg Press']);
    expect(state.mappings, isEmpty);
    expect(state.canSave, isFalse);
    final summary = state.summary!;
    expect(summary.blocks, 2);
    expect(summary.weeks, 4);
    expect(summary.days, 4);
    expect(summary.exercises, 17);
    expect(summary.techniques, hasLength(6));
    expect(summary.withRest, 16);
    expect(analytics.names, contains('ImportProgramView_File_Loaded'));
    expect(analytics.parameters('ImportProgramView_File_Loaded'), {
      'format': 'xlsx',
      'unmatched_count': 2,
    });
  });

  test(
    'mapping one from the library and creating one saves in order',
    () async {
      final cubit = build()
        ..fileChosen('sample-program.csv', _fixture('sample-program.csv'))
        ..chooseFromLibraryPressed();
      final barbellRow = _exercise('Barbell Row');
      cubit.libraryExerciseChosen('Row', barbellRow);
      expect(cubit.state.mappings['Row']?.exercise.name, 'Barbell Row');
      expect(cubit.state.canSave, isFalse);

      cubit.createPressed('Leg Press');
      expect(cubit.state.mappings['Leg Press']?.isNew, isTrue);
      expect(saves, isEmpty);
      expect(cubit.state.canSave, isTrue);

      await cubit.save();

      expect(saves, [
        'exercise:Leg Press',
        'mesocycle:Build',
        'mesocycle:Peak',
        'macrocycle:Sample Program',
      ]);
      final created = (await library.watchUserExercises('user-1').first).single;
      expect(created.authorId, 'user-1');
      expect(created.muscleGroups, isEmpty);
      final mesocycles = await programs.watchMesocycles('user-1').first;
      final build0 = mesocycles.firstWhere((m) => m.name == 'Build');
      expect(
        build0.workoutTemplates[0].exercises[1].exercise.id,
        barbellRow.id,
      );
      expect(build0.workoutTemplates[1].exercises[0].substituteExerciseIds, [
        'ex-hack-squat',
        created.id,
      ]);
      final saved = cubit.state.saved!;
      expect(saved.status, MacrocycleStatus.notStarted);
      expect(cubit.state.status, ImportProgramStatus.saved);
      expect(
        analytics.names,
        containsAllInOrder([
          'ImportProgramView_ChooseFromLibrary',
          'ImportProgramView_CreateExercise',
          'ImportProgramView_Save_Start',
          'ImportProgramView_Save_Success',
        ]),
      );
      expect(analytics.parameters('ImportProgramView_Save_Success'), {
        'mesocycle_count': 2,
      });
    },
  );

  test('a created exercise done per side is one-sided', () async {
    const csv =
        'Day,Exercise,Working Sets,Reps\nWeek 1\nLegs,Step Up,3,10 per leg\n';
    final cubit = build()
      ..fileChosen('plan.csv', utf8.encode(csv))
      ..createPressed('Step Up');
    await cubit.save();
    expect(
      (await library.watchUserExercises('user-1').first).single.laterality,
      Laterality.unilateral,
    );
  });

  test('a parse error keeps its row and leaves nothing to save', () {
    const csv =
        'Day,Exercise,Working Sets\nWeek 1\nPush,Squat,3\n'
        'Week 2\nPush,Leg Curl,3\n';
    final cubit = build()..fileChosen('plan.csv', utf8.encode(csv));
    expect(cubit.state.error, isA<ExercisesDifferError>());
    expect((cubit.state.error! as ProgramImportError).row, 5);
    expect(cubit.state.file, isNull);
    expect(cubit.state.canSave, isFalse);
    expect(analytics.names.last, 'ImportProgramView_File_Fail');
  });

  test('an unmatched name offers the nearest names; one tap maps it', () {
    final cubit = build(
      exercises: [
        for (final e in _library)
          if (e.name != 'Leg Press') e,
        _exercise('45° Leg Press'),
      ],
    )..fileChosen('sample-program.csv', _fixture('sample-program.csv'));
    expect(cubit.state.reviewNames, isNot(contains('Leg Press')));
    final name = cubit.state.reviewNames.firstOrNull;
    if (name == null) return;
    final suggested = cubit.state.suggestions[name]!;
    expect(suggested.length, lessThanOrEqualTo(3));
    if (suggested.isEmpty) return;
    cubit.suggestionPressed(name, suggested.first);
    expect(cubit.state.mappings[name]?.exercise, suggested.first);
    expect(analytics.names, contains('ImportProgramView_UseSuggestion'));
  });

  test('a failed save keeps the error and the screen', () async {
    final cubit = build()
      ..fileChosen('sample-program.csv', _fixture('sample-program.csv'))
      ..createPressed('Row')
      ..createPressed('Leg Press');
    library.fails = true;

    await cubit.save();

    expect(cubit.state.error, isA<StateError>());
    expect(cubit.state.status, ImportProgramStatus.loaded);
    expect(await programs.watchMesocycles('user-1').first, isEmpty);
    expect(analytics.names.last, 'ImportProgramView_Save_Fail');
  });

  test("the app's JSON needs no mapping and saves its copy first", () async {
    final cubit = build(
      exercises: [
        for (final e in _library)
          if (e.name != 'Calf Raise') e,
      ],
    )..fileChosen('sample-program.json', _fixture('sample-program.json'));
    expect(cubit.state.reviewNames, isEmpty);
    expect(cubit.state.canSave, isTrue);

    await cubit.save();

    expect(saves, [
      'exercise:Calf Raise',
      'mesocycle:Build',
      'mesocycle:Peak',
      'macrocycle:sample-program',
    ]);
  });

  test('a file of another kind is unreadable; save does nothing', () async {
    final cubit = build()..fileChosen('notes', const [1, 2]);
    expect(cubit.state.error, isA<UnreadableFileError>());
    await cubit.save();
    expect(saves, isEmpty);
  });

  test('closing is tracked', () async {
    final cubit = build();
    await cubit.close();
    expect(analytics.names, [
      'ImportProgramView_Appear',
      'ImportProgramView_Disappear',
    ]);
  });
}
