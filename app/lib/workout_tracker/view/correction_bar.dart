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
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<ActiveWorkoutCubit>();
    final exercise = state.exercise(correction.exerciseId);
    final set = state.set(correction.setId);
    if (exercise == null || set == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = [
      l10n.setLabel(TrackerText.badge(l10n, set, exercise), ''),
      ?TrackerText.figures(
        l10n,
        set,
        exercise.trackingMode,
        // The card's unit for the exercise, as its rows show it.
        state.card
                .where((member) => member.exercise.id == exercise.id)
                .firstOrNull
                ?.weightUnit ??
            exercise.weightUnit ??
            ExerciseWeightUnit.kilograms,
        locale: locale,
      ),
    ].join(' · ');
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s,
      children: [
        if (correction.correctsReps) ...[
          IconButton.filledTonal(
            tooltip: l10n.trackerRemoveRep,
            onPressed: correction.canRemoveRep
                ? () => cubit.correctReps(correction.setId, -1)
                : null,
            icon: const Icon(AppSymbols.decrease),
          ),
          IconButton.filledTonal(
            tooltip: l10n.trackerAddRep,
            onPressed: () => cubit.correctReps(correction.setId, 1),
            icon: const Icon(AppSymbols.add),
          ),
        ],
        TextButton(
          onPressed: state.undoName == null ? null : cubit.undo,
          child: Text(
            l10n.trackerUndo,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    final summary = Semantics(
      label: TrackerText.logged(l10n, set, exercise, locale: locale),
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
            child: Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
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
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
