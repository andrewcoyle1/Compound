import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/coach.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/logic/microcycle_view.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/mesocycle_style.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// The Training tab's hero (Swift `ActiveMesocycleView`): the active
/// mesocycle's microcycle as one card. The workouts done out of those
/// planned lead in the largest number on the screen, beside a ring
/// filling in the accent, with the microcycle's days under it. The
/// header's chip picks the microcycle shown, and its menu opens the
/// mesocycle (Info), asks about it (Ask Coach) or deletes it. A day opens
/// its workout, a finished one its session, a rest day ticks; an open
/// workout can be skipped.
class const ActiveMesocycleSection({
  required final Mesocycle mesocycle,
  super.key,
}) extends StatefulWidget {
  @override
  State<ActiveMesocycleSection> createState() => _ActiveMesocycleSectionState();
}

class _ActiveMesocycleSectionState extends State<ActiveMesocycleSection> {
  /// The microcycle looked at, from 0; null follows the one the user is on.
  int? _viewed;

  static const _screen = 'ActiveTrainingProgramView';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final state = context.watch<ProgramsCubit>().state;
    final mesocycle = widget.mesocycle;
    final view = mesocycle.workoutTemplates.isEmpty
        ? null
        : MicrocycleView.build(
            state.runOf(mesocycle),
            state.sessions,
            now: DateTime.now(),
            viewedCycleIndex: _viewed,
          );
    final header = view == null
        ? l10n.programCurrentMicrocycle
        : _headerText(l10n, state.currentMacrocycle, view);
    final items = view?.items ?? const <MicrocycleItem>[];
    final workouts = items.where((item) => !item.isRest);
    final total = workouts.length;
    final done = workouts.where((item) => item.isCompleted).length;
    final isDeload = view?.isDeload ?? false;
    final phase = view?.phase;
    return AppSummaryCard(
      title: mesocycle.name,
      icon: mesocycleGlyph(mesocycle.icon),
      tint: AppColors.fromHex(mesocycle.colour) ?? colors.accentInk,
      size: AppSummaryCardSize.hero,
      value: '${AppFormat.number(done)}/${AppFormat.number(total)}',
      unit: l10n.trainingWorkoutsDoneUnit,
      // The microcycle finished is the user's own progress: the accent.
      delta: total > 0 && done == total
          ? AppChip(
              label: l10n.trainingMicrocycleDone,
              icon: AppSymbols.success,
              selected: true,
            )
          : isDeload
          ? AppChip(label: l10n.programDeloadWeek)
          : null,
      // A line on the card: volt in dark mode, olive in light. The number
      // carries the figure, so the ring keeps its size at large text.
      chart: MediaQuery.withNoTextScaling(
        child: ProgressArc(
          value: total == 0 ? 0 : done / total,
          color: colors.accentInk,
          diameter: 2 * AppControlSize.cta,
          strokeWidth: AppChartMark.arcWidthHero,
        ),
      ),
      chartBeside: true,
      footer: phase == null ? null : phaseLabel(l10n, phase),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDeload) MethodInfoButton(MethodInfo.mesocycleDeload(l10n)),
          if (view == null)
            AppChip(label: header)
          else
            _MicrocycleMenu(
              view: view,
              label: header,
              onSelected: (index) => setState(
                () => _viewed = index == view.currentCycleIndex ? null : index,
              ),
            ),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            icon: Icon(AppSymbols.more),
            tooltip: l10n.programMesocycleOptions,
            itemBuilder: (_) => [
              AppMenuItem(
                value: () =>
                    unawaited(MesocycleDesignPage.edit(context, mesocycle.id)),
                label: l10n.programInfo,
              ),
              AppMenuItem(
                value: () => CoachPage.open(
                  context,
                  CoachContext(
                    kind: CoachContextKind.mesocycle,
                    id: mesocycle.id,
                    title: mesocycle.name,
                  ),
                ),
                label: l10n.coachAskCoach,
              ),
              AppMenuItem(
                value: () => unawaited(_delete(context)),
                label: l10n.programDeleteMesocycle,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
      rows: [
        for (final item in items)
          _DayRow(
            item: item,
            onPressed: () => unawaited(_pressed(context, item, view!)),
            onSkip: item.canSkip ? () => unawaited(_skip(context, item)) : null,
          ),
      ],
    );
  }

  /// "Micro 2/4", or "Meso 1/3 · Micro 2/4" inside a longer macrocycle.
  String _headerText(
    AppLocalizations l10n,
    Macrocycle? macrocycle,
    MicrocycleView view,
  ) {
    final micro = l10n.programMicroHeader(
      view.displayedCycleIndex + 1,
      view.cycleCount,
    );
    if (macrocycle != null &&
        macrocycle.mesocycleIds.length > 1 &&
        macrocycle.currentMesocycleId == widget.mesocycle.id) {
      return l10n.programMesoHeader(
        macrocycle.mesocycleIndex + 1,
        macrocycle.mesocycleIds.length,
        micro,
      );
    }
    return micro;
  }

