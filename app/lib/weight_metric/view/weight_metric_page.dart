import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/weight_metric/bloc/weight_metric_bloc.dart';
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

/// Scale Weight or Weight Trend (Swift `ScaleWeightView`,
/// `WeightTrendView`), read only: the shared metric layout over the user's
/// weigh-ins. Pushed from the Progress tab.
class WeightMetricPage extends StatelessWidget {
  const new({required this.metric, this.allData = false, super.key});

  /// Which of the two screens.
  final WeightMetric metric;

  /// Whether to show every entry (All Recorded Data) instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => WeightMetricBloc(
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        uid: state.user.uid,
        metric: metric,
      )..add(const WeightMetricSubscriptionRequested()),
      child: WeightMetricView(allData: allData),
    );
  }
}

class WeightMetricView extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WeightMetricBloc>().state;
    final title = state.metric.title(l10n);
    final hasEntries = state.weighIns?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(allData ? l10n.metricAllRecordedData : title),
        actions: [
          if (!allData && state.metric == WeightMetric.weightTrend)
            MethodInfoButton(MethodInfo.weightTrend(l10n)),
          if (!allData)
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.logWeightTitle,
              onPressed: () => context.pushNamed(LogWeightPage.name),
            ),
        ],
      ),
      body: switch (state.status) {
        WeightMetricStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        WeightMetricStatus.failure => _Message(
          title: title,
          message: l10n.weightLoadFailure,
        ),
        WeightMetricStatus.loaded when !hasEntries => _Message(
          title: title,
          message: l10n.weightNoEntries,
        ),
        WeightMetricStatus.loaded when allData => MetricAllDataView(
          title: title,
          unit: state.unit.symbol,
          entries: state.entries,
        ),
        WeightMetricStatus.loaded => _Detail(state: state, title: title),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const new({required this.state, required this.title});

  final WeightMetricState state;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = context.appColors.scaleWeight;
    final trend = state.trendPoints;
    return MetricDetailView(
      title: title,
      unit: state.unit.symbol,
      series: [
        // Weight Trend draws the readings as dots and the trend as the
        // line, so the two differ by shape, not colour alone; Scale Weight
        // joins its readings, as Swift's line chart does.
        MetricChartSeries(
          label: l10n.scaleWeightTitle,
          points: state.scalePoints,
          color: trend.isEmpty ? color : color.withValues(alpha: 0.45),
          isLine: state.metric == WeightMetric.scaleWeight,
        ),
        if (trend.isNotEmpty)
          MetricChartSeries(
            label: l10n.weightTrendSeries,
            points: trend,
            color: color,
            isLine: true,
          ),
      ],
      range: state.range,
      today: state.today,
      onRangeSelected: (range) => context.read<WeightMetricBloc>().add(
        WeightMetricRangeSelected(range),
      ),
      onShowAllData: () => context.goNamed(state.metric.dataRouteName),
    );
  }
}

/// An empty or failed state: the analytics glyph, the metric's name and a
/// line saying why (Swift's `ContentUnavailableView`).
class _Message extends StatelessWidget {
  const new({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            Icon(
              AppSymbols.analytics,
              size: AppIconSize.hero.of(context),
              color: secondary,
            ),
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
          ],
        ),
      ),
    );
  }
}
