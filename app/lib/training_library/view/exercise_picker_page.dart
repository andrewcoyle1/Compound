import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/training_library/cubit/exercise_list_cubit.dart';
import 'package:compound/training_library/cubit/exercise_picker_cubit.dart';
import 'package:compound/training_library/view/exercise_list.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What the exercise picker is opened with: the exercises already in the
/// caller's list, shown ticked and never added twice, and those not to
/// offer.
final class const ExercisePickerRequest({
  final Set<String> committedIds = const {},
  final Set<String> excludedIds = const {},
});

/// Picks several exercises at once (Swift `ExercisesPickerView`), over the
/// tabs. Pops with the newly ticked exercises in the order they were
/// ticked, or null when closed.
///
/// ```dart
/// final picked = await ExercisePickerPage.show(context);
/// ```
class ExercisePickerPage extends StatelessWidget {
  const new({this.request = const ExercisePickerRequest(), super.key});

  /// The route's path.
  static const path = '/exercise-picker';

  /// The route name.
  static const name = 'exercisePicker';

  /// Opens the picker; the result is null when it was closed.
  static Future<List<ExerciseModel>?> show(
    BuildContext context, {
    ExercisePickerRequest request = const ExercisePickerRequest(),
  }) => context.pushNamed<List<ExerciseModel>>(name, extra: request);

  final ExercisePickerRequest request;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ExerciseListCubit(
              analytics: context.read<AnalyticsRepository>(),
            )..appeared('ExercisesPickerView'),
          ),
          BlocProvider(
            create: (_) => ExercisePickerCubit(
              committedIds: request.committedIds,
              excludedIds: request.excludedIds,
            ),
          ),
        ],
        child: const ExercisePickerView(),
      ),
    );
  }
}

class ExercisePickerView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ExercisePickerCubit>().state;
    return PopScope<List<ExerciseModel>>(
      // Ticked exercises are lost if the picker closes, so it asks first.
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard(context));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: CloseButton(onPressed: () => _close(context)),
          title: Text(
            state.picked.isEmpty
                ? l10n.pickerTitleEmpty
                : l10n.pickerTitleCount(state.picked.length),
          ),
          actions: [
            IconButton(
              icon: const Icon(AppSymbols.selected),
              tooltip: l10n.pickerAdd,
              onPressed: state.canSave
                  ? () => _dismiss(context, state.picked)
                  : null,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: ExerciseList(
            onExercisePressed: context.read<ExercisePickerCubit>().toggled,
            isSelected: (exercise) => state.isSelected(exercise.id),
            // Unlike Swift, a new exercise comes back ticked (the owner's
            // call).
            onCreateExercise: () => unawaited(_create(context)),
          ),
        ),
      ),
    );
  }

  static Future<void> _create(BuildContext context) async {
    final cubit = context.read<ExercisePickerCubit>();
    final created = await CreateExercisePage.open(context);
    if (created != null && !cubit.isClosed) cubit.toggled(created);
  }

  static Future<void> _close(BuildContext context) async {
    final cubit = context.read<ExercisePickerCubit>();
    if (cubit.state.hasUnsavedChanges) return await _confirmDiscard(context);
    _dismiss(context, null);
  }

  static Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepEditingButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardChangesButton),
          ),
        ],
      ),
    );
    if ((discard ?? false) && context.mounted) _dismiss(context, null);
  }

  static void _dismiss(BuildContext context, List<ExerciseModel>? picked) {
    if (context.canPop()) {
      // Past the PopScope: the choice to leave has been made.
      Navigator.of(context).pop(picked);
    } else {
      context.go(AppTab.training.path);
    }
  }
}
