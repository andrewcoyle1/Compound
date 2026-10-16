import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_repository/health_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockHealth extends Mock implements Health;

const _own = 'com.andrewcoyle.compound.dev';

HealthDataPoint _point(
  HealthDataType type,
  HealthValue value,
  DateTime from, {
  DateTime? to,
  String uuid = 'a1b2c3d4-0000-4000-8000-000000000001',
  String source = 'com.withings.wiScaleNG',
}) => HealthDataPoint(
  uuid: uuid,
  value: value,
  type: type,
  unit: HealthDataUnit.NO_UNIT,
  dateFrom: from,
  dateTo: to ?? from,
  sourcePlatform: HealthPlatformType.appleHealth,
  sourceDeviceId: 'device',
  sourceId: source,
  sourceName: source,
);

NumericHealthValue _n(num value) => NumericHealthValue(numericValue: value);

void main() {
  late _MockHealth health;
  final now = DateTime(2026, 10, 15, 12);

  HealthPackagePlatform platform(TargetPlatform target) =>
      HealthPackagePlatform(
        ownSourceId: _own,
        health: health,
        platform: target,
        now: () => now,
      );

  void stubPoints(HealthDataType type, List<HealthDataPoint> points) => when(
    () => health.getHealthDataFromTypes(
      types: [type],
      startTime: any(named: 'startTime'),
      endTime: any(named: 'endTime'),
    ),
  ).thenAnswer((_) async => points);

  setUpAll(() {
    registerFallbackValue(DateTime(2000));
    registerFallbackValue(HealthDataType.STEPS);
    registerFallbackValue(HealthWorkoutActivityType.OTHER);
  });

  setUp(() => health = _MockHealth());

  test('defaults to the running platform and a real Health', () {
    expect(HealthPackagePlatform(ownSourceId: _own), isNotNull);
  });

  test('isAvailable asks whether Health Connect is usable', () async {
    when(() => health.isHealthConnectAvailable()).thenAnswer((_) async => true);
    expect(await platform(TargetPlatform.android).isAvailable(), isTrue);
  });

  group('requestAuthorization', () {
    setUp(() {
      when(
        () => health.requestAuthorization(
          any(),
          permissions: any(named: 'permissions'),
        ),
      ).thenAnswer((_) async => true);
      when(() => health.isHealthDataHistoryAvailable())
          .thenAnswer((_) async => true);
      when(() => health.requestHealthDataHistoryAuthorization())
          .thenAnswer((_) async => true);
    });

    test("asks for the scope's types and access", () async {
      expect(
        await platform(TargetPlatform.iOS)
            .requestAuthorization(HealthScope.bodyMeasurements),
        isTrue,
      );
      verify(
        () => health.requestAuthorization(
          [HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE],
          permissions: [HealthDataAccess.READ_WRITE, HealthDataAccess.READ],
        ),
      ).called(1);
      verifyNever(() => health.requestHealthDataHistoryAuthorization());
    });

    test('on Health Connect, also asks for history for an import', () async {
      final android = platform(TargetPlatform.android);
      await android.requestAuthorization(HealthScope.steps);
      await android.requestAuthorization(HealthScope.height);
      verify(() => health.requestHealthDataHistoryAuthorization()).called(1);
    });

    test('a scope with nothing to ask for is refused without asking', () async {
      expect(
        await platform(TargetPlatform.android)
            .requestAuthorization(HealthScope.sex),
        isFalse,
      );
      verifyNever(
        () => health.requestAuthorization(
          any(),
          permissions: any(named: 'permissions'),
        ),
      );
    });
  });

  test('needsWorkoutAuthorization is true unless writing is granted', () async {
    final answers = [true, false, null];
    when(
      () => health.hasPermissions(
        [HealthDataType.WORKOUT],
        permissions: [HealthDataAccess.WRITE],
      ),
    ).thenAnswer((_) async => answers.removeAt(0));
    final ios = platform(TargetPlatform.iOS);
    expect(await ios.needsWorkoutAuthorization(), isFalse);
    expect(await ios.needsWorkoutAuthorization(), isTrue);
    expect(await ios.needsWorkoutAuthorization(), isTrue);
  });

  group('readableSince', () {
    final longAgo = DateTime(2020);

    test('HealthKit reads everything', () async {
      expect(
        await platform(TargetPlatform.iOS).readableSince(longAgo),
        longAgo,
      );
    });

    test('Health Connect without history reads 30 days back', () async {
      when(() => health.isHealthDataHistoryAuthorized())
          .thenAnswer((_) async => false);
      final android = platform(TargetPlatform.android);
      expect(await android.readableSince(longAgo), DateTime(2026, 9, 15));
      expect(
        await android.readableSince(DateTime(2026, 10)),
        DateTime(2026, 10),
      );
    });

    test('Health Connect with history reads everything', () async {
      when(() => health.isHealthDataHistoryAuthorized())
          .thenAnswer((_) async => true);
      expect(
        await platform(TargetPlatform.android).readableSince(longAgo),
        longAgo,
      );
    });
  });

  group('dailySteps', () {
    test('one total per day, leaving out empty days', () async {
      when(() => health.getTotalStepsInInterval(any(), any()))
          .thenAnswer((call) async {
            final day = call.positionalArguments.first as DateTime;
            return day.day == 14 ? 0 : day.day * 100;
          });

      final totals = await platform(TargetPlatform.iOS)
          .dailySteps(DateTime(2026, 10, 13, 8), DateTime(2026, 10, 16));

      expect(totals, {
        DateTime(2026, 10, 13): 1300,
        DateTime(2026, 10, 15): 1500,
      });
      verify(
        () => health.getTotalStepsInInterval(
          DateTime(2026, 10, 13),
          DateTime(2026, 10, 14),
        ),
      ).called(1);
    });

    test('throws when a total cannot be read', () async {
      when(() => health.getTotalStepsInInterval(any(), any()))
          .thenAnswer((_) async => null);
      await expectLater(
        platform(TargetPlatform.iOS).dailySteps(now, DateTime(2026, 10, 16)),
        throwsStateError,
      );
    });
  });

  group('dailyNutrition', () {
    test('HealthKit: sums each dietary type per day', () async {
      when(
        () => health.getHealthDataFromTypes(
          types: [
            HealthDataType.DIETARY_ENERGY_CONSUMED,
            HealthDataType.DIETARY_PROTEIN_CONSUMED,
            HealthDataType.DIETARY_CARBS_CONSUMED,
            HealthDataType.DIETARY_FATS_CONSUMED,
          ],
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          _point(HealthDataType.DIETARY_ENERGY_CONSUMED, _n(500), now),
          _point(HealthDataType.DIETARY_ENERGY_CONSUMED, _n(300), now),
          _point(HealthDataType.DIETARY_PROTEIN_CONSUMED, _n(30), now),
          _point(HealthDataType.DIETARY_CARBS_CONSUMED, _n(60), now),
          _point(
            HealthDataType.DIETARY_FATS_CONSUMED,
            _n(20),
            DateTime(2026, 10, 14, 20),
          ),
          // A type outside the four is ignored.
          _point(HealthDataType.WATER, _n(1), now),
        ],
      );

      expect(await platform(TargetPlatform.iOS).dailyNutrition(now, now), {
        DateTime(2026, 10, 15): {
          NutrientKey.calories: 800,
          NutrientKey.protein: 30,
          NutrientKey.carbs: 60,
        },
        DateTime(2026, 10, 14): {NutrientKey.fatTotal: 20},
      });
    });

    test('Health Connect: sums the four fields of each record', () async {
      stubPoints(HealthDataType.NUTRITION, [
        _point(
          HealthDataType.NUTRITION,
          NutritionHealthValue(calories: 500, protein: 30, carbs: 50, fat: 10),
          now,
        ),
        _point(
          HealthDataType.NUTRITION,
          NutritionHealthValue(calories: 200),
          now,
        ),
      ]);

      expect(await platform(TargetPlatform.android).dailyNutrition(now, now), {
        DateTime(2026, 10, 15): {
          NutrientKey.calories: 700,
          NutrientKey.protein: 30,
          NutrientKey.carbs: 50,
          NutrientKey.fatTotal: 10,
        },
      });
    });
  });

  group('weights and bodyFat', () {
    test("leave out this app's own samples, ids upper case", () async {
      stubPoints(HealthDataType.WEIGHT, [
        _point(HealthDataType.WEIGHT, _n(72.5), now),
        _point(HealthDataType.WEIGHT, _n(70), now, source: _own),
        // Not a number: skipped.
        _point(HealthDataType.WEIGHT, NutritionHealthValue(), now),
      ]);

      final samples = await platform(TargetPlatform.iOS).weights(now, now);

      expect(samples.single.uuid, 'A1B2C3D4-0000-4000-8000-000000000001');
      expect((samples.single.value, samples.single.date), (72.5, now));
    });

    test('body fat is a percentage on both platforms', () async {
      stubPoints(HealthDataType.BODY_FAT_PERCENTAGE, [
        _point(HealthDataType.BODY_FAT_PERCENTAGE, _n(0.182), now),
      ]);
      final ios = await platform(TargetPlatform.iOS).bodyFat(now, now);
      expect(ios.single.value, closeTo(18.2, 1e-9));

      stubPoints(HealthDataType.BODY_FAT_PERCENTAGE, [
        _point(HealthDataType.BODY_FAT_PERCENTAGE, _n(18.2), now),
      ]);
      final android = await platform(TargetPlatform.android).bodyFat(now, now);
      expect(android.single.value, 18.2);
    });
  });

  group('characteristics', () {
    test('date of birth: seconds since 1970, 0 or nothing is null', () async {
      final birth = DateTime(1990, 5, 17);
      final answers = [
        [
          _point(
            HealthDataType.BIRTH_DATE,
            _n(birth.millisecondsSinceEpoch / 1000),
            now,
          ),
        ],
        [_point(HealthDataType.BIRTH_DATE, _n(0), now)],
        <HealthDataPoint>[],
      ];
      when(
        () => health.getHealthDataFromTypes(
          types: [HealthDataType.BIRTH_DATE],
          startTime: now,
          endTime: now,
        ),
      ).thenAnswer((_) async => answers.removeAt(0));
      final ios = platform(TargetPlatform.iOS);

      expect(await ios.dateOfBirth(), birth);
      expect(await ios.dateOfBirth(), isNull);
      expect(await ios.dateOfBirth(), isNull);
    });

    test('sex: female and male only', () async {
      final answers = [1, 2, 3, 0];
      when(
        () => health.getHealthDataFromTypes(
          types: [HealthDataType.GENDER],
          startTime: now,
          endTime: now,
        ),
      ).thenAnswer(
        (_) async => [
          _point(HealthDataType.GENDER, _n(answers.removeAt(0)), now),
        ],
      );
      final ios = platform(TargetPlatform.iOS);

      expect(await ios.sex(), Gender.female);
      expect(await ios.sex(), Gender.male);
      expect(await ios.sex(), isNull);
      expect(await ios.sex(), isNull);
    });

    test('Health Connect holds neither', () async {
      final android = platform(TargetPlatform.android);
      expect(await android.dateOfBirth(), isNull);
      expect(await android.sex(), isNull);
      verifyNever(
        () => health.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      );
    });
  });

  group('latest values', () {
    test('the sample that ended last, from any source', () async {
      stubPoints(HealthDataType.HEIGHT, [
        _point(HealthDataType.HEIGHT, _n(1.80), DateTime(2026, 10, 2)),
        _point(HealthDataType.HEIGHT, _n(1.82), DateTime(2026, 10, 9)),
        _point(HealthDataType.HEIGHT, _n(1.81), DateTime(2026, 10, 5)),
      ]);
      stubPoints(HealthDataType.WEIGHT, [
        _point(HealthDataType.WEIGHT, _n(81.6), now, source: _own),
      ]);
      final ios = platform(TargetPlatform.iOS);

      expect(await ios.latestHeightCentimeters(), closeTo(182, 1e-9));
      expect(await ios.latestWeightKilograms(), 81.6);
    });

    test('null when Health holds none', () async {
      stubPoints(HealthDataType.HEIGHT, []);
      expect(
        await platform(TargetPlatform.iOS).latestHeightCentimeters(),
        isNull,
      );
    });
  });

  group('writes', () {
    test('a weigh-in in kilograms, its id upper case', () async {
      final answers = ['a1b2c3d4-0000-4000-8000-000000000001', 'null', null];
      when(
        () => health.writeHealthDataUUID(
          value: 80,
          unit: HealthDataUnit.KILOGRAM,
          type: HealthDataType.WEIGHT,
          startTime: now,
        ),
      ).thenAnswer((_) async => answers.removeAt(0));
      final ios = platform(TargetPlatform.iOS);

      expect(
        await ios.writeWeight(80, now),
        'A1B2C3D4-0000-4000-8000-000000000001',
      );
      expect(await ios.writeWeight(80, now), isNull);
      expect(await ios.writeWeight(80, now), isNull);
    });

    test("a strength workout, of each platform's type", () async {
      when(
        () => health.writeWorkoutData(
          activityType: any(named: 'activityType'),
          start: any(named: 'start'),
          end: any(named: 'end'),
          title: any(named: 'title'),
        ),
      ).thenAnswer((_) async => true);
      final end = now.add(const Duration(hours: 1));

      for (final (target, type) in [
        (
          TargetPlatform.iOS,
          HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        ),
        (TargetPlatform.android, HealthWorkoutActivityType.STRENGTH_TRAINING),
      ]) {
        expect(
          await platform(target)
              .writeStrengthWorkout(start: now, end: end, title: 'Push'),
          isTrue,
        );
        verify(
          () => health.writeWorkoutData(
            activityType: type,
            start: now,
            end: end,
            title: 'Push',
          ),
        ).called(1);
      }
    });
  });
}
