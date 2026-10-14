import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

Map<String, Object?> _fixture(String model, String name) =>
    taggedJsonToFirestore(
      jsonDecode(
        File('../../../contracts/firestore/$model/$name.json')
            .readAsStringSync(),
      ) as Map<String, Object?>,
    );

void main() {
  group('OverarchingObjective', () {
    test('is written as a keyed map, never a string', () {
      expect(OverarchingObjective.loseWeight.toFirestore(), {
        'loseWeight': <String, Object?>{},
      });
    });

    test('rejects a plain string, as Swift does', () {
      expect(
        () => OverarchingObjective.fromFirestore('loseWeight'),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects no known case, or two', () {
      expect(
        () => OverarchingObjective.fromFirestore({
          'recomposition': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () => OverarchingObjective.fromFirestore({
          'loseWeight': <String, Object?>{},
          'maintain': <String, Object?>{},
        }),
        throwsFormatException,
      );
    });

    test("rejects a case whose value isn't a map", () {
      expect(
        () => OverarchingObjective.fromFirestore({'maintain': true}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => OverarchingObjective.fromFirestore({'maintain': null}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('WeightGoal', () {
    test('takes its id from user_id when goal_id is missing', () {
      final goal = WeightGoal.fromFirestore(
        _fixture('weight_goal', 'legacy-no-goal-id'),
      );
      expect(goal.goalId, 'user_legacy');
      expect(goal.objective, OverarchingObjective.loseWeight);
    });

    test('requires a known status', () {
      final goal = _fixture('weight_goal', 'full')..['status'] = 'archived';
      expect(() => WeightGoal.fromFirestore(goal), throwsFormatException);
    });

    test('requires the starting weight', () {
      final goal = _fixture('weight_goal', 'full')
        ..remove('starting_weight_kg');
      expect(() => WeightGoal.fromFirestore(goal), throwsA(isA<TypeError>()));
    });
  });

  group('BodyMeasurementEntry', () {
    test('rejects a healthkit_uuid that is not a UUID, as Swift does', () {
      final entry = _fixture('body_measurement', 'full')
        ..['healthkit_uuid'] = 'not-a-uuid';
      expect(
        () => BodyMeasurementEntry.fromFirestore(entry),
        throwsFormatException,
      );
    });

    test('requires a known source', () {
      final entry = _fixture('body_measurement', 'minimal')
        ..['source'] = 'scale';
      expect(
        () => BodyMeasurementEntry.fromFirestore(entry),
        throwsFormatException,
      );
    });
  });

  group('StepsModel', () {
    test('rejects a fractional step count', () {
      final steps = _fixture('steps', 'minimal')..['number'] = 10.5;
      expect(() => StepsModel.fromFirestore(steps), throwsFormatException);
    });
  });

  group('AnalyticsSettings', () {
    test("defaults the step goal to Swift's 8,000", () {
      expect(const AnalyticsSettings(authorId: 'me').stepGoal, 8000);
      expect(
        const AnalyticsSettings(authorId: 'me', dailyStepGoal: 12000).stepGoal,
        12000,
      );
    });

    test('requires hidden_section_ids, as Swift does', () {
      final settings = _fixture('analytics_settings', 'minimal')
        ..remove('hidden_section_ids');
      expect(
        () => AnalyticsSettings.fromFirestore(settings),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
