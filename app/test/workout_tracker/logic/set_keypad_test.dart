import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSetModel _set({
  double? weightKg,
  int? reps,
  int? durationSec,
  bool logged = false,
  double? machineBaseKg,
  String? kind,
  String? parent,
}) => WorkoutSetModel(
  id: 's1',
  authorId: 'u',
  index: 1,
  isWarmup: false,
  dateCreated: DateTime(2026),
  weightKg: weightKg,
  reps: reps,
  durationSec: durationSec,
  machineBaseKg: machineBaseKg,
  kindRawValue: kind,
  parentSetId: parent,
  completedAt: logged ? DateTime(2026) : null,
);

SetKeypad _open(
  WorkoutSetModel set,
  SetField field, {
  ExerciseWeightUnit unit = ExerciseWeightUnit.kilograms,
}) => SetKeypad.open(
  exerciseId: 'e1',
  set: set,
  field: field,
  fields: SetField.of(set, TrackingMode.weightReps),
  unit: unit,
);

void main() {
  const kg = ExerciseWeightUnit.kilograms;

  group(SetField, () {
    test("a row offers its tracking mode's fields", () {
      final set = _set();
      expect(SetField.of(set, TrackingMode.weightReps), [
        SetField.weight,
        SetField.reps,
      ]);
      expect(SetField.of(set, TrackingMode.repsOnly), [SetField.reps]);
      expect(SetField.of(set, TrackingMode.timeOnly), [SetField.duration]);
      expect(SetField.of(set, TrackingMode.distanceTime), [
        SetField.distance,
        SetField.duration,
      ]);
      final hold = _set(kind: 'hold', parent: 'p');
      expect(SetField.of(hold, TrackingMode.weightReps), [
        SetField.weight,
        SetField.duration,
      ]);
      expect(SetField.of(hold, TrackingMode.repsOnly), [SetField.duration]);
    });
  });

  group(SetKeypad, () {
    test('the first key replaces the value, the rest append', () {
      final set = _set(weightKg: 100);
      var keypad = _open(set, SetField.weight);
      expect(keypad.text, '100');
      final (k1, s1) = keypad.type('6', set, kg)!;
      final (k2, s2) = k1.type('2', s1, kg)!;
      final (k3, s3) = k2.type('.', s2, kg)!;
      final (k4, s4) = k3.type('5', s3, kg)!;
      expect(k4.text, '62.5');
      expect(s4.weightKg, 62.5);
      keypad = k4;
      expect(keypad.type('.', s4, kg), isNull);
      final (k5, s5) = keypad.type('5', s4, kg)!;
      expect(k5.text, '62.55');
      expect(k5.type('5', s5, kg), isNull);
      expect(k5.type('x', s5, kg), isNull);
    });

    test('a weight is typed in its unit, as the load', () {
      final set = _set(weightKg: 50, machineBaseKg: 10);
      final keypad = _open(
        set,
        SetField.weight,
        unit: ExerciseWeightUnit.pounds,
      );
      expect(keypad.text, '88.18');
      final (_, typed) = keypad.type('0', set, ExerciseWeightUnit.pounds)!;
      expect(typed.weightKg, 10);
      final (_, cleared) = keypad.backspace(set, kg)!;
      expect(cleared.weightKg, isNull);
    });

    test('reps keep at least one on a logged set', () {
      final set = _set(reps: 8, logged: true);
      final keypad = _open(set, SetField.reps);
      expect(keypad.backspace(set, kg), isNull);
      final (k, s) = keypad.type('1', set, kg)!;
      expect(s.reps, 1);
      expect(k.type('2', s, kg)!.$2.reps, 12);
      expect(_open(_set(), SetField.reps).type('.', _set(), kg), isNull);
    });

    test('a time fills from the right, as a microwave', () {
      final set = _set(durationSec: 90);
      final keypad = SetKeypad.open(
        exerciseId: 'e1',
        set: set,
        field: SetField.duration,
        fields: const [SetField.duration],
        unit: kg,
      );
      expect(keypad.text, '130');
      expect(keypad.nextField, isNull);
      var (k, s) = keypad.type('4', set, kg)!;
      (k, s) = k.type('5', s, kg)!;
      expect(s.durationSec, 45);
      (k, s) = k.type('0', s, kg)!;
      expect(s.durationSec, 290);
      expect(SetKeypad.clockFromDigits('450'), '4:50');
      expect(SetKeypad.clockFromDigits('5'), '0:05');
      expect(SetKeypad.secondsFromDigits(''), isNull);
    });

    test('a distance takes decimals', () {
      final set = _set();
      final keypad = SetKeypad.open(
        exerciseId: 'e1',
        set: set,
        field: SetField.distance,
        fields: const [SetField.distance, SetField.duration],
        unit: kg,
      );
      expect(keypad.text, '');
      final (k, s) = keypad.type('.', set, kg)!;
      expect(k.text, '0.');
      expect(k.type('5', s, kg)!.$2.distanceMeters, 0.5);
      expect(keypad.nextField, SetField.duration);
      expect(
        SetKeypad.valueText(
          SetField.distance,
          set.copyWith(distanceMeters: 400),
          kg,
        ),
        '400',
      );
    });

    test('moves to the next field and shows a value again', () {
      final set = _set(weightKg: 60, reps: 8);
      final keypad = _open(set, SetField.weight);
      expect(keypad.nextField, SetField.reps);
      final moved = keypad.moved(SetField.reps, set, kg);
      expect(moved.field, SetField.reps);
      expect(moved.text, '8');
      expect(moved.nextField, isNull);
      expect(keypad.showing(set.copyWith(weightKg: 62.5), kg).text, '62.5');
      expect(SetKeypad.formatNumber(60), '60');
      expect(SetKeypad.formatNumber(102.25), '102.25');
    });
  });
}

extension on WorkoutSetModel {
  WorkoutSetModel copyWith({double? weightKg, double? distanceMeters}) =>
      WorkoutSetModel(
        id: id,
        authorId: authorId,
        index: index,
        isWarmup: isWarmup,
        dateCreated: dateCreated,
        weightKg: weightKg ?? this.weightKg,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        reps: reps,
      );
}
