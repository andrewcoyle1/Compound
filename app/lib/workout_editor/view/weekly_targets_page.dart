import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_editor/cubit/set_target_cubit.dart';
import 'package:compound/workout_editor/cubit/weekly_targets_cubit.dart';
import 'package:compound/workout_editor/logic/editor_text.dart';
import 'package:compound/workout_editor/view/editor_widgets.dart';
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// How a template exercise's targets vary by week (Swift
/// `WeeklyTargetsView`): a section per variation with its first week and
/// its targets, and Add Week. Each change goes to [onChange].
class const WeeklyTargetsPage({
  required final WorkoutTemplateExercise exercise,
  required final WorkoutSettings settings,
  required final void Function(List<MicrocycleSetTargets>) onChange,
  final List<ExerciseModel> library = const [],
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WeeklyTargetsCubit(
        exercise: exercise,
        onChange: onChange,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: WeeklyTargetsView(settings: settings, library: library),
    );
  }
}

class WeeklyTargetsView extends StatelessWidget {
  const new({required this.settings, this.library = const [], super.key});

  final WorkoutSettings settings;
  final List<ExerciseModel> library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<WeeklyTargetsCubit>();
    final state = context.watch<WeeklyTargetsCubit>().state;
    final text = EditorText(l10n);
    return AppScaffold(
      appBar: AppBar(
        title: EditorTitle(
          title: l10n.editorWeeklyTargets,
          subtitle: state.exercise.exercise.name,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              footer: l10n.editorWeeklyFooter,
              children: [
                AppListRow(
                  title: text.variationSummary(
                    state.exercise.setTargets,
                    state.overrides,
                  ),
                ),
              ],
            ),
            for (final variation in state.variations) ...[
              const SizedBox(height: AppSpacing.l),
              Dismissible(
                key: ValueKey(variation.id),
                direction: DismissDirection.endToStart,
                background: DeleteBackground(label: l10n.editorDelete),
                onDismissed: (_) => cubit.delete(variation),
                child: AppSection(
                  children: [
                    AppListRow(
                      title: l10n.editorFromWeek(variation.fromMicrocycle),
                      accessory: AppListRowCustom(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(AppSymbols.decrease),
                              tooltip: l10n.editorDecrease,
                              onPressed: state.canStep(variation, -1)
                                  ? () => _step(cubit, variation, -1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(AppSymbols.increase),
                              tooltip: l10n.editorIncrease,
                              onPressed: state.canStep(variation, 1)
                                  ? () => _step(cubit, variation, 1)
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(
                                AppSymbols.delete,
                                color: context.appColors.danger,
                              ),
                              tooltip: l10n.editorDelete,
                              onPressed: () => cubit.delete(variation),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppListRowButton(
                      key: Key('WeeklyTargets.targets.${variation.id}'),
                      title: l10n.editorTargets,
                      subtitle: l10n.setCount(variation.setTargets.length),
                      onPressed: () => unawaited(_edit(context, variation)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            AppSection(
              children: [
                AppListRowButton(
                  key: const Key('WeeklyTargets.add'),
                  title: l10n.editorAddWeek,
                  icon: AppSymbols.add,
                  onPressed: state.nextWeek == null ? null : cubit.add,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _step(WeeklyTargetsCubit cubit, Variation variation, int delta) {
    unawaited(HapticFeedback.selectionClick());
    cubit.step(variation, delta);
  }

  /// The week's own targets in the targets editor, saved back to it.
  Future<void> _edit(BuildContext context, Variation variation) async {
    final cubit = context.read<WeeklyTargetsCubit>();
    final edited = await openSetTarget(
      context,
      cubit.state.exerciseFor(variation),
      scope: WeekScope(variation.fromMicrocycle),
      settings: settings,
      library: library,
    );
    if (edited != null) cubit.targetsEdited(variation.id, edited.setTargets);
  }
}
