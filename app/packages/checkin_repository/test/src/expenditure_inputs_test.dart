import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/models.dart';

void main() {
  // A Wednesday afternoon, local time.
  final now = DateTime(2026, 10, 14, 15, 30);
  final today = DateTime(2026, 10, 14);
  DateTime day(int daysAgo) => dayBefore(today, daysAgo);
  const settings = NutritionStrategySettings(authorId: 'user-1');

  ExpenditureInputs inputs({
    List<MealLogModel> meals = const [],
    List<BodyMeasurementEntry> measurements = const [],
    List<StepsModel> stepRecords = const [],
    List<NutritionDayAnnotation> annotations = const [],
    LoggingBreak? loggingBreak,
    NutritionStrategySettings strategy = settings,
    UserModel? user,
    CheckInRecord? record,
  }) => ExpenditureInputs(
    now: now,
    settings: strategy,
    user: user,
    meals: meals,
    measurements: measurements,
    steps: stepRecords,
    annotations: annotations,
    loggingBreak: loggingBreak,
    checkInRecord: record,
  );

  group('localDayKey and localMidnight', () {
    test('read a moment in local time', () {
      expect(localDayKey(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
      expect(localDayKey(DateTime(2026, 1, 2).toUtc()), '2026-01-02');
      expect(localMidnight('2026-01-02'), DateTime(2026, 1, 2));
    });
  });

  // ExpenditureSampleBuilderTests.swift, case for case.
  group('samples', () {
    test('meal calories are summed per day', () {
      final samples = inputs(
        meals: [meal(day(2), 600), meal(day(2), 400), meal(day(1), 1800)],
      ).samples;

      expect(samples.map((s) => s.intakeKcal), [1000, 1800]);
    });

    test('a day with no meal log is unlogged rather than zero', () {
      final samples = inputs(meals: [meal(day(3), 2000), meal(day(1), 2000)])
          .samples;

      expect(samples, hasLength(3));
      expect(samples[1].intakeKcal, isNull);
    });

    test('a meal logging zero calories still counts as logged', () {
      expect(inputs(meals: [meal(day(1), 0)]).samples.single.intakeKcal, 0);
      expect(inputs(meals: [meal(day(1), null)]).samples.single.intakeKcal, 0);
    });

    test("the first weigh-in of a day is the day's reading", () {
      final samples = inputs(
        measurements: [
          weighIn(day(1).add(const Duration(hours: 20)), weightKg: 82),
          weighIn(day(1).add(const Duration(hours: 7)), weightKg: 80),
        ],
      ).samples;

      expect(samples.single.weightKg, 80);
    });

    test('a fasting annotation marks the sample', () {
      final sample = inputs(
        measurements: [weighIn(day(1), weightKg: 80)],
        annotations: [note(keyOf(day(1)), fasting: true)],
      ).samples.single;

      expect(sample.isFastingDay, isTrue);
      expect(sample.intakeKcal, 0);
    });

    test('a partly logged day is excluded', () {
      final sample = inputs(
        meals: [meal(day(1), 900)],
        annotations: [note(keyOf(day(1)), partial: true)],
      ).samples.single;

      expect(sample.isExcluded, isTrue);
      expect(sample.intakeKcal, 900);
    });

    test('deleted and weightless entries are skipped', () {
      final samples = inputs(
        measurements: [
          weighIn(day(2), weightKg: 80),
          weighIn(day(1), weightKg: 99, deleted: true),
          weighIn(day(1)),
        ],
      ).samples;

      expect(samples.map((s) => s.weightKg), [80, null]);
    });

    test('the largest steps record for a day wins', () {
      final samples = inputs(
        stepRecords: [
          steps(day(1), 4000),
          steps(day(1), 11000),
          steps(day(1), 90000, deleted: true),
        ],
      ).samples;

      expect(samples.single.steps, 11000);
    });

    test('today is never a sample', () {
      final samples = inputs(
        meals: [meal(day(0), 5000), meal(day(1), 2000)],
        measurements: [weighIn(day(0), weightKg: 120)],
      ).samples;

      expect(samples.single.day, keyOf(day(1)));
      expect(samples.single.intakeKcal, 2000);
    });

    test('no data at all gives no samples', () {
      expect(inputs().samples, isEmpty);
    });

    test("a meal's day is its day key, or its date's when the key is not "
        'a day', () {
      final samples = inputs(
        meals: [
          meal(
            day(1).add(const Duration(hours: 1)),
            500,
            dayKey: keyOf(day(2)),
          ),
          meal(day(1), 700, dayKey: 'not-a-day'),
          meal(day(1), 100, dayKey: '2026-02-30'),
        ],
      ).samples;

      expect(samples.map((s) => (s.day, s.intakeKcal)), [
        (keyOf(day(2)), 500),
        (keyOf(day(1)), 800),
      ]);
    });

    test('an annotation whose day key is not a day is dropped', () {
      final sample = inputs(
        meals: [meal(day(1), 900)],
        annotations: [note('yesterday', partial: true)],
      ).samples.single;

      expect(sample.isExcluded, isFalse);
    });

    group('a logging break', () {
      final meals = [for (var d = 5; d >= 1; d--) meal(day(d), 2000)];
      List<bool> excluded(LoggingBreak loggingBreak) => inputs(
        meals: meals,
        loggingBreak: loggingBreak,
      ).samples.map((s) => s.isExcluded).toList();

      test('begun mid-morning covers the days after', () {
        expect(
          excluded(
            LoggingBreak(
              authorId: 'user-1',
              startDate: day(4).add(const Duration(hours: 9)),
              endDate: day(2).add(const Duration(hours: 12)),
            ),
          ),
          [false, false, true, true, false],
        );
      });

      test('begun at midnight covers that day', () {
        expect(
          excluded(
            LoggingBreak(
              authorId: 'user-1',
              startDate: day(4).toUtc(),
              endDate: day(3),
            ),
          ),
          [false, true, true, false, false],
        );
      });
    });
  });

  group('today', () {
    test("is now's day, or the day an open break began", () {
      expect(inputs().today, '2026-10-14');
      final open = LoggingBreak(
        authorId: 'user-1',
        startDate: day(3).add(const Duration(hours: 10)),
      );
      expect(inputs(loggingBreak: open).today, keyOf(day(3)));
      expect(inputs(loggingBreak: open).openLoggingBreak, open);
    });

    test('ignores a break that has ended or not begun', () {
      final ended = LoggingBreak(
        authorId: 'user-1',
        startDate: day(9),
        endDate: day(3),
      );
      final future = LoggingBreak(
        authorId: 'user-1',
        startDate: now.add(const Duration(hours: 1)),
      );
      expect(inputs(loggingBreak: ended).today, '2026-10-14');
      expect(inputs(loggingBreak: future).openLoggingBreak, isNull);
    });
  });

  test('engine settings follow the strategy settings', () {
    final engine = inputs(
      strategy: NutritionStrategySettings(
        authorId: 'user-1',
        calculationMode: ExpenditureCalculationMode.fixed,
        calculationStartDate: day(10).add(const Duration(hours: 18)),
        stepInformedUpdates: true,
      ),
    ).engineSettings;

    expect(engine.calculationMode, maths.ExpenditureCalculationMode.fixed);
    expect(engine.calculationStartDay, keyOf(day(10)));
    expect(engine.stepInformedUpdates, isTrue);
    expect(
      inputs().engineSettings.calculationMode,
      maths.ExpenditureCalculationMode.dynamic,
    );
    expect(inputs().engineSettings.calculationStartDay, isNull);
  });

  group('priorKcal', () {
    UserModel user({DateTime? dob}) => UserModel(
      userId: 'user-1',
      submittedGender: Gender.female,
      submittedWeightKilograms: 64.5,
      submittedHeightCentimeters: 170,
      submittedDailyActivityLevel: ActivityLevel.active,
      submittedDateOfBirth: dob,
    );
    double formula({
      int? age,
      maths.BmrEquation equation = maths.BmrEquation.mifflinStJeor,
      double? bodyFat,
    }) => maths.estimateTdee(
      gender: maths.Gender.female,
      weightKg: 64.5,
      heightCm: 170,
      ageYears: age,
      activity: maths.ActivityLevel.active,
      equation: equation,
      bodyFatPercentage: bodyFat,
    );

    test("is the formula on the user's profile", () {
      expect(inputs(user: user()).priorKcal, formula());
      expect(inputs().priorKcal, maths.estimateTdee());
    });

    test('counts whole years, never under 14', () {
      expect(
        inputs(user: user(dob: DateTime(1990, 10, 14, 15))).priorKcal,
        formula(age: 36),
      );
      expect(
        inputs(user: user(dob: DateTime(1990, 10, 14, 16))).priorKcal,
        formula(age: 35),
      );
      expect(
        inputs(user: user(dob: DateTime(2020))).priorKcal,
        formula(age: 14),
      );
    });

    test('runs Cunningham when body-fat aware and a reading is logged', () {
      final measurements = [
        weighIn(day(5), bodyFat: 30),
        weighIn(day(2), bodyFat: 20),
        weighIn(day(1), bodyFat: 10, deleted: true),
      ];
      const aware = NutritionStrategySettings(
        authorId: 'user-1',
        estimationMethod: ExpenditureEstimationMethod.bodyFatAware,
      );

      expect(
        inputs(
          user: user(),
          strategy: aware,
          measurements: measurements,
        ).priorKcal,
        formula(equation: maths.BmrEquation.cunningham, bodyFat: 20),
      );
      expect(
        inputs(user: user(), measurements: measurements).priorKcal,
        formula(bodyFat: 20),
      );
      expect(
        inputs(
          user: user(),
          strategy: const NutritionStrategySettings(
            authorId: 'user-1',
            bmrEquation: BmrEquation.harrisBenedict,
          ),
        ).priorKcal,
        formula(equation: maths.BmrEquation.harrisBenedict),
      );
    });
  });

  group('kcalPerKg', () {
    test('partitions with a body fat reading from the last 90 days', () {
      expect(
        inputs(
          measurements: [
            weighIn(day(1), weightKg: 80),
            weighIn(day(30), weightKg: 82, bodyFat: 25),
            weighIn(day(10), bodyFat: 0),
          ],
        ).kcalPerKg,
        maths.energyDensityKcalPerKg(80, 25),
      );
    });

    test('is 7,700 when the reading is older', () {
      expect(
        inputs(measurements: [weighIn(day(91), weightKg: 80, bodyFat: 25)])
            .kcalPerKg,
        maths.EnergyDensity.conventionalKcalPerKg,
      );
    });

    test("falls back to the profile's weight", () {
      expect(
        inputs(
          user: const UserModel(userId: 'user-1', submittedWeightKilograms: 70),
          measurements: [weighIn(day(3), bodyFat: 20)],
        ).kcalPerKg,
        maths.energyDensityKcalPerKg(70, 20),
      );
    });
  });

  group('history', () {
    test('ends today, on the formula while calibrating', () {
      final subject = inputs(
        meals: [meal(day(2), 2100), meal(day(1), 1900)],
        measurements: [weighIn(day(2), weightKg: 80)],
      );

      expect(subject.history.last.day, '2026-10-14');
      expect(subject.current.kcal, subject.priorKcal.roundToDouble());
      expect(subject.current.source, ExpenditureSource.prior);
    });

    test('freezes on the day an open break began', () {
      final subject = inputs(
        meals: [for (var d = 10; d >= 1; d--) meal(day(d), 2000)],
        loggingBreak: LoggingBreak(authorId: 'user-1', startDate: day(4)),
      );

      expect(subject.current.day, keyOf(day(4)));
    });
  });

  group('checkInState', () {
    // 14 Oct 2026 is a Wednesday: the week began on Monday the 12th.
    final monday = DateTime(2026, 10, 12);

    test('is due from the check-in day for the Monday-first week', () {
      expect(inputs().checkInState, CheckInState.due);
      expect(inputs().checkInWeekStart, monday);
      expect(
        inputs(
          strategy: const NutritionStrategySettings(
            authorId: 'user-1',
            checkInWeekday: 6,
          ),
        ).checkInState,
        CheckInState.notDue,
      );
    });

    test('is not due once this week is completed or skipped', () {
      expect(
        inputs(
          record: CheckInRecord(
            authorId: 'user-1',
            lastCompletedWeekStart: monday.toUtc(),
          ),
        ).checkInState,
        CheckInState.notDue,
      );
      expect(
        inputs(
          record: CheckInRecord(
            authorId: 'user-1',
            lastSkippedWeekStart: monday,
          ),
        ).checkInState,
        CheckInState.notDue,
      );
      expect(
        inputs(
          record: CheckInRecord(
            authorId: 'user-1',
            lastCompletedWeekStart: DateTime(2026, 10, 5),
          ),
        ).checkInState,
        CheckInState.due,
      );
    });

    test('is in a break from the moment it began, even mid-day', () {
      expect(
        inputs(
          loggingBreak: LoggingBreak(
            authorId: 'user-1',
            startDate: now.subtract(const Duration(minutes: 1)),
          ),
        ).checkInState,
        CheckInState.inBreak,
      );
    });
  });
}
