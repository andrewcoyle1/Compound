// The pure half of CheckInPresenterTests.swift: which steps the check-in
// builds, the rows each list step shows, and what each saves.
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/models.dart';

void main() {
  final now = DateTime(2026, 10, 14, 15, 30);
  final today = DateTime(2026, 10, 14);
  DateTime day(int daysAgo) => dayBefore(today, daysAgo);

  /// The seven reviewed days, oldest first: the days ending yesterday.
  final reviewed = [for (var d = 7; d >= 1; d--) keyOf(day(d))];

  /// Five logged days and two with nothing, as the Swift fixture has.
  final week = [for (var d = 7; d >= 3; d--) meal(day(d), 2000)];

  CheckInFlow flow({
    NutritionStrategySettings settings = const NutritionStrategySettings(
      authorId: 'user-1',
    ),
    List<MealLogModel>? meals,
    List<NutritionDayAnnotation> annotations = const [],
    List<BodyMeasurementEntry> measurements = const [],
    double expenditureKcal = 2500,
  }) => CheckInFlow(
    now: now,
    settings: settings,
    expenditureKcal: expenditureKcal,
    meals: meals ?? week,
    annotations: annotations,
    measurements: measurements,
  );

  test('every step is built when every toggle is on', () {
    expect(flow().steps, CheckInStep.values);
  });

  group('the step list follows the four toggles', () {
    for (var mask = 0; mask < 16; mask++) {
      final partial = mask & 1 != 0;
      final weighIn = mask & 2 != 0;
      final fasting = mask & 4 != 0;
      final loggingBreak = mask & 8 != 0;
      test('partial $partial, weigh-in $weighIn, fasting $fasting, '
          'break $loggingBreak', () {
        expect(
          flow(
            settings: NutritionStrategySettings(
              authorId: 'user-1',
              partialLoggingEnabled: partial,
              weighInEnabled: weighIn,
              fastingEnabled: fasting,
              loggingBreakEnabled: loggingBreak,
            ),
          ).steps,
          [
            CheckInStep.introduction,
            if (partial) CheckInStep.partialLogging,
            if (weighIn) CheckInStep.weighIn,
            if (fasting) CheckInStep.fasting,
            if (loggingBreak) CheckInStep.loggingBreak,
            CheckInStep.programUpdate,
          ],
        );
      });
    }
  });

  test('a fast check-in drops the introduction and unsuspicious days', () {
    final subject = flow(
      settings: const NutritionStrategySettings(
        authorId: 'user-1',
        fastCheckIn: true,
      ),
    );

    expect(subject.steps.first, CheckInStep.weighIn);
    expect(subject.steps, isNot(contains(CheckInStep.partialLogging)));
  });

  test('a fast check-in keeps the suspicious days', () {
    final suspicious = keyOf(day(4));
    final subject = flow(
      settings: const NutritionStrategySettings(
        authorId: 'user-1',
        fastCheckIn: true,
      ),
      meals: [for (var d = 7; d >= 3; d--) meal(day(d), d == 4 ? 900 : 2000)],
    );

    expect(subject.steps, contains(CheckInStep.partialLogging));
    expect(subject.partialRows.map((r) => r.dayKey), [suspicious]);
  });

  test('the fasting step is absent with a fully logged week', () {
    final subject = flow(
      meals: [for (var d = 7; d >= 1; d--) meal(day(d), 2000)],
    );

    expect(subject.steps, isNot(contains(CheckInStep.fasting)));
    expect(subject.steps, contains(CheckInStep.partialLogging));
  });

  test('nothing logged leaves out partial logging', () {
    expect(
      flow(meals: const []).steps,
      isNot(contains(CheckInStep.partialLogging)),
    );
  });

  test('the weigh-in step is absent when a weigh-in is two days old', () {
    final subject = flow(measurements: [weighIn(day(2), weightKg: 80)]);

    expect(subject.hasRecentWeighIn, isTrue);
    expect(subject.steps, isNot(contains(CheckInStep.weighIn)));
  });

  test('the weigh-in step returns when the last one is old', () {
    final subject = flow(
      measurements: [
        weighIn(day(4), weightKg: 80),
        weighIn(day(1), weightKg: 80, deleted: true),
        weighIn(day(1)),
      ],
    );

    expect(subject.hasRecentWeighIn, isFalse);
    expect(subject.steps, contains(CheckInStep.weighIn));
  });

  test('the introduction counts the week', () {
    final subject = flow(
      measurements: [
        weighIn(day(8), weightKg: 80),
        weighIn(day(7), weightKg: 80),
        weighIn(day(1).add(const Duration(hours: 23)), weightKg: 80),
        weighIn(day(0), weightKg: 80),
      ],
    );

    expect(subject.weekDays.map((d) => d.dayKey), reviewed);
    expect(subject.loggedDayCount, 5);
    expect(subject.weighInCount, 2);
  });

  test('existing annotations pre-set the toggles', () {
    final logged = reviewed[0];
    final unlogged = reviewed[6];
    final subject = flow(
      annotations: [note(logged, partial: true), note(unlogged, fasting: true)],
    );

    expect(
      subject.partialRows.firstWhere((r) => r.dayKey == logged).isOn,
      isTrue,
    );
    expect(
      subject.fastingRows.firstWhere((r) => r.dayKey == unlogged).isOn,
      isTrue,
    );
    expect(subject.fastingRows.map((r) => r.dayKey), reviewed.sublist(5));
  });

  test('a row reports its intake and whether anything was logged', () {
    final subject = flow(meals: [meal(day(1), 600), meal(day(1), 400)]);

    expect(subject.weekDays.last.intakeKcal, 1000);
    expect(subject.weekDays.last.isLogged, isTrue);
    expect(subject.weekDays.first.isLogged, isFalse);
  });

  group('saving', () {
    test('partial logging writes every row, keeping the fasting flag', () {
      final first = reviewed[0];
      final subject = flow(annotations: [note(first, fasting: true)]);
      final rows = [
        subject.partialRows.first.toggled(on: true),
        ...subject.partialRows.skip(1),
      ];

      final saved = subject.partialAnnotations(rows, uid: 'user-1', now: now);

      expect(saved, hasLength(7));
      expect(saved.first.isPartiallyLogged, isTrue);
      expect(saved.first.isFastingDay, isTrue);
      expect(saved.first.dateModified, now);
      expect(saved.last.isEmpty, isTrue);
      expect(saved.last.authorId, 'user-1');
    });

    test('fasting writes its rows, keeping the partial flag', () {
      final last = reviewed[6];
      final subject = flow(annotations: [note(last, partial: true)]);
      final rows = [for (final r in subject.fastingRows) r.toggled(on: true)];

      final saved = subject.fastingAnnotations(rows, uid: 'user-1', now: now);

      expect(saved.map((a) => a.dayKey), reviewed.sublist(5));
      expect(saved.every((a) => a.isFastingDay), isTrue);
      expect(saved.last.isPartiallyLogged, isTrue);
      expect(saved.first.isPartiallyLogged, isFalse);
    });
  });

  test('carries the open break for the logging-break step', () {
    final open = LoggingBreak(authorId: 'user-1', startDate: day(2));
    final subject = CheckInFlow(
      now: now,
      settings: const NutritionStrategySettings(authorId: 'user-1'),
      expenditureKcal: 2500,
      openLoggingBreak: open,
    );

    expect(subject.openLoggingBreak, open);
    expect(subject.steps, contains(CheckInStep.loggingBreak));
    expect(CheckInFlow.weighInRecencyDays, 3);
  });
}
