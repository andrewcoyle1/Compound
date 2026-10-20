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

  // SetKeyboardPresenterTests' assistance cases.
  group('the sign key', () {
    SetKeypad assisted(
      WorkoutSetModel set, {
      SetField field = SetField.weight,
    }) => SetKeypad.open(
      exerciseId: 'e1',
      set: set,
      field: field,
      fields: SetField.of(set, TrackingMode.weightReps),
      unit: kg,
      isAssisted: true,
    );

    (SetKeypad, WorkoutSetModel) typeAll(
      String keys,
      SetKeypad keypad,
      WorkoutSetModel set,
    ) {
      var result = (keypad, set);
      for (final key in keys.split('')) {
        result = result.$1.type(key, result.$2, kg)!;
      }
      return result;
    }

    test('shows only for an assisted weight', () {
      final set = _set();
      expect(_open(set, SetField.weight).showsSignKey, isFalse);
      expect(assisted(set).showsSignKey, isTrue);
      expect(assisted(set, field: SetField.reps).showsSignKey, isFalse);
      // Moving on keeps knowing the exercise is assisted.
      final moved = assisted(set).moved(SetField.reps, set, kg);
      expect(moved.isAssisted, isTrue);
      expect(moved.showsSignKey, isFalse);
      expect(moved.moved(SetField.weight, set, kg).showsSignKey, isTrue);
    });

    test('types and flips assistance', () {
      var set = _set();
      var keypad = assisted(set);
      (keypad, set) = keypad.toggleSign(set, kg)!;
      expect(keypad.text, '-');
      expect(set.weightKg, isNull);
      (keypad, set) = typeAll('30', keypad, set);
      expect(set.weightKg, -30);

      (keypad, set) = keypad.toggleSign(set, kg)!;
      expect(set.weightKg, 30);
      (keypad, set) = keypad.toggleSign(set, kg)!;
      expect(set.weightKg, -30);
      expect(keypad.text, '-30');

      // The first key after a flip replaces the value, but assistance
      // stays assistance.
      (keypad, set) = typeAll('25', keypad, set);
      expect(set.weightKg, -25);
    });

    test('a sign started and pressed again is cancelled', () {
      var set = _set();
      var keypad = assisted(set);
      (keypad, set) = keypad.toggleSign(set, kg)!;
      (keypad, set) = keypad.toggleSign(set, kg)!;
      expect(keypad.text, isEmpty);
      // A point after the sign starts "-0.".
      (keypad, set) = keypad.toggleSign(set, kg)!;
      (keypad, set) = typeAll('.5', keypad, set);
      expect(keypad.text, '-0.5');
      expect(set.weightKg, -0.5);
    });

    test('a hardware minus flips only an assisted weight', () {
      final set = _set(weightKg: 20);
      expect(_open(set, SetField.weight).type('-', set, kg), isNull);
      final (_, flipped) = assisted(set).type('-', set, kg)!;
      expect(flipped.weightKg, -20);
      expect(_open(set, SetField.weight).toggleSign(set, kg), isNull);
    });

    test('four whole digits fit after the sign', () {
      var set = _set();
      var keypad = assisted(set);
      (keypad, set) = keypad.toggleSign(set, kg)!;
      (keypad, set) = typeAll('1234', keypad, set);
      expect(set.weightKg, -1234);
      expect(keypad.type('5', set, kg), isNull);
    });
  });

  // LoadingBarFollowsTheFieldTests: the weight the loading bar loads.
  group('the weight shown', () {
    test('follows typing and the stored weight', () {
      var set = _set(weightKg: 60);
      var keypad = _open(set, SetField.weight);
      expect(keypad.shownWeight(set, kg), 60);
      (keypad, set) = keypad.type('1', set, kg)!;
      (keypad, set) = keypad.type('0', set, kg)!;
      (keypad, set) = keypad.type('0', set, kg)!;
      expect(keypad.shownWeight(set, kg), 100);
      (keypad, set) = keypad.backspace(set, kg)!;
      (keypad, set) = keypad.backspace(set, kg)!;
      (keypad, set) = keypad.backspace(set, kg)!;
      expect(keypad.shownWeight(set, kg), isNull);
    });

    test('reads the stored weight where the field rounds it', () {
      const lb = ExerciseWeightUnit.pounds;
      // 224.092 lb, shown as "224.09".
      final set = _set(weightKg: 224.092 / 2.20462);
      final keypad = _open(set, SetField.weight, unit: lb);
      expect(keypad.text, '224.09');
      expect(keypad.shownWeight(set, lb), 224.092);
    });

    test("puts a machine's base back on", () {
      final set = _set(weightKg: 60, machineBaseKg: 20);
      final keypad = _open(set, SetField.weight);
      expect(keypad.text, '40');
      expect(keypad.shownWeight(set, kg), 60);
      final (typed, typedSet) = keypad.type('5', set, kg)!;
      expect(typed.shownWeight(typedSet, kg), 25);
    });

    test('another field reads the stored weight', () {
      final set = _set(weightKg: 60, reps: 8);
      expect(_open(set, SetField.reps).shownWeight(set, kg), 60);
      expect(
        _open(_set(reps: 8), SetField.reps).shownWeight(_set(), kg),
        isNull,
      );
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
