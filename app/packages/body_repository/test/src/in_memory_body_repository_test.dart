import 'dart:async';

import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(InMemoryBodyRepository, () {
    BodyMeasurementEntry entry(
      String id,
      String authorId,
      int day, {
      bool deleted = false,
    }) => BodyMeasurementEntry(
      id: id,
      authorId: authorId,
      weightKg: 80,
      date: DateTime.utc(2026, 10, day),
      source: WeightSource.manual,
      dateCreated: DateTime.utc(2026, 10, day),
      deletedAt: deleted ? DateTime.utc(2026, 10, 13) : null,
    );
    StepsModel steps(
      String id,
      String authorId,
      int day, {
      bool deleted = false,
    }) => StepsModel(
      id: id,
      authorId: authorId,
      number: 9000,
      date: DateTime.utc(2026, 10, day),
      source: StepsSource.healthkit,
      dateCreated: DateTime.utc(2026, 10, day),
      dateModified: DateTime.utc(2026, 10, day),
      deletedAt: deleted ? DateTime.utc(2026, 10, 13) : null,
    );
    WeightGoal goal(String goalId, String userId) => WeightGoal(
      goalId: goalId,
      userId: userId,
      objective: OverarchingObjective.loseWeight,
      startingWeightKg: 80,
      targetWeightKg: 75,
      weeklyChangeKg: 0.5,
      createdAt: DateTime.utc(2026, 9),
      status: GoalStatus.active,
    );
    const settings = AnalyticsSettings(authorId: 'me', dailyStepGoal: 10000);

    late InMemoryBodyRepository subject;

    setUp(() {
      subject = InMemoryBodyRepository(
        measurements: [
          entry('b', 'me', 12),
          entry('a', 'me', 10),
          entry('deleted', 'me', 11, deleted: true),
          entry('theirs', 'you', 11),
        ],
        steps: [
          steps('b', 'me', 12),
          steps('a', 'me', 10),
          steps('deleted', 'me', 11, deleted: true),
          steps('theirs', 'you', 11),
        ],
        goals: [goal('me', 'me'), goal('g2', 'me'), goal('you', 'you')],
        analyticsSettings: settings,
      );
    });

    test("watchMeasurements emits the user's live entries, oldest first", () {
      expect(
        subject.watchMeasurements('me').map((l) => [for (final e in l) e.id]),
        emits(['a', 'b']),
      );
    });

    test("watchSteps emits the user's live counts, oldest first", () {
      expect(
        subject.watchSteps('me').map((l) => [for (final e in l) e.id]),
        emits(['a', 'b']),
      );
    });

    group('watchAnalyticsSettings', () {
      test("emits the user's settings", () {
        expect(subject.watchAnalyticsSettings('me'), emits(settings));
      });

      test("emits Swift's defaults for another user, or with none", () {
        expect(
          subject.watchAnalyticsSettings('you').map((s) => s.toFirestore()),
          emits(const AnalyticsSettings(authorId: 'you').toFirestore()),
        );
        expect(
          InMemoryBodyRepository()
              .watchAnalyticsSettings('me')
              .map((s) => (s.authorId, s.stepGoal)),
          emits(('me', 8000)),
        );
      });
    });

    group('watchCurrentGoal', () {
      test(
        'emits the goal currentGoalId names, else the one under the uid',
        () {
          expect(
            subject
                .watchCurrentGoal('me', currentGoalId: 'g2')
                .map((g) => g?.goalId),
            emits('g2'),
          );
          expect(
            subject.watchCurrentGoal('me').map((g) => g?.goalId),
            emits('me'),
          );
        },
      );

      test("never emits another user's goal, or a missing one", () {
        expect(
          subject.watchCurrentGoal('me', currentGoalId: 'you'),
          emits(isNull),
        );
        expect(InMemoryBodyRepository().watchCurrentGoal('me'), emits(isNull));
      });
    });

    group('saveMeasurement', () {
      test('adds an entry, and watchers see it', () async {
        final expectation = expectLater(
          subject.watchMeasurements('me').map((l) => [for (final e in l) e.id]),
          emitsInOrder([
            ['a', 'b'],
            ['a', 'c', 'b'],
          ]),
        );

        await subject.saveMeasurement(entry('c', 'me', 11));

        await expectation;
      });

      test('merges over the stored entry, as Firestore', () async {
        await subject.saveMeasurement(
          BodyMeasurementEntry(
            id: 'a',
            authorId: 'me',
            date: DateTime.utc(2026, 10, 10),
            source: WeightSource.manual,
            dateCreated: DateTime.utc(2026, 10, 10),
            bodyFatPercentage: 18.5,
          ),
        );

        final a = (await subject.watchMeasurements('me').first).first;
        expect((a.id, a.weightKg, a.bodyFatPercentage), ('a', 80, 18.5));
      });

      test("leaves another user's entry with the same id alone", () async {
        await subject.saveMeasurement(entry('theirs', 'me', 9));

        final mine = await subject.watchMeasurements('me').first;
        expect([for (final e in mine) e.id], ['theirs', 'a', 'b']);
      });
    });

    group('saveSteps', () {
      test('adds a count, and watchers see it', () async {
        final expectation = expectLater(
          subject.watchSteps('me').map((l) => [for (final e in l) e.id]),
          emitsInOrder([
            ['a', 'b'],
            ['a', 'c', 'b'],
          ]),
        );

        await subject.saveSteps(steps('c', 'me', 11));

        await expectation;
      });

      test('merges over the stored count, as Firestore', () async {
        await subject.saveSteps(
          StepsModel(
            id: 'a',
            authorId: 'me',
            number: 12000,
            date: DateTime.utc(2026, 10, 10),
            source: StepsSource.healthkit,
            dateCreated: DateTime.utc(2026, 10, 10),
            dateModified: DateTime.utc(2026, 10, 14),
            healthKitId: 'hk',
          ),
        );

        final a = (await subject.watchSteps('me').first).first;
        expect((a.id, a.number, a.healthKitId), ('a', 12000, 'hk'));
      });
    });

    group('clearMeasurementFields', () {
      test('removes the fields, and watchers see it', () async {
        await subject.saveMeasurement(
          BodyMeasurementEntry(
            id: 'a',
            authorId: 'me',
            date: DateTime.utc(2026, 10, 10),
            source: WeightSource.manual,
            dateCreated: DateTime.utc(2026, 10, 10),
            bodyFatPercentage: 18.5,
          ),
        );
        final expectation = expectLater(
          subject
              .watchMeasurements('me')
              .map((l) => (l.first.weightKg, l.first.bodyFatPercentage)),
          emitsInOrder([(80, 18.5), (null, 18.5)]),
        );

        await subject.clearMeasurementFields('me', 'a', {'weight_kg'});

        await expectation;
      });

      test('fails with not-found for a missing entry', () {
        expect(
          subject.clearMeasurementFields('you', 'a', {'weight_kg'}),
          throwsA(
            isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
          ),
        );
      });

      test('refuses a field the entry needs', () {
        expect(
          subject.clearMeasurementFields('me', 'a', {'author_id'}),
          throwsArgumentError,
        );
      });
    });

    group('goals', () {
      test('saveGoal adds a goal, and watchers see it', () async {
        final expectation = expectLater(
          subject
              .watchCurrentGoal('me', currentGoalId: 'g3')
              .map((g) => g?.goalId),
          emitsInOrder([null, 'g3']),
        );

        await subject.saveGoal(goal('g3', 'me'));

        await expectation;
      });

      test('saveGoal merges over a goal with the same id', () async {
        await subject.saveGoal(
          WeightGoal(
            goalId: 'g2',
            userId: 'me',
            objective: OverarchingObjective.loseWeight,
            startingWeightKg: 80,
            targetWeightKg: 72.5,
            weeklyChangeKg: 0.5,
            createdAt: DateTime.utc(2026, 9),
            status: GoalStatus.active,
          ),
        );

        final g2 = await subject
            .watchCurrentGoal('me', currentGoalId: 'g2')
            .first;
        expect(g2!.targetWeightKg, 72.5);
      });

      test(
        'abandonGoal changes only the status, and watchers see it',
        () async {
          final expectation = expectLater(
            subject.watchCurrentGoal('me').map((g) => g?.status),
            emitsInOrder([GoalStatus.active, GoalStatus.abandoned]),
          );

          await subject.abandonGoal('me', 'me');

          await expectation;
          final abandoned = await subject.watchCurrentGoal('me').first;
          expect(abandoned!.toFirestore(), {
            ...goal('me', 'me').toFirestore(),
            'status': 'abandoned',
          });
        },
      );

      test('abandonGoal fails with not-found for a missing goal', () {
        expect(
          subject.abandonGoal('me', 'you'),
          throwsA(
            isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
          ),
        );
      });
    });
  });

  testWidgets("a watcher's first value arrives under a fake clock", (
    tester,
  ) async {
    // A bloc awaits `.first`; it must not wait on anything outside the
    // widget test's zone.
    var arrived = false;
    unawaited(
      InMemoryBodyRepository()
          .watchMeasurements('x')
          .first
          .then((_) => arrived = true),
    );
    await tester.pump();
    expect(arrived, isTrue);
  });
}
