import 'package:compound/app/widget_snapshot.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  group('widgetSnapshot', () {
    final now = DateTime(2026, 10, 16, 18);

    WorkoutSessionModel finished(String id, DateTime day) =>
        WorkoutSessionModel(
          id: id,
          authorId: sampleUserId,
          name: 'Workout',
          dateCreated: day,
          dateModified: day,
          endedAt: day.add(const Duration(hours: 1)),
          exercises: const [],
        );

    test('counts this week against the goal and the streak', () {
      final user = sampleUser(now: now);
      final snapshot = widgetSnapshot(
        user: user,
        run: null,
        sessions: [
          // Monday to Wednesday of this week, and of the week before.
          for (final day in [5, 6, 7, 12, 13, 14])
            finished('$day', DateTime(2026, 10, day, 9)),
        ],
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(snapshot.todaysWorkout, isNull);
      expect(snapshot.upcomingWorkout, isNull);
      expect(snapshot.day, DateTime(2026, 10, 16));
      expect(snapshot.sessionsThisWeek, 3);
      expect(snapshot.weeklyGoal, 3);
      expect(snapshot.currentStreak, 2);
      expect(snapshot.updatedAt, now);
    });

    test("names today's and tomorrow's workouts from the program", () {
      final mesocycle = sampleMesocycles(now: now).first;
      final snapshot = widgetSnapshot(
        user: sampleUser(now: now),
        run: MesocycleSchedule.legacyRun(mesocycle, const []),
        sessions: const [],
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(snapshot.todaysWorkout, isNotNull);
      expect(
        snapshot.todaysWorkout!.exerciseCount,
        mesocycle.workoutTemplates
            .firstWhere((t) => t.name == snapshot.todaysWorkout!.name)
            .exercises
            .length,
      );
      expect(snapshot.upcomingWorkout, isNotNull);
    });
  });
}
