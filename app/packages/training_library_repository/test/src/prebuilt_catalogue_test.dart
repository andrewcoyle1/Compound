import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/src/prebuilt_exercises_json.dart';
import 'package:training_library_repository/src/prebuilt_mesocycles_json.dart';
import 'package:training_library_repository/src/prebuilt_workouts_json.dart';
import 'package:training_library_repository/training_library_repository.dart';

String _swift(String name) =>
    File('../../../Compound/SupportingFiles/Resources/$name')
        .readAsStringSync();

void main() {
  group(PrebuiltCatalogue, () {
    final catalogue = PrebuiltCatalogue.instance;

    for (final (name, embedded) in [
      ('PrebuiltExercises.json', prebuiltExercisesJson),
      ('PrebuiltWorkouts.json', prebuiltWorkoutsJson),
      ('PrebuiltMesocycles.json', prebuiltMesocyclesJson),
    ]) {
      test("embeds the Swift app's $name byte for byte", () {
        expect(
          embedded,
          _swift(name),
          reason:
              'Regenerate with dart ../compound_models/tool/embed_json.dart',
        );
      });
    }

    test('decodes every system exercise, by name', () {
      final stored = jsonDecode(prebuiltExercisesJson) as Map<String, Object?>;
      expect(
        catalogue.exercises,
        hasLength((stored['exercises']! as List).length),
      );
      final names = [for (final exercise in catalogue.exercises) exercise.name];
      expect(names, [...names]..sort());
    });

    test("reads the bench press as Swift's JSONDecoder does", () {
      final bench = catalogue.exercises.firstWhere(
        (exercise) => exercise.id == 'system-barbell-bench-press',
      );
      expect(bench.authorId, 'official');
      expect(bench.isSystemExercise, isTrue);
      expect(bench.type, ExerciseType.compoundUpper);
      expect(bench.muscleGroups[Muscles.chest], MuscleTargetType.primary);
      expect(bench.equipmentVariations, hasLength(2));
      expect(bench.trackableMetrics, [
        TrackableExerciseMetric.reps,
        TrackableExerciseMetric.weight,
      ]);
      // 757382400 seconds after 1 January 2001.
      expect(bench.dateCreated, DateTime.utc(2025));
      expect(bench.dateModified, DateTime.utc(2025));
    });

    test('builds each workout as PrebuiltWorkoutDTO.toModel does', () {
      final stored =
          (jsonDecode(prebuiltWorkoutsJson) as Map)['workouts'] as List;
      expect(catalogue.workoutTemplates, hasLength(stored.length));
      final push = catalogue.workoutTemplates.first;
      expect(push.workoutId, 'workout-push-1');
      expect(push.authorId, 'official');
      expect(push.name, 'Push Day A');
      expect(push.exercises.first.exercise.id, 'system-barbell-bench-press');
      final first = push.exercises.first;
      expect(first.id, 'workout-push-1_1');
      expect(first.setRestTimers, isFalse);
      expect(first.setTargets.single.toFirestore(), {
        'id': 'workout-push-1_1_set_1',
        'set_number': 1,
        'min_reps': 8,
        'max_reps': 12,
        'set_type': 'standard',
      });
      for (final (index, workout) in catalogue.workoutTemplates.indexed) {
        final ids = (stored[index] as Map)['exerciseIds'] as List;
        expect(
          [for (final slot in workout.exercises) slot.exercise.id],
          ids,
          reason: '${workout.workoutId} lost an exercise',
        );
      }
    });

    test('decodes every prebuilt mesocycle, as PrebuiltSeedData does', () {
      final stored =
          (jsonDecode(prebuiltMesocyclesJson) as Map)['mesocycles'] as List;
      expect(
        [for (final mesocycle in catalogue.mesocycles) mesocycle.id],
        [for (final mesocycle in stored) (mesocycle as Map)['mesocycleId']],
      );
      expect(
        {
          for (final mesocycle in catalogue.mesocycles)
            mesocycle.id: mesocycle.workoutTemplates
                .where((day) => day.exercises.isNotEmpty)
                .length,
        },
        {
          'program-push-pull-legs': 6,
          'program-upper-lower': 4,
          'program-full-body': 3,
          'program-531': 4,
        },
      );
      for (final (index, mesocycle) in catalogue.mesocycles.indexed) {
        expect(mesocycle.authorId, 'official');
        final days = (stored[index] as Map)['days'] as List;
        expect(
          [for (final day in mesocycle.workoutTemplates) day.workoutId],
          [
            for (final (i, day) in days.indexed)
              if (day == 'rest') '${mesocycle.id}-rest-$i' else day,
          ],
        );
        // Each is a document Swift can read back.
        expect(
          Mesocycle.fromFirestore(mesocycle.toFirestore()).toFirestore(),
          mesocycle.toFirestore(),
        );
      }
      final wave = catalogue.mesocycles.last;
      expect(wave.name, '5/3/1');
      expect(wave.periodisation, isTrue);
      expect(wave.numMicrocycles, 4);
      expect(wave.deload, DeloadType.end);
      final rest = wave.workoutTemplates[2];
      expect(rest.name, 'Rest Day');
      expect(rest.exercises, isEmpty);
      expect(rest.dateCreated, wave.dateCreated);
    });

    test('drops a mesocycle naming a missing workout, or with none', () {
      final workouts = catalogue.workoutTemplates;
      Map<String, Object?> json(List<String> days) => {
        'mesocycleId': 'p',
        'name': 'P',
        'icon': 'flag',
        'colour': '#FF0000',
        'numMicrocycles': 6,
        'deload': 'start',
        'periodisation': false,
        'days': days,
      };
      final read = PrebuiltCatalogue.mesocycleFromJson(
        json(['workout-push-1', 'rest']),
        workouts,
      )!;
      expect(read.deload, DeloadType.start);
      expect(
        [for (final day in read.workoutTemplates) day.workoutId],
        ['workout-push-1', 'p-rest-1'],
      );
      expect(
        PrebuiltCatalogue.mesocycleFromJson(
          json(['workout-push-1', 'workout-nope']),
          workouts,
        ),
        isNull,
      );
      expect(
        PrebuiltCatalogue.mesocycleFromJson(json(['rest', 'rest']), workouts),
        isNull,
      );
    });

    test('is decoded once', () {
      expect(PrebuiltCatalogue.instance, same(catalogue));
      expect(
        PrebuiltCatalogue.decode().exercises,
        hasLength(catalogue.exercises.length),
      );
    });
  });
}
