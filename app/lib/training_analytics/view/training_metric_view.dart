import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What one training metric screen shows, built from the state.
class const TrainingMetric({
  /// The screen's title.
  required final String title,

  /// The unit every value is shown with; empty for a bare count.
  required final String unit,

  /// The readings, oldest first: one a day for a line, one a session for
  /// bars.
  required final List<MetricPoint> points,

  /// The series' name, for the chart's summary.
  required final String seriesLabel,

  /// The chart's colour.
  required final Color color,

  /// Why there is nothing to show.
  required final String emptyMessage,

  /// Bars (a total, such as sets) rather than a line.
  final bool isBar = false,

  /// The method behind the figure, for an info button.
  final MethodInfo? info,

  /// A section above Show All Data.
  final Widget? summary,

  /// The text of each entry on All Recorded Data, newest first; by default
  /// the value and unit.
  final String Function(int index)? entryText,
});

/// A training metric's screen (Swift `MetricDetailView` with the
/// `ExerciseDetail`, `MuscleGroupDetail` and `Workout` presenters): the
/// shared chart and rows, or every entry when [allData]. Start Workout
/// stands in for Add, since these figures come from training.
class TrainingMetricView extends StatelessWidget {
  const new({
    required this.metric,
    required this.allDataRoute,
    this.allData = false,
    this.pathParameters = const {},
    super.key,
  });

  /// Builds the metric from the state.
  final TrainingMetric Function(
    BuildContext context,
    TrainingAnalyticsState state,
  )
  metric;

  /// The All Recorded Data route's name.
  final String allDataRoute;

  /// Its path parameters.
  final Map<String, String> pathParameters;

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TrainingAnalyticsBloc>().state;
    final metric = this.metric(context, state);
    final info = metric.info;
    final hasEntries =
        state.status == TrainingAnalyticsStatus.loaded &&
        metric.points.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(allData ? l10n.metricAllRecordedData : metric.title),
        actions: [
          if (!allData && info != null) MethodInfoButton(info),
          if (!allData) const StartWorkoutButton(),
        ],
      ),
      body: TrainingAnalyticsBody(
        title: metric.title,
        loaded: (state) {
          if (!hasEntries) {
            return AnalyticsMessage(
              title: metric.title,
              message: metric.emptyMessage,
              offersWorkout: true,
            );
          }
          if (allData) {
            return MetricAllDataView(
              title: metric.title,
              unit: metric.unit,
              entries: metric.points.reversed.toList(),
              valueText: metric.entryText,
            );
          }
          return MetricDetailView(
            title: metric.title,
            unit: metric.unit,
            series: [
              MetricChartSeries(
                label: metric.seriesLabel,
                points: metric.points,
                color: metric.color,
                isLine: !metric.isBar,
                isBar: metric.isBar,
              ),
            ],
            range: state.range,
            today: state.today,
            summary: metric.summary,
            onRangeSelected: (range) => context
                .read<TrainingAnalyticsBloc>()
                .add(TrainingAnalyticsRangeSelected(range)),
            onShowAllData: () =>
                context.goNamed(allDataRoute, pathParameters: pathParameters),
          );
        },
      ),
    );
  }
}
