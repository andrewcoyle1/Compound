// Mirrors the Swift `WeeklyStreakTests` and the week and goal parts of
// `CircleWeekTests`. Weeks run Monday to Sunday unless a test says
// otherwise. "Today" is Saturday 14 March 2026, so the current week is 9–15
// March, with Saturday and Sunday left.
import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

/// The key of [day] March 2026; days before 1 reach back into February.
String day(int day) => addDays('2026-03-01', day - 1);

const today = '2026-03-14';

/// [count] sessions in the week containing [of], on consecutive days from
/// that week's Monday.
List<String> week(int of, int count) {
  final monday = weekStartOf(day(of), firstWeekday: DateTime.monday);
  return [for (var i = 0; i < count; i++) addDays(monday, i)];
}

WeeklyStreak streak(List<String> days, {int goal = 3}) => WeeklyStreak.make(
  sessionDays: days,
  today: today,
  goal: goal,
  firstWeekday: DateTime.monday,
);

void main() {
  group('WeeklyStreak', () {
    test('consecutive met weeks count this week once met', () {
      final result = streak([...week(14, 3), ...week(7, 3), ...week(0, 4)]);
      expect(result.weeks, 3);
      expect(result.state, StreakState.met);
    });

    test('a week under way does not break the streak', () {
      final result = streak([day(14), ...week(7, 3), ...week(0, 3)]);
      expect(result.weeks, 2);
      expect(result.sessionsThisWeek, 1);
      expect(result.sessionsRemaining, 2);
      expect(result.state, StreakState.onTrack);
    });

    test('a missed week ends the streak', () {
      // Two weeks ago met, last week two of three: nothing carries over.
      final result = streak([...week(7, 2), ...week(0, 3)]);
      expect(result.weeks, 0);
      expect(result.state, StreakState.none);
      expect(result.best, 1);
    });

    test('the best streak is the longest run', () {
      // Four met weeks in February, a gap, then last week met again.
      final february = [
        for (final of in [-27, -20, -13, -6]) ...week(of, 3),
      ];
      final result = streak([...week(7, 3), ...february]);
      expect(result.weeks, 1);
      expect(result.best, 4);
    });

    test('no sessions is no streak', () {
      final result = streak([]);
      expect(result.weeks, 0);
      expect(result.best, 0);
      expect(result.state, StreakState.none);
    });

    test('owing as many sessions as days left is at risk', () {
      // Saturday, one of three: two owed, two days left, nothing today.
      final result = streak([day(10), ...week(7, 3)]);
      expect(result.daysRemaining, 2);
      expect(result.sessionsRemaining, 2);
      expect(result.state, StreakState.atRisk);
    });

    test('training today is not at risk', () {
      // Last week met a goal of four; today's session leaves three owed
      // with two days left.
      final result = streak([day(14), ...week(7, 4)], goal: 4);
      expect(result.weeks, 1);
      expect(result.trainedToday, isTrue);
      expect(result.state, StreakState.onTrack);
    });

    test('without a streak nothing is at risk', () {
      expect(streak([day(10)]).state, StreakState.onTrack);
    });

    test('remaining never goes below zero', () {
      final result = streak([...week(14, 5)]);
      expect(result.sessionsRemaining, 0);
      expect(result.state, StreakState.met);
    });

    test('the week follows the first weekday', () {
      // Sunday-first: the week is 8–14 March, and Saturday is its last day.
      final result = WeeklyStreak.make(
        sessionDays: [day(8), day(9), day(13)],
        today: today,
        goal: 3,
        firstWeekday: DateTime.sunday,
      );
      expect(result.sessionsThisWeek, 3);
      expect(result.daysRemaining, 1);
      expect(result.weeks, 1);
    });
  });

  group('weekStartOf', () {
    test('Sunday and Monday fall in different weeks', () {
      expect(weekStartOf('2026-03-08', firstWeekday: 1), '2026-03-02');
      expect(weekStartOf('2026-03-02', firstWeekday: 1), '2026-03-02');
      expect(weekStartOf('2026-03-09', firstWeekday: 1), '2026-03-09');
    });

    test('a week spanning New Year is one week', () {
      expect(weekStartOf('2025-12-31', firstWeekday: 1), '2025-12-29');
      expect(weekStartOf('2026-01-04', firstWeekday: 1), '2025-12-29');
      expect(weekStartOf('2026-01-05', firstWeekday: 1), '2026-01-05');
    });

    test('a Sunday-first week starts on the Sunday', () {
      expect(weekStartOf('2026-03-14', firstWeekday: 7), '2026-03-08');
      expect(weekStartOf('2026-03-08', firstWeekday: 7), '2026-03-08');
    });
  });

  test('an unset goal reads as three and a stored one is clamped', () {
    expect(weeklySessionGoal(null), 3);
    expect(weeklySessionGoal(5), 5);
    expect(weeklySessionGoal(0), 1);
    expect(weeklySessionGoal(12), 7);
  });
}
