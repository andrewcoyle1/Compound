import 'package:compound/social/logic/people.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// One face in the circle strip (Swift `CircleMember`).
final class const CircleMember({
  required final UserModel user,

  /// Finished a non-rest session today, by the device's calendar.
  required final bool trainedToday,

  /// Not trained, not the reader, and not already nudged today.
  required final bool canNudge,

  /// Finished sessions this week, for the ring.
  required final int sessionsThisWeek,

  /// The person's weekly goal.
  required final int weeklyGoal,

  /// The reader's own face.
  required final bool isCurrentUser,

  /// Set only on the reader's face, on the week's last day, while short.
  final int? sessionsToGo,
}) extends Equatable {
  /// How full the ring is, 0 to 1.
  double get progress => CircleWeek.progress(sessionsThisWeek, weeklyGoal);

  @override
  List<Object?> get props => [
    user,
    trainedToday,
    canNudge,
    sessionsThisWeek,
    weeklyGoal,
    isCurrentUser,
    sessionsToGo,
  ];
}

/// A row of the "This Week" leaderboard (`CircleWeek.Standing`).
final class const CircleStanding({
  required final UserModel user,
  required final int sessions,
  required final double volumeKg,
  required final int goal,
}) extends Equatable {
  @override
  List<Object> get props => [user, sessions, volumeKg, goal];
}

/// Monday's recap of last week (`CircleWeek.Summary`).
final class const CircleSummary({
  /// The first day of this week, which names the recap for dismissing it.
  required final DateTime weekStart,
  required final int ownSessions,
  required final int ownGoal,
  required final int circleSessions,
}) extends Equatable {
  @override
  List<Object> get props => [weekStart, ownSessions, ownGoal, circleSessions];
}

/// The circle's week: goals, rings, the leaderboard and the Monday recap
/// (`CircleWeek.swift`). Weeks start on `firstDayOfWeek`, 0 for Sunday as
/// `MaterialLocalizations` counts.
abstract final class CircleWeek {
  /// How full a ring is: 0 to 1, never past full.
  static double progress(int sessions, int goal) =>
      goal <= 0 ? 1 : (sessions / goal).clamp(0, 1).toDouble();

  /// Sessions still owed this week, never below none.
  static int remaining(int sessions, int goal) =>
      goal - sessions < 0 ? 0 : goal - sessions;

  /// [author]'s finished, non-rest, undeleted sessions in [date]'s week:
  /// the one bucketing rule the feed's weekly count also uses.
  static List<WorkoutSessionModel> sessionsInWeek(
    String author,
    DateTime date,
    List<WorkoutSessionModel> history,
    int firstDayOfWeek,
  ) {
    final week = WorkoutSessionHighlights.weekStart(date, firstDayOfWeek);
    return [
      for (final session in history)
        if (session.authorId == author &&
            session.endedAt != null &&
            !session.isRestDay &&
            session.deletedAt == null &&
            WorkoutSessionHighlights.weekStart(
                  session.dateCreated,
                  firstDayOfWeek,
                ) ==
                week)
          session,
    ];
  }

