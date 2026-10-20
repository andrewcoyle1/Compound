/// Day keys: `YYYY-MM-DD` in the user's own time zone.
///
/// The caller turns timestamps into day keys once, so the arithmetic in this
/// package never meets a time zone or a clock, as in
/// `functions/coach-maths.js`. Keys compare in calendar order as strings.
library;

DateTime _utc(String dayKey) {
  final parts = dayKey.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

String _key(DateTime date) => date.toIso8601String().substring(0, 10);

/// The day key [days] after [dayKey] (before it when negative).
String addDays(String dayKey, int days) =>
    _key(_utc(dayKey).add(Duration(days: days)));

/// The ISO weekday of [dayKey]: 1 for Monday to 7 for Sunday.
int isoWeekday(String dayKey) => _utc(dayKey).weekday;

/// Whole days from [from] to [to], negative when [to] is earlier.
int daysBetween(String from, String to) =>
    _utc(to).difference(_utc(from)).inDays;
