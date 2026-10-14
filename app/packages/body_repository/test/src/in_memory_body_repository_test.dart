import 'package:body_repository/body_repository.dart';
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
  });
}
