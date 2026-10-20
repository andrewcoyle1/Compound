import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:compound_models/src/gym_equipment_catalogue_json.dart';
import 'package:test/test.dart';

Map<String, Object?> _fixture(String model, String name) => jsonDecode(
  File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
) as Map<String, Object?>;

void main() {
  group(GymEquipmentCatalogue, () {
    test('is the Swift-recorded catalogue, byte for byte', () {
      expect(
        gymEquipmentCatalogueJson,
        File('../../../contracts/firestore/gym_equipment_catalogue.json')
            .readAsStringSync(),
        reason:
            'Regenerate: dart run tool/embed_json.dart '
            '../../../contracts/firestore/gym_equipment_catalogue.json '
            'lib/src/gym_equipment_catalogue_json.dart '
            'gymEquipmentCatalogueJson',
      );
    });

    test('knows the one-sleeve plate-loaded machines', () {
      final sled = GymEquipmentCatalogue.instance.plateLoadedMachines
          .firstWhere((machine) => machine.id == 'sled');
      expect(sled.sleeves, 1);
    });
  });

  group(GymProfileModel, () {
    final profile = {'id': 'gym', 'author_id': 'u'};

    test('dates a profile saved without dates now, as Swift does', () {
      final before = DateTime.now();
      final read = GymProfileModel.fromFirestore(profile);
      expect(read.dateCreated.isBefore(before), isFalse);
      expect(read.dateModified.isBefore(before), isFalse);
      expect(read.name, '');
      expect(read.icon, 'dumbbell');
    });

    test('is the whole catalogue, as it stands, with no lists stored', () {
      final read = GymProfileModel.fromFirestore(profile);
      final catalogue = GymEquipmentCatalogue.instance;
      expect(read.freeWeights, same(catalogue.freeWeights));
      expect(read.pinLoadedMachines, same(catalogue.pinLoadedMachines));
    });

    test('appends what a list lacks, switched off, nested entries kept', () {
      final catalogue = GymEquipmentCatalogue.instance.freeWeights;
      final kept = catalogue.first.toFirestore();
      final read = GymProfileModel.fromFirestore({
        ...profile,
        GymProfileModelKeys.freeWeights: [kept],
      });
      expect(read.freeWeights.first.toFirestore(), kept);
      expect(read.freeWeights, hasLength(catalogue.length));
      for (final (index, item) in read.freeWeights.skip(1).indexed) {
        expect(item.isActive, isFalse);
        expect(item.id, catalogue[index + 1].id);
        expect(
          [for (final weight in item.range) weight.id],
          [for (final weight in catalogue[index + 1].range) weight.id],
        );
      }
    });

    test('fails without an author, as Swift does', () {
      expect(
        () => GymProfileModel.fromFirestore({'id': 'gym'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group(WorkoutSettings, () {
    test("defaults are Swift's", () {
      // The minimal fixture is Swift's defaults but for this one scaling,
      // whose default 1.0 a fixture would record as the integer 1.
      expect(
        firestoreToTaggedJson(
          const WorkoutSettings(
            authorId: 'user_contract_minimal',
            betweenExercisesRestScaling: 1.5,
          ).toFirestore(),
        ),
        _fixture('workout_settings', 'minimal'),
      );
      expect(
        const WorkoutSettings(authorId: 'u').betweenExercisesRestScaling,
        1,
      );
    });

    test('fails on a missing field, as Swift does', () {
      final stored = taggedJsonToFirestore(
        _fixture('workout_settings', 'minimal'),
      )..remove(WorkoutSettingsKeys.keepAlive);
      expect(
        () => WorkoutSettings.fromFirestore(stored),
        throwsA(isA<TypeError>()),
      );
    });

    test('stores the older raw values of previous-workout reference', () {
      expect(PreviousWorkoutReferenceOption.sameWorkout.value, 'anyWorkout');
      expect(
        PreviousWorkoutReferenceOption.workoutsInMesocycle.value,
        'workoutsInProgram',
      );
    });
  });

  group(ExerciseModel, () {
    test('fails without a name, as Swift does', () {
      expect(
        () => ExerciseModel.fromFirestore({'id': 'e'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group(WorkoutTemplateExercise, () {
    test('fails on an unreadable set target, as Swift does', () {
      expect(
        () => WorkoutTemplateExercise.fromFirestore({
          'id': 'slot',
          'exercise': {'id': 'e', 'name': 'Row'},
          'set_targets': [
            {'id': 't'},
          ],
          'set_rest_timers': false,
        }),
        throwsFormatException,
      );
    });
  });
}