  /// Completed working sets' weight × reps that week: the leaderboard's
  /// tie-break, external load only.
  static double volumeKg(
    String author,
    DateTime date,
    List<WorkoutSessionModel> history,
    int firstDayOfWeek,
  ) {
    var total = 0.0;
    for (final session in sessionsInWeek(
      author,
      date,
      history,
      firstDayOfWeek,
    )) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (!set.isWarmup && set.completedAt != null) {
            total += set.volumeKg ?? 0;
          }
        }
      }
    }
    return total;
  }

  static bool _sameWeek(DateTime a, DateTime b, int firstDayOfWeek) =>
      WorkoutSessionHighlights.weekStart(a, firstDayOfWeek) ==
      WorkoutSessionHighlights.weekStart(b, firstDayOfWeek);

  /// Whether [date] is its week's first day.
  static bool isFirstDayOfWeek(DateTime date, int firstDayOfWeek) {
    final local = date.toLocal();
    final yesterday = DateTime(local.year, local.month, local.day - 1, 12);
    return !_sameWeek(yesterday, local, firstDayOfWeek);
  }

  /// Whether [date] is its week's last day.
  static bool isLastDayOfWeek(DateTime date, int firstDayOfWeek) {
    final local = date.toLocal();
    final tomorrow = DateTime(local.year, local.month, local.day + 1, 12);
    return !_sameWeek(tomorrow, local, firstDayOfWeek);
  }

  static String _name(UserModel user) =>
      (commonNameOf(user) ?? '').toLowerCase();

  /// The strip: [viewer] and everyone they follow (less themselves and
  /// anyone they blocked), trained-today first, then by name. Empty when
  /// they follow nobody, since a strip of one is just their own face.
  static List<CircleMember> members({
    required UserModel viewer,
    required List<UserModel> following,
    required List<WorkoutSessionModel> sessions,
    required Set<String> nudged,
    required DateTime now,
    required int firstDayOfWeek,
  }) {
    final followed = [
      for (final user in following)
        if (!hasBlocked(viewer, user.userId) && user.userId != viewer.userId)
          user,
    ];
    if (followed.isEmpty) return const [];
    final today = now.toLocal();
    bool isToday(DateTime date) {
      final local = date.toLocal();
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }

    final trained = {
      for (final session in sessions)
        if (session.endedAt case final ended?
            when !session.isRestDay &&
                session.deletedAt == null &&
                isToday(ended))
          session.authorId,
    };
    final lastDay = isLastDayOfWeek(now, firstDayOfWeek);
    final members = [
      for (final user in [viewer, ...followed])
        () {
          final isSelf = user.userId == viewer.userId;
          final trainedToday = trained.contains(user.userId);
          final count = sessionsInWeek(
            user.userId,
            now,
            sessions,
            firstDayOfWeek,
          ).length;
          final goal = weeklySessionGoal(user.weeklySessionGoal);
          final toGo = remaining(count, goal);
          return CircleMember(
            user: user,
            trainedToday: trainedToday,
            canNudge: !trainedToday && !isSelf && !nudged.contains(user.userId),
            sessionsThisWeek: count,
            weeklyGoal: goal,
            isCurrentUser: isSelf,
            sessionsToGo: isSelf && toGo > 0 && lastDay ? toGo : null,
          );
        }(),
    ];
    return members..sort((a, b) {
      if (a.trainedToday != b.trainedToday) return a.trainedToday ? -1 : 1;
      return _name(a.user).compareTo(_name(b.user));
    });
  }

  /// The leaderboard: most sessions, then most volume, then by name.
  static List<CircleStanding> standings({
    required List<UserModel> users,
    required List<WorkoutSessionModel> sessions,
    required DateTime now,
    required int firstDayOfWeek,
  }) {
    final standings = [
      for (final user in users)
        CircleStanding(
          user: user,
          sessions: sessionsInWeek(
            user.userId,
            now,
            sessions,
            firstDayOfWeek,
          ).length,
          volumeKg: volumeKg(user.userId, now, sessions, firstDayOfWeek),
          goal: weeklySessionGoal(user.weeklySessionGoal),
        ),
    ];
    return standings..sort((a, b) {
      if (a.sessions != b.sessions) return b.sessions.compareTo(a.sessions);
      if (a.volumeKg != b.volumeKg) return b.volumeKg.compareTo(a.volumeKg);
      return _name(a.user).compareTo(_name(b.user));
    });
  }

  /// [standing]'s place on the leaderboard: one more than the number with
  /// more sessions, so a tie shares a place (volume only orders the rows).
  /// Null with no sessions yet: a place nobody earned is not shown.
  static int? place(List<CircleStanding> standings, CircleStanding standing) {
    if (standing.sessions == 0) return null;
    return 1 + standings.where((s) => s.sessions > standing.sessions).length;
  }

  /// Last week's recap, on the first day of the week only, until dismissed
  /// for that week. [circle] includes [reader]; the goal is today's.
  static CircleSummary? summary({
    required UserModel reader,
    required List<UserModel> circle,
    required List<WorkoutSessionModel> sessions,
    required DateTime now,
    required int firstDayOfWeek,
    DateTime? dismissedWeek,
  }) {
    final week = WorkoutSessionHighlights.weekStart(now, firstDayOfWeek);
    if (!isFirstDayOfWeek(now, firstDayOfWeek) || dismissedWeek == week) {
      return null;
    }
    final lastWeek = DateTime(week.year, week.month, week.day - 3, 12);
    int count(String id) =>
        sessionsInWeek(id, lastWeek, sessions, firstDayOfWeek).length;
    return CircleSummary(
      weekStart: week,
      ownSessions: count(reader.userId),
      ownGoal: weeklySessionGoal(reader.weeklySessionGoal),
      circleSessions: circle.fold(
        0,
        (total, user) => total + count(user.userId),
      ),
    );
  }
}