  Future<void> _pressed(
    BuildContext context,
    MicrocycleItem item,
    MicrocycleView view,
  ) async {
    final cubit = context.read<ProgramsCubit>();
    final mesocycle = widget.mesocycle;
    if (item.isRest) {
      if (!item.canToggleRest) return;
      final ok = await cubit.succeeded(
        (c) => c.toggleRestDay(item.slot, mesocycle.id),
      );
      await _feedback(ok);
      if (!ok && context.mounted) {
        await showFailureAlert(context, context.l10n.programRestFailed);
      }
      return;
    }
    if (item.slot.completedSessionId case final sessionId?) {
      cubit.pressed('${_screen}_OpenCompletedSession_Start');
      if (!cubit.state.sessions.any((s) => s.id == sessionId)) {
        cubit.pressed('${_screen}_OpenCompletedSession_Fail');
        return;
      }
      unawaited(
        context.pushNamed(
          WorkoutSessionDetailPage.name,
          pathParameters: {
            WorkoutSessionDetailPage.sessionIdParameter: sessionId,
          },
        ),
      );
      cubit.pressed('${_screen}_OpenCompletedSession_Success');
      return;
    }
    await WorkoutTemplateDetailPage.open(
      context,
      item.slot.dayPlan.workoutId,
      mesocycleId: mesocycle.id,
      microcycleIndex: view.displayedCycleIndex + 1,
      isDeload: view.isDeload,
      allowsStart: item.timing == MicrocycleTiming.current && !item.isSkipped,
    );
  }

  Future<void> _skip(BuildContext context, MicrocycleItem item) async {
    final ok = await context.read<ProgramsCubit>().succeeded(
      (c) => c.skip(item.slot, eventPrefix: _screen),
    );
    await _feedback(ok);
    if (!ok && context.mounted) {
      await showFailureAlert(context, context.l10n.programSkipFailed);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.programDeleteMesocycle,
      message: l10n.programDeleteActiveMessage,
      confirmLabel: l10n.programDelete,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await context.read<ProgramsCubit>().succeeded(
      (c) => c.deleteMesocycle(widget.mesocycle, eventPrefix: _screen),
    );
    if (!ok && context.mounted) {
      await showFailureAlert(
        context,
        l10n.programDeleteFailed,
        l10n.programTryAgain,
      );
    }
  }

  static Future<void> _feedback(bool ok) =>
      ok ? AppHaptics.success() : AppHaptics.error();
}

/// The microcycle picker in the section header.
class const _MicrocycleMenu({
  required final MicrocycleView view,
  required final String label,
  required final ValueChanged<int> onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.programChooseMicrocycle,
      value: label,
      button: true,
      excludeSemantics: true,
      child: PopupMenuButton<int>(
        initialValue: view.displayedCycleIndex,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (var index = 0; index < view.cycleCount; index++)
            CheckedPopupMenuItem(
              value: index,
              checked: index == view.displayedCycleIndex,
              child: Text(
                index == view.currentCycleIndex
                    ? l10n.programMicrocycleCurrent(index + 1)
                    : l10n.programMicrocycleNumber(index + 1),
              ),
            ),
        ],
        // The chip is the menu's face; the menu takes the tap.
        child: AppChip(label: label, icon: AppSymbols.choose),
      ),
    );
  }
}

/// A day of the microcycle (Swift `MicrocycleItemRow`): its name, what it
/// holds, and a mark at the trailing edge: volt and ticked when done, an
/// empty circle when not. The day the schedule puts on today leads with
/// the start glyph in the accent. A swipe or a long press offers Skip.
class const _DayRow({
  required final MicrocycleItem item,
  required final VoidCallback onPressed,
  final VoidCallback? onSkip,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final onSkip = this.onSkip;
    final badge = item.isToday
        ? l10n.tabToday
        : item.isBeforeStart
        ? l10n.programNotTracked
        : null;
    final value = item.isCompleted
        ? l10n.programDayCompleted
        : item.isSkipped
        ? l10n.programDaySkipped
        : item.isBeforeStart
        ? l10n.programNotTracked
        : item.timing == MicrocycleTiming.future
        ? l10n.programDayUpcoming
        : l10n.programDayNotStarted;
    final plan = item.slot.dayPlan;
    final muscles = [
      for (final (muscle, target) in TemplateSummary.muscleTags(
        plan,
        l10n.muscleName,
      ))
        if (target == MuscleTargetType.primary) l10n.muscleName(muscle),
    ];
    final subtitle = [
      ?badge,
      if (plan.exercises.isEmpty)
        l10n.programRest
      else ...[
        l10n.exerciseCount(plan.exercises.length),
        if (muscles.isNotEmpty) muscles.take(3).join(', '),
      ],
    ].join(' · ');
    // Swift's swipe action, which the long press also offers.
    return AppSwipeActions(
      trailing: [
        if (onSkip != null)
          AppSwipeAction(
            label: l10n.programSkip,
            icon: AppSymbols.skip,
            onPressed: onSkip,
          ),
      ],
      child: MergeSemantics(
        child: Semantics(
          value: value,
          hint: item.canToggleRest
              ? (item.isCompleted
                    ? l10n.programRestUntickHint
                    : l10n.programRestTickHint)
              : null,
          child: AppListRowButton(
            title: plan.name,
            subtitle: subtitle,
            icon: item.isToday
                ? AppSymbols.start
                : plan.exercises.isEmpty
                ? AppSymbols.restDay
                : AppSymbols.workout,
            tint: item.isToday ? context.appColors.accentInk : null,
            onPressed: onPressed,
            onLongPress: onSkip == null
                ? null
                : () => unawaited(_offerSkip(context, onSkip)),
            accessory: AppListRowCustom(
              item.isCompleted
                  ? const AppDoneMark()
                  : ExcludeSemantics(
                      child: Icon(
                        item.isSkipped
                            ? AppSymbols.skip
                            : AppSymbols.choiceUnselected,
                        size: AppIconSize.medium.of(context),
                        color: scheme.outline,
                      ),
                    ),
              pinned: true,
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _offerSkip(
    BuildContext context,
    VoidCallback onSkip,
  ) async {
    final skip = await showAppSheet<bool>(
      context: context,
      size: AppSheetSize.compact,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            children: [
              AppListRowButton(
                title: context.l10n.programSkip,
                icon: AppSymbols.skip,
                accessory: null,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (skip ?? false) onSkip();
  }
}
