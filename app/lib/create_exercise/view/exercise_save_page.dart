import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/create_exercise/cubit/exercise_save_cubit.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The review, and Create (Swift `ExerciseSaveView`). Create closes the
/// flow with the new exercise, which a picker that opened it ticks (Swift
/// leaves it unticked; the owner asked for this).
class ExerciseSavePage extends StatelessWidget {
  const new({required this.draft, super.key});

  final ExerciseDraft draft;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    return BlocProvider(
      create: (context) => ExerciseSaveCubit(
        draft: draft,
        uid: app is AppAuthenticated ? app.user.uid : null,
        library: context.read<TrainingLibraryRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: ExerciseSaveView(draft: draft),
    );
  }
}

class ExerciseSaveView extends StatelessWidget {
  const new({required this.draft, super.key});

  /// The exercise to create.
  final ExerciseDraft draft;

  static Future<void> _done(
    BuildContext context,
    ExerciseSaveState state,
  ) async {
    final l10n = context.l10n;
    if (state.status == ExerciseSaveStatus.saved) {
      unawaited(AppHaptics.success());
      CreateExerciseFlow.close(context, state.created);
      return;
    }
    unawaited(AppHaptics.error());
    await showFailureAlert(
      context,
      l10n.createExerciseFailed,
      l10n.editorTryAgain,
    );
    if (context.mounted) context.read<ExerciseSaveCubit>().failureShown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseSaveCubit>();
    final status = context.watch<ExerciseSaveCubit>().state.status;
    final library = switch (context.watch<TrainingLibraryBloc>().state) {
      TrainingLibraryLoaded(:final library) => library,
      _ => null,
    };
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: BlocListener<ExerciseSaveCubit, ExerciseSaveState>(
        listenWhen: (previous, current) =>
            current.status == ExerciseSaveStatus.saved ||
            current.status == ExerciseSaveStatus.failed,
        listener: (context, state) => unawaited(_done(context, state)),
        child: AppScaffold(
          appBar: AppBar(title: Text(l10n.createExerciseSave)),
          body: SafeArea(
            bottom: false,
            child: library == null
                ? AppLoadingView(label: context.l10n.launchLoading)
                : ExerciseAbout(
                    // Only shown: the id and dates are made on Create.
                    exercise: draft.toModel(
                      id: '',
                      authorId: '',
                      now: DateTime.utc(2000),
                    ),
                    library: library,
                  ),
          ),
          bottomNavigationBar: AppBottomCta(
            children: [
              AppCtaButton(
                key: const Key('ExerciseSave.create'),
                label: l10n.createExerciseCreate,
                isLoading: status == ExerciseSaveStatus.saving,
                onPressed: status == ExerciseSaveStatus.saving
                    ? null
                    : () => unawaited(cubit.create()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
