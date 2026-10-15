/// The app's one streak: consecutive weeks in which the user finished at
/// least their weekly session goal (`WeeklyStreak.swift`, `CircleWeek.swift`).
/// A rest day never breaks it, which a day streak did to anyone not training
/// daily.
///
/// Works on day keys, as the rest of this package does: the caller passes the
/// start day of each session that counts (finished, not a rest day, not
/// deleted, the user's own, not after now) and today's key.
library;

import 'dart:math' as math;

import 'package:compound_maths/src/day_key.dart';

/// The weekly goal for someone who has not picked one (`CircleWeek`).
const defaultWeeklySessionGoal = 3;

/// The fewest sessions a weekly goal can ask for.
const minWeeklySessionGoal = 1;

/// The most sessions a weekly goal can ask for.
const maxWeeklySessionGoal = 7;

/// The user's weekly target: [stored], or 3 when they have not picked one,
/// clamped to 1–7 whatever the document holds (`CircleWeek.goal(for:)`).
int weeklySessionGoal(int? stored) => math.min(
  math.max(stored ?? defaultWeeklySessionGoal, minWeeklySessionGoal),
  maxWeeklySessionGoal,
);

/// The first day of [dayKey]'s week, for a week starting on [firstWeekday]
/// (ISO: 1 for Monday to 7 for Sunday), as `Calendar.dateInterval(of:
/// .weekOfYear)` gives it.
String weekStartOf(String dayKey, {required int firstWeekday}) =>
    addDays(dayKey, -((isoWeekday(dayKey) - firstWeekday) % 7));

/// Where this week stands (`WeeklyStreak.State`).
enum StreakState {
  /// This week's goal is met.
  met,

  /// Not met yet, with enough days left to meet it comfortably.
  onTrack,

  /// A streak to lose, nothing logged today, and every day left is needed:
  /// the sessions still owed are at least the days left, today included.
  atRisk,

  /// No streak and nothing logged this week.
  none,
}

/// The streak as of one day (`WeeklyStreak`). Every past week is judged by
/// today's [goal]: the app keeps no history of goal changes.
class const WeeklyStreak({
  /// Weeks in a row the goal was met, this week included once it is met. A
  /// week still under way does not break it.
  required final int weeks,

  /// The longest run of met weeks, at least [weeks].
  required final int best,

  /// Sessions counted this week.
  required final int sessionsThisWeek,

  /// The weekly goal.
  required final int goal,

  /// Days left in the week, today included.
  required final int daysRemaining,

  /// Whether a counted session started today.
  required final bool trainedToday,
}) {
  /// Builds the streak from [sessionDays], the start day of each counted
  /// session (`WeeklyStreak.make`), as of [today], in weeks starting on
  /// [firstWeekday] (ISO weekday).
  factory make({
    required Iterable<String> sessionDays,
    required String today,
    required int goal,
    required int firstWeekday,
  }) {
    String weekOf(String day) => weekStartOf(day, firstWeekday: firstWeekday);
    final perWeek = <String, int>{};
    for (final day in sessionDays) {
      perWeek.update(weekOf(day), (count) => count + 1, ifAbsent: () => 1);
    }
    bool met(String week) => (perWeek[week] ?? 0) >= goal;

    final thisWeek = weekOf(today);
    var weeks = 0;
    var week = met(thisWeek) ? thisWeek : addDays(thisWeek, -7);
    while (met(week)) {
      weeks++;
      week = addDays(week, -7);
    }

    var best = 0;
    var run = 0;
    final weekKeys = perWeek.keys.toList()..sort();
    if (weekKeys.isNotEmpty) {
      for (
        week = weekKeys.first;
        week.compareTo(thisWeek) <= 0;
        week = addDays(week, 7)
      ) {
        run = met(week) ? run + 1 : 0;
        best = math.max(best, run);
      }
    }

    return WeeklyStreak(
      weeks: weeks,
      best: math.max(best, weeks),
      sessionsThisWeek: perWeek[thisWeek] ?? 0,
      goal: goal,
      daysRemaining: 7 - daysBetween(thisWeek, today),
      trainedToday: sessionDays.contains(today),
    );
  }

  /// Sessions still owed this week, never below zero
  /// (`CircleWeek.remaining`).
  int get sessionsRemaining => math.max(goal - sessionsThisWeek, 0);

  /// Where this week stands.
  StreakState get state {
    if (sessionsThisWeek >= goal) return StreakState.met;
    if (weeks > 0 && !trainedToday && sessionsRemaining >= daysRemaining) {
      return StreakState.atRisk;
    }
    if (weeks == 0 && sessionsThisWeek == 0) return StreakState.none;
    return StreakState.onTrack;
  }
}
