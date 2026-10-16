import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/today/logic/today_checklist.dart' show countedSessions;
import 'package:compound_maths/compound_maths.dart';
import 'package:compound_models/compound_models.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:program_repository/program_repository.dart';

/// What the home-screen widgets show for [user] as of [now] (Swift
/// `WidgetSnapshot.make`): today's and tomorrow's entries of [run]'s queue,
/// the weekly streak, and this week's sessions against the goal, in weeks
/// starting on [firstWeekday] (ISO). [sessions] is the user's history,
/// including a session just finished that may not be back from the
/// listener yet.
WidgetSnapshot widgetSnapshot({
  required UserModel user,
  required MesocycleRun? run,
  required List<WorkoutSessionModel> sessions,
  required DateTime now,
  required int firstWeekday,
}) {
  WidgetWorkout? workout(DateTime date) =>
      switch (MesocycleSchedule.todayItem(run, sessions, now: date)) {
        null => null,
        final day => WidgetWorkout(
          name: day.dayPlan.name,
          exerciseCount: day.dayPlan.exercises.length,
          isRestDay: day.dayPlan.exercises.isEmpty,
          isCompleted: day.isCompleted,
        ),
      };
  final today = DateTime(now.year, now.month, now.day);
  final streak = WeeklyStreak.make(
    sessionDays: [
      for (final session in countedSessions(
        sessions,
        uid: user.userId,
        now: now,
      ))
        dayKeyOf(session.dateCreated.toLocal()),
    ],
    today: dayKeyOf(now),
    goal: weeklySessionGoal(user.weeklySessionGoal),
    firstWeekday: firstWeekday,
  );
  return WidgetSnapshot(
    todaysWorkout: workout(now),
    upcomingWorkout: workout(DateTime(now.year, now.month, now.day + 1)),
    day: today,
    currentStreak: streak.weeks,
    sessionsThisWeek: streak.sessionsThisWeek,
    weeklyGoal: streak.goal,
    updatedAt: now,
  );
}
