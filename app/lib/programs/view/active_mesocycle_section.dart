import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/coach.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/logic/microcycle_view.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// The Training tab's active mesocycle (Swift `ActiveMesocycleView`): its
/// header, a picker for the microcycle shown, and that microcycle's days.
/// A day opens its workout, a finished one its session, a rest day ticks;
/// an open workout can be skipped, and the mesocycle opened (Info), asked
/// about (Ask Coach) or deleted.
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
    final state = context.watch<ProgramsCubit>().state;
    final mesocycle = widget.mesocycle;
    final scheme = Theme.of(context).colorScheme;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
          child: Row(
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.programActiveMesocycle,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (view?.isDeload ?? false)
                MethodInfoButton(MethodInfo.mesocycleDeload(l10n)),
              const Spacer(),
              if (view == null)
                Text(
                  header,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                _MicrocycleMenu(
                  view: view,
                  label: header,
                  onSelected: (index) => setState(
                    () => _viewed = index == view.currentCycleIndex
                        ? null
                        : index,
                  ),
                ),
            ],
          ),
        ),
        AppSection(
          children: [
            // Swift's swipe actions on the header, as its menu offers.
            AppSwipeActions(
              trailing: [
                AppSwipeAction(
                  label: l10n.programDelete,
                  icon: AppSymbols.delete,
                  isDestructive: true,
                  onPressed: () => unawaited(_delete(context)),
                ),
                AppSwipeAction(
                  label: l10n.programInfo,
                  icon: AppSymbols.info,
                  onPressed: () => unawaited(
                    MesocycleDesignPage.edit(context, mesocycle.id),
                  ),
                ),
                AppSwipeAction(
                  label: l10n.coachAskCoach,
                  icon: AppSymbols.coach,
                  onPressed: () => CoachPage.open(
                    context,
                    CoachContext(
                      kind: CoachContextKind.mesocycle,
                      id: mesocycle.id,
                      title: mesocycle.name,
                    ),
                  ),
                ),
              ],
              child: MesocycleHeader(
                mesocycle: mesocycle,
                isDeload: view?.isDeload ?? false,
                phase: view?.phase,
                trailing: PopupMenuButton<void>(
                  icon: Icon(AppSymbols.more),
                  tooltip: l10n.programMesocycleOptions,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => unawaited(
                        MesocycleDesignPage.edit(context, mesocycle.id),
                      ),
                      child: Text(l10n.programInfo),
                    ),
                    PopupMenuItem(
                      onTap: () => CoachPage.open(
                        context,
                        CoachContext(
                          kind: CoachContextKind.mesocycle,
                          id: mesocycle.id,
                          title: mesocycle.name,
                        ),
                      ),
                      child: Text(l10n.coachAskCoach),
                    ),
                    PopupMenuItem(
                      onTap: () => unawaited(_delete(context)),
                      child: Text(
                        l10n.programDeleteMesocycle,
                        style: TextStyle(color: context.appColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final item in view?.items ?? const <MicrocycleItem>[])
              _DayRow(
                item: item,
                onPressed: () => unawaited(_pressed(context, item, view!)),
                onSkip: item.canSkip
                    ? () => unawaited(_skip(context, item))
                    : null,
              ),
          ],
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

  static Future<void> _feedback(bool ok) => ok
      ? HapticFeedback.successNotification()
      : HapticFeedback.errorNotification();
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
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.s,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xxs,
            children: [
              Text(
                label,
                style: AppTextStyles.rowDetail.copyWith(
                  color: secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Icon(AppSymbols.choose, color: secondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A day of the microcycle (Swift `MicrocycleItemRow`): the same circle on
/// every day, filled when done. A swipe or a long press offers Skip.
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
      child: Semantics(
        button: true,
        value: value,
        hint: item.canToggleRest
            ? (item.isCompleted
                  ? l10n.programRestUntickHint
                  : l10n.programRestTickHint)
            : null,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onSkip == null
              ? null
              : () => unawaited(_offerSkip(context, onSkip)),
          child: DayPlanRow(
            plan: item.slot.dayPlan,
            badge: badge,
            trailing: ExcludeSemantics(
              child: Icon(
                item.isCompleted
                    ? AppSymbols.success
                    : item.isSkipped
                    ? AppSymbols.skip
                    : AppSymbols.choiceUnselected,
                color: item.isCompleted ? scheme.primary : scheme.outline,
              ),
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
    final skip = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: AppListRowButton(
          title: context.l10n.programSkip,
          icon: AppSymbols.skip,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (skip ?? false) onSkip();
  }
}
