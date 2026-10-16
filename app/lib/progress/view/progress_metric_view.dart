import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// A metric screen's add action (Swift `MetricConfiguration`'s
/// `addActionTitle` and `addActionSystemImage`).
class const ProgressMetricAction({
  required final String label,
  required final IconData icon,
  required final VoidCallback onPressed,
});

/// What one metric screen behind the Progress tab shows, built from the
/// state (Swift `MetricDetailPresenter`).
class const ProgressMetric({
  /// The screen's title.
  required final String title,

  /// The unit every value is shown with; empty for none.
  required final String unit,

  /// The chart's series; the first is the readings the rows describe.
  required final List<MetricChartSeries> series,

  /// Every entry, oldest first, in [unit].
  required final List<MetricPoint> entries,

  /// Why there is nothing to show.
  required final String emptyMessage,

  /// The decimal places a reading is shown to, when not the chart's own
  /// (a ratio's two).
  final int? decimals,

  /// Each of [entries]' stored entry, for deleting it.
  final List<String>? entryIds,

  /// The fields a delete removes; null when entries cannot be deleted
  /// (derived values, Swift `supportsDeletion` false).
  final Set<String>? deleteFields,

  /// The text of each entry on All Recorded Data, newest first.
  final String Function(int index)? entryText,

  /// The method behind the figure.
  final MethodInfo? info,

  /// A section above Show All Data.
  final Widget? summary,

  /// The add action, in the app bar and on the empty state.
  final ProgressMetricAction? add,

  /// More app bar actions, after the add action (Goal Progress's Change
  /// Goal).
  final List<ProgressMetricAction> actions = const [],

  /// Shown in place of the chart and its rows: a contribution grid, or Goal
  /// Progress's bar (Swift `contributionSeries`, `customChartView`).
  final Widget? chart,
}) {
  /// The All Recorded Data rows' values, newest first.
  List<MetricPoint> get newestFirst => entries.reversed.toList();
}

/// One metric screen over a [ProgressBloc] (Swift `MetricDetailView`): the
/// chart and its rows, or every entry when [allData], which can be deleted
/// where the metric is stored here.
class ProgressMetricView extends StatelessWidget {
  const new({
    required this.metric,
    required this.allDataRoute,
    this.allData = false,
    this.pathParameters = const {},
    super.key,
  });

  /// Builds the metric from the state.
  final ProgressMetric Function(BuildContext context, ProgressState state)
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
    final state = context.watch<ProgressBloc>().state;
    final metric = this.metric(context, state);
    final info = metric.info;
    final add = metric.add;
    return BlocListener<ProgressBloc, ProgressState>(
      listenWhen: (previous, current) =>
          current.deleteFailures > previous.deleteFailures,
      listener: (context, _) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.metricDeleteFailed),
          content: Text(context.l10n.metricTryAgain),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(allData ? l10n.metricAllRecordedData : metric.title),
          actions: [
            if (!allData && info != null) MethodInfoButton(info),
            if (!allData && add != null)
              IconButton(
                icon: Icon(add.icon),
                tooltip: add.label,
                onPressed: add.onPressed,
              ),
            if (!allData)
              for (final action in metric.actions)
                IconButton(
                  icon: Icon(action.icon),
                  tooltip: action.label,
                  onPressed: action.onPressed,
                ),
          ],
        ),
        body: switch (state.status) {
          ProgressStatus.loading => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          ProgressStatus.failure => ProgressMessage(
            title: metric.title,
            message: l10n.progressLoadFailure,
          ),
          ProgressStatus.loaded => _loaded(context, state, metric),
        },
      ),
    );
  }

  Widget _loaded(
    BuildContext context,
    ProgressState state,
    ProgressMetric metric,
  ) {
    final l10n = context.l10n;
    final chart = metric.chart;
    final add = metric.add;
    if (metric.entries.isEmpty && (allData || chart == null)) {
      return ProgressMessage(
        title: metric.title,
        message: metric.emptyMessage,
        action: add,
      );
    }
    if (allData) {
      final ids = metric.entryIds?.reversed.toList();
      final fields = metric.deleteFields;
      return MetricAllDataView(
        title: metric.title,
        unit: metric.unit,
        entries: metric.newestFirst,
        valueText: metric.entryText,
        onDelete: ids == null || fields == null
            ? null
            : (index) => context.read<ProgressBloc>().add(
                ProgressMeasurementCleared(entryId: ids[index], fields: fields),
              ),
      );
    }
    void showAll() =>
        context.goNamed(allDataRoute, pathParameters: pathParameters);
    if (chart != null) {
      final summary = metric.summary;
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          chart,
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.xl),
            summary,
          ],
          if (metric.entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(
              children: [
                AppListRowButton(
                  title: l10n.metricShowAllData,
                  onPressed: showAll,
                ),
              ],
            ),
          ],
        ],
      );
    }
    return MetricDetailView(
      title: metric.title,
      unit: metric.unit,
      series: metric.series,
      range: state.range,
      today: state.today,
      summary: metric.summary,
      decimals: metric.decimals,
      onRangeSelected: (range) =>
          context.read<ProgressBloc>().add(ProgressRangeSelected(range)),
      onShowAllData: showAll,
    );
  }
}

/// An empty or failed state (Swift's `ContentUnavailableView`): the
/// analytics glyph, the metric's name, a line saying why, and the add
/// action when there is one, so it is not a dead end.
class ProgressMessage extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    this.action,
    this.icon = AppSymbols.analytics,
    super.key,
  });

  /// The metric's name.
  final String title;

  /// Why there is nothing to show.
  final String message;

  /// What the user can do about it.
  final ProgressMetricAction? action;

  /// The glyph.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            Icon(icon, size: AppIconSize.hero.of(context), color: secondary),
            Text(
              title,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            Text(
              message,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
            if (action != null)
              TextButton(
                onPressed: action.onPressed,
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
