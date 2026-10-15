// Swift ProgramImporterTests: a parsed program as mesocycles in a
// macrocycle: blocks, weekly overrides, supersets, double entries, rest
// days, techniques, effort, and the single values ranges import as. Then
// the file reader, the JSON path and the summary.
import 'dart:convert';

import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../../helpers/program_fixtures.dart';

final _now = DateTime.utc(2026, 10, 15);

ProgramImportResult _build([ProgramSheet? sheet]) => buildProgramFromSheet(
  sheet ?? xlsxSheet(),
  style: fixtureStyle,
  resolve: fixtureResolve(),
  now: _now,
);

WorkoutTemplateExercise _exercise(
  ProgramImportResult result,
  int index, {
  int block = 0,
  int day = 0,
}) => result.mesocycles[block].workoutTemplates[day].exercises[index];

ProgramSheetRow _sheetRow(String reps, {List<int?> rir = const []}) =>
    ProgramSheetRow(
      exerciseName: 'Press',
      workingSets: 0,
      sourceRow: 1,
      reps: ValueRange.single(double.parse(reps)),
      rirPerSet: rir,
    );

/// The sample program's mesocycles from the app's JSON.
List<Mesocycle> _json() =>
    mesocyclesFromJson(fixtureBytes('sample-program.json'));

