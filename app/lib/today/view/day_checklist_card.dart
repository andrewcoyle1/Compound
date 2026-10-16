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
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The day's checklist at the top of Today (Swift `DayChecklistCard`):
/// each item says whether it is done, and opens the screen behind it. The
/// Steps item, held, offers the step goals. The footer says how "on
/// target" and the step goal are judged, each with its sources.
class DayChecklistCard extends StatelessWidget {
  const new({
    required this.checklist,
    required this.stepGoal,
    required this.unit,
    this.workout,
    this.onItemPressed,
    this.onStepGoalSelected,
    super.key,
  });

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
                _ItemRow(
                  item: item,
                  unit: unit,
                  workout: workout,
                  stepGoal: stepGoal,
                  onPressed: onItemPressed,
                  onStepGoalSelected: onStepGoalSelected,
                ),
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
  const new({
    required this.item,
    required this.unit,
    required this.workout,
    required this.stepGoal,
    required this.onPressed,
    required this.onStepGoalSelected,
  });

  final ChecklistItem item;
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
        child: InkWell(
          onTap: onTap,
          onLongPress: chooseGoal,
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

  /// The step goals, the one in force ticked (Swift's context-menu
  /// picker).
  Future<void> _chooseStepGoal(
    BuildContext context,
    ValueChanged<int> onSelected,
  ) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goal = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: AppSection(
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
