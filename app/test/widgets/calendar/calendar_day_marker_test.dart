import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swift's `CalendarDayMarkerAccessibilityTests` and
/// `CalendarDayMarkerRingStyleTests`, case for case.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  GoalProgressMarker progress(double value, {double goal = 2200}) =>
      GoalProgressMarker(value: value, goal: goal, grace: 100);

  group('accessibility', () {
    test('an empty day says nothing', () {
      expect(const CountMarker(0).describe(l10n), isNull);
      expect(progress(0).describe(l10n), isNull);
    });

    test('counts are spoken', () {
      expect(const CountMarker(1).describe(l10n), 'Logged');
      expect(const CountMarker(3).describe(l10n), '3 logged');
    });

    test('workouts by mesocycle are counted without a badge', () {
      expect(const SessionsMarker([]).describe(l10n), isNull);
      expect(const SessionsMarker(['#FF0000']).describe(l10n), 'Logged');
      const two = SessionsMarker(['#FF0000', null]);
      expect(two.describe(l10n), '2 logged');
      expect(two.badgeCount, isNull);
    });

    test('progress says how far toward the goal', () {
      final half = progress(1100).describe(l10n)!;
      expect(half, contains('50%'));
      expect(half, isNot(contains('Goal met')));
      expect(half, isNot(contains('Over goal')));
    });

    test('met and over goal are told apart', () {
      expect(progress(2250).describe(l10n), contains('Goal met'));
      final over = progress(2650).describe(l10n)!;
      expect(over, contains('Over goal'));
      expect(over, isNot(contains('Goal met')));
    });

    test('a day without a goal reads as logged', () {
      expect(progress(900, goal: 0).describe(l10n), 'Logged');
    });
  });

  group('ring style', () {
    test('a met goal is solid', () {
      expect(progress(2250).ringIsDashed, isFalse);
    });

    test('over goal is dashed', () {
      expect(progress(2650).ringIsDashed, isTrue);
    });

    test('a count is never dashed', () {
      expect(const CountMarker(3).ringIsDashed, isFalse);
    });

    test('within grace is solid', () {
      expect(progress(2290).ringIsDashed, isFalse);
    });
  });

  group('shape', () {
    test('fractions, badges and emptiness', () {
      expect(const CountMarker(2).fraction, 1);
      expect(const CountMarker(0).fraction, 0);
      expect(const CountMarker(0).isEmpty, isTrue);
      expect(const CountMarker(2).badgeCount, 2);
      expect(const CountMarker(1).badgeCount, isNull);
      expect(const SessionsMarker([null]).fraction, 1);
      expect(const SessionsMarker([]).fraction, 0);
      expect(const SessionsMarker([]).isEmpty, isTrue);
      expect(progress(1100).fraction, 0.5);
      expect(progress(3000).fraction, 1);
      expect(progress(100, goal: 0).fraction, 0);
      expect(progress(2200).isGoalMet, isTrue);
      expect(const CountMarker(5).isGoalMet, isFalse);
      expect(const CountMarker(5).isOverGoal, isFalse);
      expect(progress(1100).badgeCount, isNull);
      expect(progress(1100), progress(1100));
      expect(
        const SessionsMarker(['#FF0000']),
        const SessionsMarker(['#FF0000']),
      );
    });
  });
}
