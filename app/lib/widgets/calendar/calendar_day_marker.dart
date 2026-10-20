import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:equatable/equatable.dart';

/// What a calendar day marks, supplied per day by the screen hosting the
/// header (Swift `CalendarDayMarker`): Training's workouts, Nutrition's
/// calories against the day's goal.
sealed class CalendarDayMarker extends Equatable {
  const new();

  /// How much of the ring is drawn, 0–1. A count is all or nothing.
  double get fraction;

  /// Whether the goal has been reached, grace or not.
  bool get isGoalMet => false;

  /// Whether the goal and its grace have both been passed.
  bool get isOverGoal => false;

  /// Over goal also changes the ring's shape, so it is not hue alone.
  bool get ringIsDashed => isOverGoal;

  /// Whether the day has nothing on it.
  bool get isEmpty;

  /// The number badged on the day: a count above one.
  int? get badgeCount => null;

  /// What a screen reader says the day holds, or null for nothing.
  String? describe(AppLocalizations l10n);
}

/// A number of logged items: outlines the day, and badges counts above one.
final class const CountMarker(final int count) extends CalendarDayMarker {
  @override
  double get fraction => count > 0 ? 1 : 0;

  @override
  bool get isEmpty => count <= 0;

  @override
  int? get badgeCount => count > 1 ? count : null;

  @override
  String? describe(AppLocalizations l10n) => _logged(l10n, count);

  @override
  List<Object?> get props => [count];
}

/// The day's finished workouts in the order done, each its own stroke in
/// its mesocycle's colour (`#RRGGBB`), or the accent for null.
final class const SessionsMarker(final List<String?> colours)
    extends CalendarDayMarker {
  @override
  double get fraction => colours.isEmpty ? 0 : 1;

  @override
  bool get isEmpty => colours.isEmpty;

  @override
  String? describe(AppLocalizations l10n) => _logged(l10n, colours.length);

  @override
  List<Object?> get props => [colours];
}

/// Progress toward a daily goal, drawn as a ring. [grace] is how far past
/// the goal still reads as on target.
final class const GoalProgressMarker({
  required final double value,
  required final double goal,
  required final double grace,
}) extends CalendarDayMarker {
  @override
  double get fraction => goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0;

  @override
  bool get isGoalMet => goal > 0 && value >= goal;

  @override
  bool get isOverGoal => goal > 0 && value > goal + grace;

  @override
  bool get isEmpty => value <= 0;

  @override
  String? describe(AppLocalizations l10n) {
    if (isEmpty) return null;
    if (goal <= 0) return l10n.calendarLogged;
    return [
      l10n.calendarProgress(AppFormat.percent(value / goal)),
      if (isOverGoal)
        l10n.calendarOverGoal
      else if (isGoalMet)
        l10n.calendarGoalMet,
    ].join(', ');
  }

  @override
  List<Object?> get props => [value, goal, grace];
}

String? _logged(AppLocalizations l10n, int count) => switch (count) {
  <= 0 => null,
  1 => l10n.calendarLogged,
  _ => l10n.calendarLoggedCount(count),
};
