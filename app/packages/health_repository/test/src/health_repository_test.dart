import 'dart:async';

import 'package:body_repository/body_repository.dart';
import 'package:compound_models/compound_models.dart' show WorkoutExerciseModel;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

// The pure parts of StepsManagerTests, BodyMeasurementsManagerTests'
// Apple Health section, MealLogHealthKitImportTests and HealthKitManagerTests,
// run against the in-memory repositories and a FakeHealthPlatform.
void main() {
  const uid = 'me';
  final now = DateTime(2026, 10, 15, 12);
  final today = DateTime(2026, 10, 15);
  final yesterday = DateTime(2026, 10, 14);
  DateTime at(DateTime day, num hour) =>
      day.add(Duration(minutes: (hour * 60).round()));

  late FakeHealthPlatform health;
  late InMemoryBodyRepository body;
  late InMemoryNutritionRepository nutrition;
  late List<Object> errors;
  late HealthRepository subject;

  HealthRepository build() => HealthRepository(
    platform: health,
    body: body,
    nutrition: nutrition,
    now: () => now,
    onError: (error, _) => errors.add(error),
  );

  setUp(() {
    health = FakeHealthPlatform();
    body = InMemoryBodyRepository();
    nutrition = InMemoryNutritionRepository();
    errors = [];
    subject = build();
  });

  group('access', () {
    test('isAvailable reflects the platform, and a failure is false', () async {
      expect(await subject.isAvailable(), isTrue);
      health.available = false;
      expect(await subject.isAvailable(), isFalse);
      expect(
        await HealthRepository(
          platform: _ThrowingPlatform(),
          body: body,
          nutrition: nutrition,
        ).isAvailable(),
        isFalse,
      );
    });

    test('requestAuthorization asks only when Health is available', () async {
      expect(await subject.requestAuthorization(HealthScope.steps), isTrue);
      health.available = false;
      expect(await subject.requestAuthorization(HealthScope.steps), isFalse);
      expect(health.requested, [HealthScope.steps]);
    });

    test('a failed request is false and reported', () async {
      health.error = Exception('refused');
      expect(await subject.requestAuthorization(HealthScope.steps), isFalse);
      expect(errors, hasLength(1));
    });

    test('needsWorkoutAuthorization reflects the platform, false when '
        'Health is unavailable', () async {
      expect(await subject.needsWorkoutAuthorization(), isFalse);
      health.granted = false;
      expect(await subject.needsWorkoutAuthorization(), isTrue);
      health.available = false;
      expect(await subject.needsWorkoutAuthorization(), isFalse);
    });
  });

  group('onboarding reads', () {
    test('each returns what Health holds, asking for its own scope', () async {
      health
        ..birthDate = DateTime(1990)
        ..biologicalSex = Gender.female
        ..heightCentimeters = 170
        ..weightSamples.add(
          HealthSample(uuid: 'x', value: 65, date: yesterday),
        );

      expect(await subject.readDateOfBirth(), DateTime(1990));
      expect(await subject.readSex(), Gender.female);
      expect(await subject.readLatestHeightCentimeters(), 170);
      expect(await subject.readLatestWeightKilograms(), 65);
      expect(health.requested, [
        HealthScope.dateOfBirth,
        HealthScope.sex,
        HealthScope.height,
        HealthScope.weight,
      ]);
    });

    test('return nothing when access cannot be requested or fails', () async {
      health
        ..heightCentimeters = 170
        ..granted = false;
      expect(await subject.readLatestHeightCentimeters(), isNull);

      health
        ..granted = true
        ..available = false;
      expect(await subject.readSex(), isNull);

      health.available = true;
      final failing = _FailingReads()..heightCentimeters = 170;
      expect(
        await HealthRepository(
          platform: failing,
          body: body,
          nutrition: nutrition,
          onError: (error, _) => errors.add(error),
        ).readLatestHeightCentimeters(),
        isNull,
      );
      expect(errors, hasLength(1));
    });
  });

  group('importSteps', () {
    FakeSteps walk(int steps, DateTime day, [num hour = 9]) =>
        (date: at(day, hour), steps: steps);
    Future<List<StepsModel>> history() => body.watchSteps(uid).first;
    Future<int?> total(DateTime day) async => [
      for (final entry in await history())
        if (entry.date == day) entry.number,
    ].firstOrNull;

    test('imports one total per day', () async {
      health.steps.addAll([
        walk(3000, yesterday),
        walk(3000, yesterday, 18),
        walk(8000, today),
      ]);

      await subject.importSteps(uid);

      final steps = await history();
      expect(steps, hasLength(2));
      expect(await total(yesterday), 6000);
      expect(await total(today), 8000);
      expect(steps.every((s) => s.source == StepsSource.healthkit), isTrue);
      expect(steps.map((s) => s.id), [
        'healthkit-steps-${yesterday.millisecondsSinceEpoch ~/ 1000}',
        'healthkit-steps-${today.millisecondsSinceEpoch ~/ 1000}',
      ]);
    });

    test('more steps in Health update the day', () async {
      health.steps.add(walk(2000, today));
      await subject.importSteps(uid);

      health.steps.add(walk(1500, today, 15));
      await subject.importSteps(uid);

      expect(await total(today), 3500);
      final entry = (await history()).single;
      expect(entry.dateModified, now);
    });

    test('steps synced late for an earlier day are imported', () async {
      health.steps.add(walk(8000, today));
      await subject.importSteps(uid);

      health.steps.add(walk(4000, yesterday));
      await subject.importSteps(uid);

      expect(await total(yesterday), 4000);
    });

    test('deleting in Health recounts the day, to zero', () async {
      final removed = walk(1000, today, 15);
      health.steps.addAll([walk(5000, today), removed, walk(4000, yesterday)]);
      await subject.importSteps(uid);
      expect(await total(today), 6000);

      health.steps.remove(removed);
      await subject.importSteps(uid);
      expect(await total(today), 5000);

      health.steps.removeWhere((s) => s.date.day == today.day);
      await subject.importSteps(uid);
      expect(await total(today), 0);
    });

    test('steps before the import start are left out', () async {
      health.steps.addAll([walk(3000, yesterday), walk(9000, today)]);

      await subject.importSteps(uid, since: at(today, 10));

      expect((await history()).single.number, 9000);
    });

    test('a year back when no start is given', () async {
      health.steps.addAll([
        walk(3000, DateTime(2025, 10, 14)),
        walk(4000, DateTime(2025, 10, 15)),
      ]);

      await subject.importSteps(uid);

      expect((await history()).single.number, 4000);
    });

    test('a higher count entered here wins the day', () async {
      await body.saveSteps(
        StepsModel(
          id: 'typed',
          authorId: uid,
          number: 10000,
          date: today,
          source: StepsSource.manual,
          dateCreated: now,
          dateModified: now,
        ),
      );
      health.steps.add(walk(7000, today));

      await subject.importSteps(uid);

      expect((await history()).single.id, 'typed');
    });

    test('a failing read imports nothing, and is reported', () async {
      health
        ..steps.add(walk(6000, today))
        ..error = Exception('unavailable');

      await subject.importSteps(uid);

      expect(await history(), isEmpty);
      expect(errors, hasLength(1));
    });

    test(
      'nothing read writes nothing, so revoked access keeps the history',
      () async {
        health.steps.add(walk(6000, today));
        await subject.importSteps(uid);

        health.steps.clear();
        await subject.importSteps(uid);

        expect(await total(today), 6000);
      },
    );

    test('a run asked for during a run follows it, once', () async {
      final gate = _GatedPlatform(health);
      subject = HealthRepository(
        platform: gate,
        body: body,
        nutrition: nutrition,
        now: () => now,
      );
      health.steps.add(walk(8000, today));

      final first = subject.importSteps(uid);
      await pumpEventQueue();
      health.steps.add(walk(1000, today, 15));
      await subject.importSteps(uid);
      await subject.importSteps(uid);
      gate.open();
      await first;

      expect(gate.stepReads, 2);
      expect(await total(today), 9000);
    });
  });

  group('importBodyMeasurements', () {
    final day = DateTime(2026, 10, 10);
    final nextDay = DateTime(2026, 10, 11);
    var uuids = 0;
    HealthSample weighIn(double kg, num hour) => HealthSample(
      uuid: 'C0000000-0000-4000-8000-${(++uuids).toString().padLeft(12, '0')}',
      value: kg,
      date: at(day, hour),
    );
    Future<List<BodyMeasurementEntry>> entries() =>
        body.watchMeasurements(uid).first;

    test("one entry per day, at its lowest weigh-in, carrying that day's "
        'latest body fat', () async {
      final lowest = weighIn(72.5, 20);
      health
        ..weightSamples.addAll([weighIn(72.8, 8), lowest, weighIn(72.1, 32)])
        ..bodyFatSamples.addAll([
          HealthSample(uuid: 'f1', value: 17.9, date: at(day, 6)),
          HealthSample(uuid: 'f2', value: 18.2, date: at(day, 8)),
        ]);

      await subject.importBodyMeasurements(uid);

      final imported = await entries();
      expect(imported.map((e) => e.weightKg), [72.5, 72.1]);
      final first = imported.first;
      expect(first.bodyFatPercentage, 18.2);
      expect(first.healthKitUuid, lowest.uuid);
      expect(first.date, lowest.date);
      expect(first.id, 'healthkit-$uid-${day.millisecondsSinceEpoch ~/ 1000}');
      expect(imported.every((e) => e.source == WeightSource.healthkit), true);
      expect(imported.last.bodyFatPercentage, isNull);
    });

    test('a lower reading in Health updates the day', () async {
      health.weightSamples.add(weighIn(72.8, 8));
      await subject.importBodyMeasurements(uid);

      health.weightSamples.add(weighIn(72.4, 20));
      await subject.importBodyMeasurements(uid);

      expect((await entries()).single.weightKg, 72.4);
    });

    test('deleting in Health clears the weight and keeps the entry', () async {
      final sample = weighIn(72.8, 8);
      health.weightSamples.addAll([sample, weighIn(70, 40)]);
      await subject.importBodyMeasurements(uid);
      final id = (await entries()).first.id;
      await body.saveMeasurement(
        BodyMeasurementEntry(
          id: id,
          authorId: uid,
          date: sample.date,
          source: WeightSource.healthkit,
          dateCreated: sample.date,
          waistCircumference: 80,
        ),
      );

      health.weightSamples.remove(sample);
      await subject.importBodyMeasurements(uid);

      final cleared = (await entries()).first;
      expect(
        (cleared.id, cleared.weightKg, cleared.healthKitUuid),
        (id, null, null),
      );
      expect(cleared.waistCircumference, 80);
    });

    test('a lower weigh-in logged here wins the day', () async {
      await body.saveMeasurement(
        BodyMeasurementEntry(
          id: 'manual',
          authorId: uid,
          weightKg: 72,
          date: day,
          source: WeightSource.manual,
          dateCreated: day,
        ),
      );
      health.weightSamples.addAll([weighIn(72.8, 8), weighIn(72.6, 20)]);

      await subject.importBodyMeasurements(uid);

      expect((await entries()).single.id, 'manual');
    });

    test('a weight cleared here does not come back while Health holds the '
        'same reading', () async {
      health.weightSamples.add(weighIn(72.8, 8));
      await subject.importBodyMeasurements(uid);
      final id = (await entries()).single.id;
      await body.clearMeasurementFields(uid, id, {'weight_kg'});

      await subject.importBodyMeasurements(uid);

      expect((await entries()).single.weightKg, isNull);
    });

    test('body fat changing alone updates the day', () async {
      health.weightSamples.add(weighIn(72.8, 8));
      await subject.importBodyMeasurements(uid);

      health.bodyFatSamples.add(
        HealthSample(uuid: 'f', value: 19, date: at(day, 9)),
      );
      await subject.importBodyMeasurements(uid);

      expect((await entries()).single.bodyFatPercentage, 19);
    });

    test(
      'nothing read writes nothing, so revoked access keeps the weights',
      () async {
        health.weightSamples.add(weighIn(72.8, 8));
        await subject.importBodyMeasurements(uid);

        health.weightSamples.clear();
        await subject.importBodyMeasurements(uid);

        expect((await entries()).single.weightKg, 72.8);
      },
    );

    test('an entry before since is left alone', () async {
      health.weightSamples.add(weighIn(72.8, 8));
      await subject.importBodyMeasurements(uid);

      health.weightSamples
        ..clear()
        ..add(
          HealthSample(
            uuid: 'D0000000-0000-4000-8000-000000000001',
            value: 71,
            date: at(nextDay, 8),
          ),
        );
      await subject.importBodyMeasurements(uid, since: nextDay);

      expect((await entries()).map((e) => e.weightKg), [72.8, 71]);
    });
  });

  group('importNutrition', () {
    FakeFood food(double calories, DateTime day, {double protein = 0}) => (
      date: at(day, 12),
      nutrients: {NutrientKey.calories: calories, NutrientKey.protein: protein},
    );
    Future<List<MealLogModel>> meals() => nutrition.watchMeals(uid).first;
    Future<double?> calories(DateTime day) async {
      final dayMeals = [
        for (final meal in await meals())
          if (meal.dayKey ==
              '${day.year}-${day.month}-${day.day}'.replaceAllMapped(
                RegExp(r'-(\d)\b'),
                (m) => '-0${m[1]}',
              ))
            meal,
      ];
      if (dayMeals.isEmpty) return null;
      return dayMeals.fold<double>(
        0,
        (sum, meal) =>
            sum +
            meal.items.fold(
              0,
              (s, item) =>
                  s + (item.nutrients.values[NutrientKey.calories] ?? 0),
            ),
      );
    }

    test('imports one total per day', () async {
      health.food.addAll([
        food(500, yesterday, protein: 30),
        food(700, yesterday, protein: 40),
        food(400, today),
      ]);

      await subject.importNutrition(uid);

      final imported = await meals();
      expect(imported, hasLength(2));
      expect(await calories(yesterday), 1200);
      expect(await calories(today), 400);
      expect(imported.every((m) => m.isHealthKitImport), isTrue);
      final item = imported.first.items.single;
      expect(item.nutrients.values[NutrientKey.protein], 70);
      expect(
        (item.displayName, item.sourceType, item.amount, item.unit),
        ('Apple Health', MealItemSourceType.quickAdd, 1, 'serving'),
      );
      expect(imported.first.mealId, 'healthkit-nutrition-2026-10-14');
      expect(imported.first.date, yesterday);
    });

    test('more food in Health updates the day', () async {
      health.food.add(food(400, today));
      await subject.importNutrition(uid);

      health.food.add(food(600, today));
      await subject.importNutrition(uid);

      expect(await calories(today), 1000);
      expect(await meals(), hasLength(1));
    });

    test('food deleted from Health leaves the day', () async {
      final lunch = food(400, today);
      health.food.addAll([lunch, food(300, yesterday)]);
      await subject.importNutrition(uid);

      health.food.remove(lunch);
      await subject.importNutrition(uid);

      expect(await calories(today), isNull);
      expect(await calories(yesterday), 300);
    });

    test("a meal logged here hides the day's Health total, which is kept "
        'current behind it', () async {
      health.food.add(food(900, today));
      await subject.importNutrition(uid);
      final logged = MealLogModel(
        mealId: 'logged',
        authorId: uid,
        dayKey: '2026-10-15',
        date: now,
        items: const [
          MealItemModel(
            itemId: 'i',
            sourceType: MealItemSourceType.quickAdd,
            sourceId: 'i',
            displayName: 'Toast',
            amount: 1,
            unit: 'serving',
            nutrients: NutrientMap({NutrientKey.calories: 250}),
          ),
        ],
      );
      await nutrition.saveMeal(logged);
      expect((await meals()).map((m) => m.mealId), ['logged']);

      health.food.add(food(100, today));
      await subject.importNutrition(uid);
      await nutrition.deleteMeal(uid, 'logged');

      expect(await calories(today), 1000);
    });

    test('an unchanged day is not written again', () async {
      health.food.add(food(400, today));
      await subject.importNutrition(uid);
      final changes = <int>[];
      final subscription = nutrition
          .watchMeals(uid)
          .listen((m) => changes.add(m.length));

      await subject.importNutrition(uid);
      await subscription.cancel();

      expect(changes, [1]);
    });
  });

  group('saveMeasurement', () {
    BodyMeasurementEntry logged({double? weightKg = 80, String? uuid}) =>
        BodyMeasurementEntry(
          id: 'e',
          authorId: uid,
          weightKg: weightKg,
          date: now,
          source: WeightSource.manual,
          dateCreated: now,
          healthKitUuid: uuid,
        );
    Future<BodyMeasurementEntry> saved() async =>
        (await body.watchMeasurements(uid).first).single;

    test('sends a weigh-in to Health first and saves its id', () async {
      await subject.saveMeasurement(logged());

      expect(health.requested, [HealthScope.bodyMeasurements]);
      expect(health.writtenWeights.single.value, 80);
      expect((await saved()).healthKitUuid, health.writtenWeights.single.uuid);
    });

    test('never sends one twice, nor an entry without weight', () async {
      await subject.saveMeasurement(
        logged(uuid: 'E0000000-0000-4000-8000-000000000001'),
      );
      await subject.saveMeasurement(logged(weightKg: null));

      expect(health.writtenWeights, isEmpty);
      expect(health.requested, isEmpty);
    });

    test('saves anyway when Health refuses or fails', () async {
      health.granted = false;
      await subject.saveMeasurement(logged());
      expect((await saved()).healthKitUuid, isNull);

      final failing = _FailingWrites();
      await HealthRepository(
        platform: failing,
        body: body,
        nutrition: nutrition,
        onError: (error, _) => errors.add(error),
      ).saveMeasurement(logged());
      expect((await saved()).healthKitUuid, isNull);
      expect(errors, hasLength(1));
    });

    test('an id that is not a UUID is not stored', () async {
      await HealthRepository(
        platform: _OddIds(),
        body: body,
        nutrition: nutrition,
      ).saveMeasurement(logged());

      expect((await saved()).healthKitUuid, isNull);
    });
  });

  group('exportWorkout', () {
    WorkoutSessionModel session({DateTime? endedAt}) => WorkoutSessionModel(
      id: 's',
      authorId: uid,
      name: 'Push',
      dateCreated: DateTime(2026, 10, 15, 7),
      dateModified: now,
      exercises: const <WorkoutExerciseModel>[],
      endedAt: endedAt,
    );

    test('saves a finished session as a strength workout', () async {
      expect(
        await subject.exportWorkout(
          session(endedAt: DateTime(2026, 10, 15, 8)),
        ),
        isTrue,
      );
      expect(health.writtenWorkouts.single, (
        start: DateTime(2026, 10, 15, 7),
        end: DateTime(2026, 10, 15, 8),
        title: 'Push',
      ));
    });

    test('skips one still running, and a failure is false', () async {
      expect(await subject.exportWorkout(session()), isFalse);
      health.error = Exception('denied');
      expect(await subject.exportWorkout(session(endedAt: now)), isFalse);
      expect(health.writtenWorkouts, isEmpty);
    });
  });

  test('logs a failure when no reporter is given', () async {
    health.error = Exception('unavailable');
    await HealthRepository(
      platform: health,
      body: body,
      nutrition: nutrition,
    ).importSteps(uid);
  });
}

class _ThrowingPlatform extends FakeHealthPlatform {
  @override
  Future<bool> isAvailable() => Future.error(Exception('no store'));
}

class _FailingReads extends FakeHealthPlatform {
  @override
  Future<double?> latestHeightCentimeters() =>
      Future.error(Exception('read failed'));
}

class _FailingWrites extends FakeHealthPlatform {
  @override
  Future<String?> writeWeight(double kilograms, DateTime date) =>
      Future.error(Exception('write failed'));
}

class _OddIds extends FakeHealthPlatform {
  @override
  Future<String?> writeWeight(double kilograms, DateTime date) async =>
      'not-a-uuid';
}

/// Holds the first steps read until [open], counting the reads.
class _GatedPlatform extends FakeHealthPlatform {
  new(this._inner);

  final FakeHealthPlatform _inner;
  final _gate = Completer<void>();
  int stepReads = 0;

  void open() => _gate.complete();

  @override
  Future<Map<DateTime, int>> dailySteps(DateTime start, DateTime end) async {
    stepReads++;
    await _gate.future;
    return await _inner.dailySteps(start, end);
  }
}
