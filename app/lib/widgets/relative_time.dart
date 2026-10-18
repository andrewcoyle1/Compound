import 'dart:async';
import 'dart:math' as math;

import 'package:compound/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The unit a relative time is told in.
enum RelativeUnit { second, minute, hour, day, week, month, year }

/// How long ago [date] was, as Swift's
/// `.formatted(.relative(presentation: .named))` measures it
/// (`Date.RelativeFormatStyle` in swift-foundation):
///
/// - the gap is first rounded to whole seconds;
/// - under a day, the largest unit rounds half up on the next one (1 min 30 s
///   is 2 minutes, 23 h 30 min is a day);
/// - from a day up, [now] is moved to the end of its day, week, month or
///   year, so days, weeks, months and years count calendar boundaries
///   crossed (anything yesterday is a day ago, whatever the hour).
///
/// Weeks start on [firstWeekday] (`DateTime.monday`…`DateTime.sunday`), as
/// Swift's calendar does for the region. A date in the future is told as now
/// (Swift says "in 3 seconds"), since only a clock difference puts one there.
({RelativeUnit unit, int count}) relativeTimeOf(
  DateTime date, {
  required DateTime now,
  int firstWeekday = DateTime.monday,
}) {
  const none = (unit: RelativeUnit.second, count: 0);
  final to = date.toLocal();
  final seconds = (now.difference(to).inMilliseconds / 1000).round();
  if (seconds <= 0) return none;
  final from = to.add(Duration(seconds: seconds));
  final largest = _largest(_between(from, to));
  if (largest == null) return none;
  final (unit, count) = largest;
  if (unit.index >= RelativeUnit.day.index) {
    final start = switch (unit) {
      RelativeUnit.day => DateTime(from.year, from.month, from.day),
      RelativeUnit.week => DateTime(
        from.year,
        from.month,
        from.day - (from.weekday - firstWeekday) % 7,
      ),
      RelativeUnit.month => DateTime(from.year, from.month),
      _ => DateTime(from.year),
    };
    final next = switch (unit) {
      RelativeUnit.day => _addDays(start, 1),
      RelativeUnit.week => _addDays(start, 7),
      RelativeUnit.month => _addMonths(start, 1),
      _ => _addMonths(start, 12),
    };
    final end = next.subtract(const Duration(seconds: 1));
    final (alignedUnit, alignedCount) = _largest(_between(end, to))!;
    return (unit: alignedUnit, count: alignedCount);
  }
  // Under a day: round half up on the next unit, carrying into the next
  // larger one (60 minutes is an hour, 24 hours a day).
  final parts = _between(from, to);
  final next = unit == RelativeUnit.second ? 0 : parts[unit.index - 1];
  final rounded = next * 2 >= 60 ? count + 1 : count;
  final carry = switch (unit) {
    RelativeUnit.second || RelativeUnit.minute => 60,
    _ => 24,
  };
  if (rounded == carry) {
    return (unit: RelativeUnit.values[unit.index + 1], count: 1);
  }
  return (unit: unit, count: rounded);
}

/// The calendar gap from [from] back to the earlier [to], as Foundation's
/// `dateComponents(from:to:)` counts it: whole years, months, weeks and days
/// stepped back on the calendar, then hours, minutes and seconds. Indexed by
/// [RelativeUnit].
List<int> _between(DateTime from, DateTime to) {
  var years = 0;
  while (!_addMonths(from, -12 * (years + 1)).isBefore(to)) {
    years++;
  }
  var cursor = _addMonths(from, -12 * years);
  var months = 0;
  while (!_addMonths(cursor, -(months + 1)).isBefore(to)) {
    months++;
  }
  cursor = _addMonths(cursor, -months);
  var days = 0;
  while (!_addDays(cursor, -(days + 1)).isBefore(to)) {
    days++;
  }
  final rest = _addDays(cursor, -days).difference(to);
  return [
    rest.inSeconds % 60,
    rest.inMinutes % 60,
    rest.inHours,
    days % 7,
    days ~/ 7,
    months,
    years,
  ];
}

(RelativeUnit, int)? _largest(List<int> parts) {
  for (final unit in RelativeUnit.values.reversed) {
    if (parts[unit.index] != 0) return (unit, parts[unit.index]);
  }
  return null;
}

DateTime _addDays(DateTime date, int days) => DateTime(
  date.year,
  date.month,
  date.day + days,
  date.hour,
  date.minute,
  date.second,
  date.millisecond,
  date.microsecond,
);

/// [months] on, keeping the day of the month where the month has it and
/// otherwise its last day (31 January plus a month is 28 February).
DateTime _addMonths(DateTime date, int months) {
  final index = date.year * 12 + date.month - 1 + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final length = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    math.min(date.day, length),
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// How long ago [date] was in words: "now", "5 minutes ago", "yesterday",
/// "last week". See [relativeTimeOf].
String relativeTimeText(
  AppLocalizations l10n,
  DateTime date, {
  required DateTime now,
  int firstWeekday = DateTime.monday,
}) {
  final (:unit, :count) = relativeTimeOf(
    date,
    now: now,
    firstWeekday: firstWeekday,
  );
  return switch (unit) {
    RelativeUnit.second => l10n.relativeSecondsAgo(count),
    RelativeUnit.minute => l10n.relativeMinutesAgo(count),
    RelativeUnit.hour => l10n.relativeHoursAgo(count),
    RelativeUnit.day => l10n.relativeDaysAgo(count),
    RelativeUnit.week => l10n.relativeWeeksAgo(count),
    RelativeUnit.month => l10n.relativeMonthsAgo(count),
    RelativeUnit.year => l10n.relativeYearsAgo(count),
  };
}

/// Builds [builder] with how long ago [date] was ([relativeTimeText]), and
/// builds it again as that changes: every second while it is in seconds,
/// every 30 seconds in minutes, every 5 minutes in hours, and hourly after.
class RelativeTimeBuilder extends StatefulWidget {
  const new({required this.date, required this.builder, this.now, super.key});

  /// The moment told.
  final DateTime date;

  /// Builds with the text.
  final Widget Function(BuildContext context, String text) builder;

  /// The clock, for tests. `DateTime.now` by default.
  final DateTime Function()? now;

  @override
  State<RelativeTimeBuilder> createState() => _RelativeTimeBuilderState();
}

class _RelativeTimeBuilderState extends State<RelativeTimeBuilder> {
  Timer? _refresh;

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.now ?? DateTime.now)();
    // MaterialLocalizations counts from Sunday = 0.
    final sundayFirst = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final firstWeekday = sundayFirst == 0 ? DateTime.sunday : sundayFirst;
    final (:unit, count: _) = relativeTimeOf(
      widget.date,
      now: now,
      firstWeekday: firstWeekday,
    );
    _refresh?.cancel();
    _refresh = Timer(switch (unit) {
      RelativeUnit.second => const Duration(seconds: 1),
      RelativeUnit.minute => const Duration(seconds: 30),
      RelativeUnit.hour => const Duration(minutes: 5),
      _ => const Duration(hours: 1),
    }, () => setState(() {}));
    return widget.builder(
      context,
      relativeTimeText(
        context.l10n,
        widget.date,
        now: now,
        firstWeekday: firstWeekday,
      ),
    );
  }
}
