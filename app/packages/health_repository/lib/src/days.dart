/// [time]'s day on the device's calendar, as its local midnight (Swift
/// `Calendar.current.startOfDay`).
DateTime startOfDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The midnight after [day], however long the day is.
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

/// `yyyy-MM-dd` for [day], as Swift's `dayKey`.
String dayKeyOf(DateTime day) {
  final local = day.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}

/// Swift's `Int(date.timeIntervalSince1970)`, for ids derived from a day.
int epochSeconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
