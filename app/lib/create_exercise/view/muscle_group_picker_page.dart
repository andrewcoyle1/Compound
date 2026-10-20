import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/create_exercise/cubit/muscle_group_picker_cubit.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/create_exercise/view/exercise_equipment_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The muscles the new exercise works (Swift `MuscleGroupPickerView`).
class MuscleGroupPickerPage extends StatelessWidget {
  const new({required this.draft, super.key});

  final ExerciseDraft draft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MuscleGroupPickerCubit(
        draft: draft,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const MuscleGroupPickerView(),
    );
  }
}

class MuscleGroupPickerView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<MuscleGroupPickerCubit>();
    final state = context.watch<MuscleGroupPickerCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // Fewer, wider tiles at large text, so names wrap rather than clip.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale >= 2 ? 1 : (scale >= 1.3 ? 2 : 3);
    // A wrap rather than a grid: no scrollable nested in the list.
    Widget grid(List<Muscles> muscles) => Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              (constraints.maxWidth - AppSpacing.s * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final muscle in muscles)
                SizedBox(
                  width: width,
                  child: _MuscleTile(
                    muscle: muscle,
                    selected: state.selected[muscle],
                    onPressed: () {
                      unawaited(AppHaptics.selection());
                      cubit.pressed(muscle);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: AppScaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.createExerciseSelectMuscles),
              Text(
                l10n.createExerciseMuscleCounts(
                  state.primaryCount,
                  state.secondaryCount,
                ),
                style: AppTextStyles.rowDetail.copyWith(color: secondary),
              ),
            ],
          ),
          actions: [
            if (state.selected.isNotEmpty)
              AppTextButton(
                key: const Key('MuscleGroupPicker.reset'),
                label: l10n.createExerciseReset,
                onPressed: cubit.reset,
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: LibrarySections(
            children: [
              Text(
                l10n.createExerciseMuscleInstruction,
                style: AppTextStyles.rowDetail.copyWith(color: secondary),
              ),
              AppSection(
                header: l10n.muscleRegionUpper,
                children: [grid(ExerciseDefinitionRules.upperMuscles)],
              ),
              AppSection(
                header: l10n.muscleRegionLower,
                children: [grid(ExerciseDefinitionRules.lowerMuscles)],
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('MuscleGroupPicker.next'),
              label: state.selected.isEmpty
                  ? l10n.createExerciseSkip
                  : l10n.createExerciseNext,
              variant: state.selected.isEmpty
                  ? AppCtaVariant.secondary
                  : AppCtaVariant.primary,
              onPressed: () => unawaited(
                pushCreateStep(
                  context,
                  ExerciseEquipmentPage(draft: cubit.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One muscle: tapped once for primary, again for secondary, a third time
/// to clear. Primary has the thicker ring, and the badge names which, so
/// the two never differ by colour alone.
class _MuscleTile extends StatelessWidget {
  const new({
    required this.muscle,
    required this.selected,
    required this.onPressed,
  });

  final Muscles muscle;
  final MuscleTargetType? selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = this.selected;
    final level = switch (selected) {
      MuscleTargetType.primary => l10n.musclePrimary,
      MuscleTargetType.secondary => l10n.muscleSecondary,
      null => l10n.createExerciseNotSelected,
    };
    const radius = BorderRadius.all(Radius.circular(AppRadius.l));
    return Semantics(
      key: Key('MuscleGroupPicker.${muscle.value}'),
      button: true,
      selected: selected != null,
      label: l10n.muscleName(muscle),
      value: level,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected == null
              ? BorderSide.none
              : BorderSide(
                  color: scheme.primary,
                  width: selected == MuscleTargetType.primary ? 4 : 2,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(AppSpacing.s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  l10n.muscleName(muscle),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.rowDetail,
                ),
                if (selected != null) AppChip(label: level, selected: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
