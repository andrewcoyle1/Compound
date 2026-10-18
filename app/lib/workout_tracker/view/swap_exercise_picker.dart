import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_tracker/cubit/swap_exercise_picker_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Swap Exercise (Swift `SwapExercisePickerView`), over the tracker: the
/// plan's alternatives first, then the whole library. Pops with the
/// exercise chosen, or null when closed.
class SwapExercisePicker extends StatelessWidget {
  const new({required this.library, required this.alternativeIds, super.key});

  /// Opens the picker on [library], with [alternativeIds] first.
  static Future<ExerciseModel?> show(
    BuildContext context, {
    required List<ExerciseModel> library,
    required List<String> alternativeIds,
  }) => Navigator.of(context).push<ExerciseModel>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          SwapExercisePicker(library: library, alternativeIds: alternativeIds),
    ),
  );

  final List<ExerciseModel> library;
  final List<String> alternativeIds;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SwapExercisePickerCubit(
        library: library,
        alternativeIds: alternativeIds,
        analytics: context.read<AnalyticsRepository>(),
      )..appeared(),
      child: const SwapExercisePickerView(),
    );
  }
}

class SwapExercisePickerView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<SwapExercisePickerCubit>().state;
    final planned = state.plannedAlternatives;
    final header = AppTextStyles.sectionTitle.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return AppScaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(l10n.swapExerciseTitle),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: LibrarySearchField(
                hint: l10n.exercisesSearchHint,
                onChanged: context
                    .read<SwapExercisePickerCubit>()
                    .searchChanged,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (planned.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.s,
                        AppSpacing.l,
                        AppSpacing.xs,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.swapPlannedAlternatives,
                          style: header,
                        ),
                      ),
                    ),
                    for (final exercise in planned) _Row(exercise),
                    const Divider(),
                  ],
                  for (final exercise in state.exercises) _Row(exercise),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new(this.exercise);

  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    void choose() {
      context.read<SwapExercisePickerCubit>().selected(exercise);
      Navigator.of(context).pop(exercise);
    }

    return Semantics(
      button: true,
      label: exercise.name,
      onTap: choose,
      excludeSemantics: true,
      child: InkWell(
        onTap: choose,
        child: AppListRow(
          title: exercise.name,
          thumbnail: ExerciseImage(exercise),
        ),
      ),
    );
  }
}
