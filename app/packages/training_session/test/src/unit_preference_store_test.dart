// Ports ExerciseUnitPreferenceManagerTests: the defaults from the profile,
// each unit set on its own, per exercise and per account, and kept across
// instances. The cache cases have nothing to port: the store has no cache.
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_session/training_session.dart';

void main() {
  const pounds = m.ExerciseWeightUnit.pounds;
  const kilograms = m.ExerciseWeightUnit.kilograms;

  group('UnitPreference.fromProfile', () {
    test('no profile reads kilograms and metres', () {
      final preference = UnitPreference.fromProfile(null);
      expect(preference.weightUnit, kilograms);
      expect(preference.distanceUnit, DistanceUnit.meters);
      expect(preference.weightUnitIsChosen, isFalse);
    });

    test("the profile's weight unit is the default", () {
      expect(
        UnitPreference.fromProfile(
          const m.UserModel(
            userId: 'u',
            submittedWeightUnitPreference: m.WeightUnitPreference.pounds,
          ),
        ).weightUnit,
        pounds,
      );
      expect(
        UnitPreference.fromProfile(
          const m.UserModel(
            userId: 'u',
            submittedWeightUnitPreference: m.WeightUnitPreference.kilograms,
          ),
        ).weightUnit,
        kilograms,
      );
    });

    test('distance follows the distance unit, else the length unit', () {
      DistanceUnit of(
        m.DistanceUnitPreference? distance,
        m.LengthUnitPreference? length,
      ) => UnitPreference.fromProfile(
        m.UserModel(
          userId: 'u',
          submittedDistanceUnitPreference: distance,
          submittedLengthUnitPreference: length,
        ),
      ).distanceUnit;
      expect(of(m.DistanceUnitPreference.miles, null), DistanceUnit.miles);
      expect(
        of(m.DistanceUnitPreference.kilometers, m.LengthUnitPreference.inches),
        DistanceUnit.meters,
      );
      expect(of(null, m.LengthUnitPreference.inches), DistanceUnit.miles);
      expect(of(null, m.LengthUnitPreference.centimeters), DistanceUnit.meters);
      expect(of(null, null), DistanceUnit.meters);
    });
  });

  group('DistanceUnit', () {
    test('converts and rounds', () {
      expect(DistanceUnit.miles.toMeters(1), 1609.344);
      expect(DistanceUnit.miles.fromMeters(1609.344), 1);
      expect(DistanceUnit.meters.rounded(400.4), 400);
      expect(
        DistanceUnit.miles.fromMeters(DistanceUnit.miles.rounded(5432)),
        closeTo(3.38, 1e-9),
      );
    });
  });

  group('UnitPreferenceStore', () {
    test('returns the default when nothing is saved', () {
      final store = UnitPreferenceStore();
      final preference = store.of('u1', 'bench');
      expect(preference.weightUnit, kilograms);
      expect(preference.weightUnitIsChosen, isFalse);
      const user = m.UserModel(
        userId: 'u1',
        submittedWeightUnitPreference: m.WeightUnitPreference.pounds,
      );
      expect(store.of('u1', 'bench', user: user).weightUnit, pounds);
    });

    test('setting the weight unit chooses it and leaves distance', () {
      final store = UnitPreferenceStore()
        ..setDistanceUnit('u1', 'bench', DistanceUnit.miles)
        ..setWeightUnit('u1', 'bench', pounds);
      final preference = store.of('u1', 'bench');
      expect(preference.weightUnit, pounds);
      expect(preference.weightUnitIsChosen, isTrue);
      expect(preference.distanceUnit, DistanceUnit.miles);
    });

    test('setting the distance unit leaves the weight unit unchosen', () {
      final store = UnitPreferenceStore()
        ..setDistanceUnit('u1', 'row', DistanceUnit.miles);
      final preference = store.of('u1', 'row');
      expect(preference.distanceUnit, DistanceUnit.miles);
      expect(preference.weightUnit, kilograms);
      expect(preference.weightUnitIsChosen, isFalse);
    });

    test('a later choice overwrites, per exercise', () {
      final store = UnitPreferenceStore()
        ..setWeightUnit('u1', 'bench', pounds)
        ..setWeightUnit('u1', 'squat', pounds)
        ..setWeightUnit('u1', 'bench', kilograms);
      expect(store.of('u1', 'bench').weightUnit, kilograms);
      expect(store.of('u1', 'squat').weightUnit, pounds);
      expect(store.of('u1', 'deadlift').weightUnitIsChosen, isFalse);
    });

    test('accounts are kept apart, under Swift keys', () {
      final store = UnitPreferenceStore()..setWeightUnit('u1', 'bench', pounds);
      expect(store.of('u2', 'bench').weightUnit, kilograms);
      expect(
        UnitPreferenceStore.key('u1', 'bench'),
        'exercise_unit_preference_u1_bench',
      );
    });

    test('weight units are listed per account, by exercise', () {
      final store = UnitPreferenceStore()
        ..setWeightUnit('u1', 'bench', pounds)
        ..setDistanceUnit('u1', 'row', DistanceUnit.miles)
        ..setWeightUnit('u1_x', 'squat', pounds);
      expect(store.weightUnits('u1'), {'bench': pounds, 'row': kilograms});
      expect(store.weightUnits('u1_x'), {'squat': pounds});
      expect(store.weightUnits('u2'), isEmpty);
    });

    test('with no user nothing is saved and the defaults are read', () {
      var changes = 0;
      final store = UnitPreferenceStore();
      store.changes.listen((_) => changes++);
      store
        ..setWeightUnit(null, 'bench', pounds)
        ..setDistanceUnit(null, 'bench', DistanceUnit.miles);
      expect(store.of(null, 'bench').weightUnit, kilograms);
      expect(changes, 0);
      store.setWeightUnit('u1', 'bench', pounds);
      expect(changes, 1);
    });

    group('in a file', () {
      late Directory directory;

      setUp(() => directory = Directory.systemTemp.createTempSync('units'));
      tearDown(() => directory.deleteSync(recursive: true));

      test('preferences persist across instances', () {
        final file = File('${directory.path}/nested/units.json');
        UnitPreferenceStore(file: file)
          ..setWeightUnit('u1', 'bench', pounds)
          ..setDistanceUnit('u1', 'row', DistanceUnit.miles);
        final reopened = UnitPreferenceStore(file: file);
        expect(reopened.of('u1', 'bench').weightUnit, pounds);
        expect(reopened.of('u1', 'row').distanceUnit, DistanceUnit.miles);
      });

      test('a stored preference without the flag reads as chosen', () {
        final file = File('${directory.path}/units.json')
          ..writeAsStringSync(
            '{"exercise_unit_preference_u1_bench": '
            '{"weightUnit": "pounds", "distanceUnit": "unknown"}, '
            '"other": 3}',
          );
        final preference = UnitPreferenceStore(file: file).of('u1', 'bench');
        expect(preference.weightUnit, pounds);
        expect(preference.weightUnitIsChosen, isTrue);
        expect(preference.distanceUnit, DistanceUnit.meters);
      });

      test('a file that cannot be read starts empty', () {
        final broken = File('${directory.path}/broken.json')
          ..writeAsStringSync('not json');
        expect(
          UnitPreferenceStore(file: broken)
              .of('u1', 'bench')
              .weightUnitIsChosen,
          isFalse,
        );
        final list = File('${directory.path}/list.json')
          ..writeAsStringSync('[]');
        expect(
          UnitPreferenceStore(file: list).of('u1', 'b').weightUnit,
          kilograms,
        );
        expect(
          UnitPreferenceStore(file: File('${directory.path}/none.json'))
              .of('u1', 'b')
              .weightUnit,
          kilograms,
        );
      });
    });
  });
}
