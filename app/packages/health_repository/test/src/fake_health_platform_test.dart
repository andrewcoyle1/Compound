import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';

void main() {
  group(FakeHealthPlatform, () {
    final now = DateTime(2026, 10, 15, 12);

    test('the staging sample holds a fortnight of steps, a week of '
        'weigh-ins with body fat, two days of food and the onboarding '
        'values', () async {
      final sample = sampleHealthPlatform(now);
      final start = DateTime(2026);
      final end = DateTime(2026, 10, 16);

      final steps = await sample.dailySteps(start, end);
      expect(steps, hasLength(14));
      expect(steps[DateTime(2026, 10, 15)], 3200 + 4100);
      expect(await sample.weights(start, end), hasLength(7));
      expect(await sample.bodyFat(start, end), hasLength(7));
      final food = await sample.dailyNutrition(start, end);
      expect(food.keys, [DateTime(2026, 10, 14), DateTime(2026, 10, 13)]);
      expect(food[DateTime(2026, 10, 14)]![NutrientKey.calories], 2190);
      expect(await sample.latestWeightKilograms(), 81.4);
      expect(await sample.dateOfBirth(), DateTime(1994, 5, 17));
      expect(await sample.sex(), Gender.female);
      expect(await sample.latestHeightCentimeters(), 168);
      expect(await sample.isAvailable(), isTrue);
      expect(await sample.needsWorkoutAuthorization(), isFalse);
      expect(await sample.readableSince(start), start);
    });

    test('reads are bounded by the window', () async {
      final fake = FakeHealthPlatform(
        steps: [(date: now, steps: 10)],
        food: [
          (date: now, nutrients: {NutrientKey.calories: 100}),
          (date: now, nutrients: {NutrientKey.calories: 50}),
        ],
        weights: [HealthSample(uuid: 'w', value: 70, date: now)],
      );
      final after = now.add(const Duration(hours: 1));

      expect(await fake.dailySteps(after, after), isEmpty);
      expect(await fake.dailySteps(now, now), isEmpty);
      expect(await fake.dailyNutrition(after, after), isEmpty);
      expect(await fake.dailyNutrition(now, after), {
        DateTime(2026, 10, 15): {NutrientKey.calories: 150},
      });
      expect(await fake.weights(after, after), isEmpty);
    });

    test('what the app writes is recorded, not read back', () async {
      final fake = FakeHealthPlatform();
      expect(await fake.latestWeightKilograms(), isNull);

      final first = await fake.writeWeight(80, now);
      await fake.writeWeight(79, now.add(const Duration(days: 1)));

      expect(first, '00000000-0000-4000-8000-000000000001');
      expect(await fake.weights(DateTime(2026), DateTime(2027)), isEmpty);
      expect(await fake.latestWeightKilograms(), 79);
      expect(
        await fake.writeStrengthWorkout(start: now, end: now, title: 'Legs'),
        isTrue,
      );
      expect(fake.writtenWorkouts.single.title, 'Legs');
    });

    test('a set error fails every read and write', () async {
      final fake = FakeHealthPlatform()..error = Exception('denied');
      final calls = <Future<Object?> Function()>[
        () => fake.requestAuthorization(HealthScope.steps),
        () => fake.dailySteps(now, now),
        () => fake.dailyNutrition(now, now),
        () => fake.weights(now, now),
        () => fake.bodyFat(now, now),
        fake.dateOfBirth,
        fake.sex,
        fake.latestHeightCentimeters,
        fake.latestWeightKilograms,
        () => fake.writeWeight(80, now),
        () => fake.writeStrengthWorkout(start: now, end: now),
      ];
      for (final call in calls) {
        await expectLater(call(), throwsException);
      }
    });
  });
}
