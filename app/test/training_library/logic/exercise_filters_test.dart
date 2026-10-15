import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  const barbell = EquipmentRef(
    kind: EquipmentKind.loadableBar,
    equipmentId: 'barbell',
  );
  const bench = EquipmentRef(
    kind: EquipmentKind.supportEquipment,
    equipmentId: 'flat_bench',
  );
  final press = fixtureLibraryExercise(
    'press',
    variations: const [
      EquipmentVariation(
        id: 'v1',
        resistanceEquipment: [barbell],
        supportEquipment: [bench],
      ),
    ],
  );
  final plank = fixtureLibraryExercise(
    'plank',
    type: ExerciseType.core,
    laterality: null,
    rangeOfMotion: 1,
    stability: 5,
    system: true,
  );

  bool matches(
    ExerciseFilters filters,
    ExerciseModel exercise, [
    Set<EquipmentKey> equipment = const {},
  ]) => filters.matches(exercise, equipment);

  group(ExerciseFilters, () {
    test('is inactive until something is set', () {
      expect(const ExerciseFilters().isActive, isFalse);
      expect(const ExerciseFilters(minimumStability: 2).isActive, isTrue);
    });

    test('filters by type and laterality; a missing one never matches', () {
      const core = ExerciseFilters(types: {ExerciseType.core});
      expect(matches(core, plank), isTrue);
      expect(matches(core, press), isFalse);
      const bilateral = ExerciseFilters(lateralities: {Laterality.bilateral});
      expect(matches(bilateral, press), isTrue);
      expect(matches(bilateral, plank), isFalse);
    });

    test('filters by the equipment any variation uses', () {
      expect(
        matches(
          const ExerciseFilters(resistanceKinds: {EquipmentKind.loadableBar}),
          press,
        ),
        isTrue,
      );
      expect(
        matches(
          const ExerciseFilters(resistanceKinds: {EquipmentKind.bands}),
          press,
        ),
        isFalse,
      );
      expect(
        matches(
          const ExerciseFilters(supportKinds: {EquipmentKind.supportEquipment}),
          press,
        ),
        isTrue,
      );
      expect(
        matches(
          const ExerciseFilters(supportKinds: {EquipmentKind.bands}),
          press,
        ),
        isFalse,
      );
    });

    test('ratings are floors', () {
      expect(
        matches(const ExerciseFilters(minimumRangeOfMotion: 4), press),
        isTrue,
      );
      expect(
        matches(const ExerciseFilters(minimumRangeOfMotion: 5), press),
        isFalse,
      );
      expect(
        matches(const ExerciseFilters(minimumStability: 5), plank),
        isTrue,
      );
      expect(
        matches(const ExerciseFilters(minimumStability: 4), press),
        isFalse,
      );
    });

    test('filters by library', () {
      const mine = ExerciseFilters(library: ExerciseLibraryScope.mine);
      const official = ExerciseFilters(library: ExerciseLibraryScope.official);
      expect(matches(mine, press), isTrue);
      expect(matches(mine, plank), isFalse);
      expect(matches(official, plank), isTrue);
      expect(matches(official, press), isFalse);
    });

    test('a gym needs a whole variation; no equipment always works', () {
      const gym = ExerciseFilters(gymProfileId: 'gym');
      expect(matches(gym, plank), isTrue);
      expect(
        matches(gym, press, {(EquipmentKind.loadableBar, 'barbell')}),
        isFalse,
      );
      expect(
        matches(gym, press, {
          (EquipmentKind.loadableBar, 'barbell'),
          (EquipmentKind.supportEquipment, 'flat_bench'),
        }),
        isTrue,
      );
    });

    test('copyWith keeps or replaces each field, nulls included', () {
      const filters = ExerciseFilters(
        minimumRangeOfMotion: 2,
        minimumStability: 3,
        gymProfileId: 'gym',
      );
      expect(filters.copyWith(), filters);
      expect(
        filters.copyWith(
          types: {ExerciseType.core},
          lateralities: {Laterality.unilateral},
          resistanceKinds: {EquipmentKind.bands},
          supportKinds: {EquipmentKind.bands},
          minimumRangeOfMotion: () => null,
          minimumStability: () => null,
          library: ExerciseLibraryScope.mine,
          gymProfileId: () => null,
        ),
        const ExerciseFilters(
          types: {ExerciseType.core},
          lateralities: {Laterality.unilateral},
          resistanceKinds: {EquipmentKind.bands},
          supportKinds: {EquipmentKind.bands},
          library: ExerciseLibraryScope.mine,
        ),
      );
    });
  });
}
