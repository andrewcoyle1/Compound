import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/progress/view/progress_metric_view.dart';
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
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        metric: metric,
      )..add(const WeightMetricSubscriptionRequested()),
      // Scale Weight brings Health's weigh-ins in as it appears.
      child: OnAppear(
        onAppear: () {
          if (metric == WeightMetric.scaleWeight) {
            unawaited(context.read<HealthCubit>().syncBody());
          }
        },
        child: WeightMetricView(allData: allData),
      ),
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
    final logWeight = ProgressMetricAction(
      label: l10n.logWeightTitle,
      icon: AppSymbols.add,
      onPressed: () => context.pushNamed(LogWeightPage.name),
    );
    return BlocListener<WeightMetricBloc, WeightMetricState>(
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
          title: Text(allData ? l10n.metricAllRecordedData : title),
          actions: [
            if (!allData && state.metric == WeightMetric.weightTrend)
              MethodInfoButton(MethodInfo.weightTrend(l10n)),
            if (!allData && state.metric == WeightMetric.weightTrend)
              AskCoachButton(
                CoachContext(kind: CoachContextKind.weightTrend, title: title),
              ),
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
          WeightMetricStatus.failure => ProgressMessage(
            title: title,
            message: l10n.weightLoadFailure,
          ),
          WeightMetricStatus.loaded when !hasEntries => ProgressMessage(
            title: title,
            message: l10n.weightNoEntries,
            action: logWeight,
          ),
          WeightMetricStatus.loaded when allData => MetricAllDataView(
            title: title,
            unit: state.unit.symbol,
            entries: state.entries,
            onDelete: (index) => context.read<WeightMetricBloc>().add(
              WeightMetricEntryDeleted(state.entryIds[index]),
            ),
          ),
          WeightMetricStatus.loaded => _Detail(state: state, title: title),
        },
      ),
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
