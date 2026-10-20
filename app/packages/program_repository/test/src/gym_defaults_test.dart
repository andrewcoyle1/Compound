import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 9, 30);
  final catalogue = GymEquipmentCatalogue.instance;
  late int count;
  String newId() => 'new-${++count}';

  setUp(() => count = 0);

  GymProfileModel gym(WeightUnitPreference? unit) => newGymProfile(
    authorId: 'user-1',
    name: 'Home',
    now: now,
    weightUnit: unit,
    newId: newId,
  );

  /// Encodes and decodes to itself, so saving it writes the canonical shape.
  void expectCanonical(GymProfileModel profile) {
    final encoded = firestoreToTaggedJson(profile.toFirestore());
    expect(
      firestoreToTaggedJson(
        GymProfileModel.fromFirestore(taggedJsonToFirestore(encoded))
            .toFirestore(),
      ),
      strictlyEquals(encoded),
    );
  }

  LoadableBars barbell(GymProfileModel profile) =>
      profile.loadableBars.firstWhere((bar) => bar.typeId == 'barbell');

  group('newGymProfile', () {
    test("is the user's, named, with the whole catalogue", () {
      final profile = gym(WeightUnitPreference.kilograms);

      expect(profile.id, 'new-1');
      expect(
        (profile.authorId, profile.name, profile.icon),
        ('user-1', 'Home', 'dumbbell'),
      );
      expect((profile.dateCreated, profile.dateModified), (now, now));
      expect(profile.imageUrl, isNull);
      expect(profile.deletedAt, isNull);
      expect(
        [for (final item in profile.freeWeights) item.id],
        [for (final item in catalogue.freeWeights) item.id],
      );
      expect(
        [for (final item in profile.pinLoadedMachines) item.id],
        [for (final item in catalogue.pinLoadedMachines) item.id],
      );
      expectCanonical(profile);
    });

    test('a pound user loads the 45 lb bar', () {
      final profile = gym(WeightUnitPreference.pounds);

      final bar = barbell(profile);
      final fortyFive = bar.baseWeights.singleWhere(
        (weight) => weight.id == bar.chosenBaseWeightId,
      );
      expect(
        (fortyFive.baseWeight, fortyFive.unit, fortyFive.isActive),
        (45.0, ExerciseWeightUnit.pounds, true),
      );
      // The kilogram bars are left as they are, and so is every stack.
      expect(
        [
          for (final w in bar.baseWeights)
            if (w.id != fortyFive.id) w.isActive,
        ],
        [
          for (final w in barbell(gym(null)).baseWeights)
            if (w.id != fortyFive.id) w.isActive,
        ],
      );
      expect(
        firestoreToTaggedJson({
          'machines': [
            for (final m in profile.pinLoadedMachines) m.toFirestore(),
          ],
        }),
        firestoreToTaggedJson({
          'machines': [
            for (final m in catalogue.pinLoadedMachines) m.toFirestore(),
          ],
        }),
      );
      expectCanonical(profile);
    });

    test('a kilogram user, or one who has not said, stacks in kilograms', () {
      for (final unit in [WeightUnitPreference.kilograms, null]) {
        final profile = gym(unit);

        for (final machine in [
          ...profile.pinLoadedMachines,
          ...profile.cableMachines,
        ]) {
          final active = machine.ranges.where((stack) => stack.isActive);
          expect(active, isNotEmpty);
          expect(
            active.every((s) => s.unit == ExerciseWeightUnit.kilograms),
            isTrue,
          );
          expect(
            machine.ranges
                .singleWhere((stack) => stack.id == machine.defaultRangeId)
                .unit,
            ExerciseWeightUnit.kilograms,
          );
        }
        expect(barbell(profile).chosenBaseWeightId, isNull);
        expectCanonical(profile);
      }
    });
  });

  group('adaptingDefaults', () {
    StackMachine machine(List<WeightStack> ranges) => StackMachine(
      id: 'm',
      typeId: 'm',
      name: 'Machine',
      ranges: ranges,
      isActive: true,
      defaultRangeId: ranges.firstOrNull?.id,
    );
    WeightStack stack(String id, double max, ExerciseWeightUnit unit) =>
        WeightStack(
          id: id,
          name: id,
          minWeight: 5,
          maxWeight: max,
          increment: 5,
          unit: unit,
          isActive: true,
        );
    GymProfileModel withMachines(List<StackMachine> machines) =>
        GymProfileModel.fromFirestore({
          ...gym(WeightUnitPreference.pounds).toFirestore(),
          GymProfileModelKeys.pinLoadedMachines: [
            for (final m in machines) m.toFirestore(),
          ],
          GymProfileModelKeys.cableMachines: <Object?>[],
        });

    test('adds a kilogram stack of the same reach in fives', () {
      final adapted =
          withMachines([
            machine([stack('lb', 300, ExerciseWeightUnit.pounds)]),
          ]).adaptingDefaults(
            ExerciseWeightUnit.kilograms,
            newId: () => 'kg-stack',
            kilogramStackName: 'Pila en kilogramos',
          );

      final ranges = adapted.pinLoadedMachines.first.ranges;
      expect(
        [for (final s in ranges) (s.id, s.isActive)],
        [('lb', false), ('kg-stack', true)],
      );
      final added = ranges.last;
      expect(
        (added.name, added.minWeight, added.maxWeight, added.increment),
        ('Pila en kilogramos', 5.0, 135.0, 5.0),
      );
      expect(adapted.pinLoadedMachines.first.defaultRangeId, 'kg-stack');
    });

    test('keeps a kilogram stack the machine has, and adds none', () {
      final adapted = withMachines([
        machine([
          stack('lb', 200, ExerciseWeightUnit.pounds),
          stack('kg', 100, ExerciseWeightUnit.kilograms),
        ]),
      ]).adaptingDefaults(ExerciseWeightUnit.kilograms, newId: newId);

      final machine0 = adapted.pinLoadedMachines.first;
      expect(
        [for (final s in machine0.ranges) (s.id, s.isActive)],
        [('lb', false), ('kg', true)],
      );
      expect(machine0.defaultRangeId, 'kg');
    });

    test('gives a stackless machine a 100 kg stack, never under 5 kg', () {
      final adapted = withMachines([
        machine([]),
        machine([stack('tiny', 2, ExerciseWeightUnit.kilograms)]),
        machine([stack('small', 4, ExerciseWeightUnit.pounds)]),
      ]).adaptingDefaults(ExerciseWeightUnit.kilograms, newId: newId);

      expect(adapted.pinLoadedMachines[0].ranges.single.maxWeight, 100);
      expect(adapted.pinLoadedMachines[1].ranges.single.maxWeight, 2);
      expect(adapted.pinLoadedMachines[2].ranges.last.maxWeight, 5);
    });

    test('leaves a bar list with no 45 lb barbell as it is', () {
      final noPounds = GymProfileModel.fromFirestore({
        ...gym(null).toFirestore(),
        GymProfileModelKeys.loadableBars: [
          for (final bar in catalogue.loadableBars)
            {
              ...bar.toFirestore(),
              GymEquipmentKeys.baseWeights: [
                for (final w in bar.baseWeights)
                  if (w.unit == ExerciseWeightUnit.kilograms) w.toFirestore(),
              ],
            },
        ],
      });

      final adapted = noPounds.adaptingDefaults(ExerciseWeightUnit.pounds);

      expect(
        firestoreToTaggedJson(adapted.toFirestore()),
        firestoreToTaggedJson(noPounds.toFirestore()),
      );
    });

    test('makes Swift-style ids for added stacks by default', () {
      final adapted = withMachines([
        machine([stack('lb', 300, ExerciseWeightUnit.pounds)]),
      ]).adaptingDefaults(ExerciseWeightUnit.kilograms);

      expect(adapted.pinLoadedMachines.first.ranges.last.id, hasLength(36));
      expect(
        adapted.pinLoadedMachines.first.ranges.last.name,
        'Kilogram stack',
      );
    });
  });

  group('gymProfileToSave', () {
    final later = DateTime.utc(2026, 10, 16);

    test('names a blank gym Untitled, and stamps it modified', () {
      for (final blank in ['', '  \n']) {
        final draft = GymProfileModel.fromFirestore({
          ...gym(null).toFirestore(),
          GymProfileModelKeys.name: blank,
        });

        final saved = gymProfileToSave(draft, now: later);

        expect(saved.name, 'Untitled Gym Profile');
        expect(saved.dateModified, later);
        expect(saved.dateCreated, now);
        expect(
          gymProfileToSave(draft, now: later, untitledName: 'Sin título').name,
          'Sin título',
        );
      }
    });

    test('keeps a name as typed, and everything else', () {
      final draft = GymProfileModel.fromFirestore(
        modelFixture('gym_profile', 'full'),
      );

      final saved = gymProfileToSave(draft, now: later);

      expect(
        firestoreToTaggedJson(saved.toFirestore()),
        strictlyEquals({
          ...taggedFixture('gym_profile', 'full'),
          'date_modified': {r'$timestamp': '2026-10-16T00:00:00.000Z'},
        }),
      );
    });
  });
}
