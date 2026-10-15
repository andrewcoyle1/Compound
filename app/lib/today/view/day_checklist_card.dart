import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/today_text.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:go_router/go_router.dart';

/// The day's checklist at the top of Today (Swift `DayChecklistCard`):
/// each item says whether it is done, and opens the screen behind it where
/// one is built. The footer says how "on target" and the step goal are
/// judged, each with its sources.
class DayChecklistCard extends StatelessWidget {
  const new({
    required this.checklist,
    required this.stepGoal,
    required this.unit,
    super.key,
  });

  /// The day's items.
  final TodayChecklist checklist;

  /// The step goal in force, for the footer.
  final int stepGoal;

  /// The unit weights are shown in.
  final AppWeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final footerStyle = AppTextStyles.label.copyWith(color: secondary);
    final hasSteps = checklist.items.any((item) => item is StepsItem);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.todayYourDay,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: secondary,
                    ),
                  ),
                ),
              ),
              if (checklist.isComplete)
                AppChip(
                  label: l10n.todayDayComplete,
                  icon: AppSymbols.success,
                  tint: colors.success,
                )
              else
                Text(
                  l10n.todayDoneCount(
                    checklist.doneCount,
                    checklist.items.length,
                  ),
                  style: footerStyle,
                ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in checklist.items.indexed) ...[
                if (index > 0) const Divider(indent: AppSpacing.l),
                _ItemRow(item: item, unit: unit),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FooterLine(
                text: l10n.todayCalorieBandFooter,
                info: MethodInfo.calorieAdherenceBand(l10n),
                style: footerStyle,
              ),
              if (hasSteps)
                _FooterLine(
                  text: l10n.todayStepGoalFooter(AppFormat.number(stepGoal)),
                  info: MethodInfo.dailyStepGoal(l10n),
                  style: footerStyle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const new({required this.item, required this.unit});

  final ChecklistItem item;
  final AppWeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final onTap = _destination(context);
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        value: item.isDone ? l10n.todayItemDone : l10n.todayItemNotDone,
        child: InkWell(
          onTap: onTap,
          child: AppListRow(
            title: TodayText.title(l10n, item),
            subtitle: TodayText.detail(l10n, item, unit),
            icon: TodayText.icon(item),
            accessory: AppListRowCustom(
              ExcludeSemantics(
                child: Icon(
                  item.isDone
                      ? AppSymbols.success
                      : AppSymbols.choiceUnselected,
                  size: AppIconSize.medium.of(context),
                  color: item.isDone
                      ? context.appColors.success
                      : scheme.outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where the item leads, read only: the workout's summary, the weigh-ins,
  /// or the day's meals. Steps has no screen yet.
  VoidCallback? _destination(BuildContext context) => switch (item) {
    TrainingItem(:final session) => () => context.goNamed(
      WorkoutSessionDetailPage.name,
      pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: session.id},
    ),
    WeighInItem() => () => context.goNamed(WeightMetric.scaleWeight.name),
    NutritionItem() => () => context.go(AppTab.nutrition.path),
    StepsItem() => null,
  };
}

class _FooterLine extends StatelessWidget {
  const new({required this.text, required this.info, required this.style});

  final String text;
  final MethodInfo info;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(text, style: style)),
        MethodInfoButton(info),
      ],
    );
  }
}
