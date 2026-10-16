import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/workout_tracker_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _ActiveChoice { resume, replace }

/// Starts [template]'s workout, or an empty one, and opens the tracker. With
/// a workout already under way it asks first: resume it, or discard it and
/// start this one (`showActiveWorkoutAlert`). [eventPrefix] names the
/// screen's start events, as Swift's. A program's day passes its
/// [mesocycleId], its [microcycleIndex] (from 1) and whether it is a
/// deload week.
Future<void> startWorkout(
  BuildContext context, {
  required String eventPrefix,
  WorkoutTemplateModel? template,
  String? mesocycleId,
  int? microcycleIndex,
  bool isDeload = false,
}) async {
  final l10n = context.l10n;
  final cubit = context.read<ActiveWorkoutCubit>();
  if (cubit.state.isActive) {
    final choice = await showDialog<_ActiveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackerActiveTitle),
        content: Text(l10n.trackerActiveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.trackerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ActiveChoice.replace),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.trackerReplaceButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ActiveChoice.resume),
            child: Text(l10n.trackerResumeButton),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _ActiveChoice.resume:
        await WorkoutTrackerPage.show(context);
        return;
      case _ActiveChoice.replace:
        break;
      case null:
        return;
    }
  }
  final before = cubit.state.effectId;
  await cubit.start(
    template: template,
    eventPrefix: eventPrefix,
    mesocycleId: mesocycleId,
    microcycleIndex: microcycleIndex,
    isDeload: isDeload,
  );
  if (!context.mounted) return;
  if (cubit.state.effectId != before &&
      cubit.state.effect is StartFailedEffect) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.startFailedTitle),
        content: Text(l10n.startFailedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.keypadDone),
          ),
        ],
      ),
    );
    return;
  }
  await WorkoutTrackerPage.show(context);
}

/// The workout under way, over the tabs while its tracker is minimised
/// (Swift `TrainingAccessoryView`): a ring of the sets done, the name over
/// "3/12 sets", and the rest counting down, with Skip Rest beside it, or
/// else the workout clock. A tap reopens the tracker.
class ActiveWorkoutBar extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ActiveWorkoutCubit>().state;
    final session = state.session;
    if (!state.isActive || session == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final progress = state.setProgress;
    final fraction = progress.total == 0 ? 0.0 : progress.done / progress.total;
    final digits = AppTextStyles.metricSmall.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Material(
      color: AppColors.tintedSurface(scheme.primary),
      child: Tick(
        builder: (context, now) {
          final restEnd = state.restEnd;
          final resting = restEnd != null && now.isBefore(restEnd);
          return Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.accessoryResumeLabel(
                    session.name,
                    state.elapsedAt(now).inMinutes,
                  ),
                  excludeSemantics: true,
                  child: InkWell(
                    key: const Key('ActiveWorkoutBar.open'),
                    onTap: () => WorkoutTrackerPage.show(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppControlSize.row,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.l,
                          AppSpacing.s,
                          AppSpacing.m,
                          AppSpacing.s,
                        ),
                        child: Row(
                          spacing: AppSpacing.m,
                          children: [
                            _ProgressRing(fraction: fraction),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.rowDetail.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${progress.done}/'
                                    '${l10n.setCount(progress.total)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.rowDetail.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // The rest in the accent, else the clock: the
                            // colour and Skip Rest say which.
                            Text(
                              resting
                                  ? AppFormat.duration(
                                      restEnd.difference(now) +
                                          const Duration(milliseconds: 999),
                                    )
                                  : state.isPaused
                                  ? l10n.trackerPaused
                                  : AppFormat.duration(state.elapsedAt(now)),
                              style: digits.copyWith(
                                color: resting
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Beside the bar's button rather than in it, so a screen
              // reader reaches it.
              if (resting)
                IconButton(
                  key: const Key('ActiveWorkoutBar.skipRest'),
                  tooltip: l10n.accessorySkipRest,
                  icon: const Icon(AppSymbols.skip),
                  color: scheme.primary,
                  onPressed: context.read<ActiveWorkoutCubit>().skipRestFromBar,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The sets done as a ring around the workout symbol.
class _ProgressRing extends StatelessWidget {
  const new({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                backgroundColor: AppColors.tintedSurface(scheme.primary),
              ),
            ),
            Icon(
              AppSymbols.workout,
              size: AppIconSize.small.of(context),
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
