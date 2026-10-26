import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/programs/logic/todays_workout.dart';
import 'package:compound/progress/view/progress_metric_pages.dart'
    show StepsPage;
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/today_text.dart';
import 'package:compound/training_library/view/workout_template_detail_page.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The day's checklist at the top of Today (Swift `DayChecklistCard`):
/// each item says whether it is done, and opens the screen behind it. The
/// Steps item, held, offers the step goals. The footer says how "on
/// target" and the step goal are judged, each with its sources.
///
/// With [showsHero] it opens with Today's hero card: the items done out of
/// all of them, a ring filling in the accent, and the next item to do, or
/// "Day Complete" once all are.
class DayChecklistCard extends StatelessWidget {
  const new({
    required this.checklist,
    required this.stepGoal,
    required this.unit,
    this.celebrated = const {},
    this.workout,
    this.onItemPressed,
    this.onStepGoalSelected,
    this.weighIn,
    this.showsHero = false,
    super.key,
  });

  /// Whether the day's progress leads as Today's hero card, in place of
  /// the section's header.
  final bool showsHero;

  /// Shown under the weigh-in item while it is not done, such as the
  /// coach's quick weigh-in.
  final Widget? weighIn;

  /// Today's workout in the active mesocycle: what a planned item opens.
  final TodaysWorkout? workout;

  /// Told of each tap before the item opens its screen.
  final ValueChanged<ChecklistItem>? onItemPressed;

  /// Called with the step goal chosen on the Steps item; without it the
  /// goal can't be changed here.
  final ValueChanged<int>? onStepGoalSelected;

  /// The day's items.
  final TodayChecklist checklist;

  /// The step goal in force, for the footer.
  final int stepGoal;

  /// The unit weights are shown in.
  final AppWeightUnit unit;

