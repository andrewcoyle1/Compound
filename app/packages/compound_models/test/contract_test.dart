// The Dart half of the Firestore contract
// (docs/specs/flutter/firestore-contract.md). The fixtures in
// contracts/firestore/ are recorded from the Swift models; every one must
// decode here, and the canonical ones must come back from
// fromFirestore -> toFirestore exactly, keys and number types included.
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

/// Each model folder in contracts/firestore/, with its Dart round trip and
/// field-name constants. A folder Swift adds fails until it is listed here.
final _models =
    <
      String,
      ({
        Map<String, Object?> Function(Map<String, Object?>) roundTrip,
        List<String> keys,
      })
    >{
      'user_model': (
        roundTrip: (data) => UserModel.fromFirestore(data).toFirestore(),
        keys: UserModelKeys.all,
      ),
      'private_user_settings': (
        roundTrip: (data) =>
            PrivateUserSettings.fromFirestore(data).toFirestore(),
        keys: PrivateUserSettingsKeys.all,
      ),
      'workout_session': (
        roundTrip: (data) =>
            WorkoutSessionModel.fromFirestore(data).toFirestore(),
        keys: WorkoutSessionModelKeys.all,
      ),
      'workout_exercise': (
        roundTrip: (data) =>
            WorkoutExerciseModel.fromFirestore(data).toFirestore(),
        keys: WorkoutExerciseModelKeys.all,
      ),
      'workout_set': (
        roundTrip: (data) => WorkoutSetModel.fromFirestore(data).toFirestore(),
        keys: WorkoutSetModelKeys.all,
      ),
      'set_target': (
        roundTrip: (data) => SetTarget.fromFirestore(data).toFirestore(),
        keys: SetTargetKeys.all,
      ),
      'equipment_variation': (
        roundTrip: (data) =>
            EquipmentVariation.fromFirestore(data).toFirestore(),
        keys: EquipmentVariationKeys.all,
      ),
    };

final _root = Directory('../../../contracts/firestore');

Map<String, Object?> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

File _fixture(String model, String name) =>
    File('${_root.path}/$model/$name.json');

List<String> _caseNames(String model) =>
    Directory('${_root.path}/$model')
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .where((n) => n.endsWith('.json') && !n.endsWith('.expected.json'))
        .map((n) => n.substring(0, n.length - '.json'.length))
        .toList()
      ..sort();

Map<String, Object?> _roundTrip(String model, Map<String, Object?> tagged) =>
    firestoreToTaggedJson(
      _models[model]!.roundTrip(taggedJsonToFirestore(tagged)),
    );

/// Equal values of the same JSON type: an int never matches a double, so a
/// Dart write cannot change a field's Firestore type unnoticed.
Matcher _strictlyEquals(Object? expected) => predicate<Object?>(
  (actual) => _strictEqual(actual, expected),
  'strictly equals ${jsonEncode(expected)}',
);

bool _strictEqual(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> x, final Map<String, Object?> y) =>
    x.length == y.length &&
        x.keys.every((k) => y.containsKey(k) && _strictEqual(x[k], y[k])),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        [for (var i = 0; i < x.length; i++) i]
            .every((i) => _strictEqual(x[i], y[i])),
  _ => a.runtimeType == b.runtimeType && a == b,
};

void main() {
  test('every contract folder has a Dart model', () {
    final folders = _root
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(folders, equals(_models.keys.toSet()));
  });

  for (final model in _models.keys) {
    group(model, () {
      test('has full and minimal fixtures', () {
        expect(_caseNames(model), containsAll(['full', 'minimal']));
      });

      for (final name in _caseNames(model)) {
        if (name.startsWith('legacy-')) {
          test('$name decodes to $name.expected.json', () {
            expect(
              _roundTrip(model, _read(_fixture(model, name))),
              _strictlyEquals(_read(_fixture(model, '$name.expected'))),
            );
          });
        } else {
          test('$name re-encodes to exactly itself', () {
            final fixture = _read(_fixture(model, name));
            expect(_roundTrip(model, fixture), _strictlyEquals(fixture));
          });
        }
      }

      test('field-name constants are exactly the full fixture keys', () {
        expect(
          _models[model]!.keys.toSet(),
          equals(_read(_fixture(model, 'full')).keys.toSet()),
        );
      });
    });
  }

  test('enum raw values match contracts/firestore/enums.json', () {
    final enums = _read(File('${_root.path}/enums.json'));
    List<String> raw(List<FirestoreEnum> values) => [
      for (final v in values) v.value,
    ];
    expect(
      enums,
      equals({
        'ActivityLevel': raw(ActivityLevel.values),
        'EquipmentKind': raw(EquipmentKind.values),
        'ExerciseWeightUnit': raw(ExerciseWeightUnit.values),
        'SetKind': raw(SetKind.values),
        'SetSide': raw(SetSide.values),
        'SetTargetSetType': raw(SetTargetSetType.values),
        'TrackingMode': raw(TrackingMode.values),
        'CardioFitnessLevel': raw(CardioFitnessLevel.values),
        'DistanceUnitPreference': raw(DistanceUnitPreference.values),
        'ExerciseFrequency': raw(ExerciseFrequency.values),
        'Gender': raw(Gender.values),
        'LengthUnitPreference': raw(LengthUnitPreference.values),
        'WeightUnitPreference': raw(WeightUnitPreference.values),
      }),
    );
  });
}
