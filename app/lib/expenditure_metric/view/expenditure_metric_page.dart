import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/expenditure_metric/bloc/expenditure_metric_bloc.dart';
import 'package:compound/expenditure_metric/models/expenditure_metric.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound_maths/compound_maths.dart'
    show
        ExpenditureConfidence,
        ExpenditureConstants,
        ExpenditureEstimateCertainty;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Expenditure or Energy Balance (Swift `ExpenditureDetailView`,
/// `EnergyBalanceView`): the shared metric layout over the last 90 days of
/// the expenditure engine. Pushed from the Progress tab.
class ExpenditureMetricPage extends StatelessWidget {
  const new({required this.metric, this.allData = false, super.key});

  /// Which of the two screens.
  final ExpenditureMetric metric;

  /// Whether to show every entry (All Recorded Data) instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ExpenditureMetricBloc(
        users: context.read<UserRepository>(),
        nutrition: context.read<NutritionRepository>(),
        body: context.read<BodyRepository>(),
        checkIns: context.read<CheckInRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        metric: metric,
      )..add(const ExpenditureMetricSubscriptionRequested()),
      child: ExpenditureMetricView(allData: allData),
    );
  }
}

class ExpenditureMetricView extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ExpenditureMetricBloc>().state;
    final metric = state.metric;
    final title = metric.title(l10n);
    final balance = metric == ExpenditureMetric.energyBalance
        ? state.balance
        : null;
    final expenditure = state.expenditure;
    final isEmpty = balance != null
        ? balance.days.isEmpty
        : expenditure.isEmpty;
    void logMeal() => unawaited(openMealLogger(context, date: DateTime.now()));
    return AppScaffold(
      appBar: AppBar(
        title: Text(allData ? l10n.metricAllRecordedData : title),
        actions: [
          if (!allData)
            MethodInfoButton(switch (metric) {
              ExpenditureMetric.expenditure => MethodInfo.adaptiveExpenditure(
                l10n,
              ),
              ExpenditureMetric.energyBalance => MethodInfo.energyBalance(l10n),
            }),
          if (!allData)
            AskCoachButton(
              CoachContext(kind: CoachContextKind.expenditure, title: title),
            ),
          if (!allData && metric == ExpenditureMetric.energyBalance)
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.nutritionLogMeal,
              onPressed: logMeal,
            ),
          // Expenditure's formula reads the profile (Swift's Edit Profile).
          if (!allData && metric == ExpenditureMetric.expenditure)
            IconButton(
              icon: const Icon(AppSymbols.profile),
              tooltip: l10n.profileEditProfile,
              onPressed: () => context.pushNamed(EditProfilePage.name),
            ),
        ],
      ),
      body: switch (state.status) {
        ExpenditureMetricStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        ExpenditureMetricStatus.failure => _Message(
          title: title,
          message: l10n.nutritionDayLoadFailed,
        ),
        ExpenditureMetricStatus.loaded when isEmpty => _Message(
          title: title,
          message: balance != null
              ? l10n.energyBalanceNoData
              : l10n.expenditureNoData,
          action: balance == null
              ? null
              : FilledButton(
                  onPressed: logMeal,
                  child: Text(l10n.nutritionLogMeal),
                ),
        ),
        ExpenditureMetricStatus.loaded when allData => MetricAllDataView(
          title: title,
          unit: 'kcal',
          entries: balance == null
              ? expenditure.reversed.toList()
              : [
                  for (final day in balance.days.reversed)
                    (date: day.date, value: day.expenditure - day.intake),
                ],
          format: balance == null
              ? null
              : (value) => _balanceLabel(l10n, value),
        ),
        ExpenditureMetricStatus.loaded => _Detail(
          state: state,
          title: title,
          balance: balance,
        ),
      },
    );
  }

  /// "350 deficit", "120 surplus" or "Balanced"
  /// (`EnergyBalanceEntry.balanceLabel`).
  static String _balanceLabel(AppLocalizations l10n, double balance) {
    final value = balance.round();
    if (value > 0) return l10n.energyBalanceDeficit(AppFormat.number(value));
    if (value < 0) return l10n.energyBalanceSurplus(AppFormat.number(-value));
    return l10n.energyBalanceBalanced;
  }
}

class _Detail extends StatelessWidget {
  const new({required this.state, required this.title, required this.balance});

  final ExpenditureMetricState state;
  final String title;
  final ({List<MetricPoint> expenditure, List<EnergyBalanceDay> days})? balance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final balance = this.balance;
    final current = state.currentEstimate;
    return MetricDetailView(
      title: title,
      unit: 'kcal',
      series: balance == null
          ? [
              MetricChartSeries(
                label: l10n.expenditureTitle,
                points: state.expenditure,
                color: colors.expenditure,
                isLine: true,
              ),
            ]
          : [
              // Intake first: the rows under the chart describe it.
              MetricChartSeries(
                label: l10n.expenditureIntake,
                points: [
                  for (final day in balance.days)
                    (date: day.date, value: day.intake),
                ],
                color: colors.calories,
                // Bars under the expenditure line, averaged like any
                // reading (Swift's combo chart).
                isBar: true,
                total: false,
              ),
              MetricChartSeries(
                label: l10n.expenditureTitle,
                points: balance.expenditure,
                color: colors.expenditure,
                isLine: true,
              ),
            ],
      range: state.range,
      today: state.today,
      onRangeSelected: (range) => context.read<ExpenditureMetricBloc>().add(
        ExpenditureMetricRangeSelected(range),
      ),
      onShowAllData: () => context.goNamed(state.metric.dataRouteName),
      summary: balance != null || current == null
          ? null
          : AppSection(
              header: l10n.expenditureToday,
              children: [ExpenditureEstimateSummary(estimate: current)],
            ),
    );
  }
}

/// Today's expenditure with how sure the app is of it: the 80% interval and
/// a confidence badge once adaptive, or why it is still the formula's
/// (Swift `ExpenditureEstimateSummary`).
class ExpenditureEstimateSummary extends StatelessWidget {
  const new({required this.estimate, super.key});

  final ExpenditureEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final range = estimate.likelyRange;
    final detail = range != null
        ? l10n.expenditureLikely(
            AppFormat.kcal(range.low, locale: locale),
            AppFormat.kcal(range.high, locale: locale),
          )
        : estimate.source == ExpenditureSource.fixed
        ? l10n.expenditureFixed
        : l10n.expenditureUntilCalibrated(
            ExpenditureConstants.minDays,
            ExpenditureConstants.minWeighIns,
          );
    final (label, tint) = switch (estimate.confidence) {
      ExpenditureConfidence.calibrating => (
        l10n.expenditureCalibrating,
        secondary,
      ),
      ExpenditureConfidence.low => (l10n.expenditureLowConfidence, secondary),
      ExpenditureConfidence.medium => (
        l10n.expenditureMediumConfidence,
        colors.warning,
      ),
      ExpenditureConfidence.high => (
        l10n.expenditureHighConfidence,
        colors.success,
      ),
    };
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  AppFormat.kcal(estimate.kcal.round(), locale: locale),
                  style: AppTextStyles.metricLarge,
                ),
                AppChip(label: label, tint: tint),
              ],
            ),
            Text(
              detail,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty or failed state: the analytics glyph, the metric's name, a
/// line saying why, and what to do about it.
class _Message extends StatelessWidget {
  const new({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final Widget? action;

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
            ?action,
          ],
        ),
      ),
    );
  }
}