  /// The items ([ChecklistItem.kind]) to celebrate: each bursts confetti
  /// from its tick when it joins the set.
  final Set<String> celebrated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSteps = checklist.items.any((item) => item is StepsItem);
    final rows = [
      for (final item in checklist.items) ...[
        _ItemRow(
          key: ValueKey(item.kind),
          item: item,
          celebrate: celebrated.contains(item.kind),
          unit: unit,
          workout: workout,
          stepGoal: stepGoal,
          onPressed: onItemPressed,
          onStepGoalSelected: onStepGoalSelected,
        ),
        if ((item, weighIn) case (WeighInItem(isDone: false), final row?)) row,
      ],
    ];
    void explain(MethodInfo info) => unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) => MethodInfoSheet(info: info),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        if (showsHero)
          _Hero(checklist: checklist, rows: rows)
        else
          AppSection(
            header: l10n.todayYourDay,
            trailing: checklist.isComplete
                ? AppChip(
                    label: l10n.todayDayComplete,
                    icon: AppSymbols.success,
                  )
                : Text(
                    l10n.todayDoneCount(
                      checklist.doneCount,
                      checklist.items.length,
                    ),
                  ),
            children: rows,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: AppFootnote(
            lines: [
              for (final (text, info) in [
                (
                  l10n.todayCalorieBandFooter,
                  MethodInfo.calorieAdherenceBand(l10n),
                ),
                if (hasSteps)
                  (
                    l10n.todayStepGoalFooter(AppFormat.number(stepGoal)),
                    MethodInfo.dailyStepGoal(l10n),
                  ),
              ])
                AppFootnoteLine(
                  text,
                  infoLabel: l10n.methodInfoButtonLabel(info.title),
                  onInfo: () => explain(info),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's hero, one card: the items done out of all of them in the
/// largest number on the screen, beside a heavy ring filling in the
/// accent, and the items themselves under it. Complete, the ring closes
/// and a volt "Day Complete" shows by the number.
class _Hero extends StatelessWidget {
  const new({required this.checklist, required this.rows});

  final TodayChecklist checklist;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final total = checklist.items.length;
    return AppSummaryCard(
      title: l10n.todayYourDay,
      icon: AppSymbols.today,
      tint: colors.accentInk,
      size: AppSummaryCardSize.hero,
      value:
          '${AppFormat.number(checklist.doneCount)}/'
          '${AppFormat.number(total)}',
      unit: l10n.todayDoneUnit,
      delta: checklist.isComplete
          ? AppChip(
              label: l10n.todayDayComplete,
              icon: AppSymbols.success,
              selected: true,
            )
          : null,
      // The ring is a line on the card: the accent as ink, volt in dark
      // mode and olive in light, where volt on white is 1.3:1. The number
      // carries the figure, so the ring keeps its size at large text
      // rather than pushing the items down.
      chart: MediaQuery.withNoTextScaling(
        child: ProgressArc(
          value: total == 0 ? 0 : checklist.doneCount / total,
          color: colors.accentInk,
          // As tall as the number and its unit beside it.
          diameter: 2 * AppControlSize.cta,
          strokeWidth: AppChartMark.arcWidthHero,
        ),
      ),
      chartBeside: true,
      rows: rows,
    );
  }
}

class _ItemRow extends StatelessWidget {
  const new({
    required this.item,
    required this.unit,
    required this.workout,
    required this.stepGoal,
    required this.onPressed,
    required this.onStepGoalSelected,
    required this.celebrate,
    super.key,
  });

  final ChecklistItem item;
  final bool celebrate;
  final AppWeightUnit unit;
  final TodaysWorkout? workout;
  final int stepGoal;
  final ValueChanged<ChecklistItem>? onPressed;
  final ValueChanged<int>? onStepGoalSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final destination = _destination(context);
    final onTap = destination == null
        ? null
        : () {
            onPressed?.call(item);
            destination();
          };
    final chooseGoal = switch ((item, onStepGoalSelected)) {
      (StepsItem(), final onSelected?) => () => unawaited(
        _chooseStepGoal(context, onSelected),
      ),
      _ => null,
    };
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        value: item.isDone ? l10n.todayItemDone : l10n.todayItemNotDone,
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.todayStepGoal): ?chooseGoal,
        },
        child: AppListRowButton(
          onPressed: onTap,
          onLongPress: chooseGoal,
          title: TodayText.title(l10n, item),
          subtitle: TodayText.detail(l10n, item, unit),
          icon: TodayText.icon(item),
          accessory: AppListRowCustom(
            ExcludeSemantics(
              child: AppConfetti(
                play: celebrate,
                child: item.isDone
                    ? const AppDoneMark()
                    : Icon(
                        AppSymbols.choiceUnselected,
                        size: AppIconSize.medium.of(context),
                        color: scheme.outline,
                      ),
              ),
            ),
            pinned: true,
          ),
        ),
      ),
    );
  }

  /// The step goals, the one in force ticked (Swift's context-menu
  /// picker).
  Future<void> _chooseStepGoal(
    BuildContext context,
    ValueChanged<int> onSelected,
  ) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goal = await showAppSheet<int>(
      context: context,
      size: AppSheetSize.compact,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l,
          ),
          children: [
            AppSection(
              header: l10n.todayStepGoal,
              children: [
                for (final choice in stepGoalChoices)
                  AppSelectableRow(
                    title: l10n.todayStepGoalChoice(
                      AppFormat.number(choice, locale: locale),
                    ),
                    selected: choice == stepGoal,
                    onPressed: () => Navigator.of(context).pop(choice),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (goal != null) onSelected(goal);
  }

  /// Where the item leads (Swift `onChecklistItemPressed`): the workout
  /// done today, or the one planned; on a rest day or with nothing to open,
  /// an empty workout. The day's meals; for the weigh-in, the weigh-ins once
  /// today's is in and logging one until then; the steps.
  VoidCallback? _destination(BuildContext context) => switch (item) {
    TrainingItem(:final session?) => () => context.goNamed(
      WorkoutSessionDetailPage.name,
      pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: session.id},
    ),
    TrainingItem(:final planned?) when planned.exercises.isNotEmpty =>
      () => unawaited(
        WorkoutTemplateDetailPage.open(
          context,
          planned.workoutId,
          mesocycleId: workout?.run?.mesocycle.id,
          microcycleIndex: workout?.today?.cycleIndex,
          isDeload: workout?.isDeload ?? false,
        ),
      ),
    TrainingItem() => () {
      context.read<ActiveWorkoutCubit>().pressed(
        'TodayView_StartEmptyWorkout_Press',
      );
      unawaited(
        startWorkout(context, eventPrefix: 'TodayView_StartBlankWorkout'),
      );
    },
    WeighInItem(isDone: true) => () => context.goNamed(
      WeightMetric.scaleWeight.name,
    ),
    WeighInItem() => () => context.pushNamed(LogWeightPage.name),
    NutritionItem() => () => context.go(AppTab.nutrition.path),
    StepsItem() => () => context.goNamed(StepsPage.name),
  };
}