void main() {
  group('blocks', () {
    test(
      'each block is a mesocycle of its weeks in a macrocycle not started',
      () {
        final result = _build();
        expect([for (final m in result.mesocycles) m.name], ['Build', 'Peak']);
        expect([for (final m in result.mesocycles) m.numMicrocycles], [2, 2]);
        for (final mesocycle in result.mesocycles) {
          expect(mesocycle.deload, DeloadType.none);
          expect(mesocycle.authorId, 'user-1');
          expect(mesocycle.icon, 'flag');
          expect(mesocycle.dateCreated, _now);
        }
        expect(result.macrocycle.name, 'Sample Program');
        expect(result.macrocycle.status, MacrocycleStatus.notStarted);
        expect(result.macrocycle.mesocycleIds, [
          for (final m in result.mesocycles) m.id,
        ]);
        expect(result.newExercises, isEmpty);
      },
    );

    test(
      'a sheet with no title names the macrocycle after its first block',
      () {
        final sheet = csvSheet();
        final untitled = ProgramSheet(title: null, blocks: sheet.blocks);
        expect(_build(untitled).macrocycle.name, 'Build');
      },
    );

    test('the days are the templates, a rest day empty and named Rest', () {
      final days = _build().mesocycles[0].workoutTemplates;
      expect([for (final d in days) d.name], ['Upper', 'Lower', 'Rest']);
      expect([for (final d in days) d.exercises.length], [5, 4, 0]);
    });

    test('the same exercise twice in a row is two entries', () {
      final result = _build();
      expect(_exercise(result, 2).exercise.name, 'Lateral Raise');
      expect(_exercise(result, 3).exercise.name, 'Lateral Raise');
      expect(_exercise(result, 2).setTargets, hasLength(3));
      expect(_exercise(result, 3).setTargets, hasLength(1));
    });

    test(
      'an override appears only where a week differs from the one before',
      () {
        final result = _build();
        final incline = _exercise(result, 0);
        expect(incline.setTargets, hasLength(2));
        expect(
          [for (final o in incline.setTargetsByMicrocycle) o.fromMicrocycle],
          [2],
        );
        expect(incline.setTargetsByMicrocycle.first.setTargets, hasLength(3));
        final rest = [
          for (final d in result.mesocycles[0].workoutTemplates) ...d.exercises,
        ].skip(1);
        expect(rest.every((e) => e.setTargetsByMicrocycle.isEmpty), isTrue);

        // In the second block only the row's last-set RIR changes in week 2.
        final row = _exercise(result, 1, block: 1);
        expect([for (final t in row.setTargets) t.rirTarget], [2, 1, 1]);
        expect(
          [for (final o in row.setTargetsByMicrocycle) o.fromMicrocycle],
          [2],
        );
        expect(
          [
            for (final t in row.setTargetsByMicrocycle.first.setTargets)
              t.rirTarget,
          ],
          [2, 1, 0],
        );
        expect([
          for (final d in result.mesocycles[1].workoutTemplates)
            for (final e in d.exercises)
              if (e.setTargetsByMicrocycle.isNotEmpty) e,
        ], hasLength(1));
      },
    );

    test('rows sharing a superset tag share a group', () {
      final result = _build();
      final group = _exercise(result, 0).supersetGroupId;
      expect(group, isNotNull);
      expect(_exercise(result, 1).supersetGroupId, group);
      expect(_exercise(result, 2).supersetGroupId, isNull);
      expect(_exercise(result, 0, day: 1).supersetGroupId, isNull);
    });

    test('the plan fields: notes, link, substitutions', () {
      final result = _build();
      final incline = _exercise(result, 0);
      expect(incline.notes, 'Pause at the bottom.');
      expect(incline.linkUrl, 'https://example.com/videos/incline-press');
      expect(incline.substituteExerciseIds, [
        'ex-machine-press',
        'ex-dumbbell-press',
      ]);
      expect(_exercise(result, 1).substituteExerciseIds, ['ex-cable-row']);
    });
  });

  group('techniques', () {
    test("each technique becomes the last set's type", () {
      final result = _build();
      SetTarget last(int block, int day, int index) =>
          _exercise(result, index, block: block, day: day).setTargets.last;
      expect(last(0, 0, 0).setType, SetTargetSetType.amrap);
      expect(last(0, 0, 0).rirTarget, 0);
      expect(
        _exercise(result, 0).setTargets.first.setType,
        SetTargetSetType.standard,
      );
      expect(last(0, 0, 1).setType, SetTargetSetType.myo);
      expect(last(0, 0, 1).miniSetCount, 3);
      expect(last(0, 0, 2).setType, SetTargetSetType.drop);
      expect(last(0, 0, 2).dropCount, 2);
      expect(last(0, 0, 2).dropStepPercent, 25);
      expect(last(0, 0, 3).setType, SetTargetSetType.standard);
      expect(last(0, 0, 4).setType, SetTargetSetType.partials);
      expect(last(0, 1, 0).setType, SetTargetSetType.standard);
      expect(last(0, 1, 1).setType, SetTargetSetType.stretch);
      expect(last(0, 1, 1).holdSeconds, 30);
      expect(last(0, 1, 2).setType, SetTargetSetType.hold);
      expect(last(0, 1, 2).holdSeconds, 20);
      expect(last(0, 1, 3).setType, SetTargetSetType.partials);
      expect(last(1, 0, 2).dropCount, 3);
      expect(last(1, 0, 2).dropStepPercent, 20);
      expect(last(1, 0, 3).setType, SetTargetSetType.partials);
    });

    test('a drop count may be written as a number, or not at all', () {
      ProgramSheetRow row(String technique) => ProgramSheetRow(
        exerciseName: 'Press',
        workingSets: 1,
        sourceRow: 1,
        technique: technique,
      );
      expect(programSetTargets(row('2x drop')).last.dropCount, 2);
      expect(programSetTargets(row('Drop set')).last.dropCount, isNull);
      expect(
        programSetTargets(row('Tempo')).last.setType,
        SetTargetSetType.standard,
      );
    });
  });

  group('values', () {
    test('early RPE sets every set but the last, last RPE the last', () {
      final result = _build();
      List<int?> rir(WorkoutTemplateExercise e) => [
        for (final t in e.setTargets) t.rirTarget,
      ];
      expect(rir(_exercise(result, 1)), [2, 2, 1]);
      expect(rir(_exercise(result, 0)), [2, 0]);
      expect(rir(_exercise(result, 3)), [0]);
      expect(rir(_exercise(result, 2, block: 1)), [1, 0]);
    });

    test('RIR is ten less the upper RPE, rounded down and kept to 0 to 5', () {
      expect(rirFromRpe(ValueRange(7, 8)), 2);
      expect(rirFromRpe(ValueRange.single(9.5)), 0);
      expect(rirFromRpe(ValueRange.single(10)), 0);
      expect(rirFromRpe(ValueRange.single(3)), 5);
      expect(rirFromRpe(ValueRange.single(8.5)), 1);
    });

    test('rest is the midpoint rounded to 15 seconds, none for a dash', () {
      final result = _build();
      expect(_exercise(result, 0).restSeconds, isNull);
      expect(_exercise(result, 1).restSeconds, 90);
      expect(_exercise(result, 2).restSeconds, 45);
      expect(_exercise(result, 0, day: 1).restSeconds, 180);
      expect(
        programRestSeconds(
          ProgramSheetRow(
            exerciseName: 'Press',
            workingSets: 1,
            sourceRow: 1,
            rest: ValueRange.single(2),
          ),
        ),
        15,
      );
    });

    test('warm-ups are the upper bound, null when absent', () {
      final result = _build();
      expect(_exercise(result, 0).warmupSetCount, 3);
      expect(_exercise(result, 2).warmupSetCount, 1);
      expect(_exercise(result, 3).warmupSetCount, 0);
      expect(_exercise(result, 4).warmupSetCount, isNull);
      expect(_exercise(result, 0, day: 1).warmupSetCount, 4);
    });

    test('reps are the range, a fixed value both ends, per side unchanged', () {
      final result = _build();
      expect(
        _exercise(
          result,
          0,
        ).setTargets.every((t) => t.minReps == 6 && t.maxReps == 8),
        isTrue,
      );
      expect(_exercise(result, 3).setTargets.first.minReps, 20);
      expect(_exercise(result, 3).setTargets.first.maxReps, 20);
      final split = _exercise(result, 1, day: 1);
      expect(split.setTargets.first.minReps, 10);
      expect(split.setTargets.first.maxReps, 10);
      expect(split.exercise.laterality, Laterality.bilateral);
    });

    test('at least one set, and a set past the RIR columns has none', () {
      final targets = programSetTargets(_sheetRow('8', rir: [2]));
      expect(targets, hasLength(1));
      final two = programSetTargets(
        const ProgramSheetRow(
          exerciseName: 'Press',
          workingSets: 2,
          sourceRow: 1,
          rirPerSet: [1],
        ),
      );
      expect([for (final t in two) t.rirTarget], [1, null]);
    });

    test('per side reps are found by name', () {
      final sheet = csvSheet();
      expect(isPerSideInSheet(sheet, 'Split Squat'), isTrue);
      expect(isPerSideInSheet(sheet, 'Squat'), isFalse);
    });
  });

  group('errors', () {
    test(
      'a week whose exercises differ from week 1 names the week and day',
      () {
        final sheet = csvSheet();
        final rows = sheet.blocks[0].weeks[1].days[1].rows;
        rows[0] = rows[0].copyWith(exerciseName: 'Hack Squat');
        expect(
          () => _build(sheet),
          throwsA(const ExercisesDifferError('Week 2', 'Lower', 22)),
        );
      },
    );

    test('a week whose days differ from week 1 is an error', () {
      final sheet = csvSheet();
      sheet.blocks[1].weeks[1].days.removeLast();
      expect(() => _build(sheet), throwsA(const DaysDifferError('Week 2', 41)));
    });

    test('a week with no days names no row', () {
      final sheet = csvSheet();
      sheet.blocks[1].weeks[1].days.clear();
      expect(
        () => _build(sheet),
        throwsA(isA<DaysDifferError>().having((e) => e.row, 'row', 0)),
      );
    });

    test('nothing is built until every name resolves', () {
      final sheet = csvSheet();
      final library = [
        for (final e in fixtureLibrary)
          if (!['Row', 'Leg Press'].contains(e.name)) e,
      ];
      expect(unmatchedProgramNames(sheet, fixtureResolve(library)), [
        'Row',
        'Leg Press',
      ]);
      expect(
        () => buildProgramFromSheet(
          sheet,
          style: fixtureStyle,
          resolve: fixtureResolve(library),
          now: _now,
        ),
        throwsA(const UnmatchedExercisesError(['Row', 'Leg Press'])),
      );
    });

    test('a sheet with no blocks has no exercises', () {
      expect(
        () => _build(const ProgramSheet(title: 'x', blocks: [])),
        throwsA(const NoExercisesError()),
      );
    });

    test('errors carry their row where they have one', () {
      expect(const UnreadableFileError().row, isNull);
      expect(const MissingWorkingSetsError(3).row, 3);
      expect(const ExercisesDifferError('W', 'D', 4).row, 4);
      expect(
        const UnmatchedExercisesError(['a']),
        isNot(const UnmatchedExercisesError(['b'])),
      );
      expect(
        const UnmatchedExercisesError(['a']).hashCode,
        const UnmatchedExercisesError(['a']).hashCode,
      );
    });
  });

  group('readProgramFile', () {
    test('reads each format by its extension, in any case', () {
      expect(
        readProgramFile(fixtureBytes('sample-program.xlsx'), 'XLSX'),
        isA<ProgramFileSheet>(),
      );
      final csv = readProgramFile(fixtureBytes('sample-program.csv'), 'csv');
      expect((csv as ProgramFileSheet).sheet, csvSheet());
      final json = readProgramFile(fixtureBytes('sample-program.json'), 'json');
      expect((json as ProgramFileMesocycles).mesocycles, hasLength(2));
      expect(
        () => readProgramFile(const [], 'pdf'),
        throwsA(const UnreadableFileError()),
      );
    });
  });

  group('JSON', () {
    test("the app's JSON imports as the user's own copies", () {
      final mesocycles = _json();
      expect([for (final m in mesocycles) m.name], ['Build', 'Peak']);
      expect(mesocycles.first.dateCreated.year, 2026);

      final library = [
        for (final e in fixtureLibrary)
          if (e.name != 'Calf Raise') e,
      ];
      const style = ProgramImportStyle(
        authorId: 'user-2',
        icon: 'x',
        colour: '#FFFFFF',
      );
      final result = buildProgramFromMesocycles(
        mesocycles,
        title: 'sample-program',
        style: style,
        library: library,
        now: _now,
      );
      expect([for (final m in result.mesocycles) m.name], ['Build', 'Peak']);
      expect(
        [for (final m in result.mesocycles) m.workoutTemplates.length],
        [3, 3],
      );
      for (final mesocycle in result.mesocycles) {
        expect(mesocycle.authorId, 'user-2');
        expect(mesocycle.icon, 'flag');
      }
      expect(
        {for (final m in result.mesocycles) m.id}
            .intersection({for (final m in mesocycles) m.id}),
        isEmpty,
      );
      expect(result.macrocycle.name, 'sample-program');
      expect(result.macrocycle.status, MacrocycleStatus.notStarted);
      expect(
        [
          for (final o
              in result
                  .mesocycles[0]
                  .workoutTemplates[0]
                  .exercises[0]
                  .setTargetsByMicrocycle)
            o.fromMicrocycle,
        ],
        [2],
      );
      // Someone else's exercise, used by both blocks, is copied once.
      expect([for (final e in result.newExercises) e.name], ['Calf Raise']);
      expect(result.newExercises.first.authorId, 'user-2');
    });

    test('a single mesocycle object is accepted, and anything else is '
        'unreadable', () {
      final json = jsonDecode(
        utf8.decode(fixtureBytes('sample-program.json')),
      ) as List<Object?>;
      expect(
        [
          for (final m in mesocyclesFromJson(utf8.encode(jsonEncode(json[1]))))
            m.name,
        ],
        ['Peak'],
      );
      expect(
        () => mesocyclesFromJson(utf8.encode('{"name": 1}')),
        throwsA(const UnreadableFileError()),
      );
      expect(
        () => mesocyclesFromJson(utf8.encode('not json')),
        throwsA(const UnreadableFileError()),
      );
    });

    test('a single mesocycle names the macrocycle, and one with no days '
        'gets a rest day', () {
      final peak = _json()[1];
      final empty = Mesocycle(
        id: 'm',
        authorId: 'a',
        name: 'Empty',
        icon: 'i',
        colour: '#000000',
        workoutTemplates: const [],
        dateCreated: _now,
        dateModified: _now,
      );
      final one = buildProgramFromMesocycles(
        [peak],
        title: 'file',
        style: fixtureStyle,
        library: fixtureLibrary,
        now: _now,
      );
      expect(one.macrocycle.name, 'Peak');
      expect(one.newExercises, isEmpty);
      final rest = buildProgramFromMesocycles(
        [empty],
        title: 'file',
        style: fixtureStyle,
        library: const [],
        now: _now,
      );
      expect(
        [for (final d in rest.mesocycles.single.workoutTemplates) d.name],
        ['Rest'],
      );
      expect(
        () => buildProgramFromMesocycles(
          const [],
          title: 'file',
          style: fixtureStyle,
          library: const [],
          now: _now,
        ),
        throwsA(const NoExercisesError()),
      );
    });
  });

  group('ProgramImportSummary', () {
    test('summarises what a save will create', () {
      final summary = ProgramImportSummary.of(_build().mesocycles);
      expect(summary.blocks, 2);
      expect(summary.weeks, 4);
      expect(summary.days, 4);
      expect(summary.exercises, 17);
      expect(summary.techniques, hasLength(6));
      expect(summary.techniques, isNot(contains(SetTargetSetType.standard)));
      expect(summary.withRest, 16);
      expect(summary.withWarmups, 16);
    });
  });
}
