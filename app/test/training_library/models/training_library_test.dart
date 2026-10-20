import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  final bench = fixtureLibraryExercise(
    'bench',
    name: 'Bench Press',
    alternateNames: ['Flat Press'],
  );
  final squat = fixtureLibraryExercise(
    'squat',
    name: 'Squat',
    muscles: {Muscles.quads: MuscleTargetType.primary},
  );
  final push = fixtureTemplate(
    'push',
    name: 'Push Day',
    exercises: [fixtureSlot(bench)],
  );

  GymProfileModel gym(List<Map<String, Object?>> cableMachines) =>
      GymProfileModel.fromFirestore({
        GymProfileModelKeys.id: 'gym-1',
        GymProfileModelKeys.authorId: 'friend',
        GymProfileModelKeys.name: 'Home',
        GymProfileModelKeys.cableMachines: cableMachines,
      });
  final latPulldown = GymEquipmentCatalogue.instance.cableMachines
      .firstWhere((machine) => machine.id == 'cable_lat_pulldown_machine')
      .toFirestore();

  group(TrainingLibrary, () {
    test("puts the bundled catalogue beside the user's own", () {
      final library = TrainingLibrary(userExercises: [bench]);
      final catalogue = PrebuiltCatalogue.instance;
      expect(library.systemExercises, catalogue.exercises);
      expect(library.systemWorkoutTemplates, catalogue.workoutTemplates);
      expect(library.allExercises.first, bench);
      expect(library.exercise('bench'), bench);
      expect(
        library.exercise('system-barbell-bench-press')?.name,
        'Barbell Bench Press',
      );
      expect(library.exercise('missing'), isNull);
    });

    test('searches exercises on name, other names and muscles, by name', () {
      final library = TrainingLibrary(userExercises: [squat, bench]);
      expect(library.searchExercises('flat press!').map((e) => e.id), [
        'bench',
      ]);
      expect(library.searchExercises('QUADS'), contains(squat));
      expect(library.searchExercises(''), isEmpty);
    });

    test('searches workouts on name and exercises', () {
      final library = TrainingLibrary(userWorkoutTemplates: [push]);
      expect(library.searchWorkoutTemplates('push'), contains(push));
      expect(library.searchWorkoutTemplates('bench press'), contains(push));
      expect(library.searchWorkoutTemplates('zzz'), isEmpty);
    });

    test('filters and sorts by name', () {
      final library = TrainingLibrary(userExercises: [squat, bench]);
      expect(library.filtered([squat, bench], const ExerciseFilters()), [
        bench,
        squat,
      ]);
      expect(
        library.filtered([
          squat,
          bench,
        ], const ExerciseFilters(types: {ExerciseType.core})),
        isEmpty,
      );
    });

    test("lists a mesocycle's days in its own order, without rest days", () {
      final block = fixtureMesocycle('m1', [
        fixtureTemplate('push', name: 'Push', exercises: [fixtureSlot(bench)]),
        fixtureTemplate('rest', name: 'Rest'),
        fixtureTemplate('legs', name: 'Legs', exercises: [fixtureSlot(squat)]),
      ], name: 'Block');
      final rest = fixtureMesocycle('m2', [fixtureTemplate('r2')]);
      final library = TrainingLibrary(mesocycles: [rest, block]);

      final days = library.mesocycleDays('');
      expect(days.single.$1, block);
      expect(days.single.$2.map((day) => day.name), ['Push', 'Legs']);
      expect(library.mesocycleDays('leg').single.$2.map((day) => day.name), [
        'Legs',
      ]);
      expect(library.mesocycleDays('pull'), isEmpty);
    });

    test("finds a template among the user's, the days and the bundled", () {
      final day = fixtureTemplate('day', exercises: [fixtureSlot(squat)]);
      final block = fixtureMesocycle('m1', [day]);
      final library = TrainingLibrary(
        userWorkoutTemplates: [push],
        mesocycles: [block],
      );
      expect(library.template('push'), (push, null));
      expect(library.template('day'), (day, block));
      expect(library.template('workout-push-1')?.$1.name, 'Push Day A');
      expect(library.template('missing'), isNull);
    });

    test('a gym with no such profile has no equipment', () {
      expect(const TrainingLibrary().availableEquipment(null), isEmpty);
      expect(const TrainingLibrary().availableEquipment('gym-1'), isEmpty);
    });

    test('a switched-on duplicate makes its type available', () {
      final off = gym([
        {...latPulldown, GymEquipmentKeys.isActive: false},
      ]);
      final withCopy = gym([
        {...latPulldown, GymEquipmentKeys.isActive: false},
        {
          ...latPulldown,
          GymEquipmentKeys.id: 'copy',
          GymEquipmentKeys.isActive: true,
        },
      ]);
      const key = (EquipmentKind.cableMachine, 'cable_lat_pulldown_machine');
      expect(
        TrainingLibrary(gymProfiles: [off]).availableEquipment('gym-1'),
        isNot(contains(key)),
      );
      expect(
        TrainingLibrary(gymProfiles: [withCopy]).availableEquipment('gym-1'),
        contains(key),
      );
    });

    test('leaves deleted gyms out', () {
      final deleted = GymProfileModel.fromFirestore({
        GymProfileModelKeys.id: 'old',
        GymProfileModelKeys.authorId: 'friend',
        GymProfileModelKeys.deletedAt: DateTime.utc(2026),
      });
      expect(TrainingLibrary(gymProfiles: [deleted]).gyms, isEmpty);
    });

    test("names equipment from the catalogue, then the user's gyms", () {
      final custom = gym([
        {
          ...latPulldown,
          GymEquipmentKeys.id: 'mine',
          GymEquipmentKeys.typeId: 'my-machine',
          GymEquipmentKeys.name: 'My Machine',
        },
      ]);
      final library = TrainingLibrary(gymProfiles: [custom]);
      expect(
        library.equipmentName(
          const EquipmentRef(
            kind: EquipmentKind.loadableBar,
            equipmentId: 'barbell',
          ),
        ),
        'Barbell',
      );
      expect(
        library.equipmentName(
          const EquipmentRef(
            kind: EquipmentKind.cableMachine,
            equipmentId: 'my-machine',
          ),
        ),
        'My Machine',
      );
      expect(
        library.equipmentName(
          const EquipmentRef(kind: EquipmentKind.bands, equipmentId: 'gone'),
        ),
        isNull,
      );
    });

    test("lists each equipment type once, the catalogue's then a gym's", () {
      final custom = gym([
        latPulldown,
        {
          ...latPulldown,
          GymEquipmentKeys.id: 'mine',
          GymEquipmentKeys.typeId: 'my-machine',
          GymEquipmentKeys.name: 'My Machine',
        },
      ]);
      final types = TrainingLibrary(gymProfiles: [custom]).equipmentTypes;
      final keys = [for (final (key, _) in types) key];
      expect(keys.toSet(), hasLength(keys.length));
      expect(types.last, (
        (EquipmentKind.cableMachine, 'my-machine'),
        'My Machine',
      ));
      expect(
        types,
        contains(((EquipmentKind.loadableBar, 'barbell'), 'Barbell')),
      );
    });
  });
}
