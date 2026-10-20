import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  final created = DateTime.utc(2026, 10, 12, 17, 30);
  Map<String, Object?> set([Map<String, Object?> extra = const {}]) => {
    'id': 's',
    'author_id': 'u',
    'index': 1,
    'isWarmup': false,
    'date_created': created,
    ...extra,
  };
  Map<String, Object?> exercise([Map<String, Object?> extra = const {}]) => {
    'id': 'e',
    'author_id': 'u',
    'template_id': 't',
    'name': 'Squat',
    'tracking_mode': 'weightReps',
    'index': 1,
    'sets': <Object?>[],
    ...extra,
  };

  group('readInt', () {
    test('reads a whole double as Swift does, and refuses a fraction', () {
      expect(readInt(3.0), 3);
      expect(() => readInt(2.5), throwsFormatException);
      expect(() => readInt(true), throwsFormatException);
      expect(() => readInt(null), throwsFormatException);
    });
  });

  group(WorkoutSetModel, () {
    test('reads side, kind and weight unit through the stored strings', () {
      final logged = WorkoutSetModel.fromFirestore(
        set({'side': 'right', 'kind': 'myo', 'weight_unit': 'pounds'}),
      );
      expect(logged.side, SetSide.right);
      expect(logged.kind, SetKind.myo);
      expect(logged.weightUnit, ExerciseWeightUnit.pounds);
    });

    test('reads an unknown side, kind or unit as absent or standard', () {
      final later = WorkoutSetModel.fromFirestore(
        set({'side': 'up', 'kind': 'superDrop', 'weight_unit': 'stone'}),
      );
      expect(later.side, isNull);
      expect(later.kind, SetKind.standard);
      expect(later.weightUnit, isNull);
      expect(WorkoutSetModel.fromFirestore(set()).kind, SetKind.standard);
    });

    test('is strict where Swift is strict', () {
      expect(
        () => WorkoutSetModel.fromFirestore(set({'side': 1})),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => WorkoutSetModel.fromFirestore(set({'reps': 2.5})),
        throwsFormatException,
      );
      expect(
        () => WorkoutSetModel.fromFirestore(set()..remove('isWarmup')),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group(WorkoutExerciseModel, () {
    test('rejects a tracking mode Swift does not know', () {
      expect(
        () => WorkoutExerciseModel.fromFirestore(
          exercise({'tracking_mode': 'velocity'}),
        ),
        throwsFormatException,
      );
    });

    test('fails on one unreadable set, as Swift does', () {
      expect(
        () => WorkoutExerciseModel.fromFirestore(
          exercise({
            'sets': [set()..remove('date_created')],
          }),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group(SetTarget, () {
    test('requires set_type to be present, though any value reads', () {
      expect(
        () => SetTarget.fromFirestore({'id': 't', 'set_number': 1}),
        throwsFormatException,
      );
    });
  });

  group(WorkoutSessionModel, () {
    test('requires is_rest_day and liked_by_user_ids, as Swift does', () {
      final session = {
        'id': 'w',
        'author_id': 'u',
        'name': 'Legs',
        'date_created': created,
        'date_modified': created,
        'exercises': <Object?>[],
        'is_rest_day': false,
        'liked_by_user_ids': <Object?>[],
      };
      expect(WorkoutSessionModel.fromFirestore(session).name, 'Legs');
      expect(
        () => WorkoutSessionModel.fromFirestore(
          {...session}..remove('is_rest_day'),
        ),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => WorkoutSessionModel.fromFirestore(
          {...session}..remove('liked_by_user_ids'),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  test('EquipmentRef rejects an unknown kind', () {
    expect(
      () => EquipmentRef.fromFirestore({'kind': 'hoverboard', 'id': 'x'}),
      throwsFormatException,
    );
  });
}
