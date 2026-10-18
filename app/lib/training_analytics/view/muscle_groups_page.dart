import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/training_analytics/view/muscle_balance_page.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_pages.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound_models/compound_models.dart' show Muscles;
import 'package:go_router/go_router.dart';

/// Every muscle's hard sets over the last seven days, upper body then
/// lower (Swift `MuscleGroupsView`). Pushed from the Progress tab's Muscle
/// Groups section.
class MuscleGroupsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab.
  static const path = 'muscles';

  /// The route name.
  static const name = 'muscleGroups';

  @override
  Widget build(BuildContext context) => const TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.muscleGroups,
    child: MuscleGroupsView(),
  );
}

class MuscleGroupsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.progressMuscleGroups),
        actions: [
          MethodInfoButton(MethodInfo.weeklyHardSets(l10n)),
          IconButton(
            icon: const Icon(AppSymbols.muscleBalance),
            tooltip: l10n.muscleBalanceTitle,
            onPressed: () => context.goNamed(MuscleBalancePage.name),
          ),
        ],
      ),
      body: TrainingAnalyticsBody(
        title: l10n.progressMuscleGroups,
        loaded: (state) {
          final lastSeven = state.lastSevenDaysByMuscle;
          Widget region(String header, {required bool upper}) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.s,
              children: [
                AnalyticsSectionHeader(title: header),
                ProgressCardGrid(
                  children: [
                    for (final muscle in Muscles.values)
                      if (isUpperBody(muscle) == upper)
                        MuscleSetsCard(
                          muscle: muscle,
                          lastSevenDays: lastSeven[muscle]!,
                        ),
                  ],
                ),
              ],
            ),
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              region(l10n.muscleRegionUpper, upper: true),
              region(l10n.muscleRegionLower, upper: false),
            ],
          );
        },
      ),
    );
  }
}

/// One muscle's tile: its sets on each of the last seven days and their
/// total; it opens the muscle's screen under the Progress tab.
class MuscleSetsCard extends StatelessWidget {
  const new({required this.muscle, required this.lastSevenDays, super.key});

  /// The muscle.
  final Muscles muscle;

  /// Its sets each day, oldest first.
  final List<double> lastSevenDays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final total = lastSevenDays.fold<double>(0, (a, b) => a + b);
    final most = lastSevenDays.fold<double>(0, (a, b) => a > b ? a : b);
    String number(double v) =>
        AppFormat.number(v, maxFractionDigits: 1, locale: locale);
    return ProgressCard(
      title: l10n.muscleName(muscle),
      subtitle: l10n.progressLast7Days,
      // The week the chart draws.
      value: number(total),
      unit: l10n.progressSetsUnit,
      onTap: () => context.goNamed(
        MuscleGroupDetailPage.name,
        pathParameters: {MuscleGroupDetailPage.muscleParameter: muscle.value},
      ),
      chart: StackedBars(
        stacks: [
          for (final sets in lastSevenDays) [sets],
        ],
        colors: [context.appColors.muscleGroups],
        semanticsLabel: l10n.progressSetsChartLabel,
        semanticsValue: l10n.progressSetsChartValue(
          number(total),
          number(most),
        ),
      ),
    );
  }
}
