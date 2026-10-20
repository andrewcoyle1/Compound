import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// Round values for a value axis from [min] to [max]: at most [maxCount]
/// (at least 2) of them, a 1, 2 or 5 step apart (times a power of ten), the
/// first at or below [min] and the last at or above [max]. Equal bounds are
/// widened a little either side, so a flat series sits mid-axis.
List<double> niceTicks(double min, double max, int maxCount) {
  assert(maxCount >= 2, 'An axis needs two ticks');
  final pad = max > min ? 0.0 : (min == 0 ? 1.0 : min.abs() / 100);
  final low = min - pad;
  final high = max + pad;
  // Allows for floating point when a bound is itself a tick.
  const epsilon = 1e-9;
  var magnitude = math
      .pow(10, (math.log((high - low) / maxCount) / math.ln10).floor())
      .toDouble();
  while (true) {
    for (final multiple in const [1, 2, 5]) {
      final step = multiple * magnitude;
      final first = (low / step + epsilon).floor();
      final last = (high / step - epsilon).ceil();
      if (last - first < maxCount) {
        // Rounded to the step's decimals, so 0.1 × 3 is 0.3.
        final scale = math.pow(10, fractionDigits(step));
        return [
          for (var i = first; i <= last; i++)
            (i * step * scale).round() / scale,
        ];
      }
    }
    magnitude *= 10;
  }
}

/// The decimal places a tick [step] needs: none for 1 or more, one for
/// 0.5, two for 0.02.
int fractionDigits(double step) =>
    math.max(0, -(math.log(step) / math.ln10 + 1e-9).floor());

/// One label on a time axis: its `text`, and where its leading edge sits
/// across the plot.
typedef ChartAxisLabel = ({String text, double left});

/// The date labels under a plot [width] wide, spanning [start] to [end].
///
/// Picks the finest unit whose labels, measured with [measure], fit side by
/// side: each day by its weekday for a week or less, then every week or
/// fortnight from Monday by its date, then every 1, 2, 3 or 6 months by the
/// month; a unit needs at least two labels. Each label is centred under the
/// span it names (a day, or a whole month), kept inside the plot. If none
/// fit, the finest unit's labels are thinned evenly so that no two ever
/// collide.
/// Dates are written in [locale].
List<ChartAxisLabel> dateTicks({
  required DateTime start,
  required DateTime end,
  required double width,
  required double Function(String text) measure,
  String? locale,
}) {
  final span = end.difference(start).inMinutes;
  double at(DateTime date) => width * date.difference(start).inMinutes / span;

  /// A label for each span from [first], the next starting [next] after
  /// it, the span itself running to [spanEnd].
  List<ChartAxisLabel> every(
    DateTime first,
    DateTime Function(DateTime date) next,
    DateTime Function(DateTime date) spanEnd,
    AppDateStyle style,
  ) => [
    for (var date = first; date.isBefore(end); date = next(date))
      _centred(
        AppFormat.date(date, style: style, locale: locale),
        (at(date) + at(spanEnd(date).isAfter(end) ? end : spanEnd(date))) / 2,
        measure,
      ),
  ];

  DateTime days(DateTime date, int count) =>
      DateTime(date.year, date.month, date.day + count);
  DateTime months(DateTime date, int count) =>
      DateTime(date.year, date.month + count);
  final monday = days(start, (DateTime.monday - start.weekday) % 7);
  final firstOfMonth = start.day == 1 ? start : months(start, 1);

  final units = [
    if (!end.isAfter(days(start, 7)))
      every(
        start,
        (d) => days(d, 1),
        (d) => days(d, 1),
        AppDateStyle.weekdayShort,
      ),
    for (final weeks in const [1, 2])
      every(
        monday,
        (d) => days(d, 7 * weeks),
        (d) => days(d, 1),
        AppDateStyle.dayMonth,
      ),
    for (final count in const [1, 2, 3, 6])
      every(
        firstOfMonth,
        (d) => months(d, count),
        (d) => months(d, 1),
        AppDateStyle.month,
      ),
  ];
  for (final labels in units.where((labels) => labels.length > 1)) {
    if (_placed(labels, width, measure) case final placed?) return placed;
  }
  // Nothing fits whole: every second, third… label of the finest unit, the
  // fewest left out that fit.
  final finest = units.firstWhere(
    (labels) => labels.isNotEmpty,
    orElse: () => const [],
  );
  for (var stride = 2; ; stride++) {
    final kept = [for (var i = 0; i < finest.length; i += stride) finest[i]];
    // A lone label always fits.
    if (_placed(kept, width, measure) case final placed?) return placed;
  }
}

ChartAxisLabel _centred(
  String text,
  double centre,
  double Function(String text) measure,
) => (text: text, left: centre - measure(text) / 2);

/// [labels] kept inside [width], or null if any would come within
/// [AppSpacing.s] of the one before.
List<ChartAxisLabel>? _placed(
  List<ChartAxisLabel> labels,
  double width,
  double Function(String text) measure,
) {
  final placed = <ChartAxisLabel>[];
  var right = double.negativeInfinity;
  for (final label in labels) {
    final size = measure(label.text);
    final left = label.left.clamp(0, math.max(0, width - size)).toDouble();
    if (left < right + AppSpacing.s) return null;
    placed.add((text: label.text, left: left));
    right = left + size;
  }
  return placed;
}
