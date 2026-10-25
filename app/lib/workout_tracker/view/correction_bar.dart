import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The set just logged, over the log button while its rest runs: a rep off
/// or on, reps in reserve and Undo (`WorkoutCorrectionBar`). Off the card,
/// so the set table stays sets only.
class CorrectionBar extends StatelessWidget {
  const new({required this.state, required this.correction, super.key});

  final ActiveWorkoutState state;
  final SetCorrection correction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final exercise = state.exercise(correction.exerciseId);
    final set = state.set(correction.setId);
    if (exercise == null || set == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    // "Bench Press · Set 2 · 100 kg × 8": the exercise is named, as the
    // bar shows on whichever card is open (`restCorrection`).
    final title = [
      exercise.name,
      l10n.setLabel(TrackerText.badge(l10n, set, exercise), ''),
      ?TrackerText.figures(
        l10n,
        set,
        exercise.trackingMode,
        // The set's own exercise's unit, whichever card is open.
        exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
        locale: locale,
      ),
    ].join(' · ');
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s,
      children: [
        if (correction.correctsReps) ...[
          AppIconButton(
            icon: AppSymbols.decrease,
            semanticLabel: l10n.trackerRemoveRep,
            onPressed: correction.canRemoveRep
                ? () => cubit.correctReps(correction.setId, -1)
                : null,
          ),
          AppIconButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.trackerAddRep,
            onPressed: () => cubit.correctReps(correction.setId, 1),
          ),
        ],
        AppTextButton(
          label: l10n.trackerUndo,
          onPressed: state.undoName == null ? null : cubit.undo,
        ),
      ],
    );
    final summary = Semantics(
      label:
          '${exercise.name}, '
          '${TrackerText.logged(l10n, set, exercise, locale: locale)}',
      excludeSemantics: true,
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          Icon(
            AppSymbols.success,
            color: context.appColors.success,
            size: AppIconSize.small.of(context),
          ),
          Flexible(
            child: Text(title, style: AppTextStyles.label.semibold.tabular),
          ),
        ],
      ),
    );
    return Padding(
      // In line with the button under it.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        0,
      ),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xxs,
            children: [
              if (isLarge) ...[
                summary,
                buttons,
              ] else
                Row(
                  children: [
                    Expanded(child: summary),
                    buttons,
                  ],
                ),
              if (correction.showsRir)
                Row(
                  spacing: AppSpacing.s,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        l10n.trackerRirTitle,
                        style: AppTextStyles.label.secondary(context),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final chip in r.ActiveWorkout.rirChips)
                              Semantics(
                                label: l10n.trackerRirChip(
                                  r.EffortScale.rirText(chip),
                                ),
                                excludeSemantics: true,
                                child: AppChip(
                                  label: r.EffortScale.rirText(chip),
                                  selected: correction.selectedRir == chip,
                                  onPressed: () =>
                                      cubit.setRir(correction.setId, chip),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
