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

/// The workout under way, over the tab bar while the tracker is minimised:
/// its name and clock; a tap opens the tracker.
class ActiveWorkoutBar extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ActiveWorkoutCubit>().state;
    final session = state.session;
    if (!state.isActive || session == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.tintedSurface(scheme.primary),
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => WorkoutTrackerPage.show(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              child: Row(
                spacing: AppSpacing.m,
                children: [
                  Icon(AppSymbols.workout, color: scheme.primary),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackerInProgress,
                          style: AppTextStyles.label.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          session.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.rowTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tick(
                    builder: (context, now) => Text(
                      state.isPaused
                          ? l10n.trackerPaused
                          : AppFormat.duration(state.elapsedAt(now)),
                      style: AppTextStyles.rowDetail.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(AppSymbols.disclosure, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
