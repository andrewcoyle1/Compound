import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/bloc/progress_bloc.dart' show ProgressPoint;
import 'package:compound_charts/compound_charts.dart';

/// The small charts inside the Progress cards (Swift `SparklineChart`,
/// `SetsBarChart`, `MacroStackedBarChart`, `MacroProgressChart` and the
/// card `ContributionGridView`). [Sparkline] and [StackedBars] are
/// [CartesianChart.compact]s; [HabitGridChart] is a [HeatGrid.packed]. A
/// target's bar is a [BulletBar].
/// Each carries one accessibility summary, [semanticsLabel] and
/// [semanticsValue], since a screen reader cannot read a plot.
sealed class CardChart extends StatelessWidget {
  const new({this.semanticsLabel, this.semanticsValue, super.key});

  /// What the chart shows.
  final String? semanticsLabel;

  /// What it says.
  final String? semanticsValue;

  Widget _chart(BuildContext context);

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    value: semanticsValue,
    child: _chart(context),
  );
}

/// A line through [points], against time, edge to edge and fitted closely
/// to their values, ending in a dot on the latest, over a fill that fades
/// out beneath it unless [area] is false. One point is a dot in the
/// middle; none draws nothing.
final class Sparkline extends CardChart {
  const new({
    required this.points,
    required this.color,
    this.area = true,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// The readings, oldest first.
  final List<ProgressPoint> points;

  /// The line's colour.
  final Color color;

  /// Whether a fill fades out beneath the line.
  final bool area;

  @override
  Widget _chart(BuildContext context) {
    final points = this.points;
    var start = points.firstOrNull?.date ?? _origin;
    var end = points.lastOrNull?.date ?? _origin;
    // Nothing to span: the one day sits in the middle.
    if (!end.isAfter(start)) {
      start = DateTime(start.year, start.month, start.day - 1);
      end = DateTime(end.year, end.month, end.day + 1);
    }
    return CartesianChart.compact(
      data: ChartData(
        start: start,
        end: end,
        // Readings are moments, so the first and last reach the edges.
        bucketDays: 0,
        series: [
          ChartSeries(
            label: '',
            color: color,
            mark: area ? ChartMark.area : ChartMark.line,
            points: [for (final p in points) (x: p.date, y: p.value)],
          ),
        ],
      ),
    );
  }
}

/// Where [StackedBars]' slots, and an empty [Sparkline]'s window, start:
/// any fixed day, so new data morphs in place.
final _origin = DateTime.utc(2026);

/// Bars in [slots] equal slots, a day each, each stacked from [stacks]'
/// values in [colors] order; slots past the data stand on their stub. A
/// [line], one value a slot, is drawn over them in [lineColor] (Energy
/// Balance's expenditure). Heights are from zero to the tallest bar or line
/// point.
final class StackedBars extends CardChart {
  const new({
    required this.stacks,
    required this.colors,
    this.slots = 7,
    this.line,
    this.lineColor,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// Each bar's pieces, bottom first.
  final List<List<double>> stacks;

  /// The colour of each piece of a bar.
  final List<Color> colors;

  /// How many bars there is room for.
  final int slots;

  /// A line over the bars, one value a slot.
  final List<double>? line;

  /// The [line]'s colour.
  final Color? lineColor;

  @override
  Widget _chart(BuildContext context) {
    DateTime slot(int i) => _origin.add(Duration(days: i));
    final line = this.line;
    return CartesianChart.compact(
      data: ChartData(
        start: _origin,
        end: slot(slots),
        yFit: ChartYFit.zero,
        series: [
          for (final (j, color) in colors.indexed)
            ChartSeries(
              label: '$j',
              color: color,
              mark: ChartMark.bar,
              points: [
                for (final (i, stack) in stacks.indexed)
                  (x: slot(i), y: j < stack.length ? stack[j] : 0),
              ],
            ),
          if (line != null)
            ChartSeries(
              label: 'line',
              color: lineColor ?? Theme.of(context).colorScheme.onSurface,
              points: [for (final (i, y) in line.indexed) (x: slot(i), y: y)],
            ),
        ],
      ),
    );
  }
}

/// The 30-day habit grid, a [HeatGrid.packed]: ten columns of three
/// days, oldest at the top left, read down each column; a full square for
/// each day with the habit.
final class HabitGridChart extends CardChart {
  const new({
    required this.days,
    required this.color,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// One per day, oldest first.
  final List<bool> days;

  /// The full squares' colour.
  final Color color;

  @override
  Widget _chart(BuildContext context) => HeatGrid.packed(
    values: [
      for (final done in days)
        if (done) 1 else 0,
    ],
    levels: 2,
    color: color,
  );
}
