import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_history/view/workout_history_page.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Training tab's root (Swift `TrainingView`): a search over exercises
/// and workouts, the active mesocycle's schedule (or a way to choose one),
/// and the Library. The calendar header and the + menu's New items wait
/// for their slices.
class TrainingPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: BlocProvider(
        create: (context) =>
            LibrarySearchCubit(analytics: context.read<AnalyticsRepository>()),
        child: const TrainingView(),
      ),
    );
  }
}

class TrainingView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = context.watch<LibrarySearchCubit>().state;
    final library = switch (context.watch<TrainingLibraryBloc>().state) {
      TrainingLibraryLoaded(:final library) => library,
      _ => null,
    };
    final searchField = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        0,
      ),
      child: LibrarySearchField(
        hint: l10n.trainingSearchHint,
        onChanged: context.read<LibrarySearchCubit>().queryChanged,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabTraining),
        actions: const [ProfileButton()],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchField,
            Expanded(
              child: SearchMatch.isSearching(query) && library != null
                  ? _SearchResults(library: library, query: query)
                  : const _Library(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything the user has built or done.
class _Library extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final programs = context.watch<ProgramsCubit>().state;
    final active = programs.activeMesocycle;
    return LibrarySections(
      children: [
        if (active != null)
          ActiveMesocycleSection(mesocycle: active)
        else if (programs.status == ProgramsStatus.loaded)
          AppSection(
            children: [
              LibraryEmptyState(
                icon: AppSymbols.mesocycle,
                title: l10n.programNoActiveMesocycle,
                message: l10n.programAddMesocycleMessage,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.l),
                child: Center(
                  child: FilledButton(
                    onPressed: () => context.goNamed(MesocycleLibraryPage.name),
                    child: Text(l10n.programChooseMesocycle),
                  ),
                ),
              ),
            ],
          ),
        AppSection(
          children: [
            AppListRowButton(
              title: l10n.startEmptyWorkout,
              icon: AppSymbols.start,
              onPressed: () => unawaited(
                startWorkout(context, eventPrefix: 'TrainingView_StartWorkout'),
              ),
            ),
          ],
        ),
        AppSection(
          header: l10n.trainingLibraryHeader,
          children: [
            AppListRowButton(
              title: l10n.programMacrocyclesTitle,
              icon: AppSymbols.macrocycle,
              onPressed: () => context.goNamed(MacrocyclesPage.name),
            ),
            AppListRowButton(
              title: l10n.programMesocyclesTitle,
              icon: AppSymbols.library,
              onPressed: () => context.goNamed(MesocycleLibraryPage.name),
            ),
            AppListRowButton(
              title: l10n.trainingWorkoutsRow,
              icon: AppSymbols.workout,
              onPressed: () => context.goNamed(WorkoutsPage.name),
            ),
            AppListRowButton(
              title: l10n.trainingExercisesRow,
              icon: AppSymbols.exercise,
              onPressed: () => context.goNamed(ExercisesPage.name),
            ),
            AppListRowButton(
              title: l10n.workoutHistoryTitle,
              icon: AppSymbols.history,
              onPressed: () => context.goNamed(WorkoutHistoryPage.name),
            ),
          ],
        ),
      ],
    );
  }
}

/// Exercises and workouts matching the search (Swift's `searchResults`).
class _SearchResults extends StatelessWidget {
  const new({required this.library, required this.query});

  final TrainingLibrary library;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercises = library.searchExercises(query);
    final workouts = library.searchWorkoutTemplates(query);
    if (exercises.isEmpty && workouts.isEmpty) {
      return LibraryEmptyState(
        icon: AppSymbols.search,
        title: l10n.searchNoResults(query.trim()),
        message: l10n.searchNoResultsMessage,
      );
    }
    return LibrarySections(
      children: [
        if (exercises.isNotEmpty)
          AppSection(
            header: l10n.trainingExercisesRow,
            children: [
              for (final exercise in exercises)
                MergeSemantics(
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => unawaited(
                        context.pushNamed(
                          ExerciseDetailPage.name,
                          pathParameters: {
                            ExerciseDetailPage.idParameter: exercise.id,
                          },
                        ),
                      ),
                      child: AppListRow(
                        title: exercise.name,
                        subtitle: exercise.description,
                        thumbnail: ExerciseImage(exercise),
                        accessory: const AppListRowChevron(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (workouts.isNotEmpty)
          AppSection(
            header: l10n.trainingWorkoutsRow,
            children: [for (final workout in workouts) WorkoutRow(workout)],
          ),
      ],
    );
  }
}
