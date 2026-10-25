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
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
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
    this.celebrated = const {},
    this.workout,
    this.onItemPressed,
    this.onStepGoalSelected,
    this.weighIn,
    super.key,
  });

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
    final colors = context.appColors;
    final hasSteps = checklist.items.any((item) => item is StepsItem);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        AppSection(
          header: l10n.todayYourDay,
          trailing: checklist.isComplete
              ? AppChip(
                  label: l10n.todayDayComplete,
                  icon: AppSymbols.success,
                  tint: colors.accentInk,
                )
              : Text(
                  l10n.todayDoneCount(
                    checklist.doneCount,
                    checklist.items.length,
                  ),
                ),
          children: [
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
              if ((item, weighIn) case (WeighInItem(isDone: false), final row?))
                row,
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: _Footer(
            lines: [
              (
                l10n.todayCalorieBandFooter,
                MethodInfo.calorieAdherenceBand(l10n),
              ),
              if (hasSteps)
                (
                  l10n.todayStepGoalFooter(AppFormat.number(stepGoal)),
                  MethodInfo.dailyStepGoal(l10n),
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
        child: InkWell(
          onTap: onTap,
          onLongPress: chooseGoal,
          child: AppListRow(
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

/// The footnotes, one line each, set close as one footer, each sentence
/// ending in an inline ⓘ that opens its method's sources (Swift's footer
/// of `Text`s with a `MethodInfoButton`). The ⓘ is a link within the
/// text, so it keeps the text's size.
class _Footer extends StatefulWidget {
  const new({required this.lines});

  final List<(String, MethodInfo)> lines;

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(int index, MethodInfo info) {
    while (_taps.length <= index) {
      _taps.add(TapGestureRecognizer());
    }
    return _taps[index]
      ..onTap = () => unawaited(
        showAppSheet<void>(
          context: context,
          builder: (_) => MethodInfoSheet(info: info),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final style = AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant);
    const glyph = AppSymbols.info;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (index, (text, info)) in widget.lines.indexed) ...[
            if (index > 0) const TextSpan(text: '\n'),
            TextSpan(text: '$text '),
            TextSpan(
              text: String.fromCharCode(glyph.codePoint),
              semanticsLabel: l10n.methodInfoButtonLabel(info.title),
              recognizer: _tap(index, info),
              style: style.copyWith(
                fontFamily: glyph.fontFamily,
                package: glyph.fontPackage,
                color: context.appColors.accentInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
