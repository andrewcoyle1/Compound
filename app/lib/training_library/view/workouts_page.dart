import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/cubit/library_search_cubit.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/training_library/view/workout_template_detail_page.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:compound/workout_editor/view/workout_wizard_pages.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The workout library, pushed from the Training tab's Library (Swift
/// `WorkoutsView`): the user's templates, their mesocycles' days and the
/// bundled templates, and + for a new workout.
class WorkoutsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Training tab.
  static const path = 'workouts';

  /// The route name.
  static const name = 'workouts';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: BlocProvider(
        create: (context) =>
            LibrarySearchCubit(analytics: context.read<AnalyticsRepository>())
              ..appeared('WorkoutsView'),
        child: const WorkoutsView(),
      ),
    );
  }
}

class WorkoutsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TrainingLibraryBloc>().state;
    final query = context.watch<LibrarySearchCubit>().state;
    final library = switch (state) {
      TrainingLibraryLoaded(:final library) => library,
      _ => null,
    };
    return AppScaffold(
      appBar: AppBar(
        actions: [
          AppToolbarButton(
            key: const Key('Workouts.add'),
            icon: AppSymbols.add,
            semanticLabel: l10n.editorNewWorkout,
            onPressed: () {
              context.read<LibrarySearchCubit>().addWorkoutPressed();
              unawaited(NameWorkoutPage.create(context));
            },
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.trainingWorkoutsRow),
            if (library != null)
              Text(
                l10n.workoutsCount(_count(library)),
                style: AppTextStyles.rowDetail.secondary(context),
              ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              child: AppSearchField(
                clearLabel: l10n.clearSearch,
                hint: l10n.workoutsSearchHint,
                onChanged: context.read<LibrarySearchCubit>().queryChanged,
              ),
            ),
            Expanded(
              child: switch (state) {
                TrainingLibraryLoading() => AppLoadingView(
                  label: context.l10n.launchLoading,
                ),
                TrainingLibraryFailure() => LibraryFailure(
                  message: l10n.workoutsLoadFailure,
                  onRetry: () => context.read<TrainingLibraryBloc>().add(
                    const TrainingLibrarySubscriptionRequested(),
                  ),
                ),
                TrainingLibraryLoaded(:final library) => _Sections(
                  library: library,
                  query: query,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Every template and mesocycle day on offer, as Swift's
  /// `workoutsCount`.
  static int _count(TrainingLibrary library) =>
      library.userWorkoutTemplates.length +
      library.systemWorkoutTemplates.length +
      library
          .mesocycleDays('')
          .fold(0, (sum, mesocycle) => sum + mesocycle.$2.length);
}

class _Sections extends StatelessWidget {
  const new({required this.library, required this.query});

  final TrainingLibrary library;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final searching = FuzzyMatch.isSearching(query);
    final mesocycles = [
      for (final (mesocycle, days) in library.mesocycleDays(query))
        AppSection(
          header: mesocycle.name,
          footer: l10n.workoutsMesocycleFooter,
          children: [
            for (final day in days) WorkoutRow(day, isMesocycleDay: true),
          ],
        ),
    ];
    final List<Widget> sections;
    if (searching) {
      final results = library.searchWorkoutTemplates(query);
      sections = [
        if (results.isNotEmpty)
          AppSection(
            header: l10n.workoutsSearchHeader,
            children: [for (final workout in results) WorkoutRow(workout)],
          ),
        ...mesocycles,
        if (results.isEmpty && mesocycles.isEmpty)
          LibraryEmptyState(
            icon: AppSymbols.search,
            title: l10n.searchNoResults(query.trim()),
            message: l10n.searchNoResultsMessage,
          ),
      ];
    } else {
      final mine = TrainingLibrary.byName(
        library.userWorkoutTemplates,
        (workout) => workout.name,
      );
      final prebuilt = TrainingLibrary.byName(
        library.systemWorkoutTemplates,
        (workout) => workout.name,
      );
      sections = [
        if (mine.isNotEmpty)
          AppSection(
            header: l10n.workoutsCustomHeader,
            children: [for (final workout in mine) WorkoutRow(workout)],
          ),
        ...mesocycles,
        AppSection(
          header: l10n.workoutsPrebuiltHeader,
          footer: l10n.workoutsPrebuiltFooter,
          children: [for (final workout in prebuilt) WorkoutRow(workout)],
        ),
      ];
    }
    return LibrarySections(children: sections);
  }
}

/// A workout template in a list: its name, exercises and the muscles they
/// work (Swift `WorkoutTemplateRow`). Opens its detail.
class WorkoutRow extends StatelessWidget {
  const new(
    this.workout, {
    this.isMesocycleDay = false,
    this.showsPicture = false,
    super.key,
  });

  final WorkoutTemplateModel workout;

  /// Whether the workout's picture leads the row, when it has one, as on
  /// Training's search results (`TrainingView.workoutResultRow`).
  final bool showsPicture;

  /// A day of one of the user's mesocycles rather than a library template.
  final bool isMesocycleDay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = workout.exercises
        .map((exercise) => exercise.exercise.name)
        .join(', ');
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: () {
          context.read<LibrarySearchCubit>().workoutSelected(
            workout,
            isMesocycleDay: isMesocycleDay,
          );
          unawaited(
            context.pushNamed(
              WorkoutTemplateDetailPage.name,
              pathParameters: {
                WorkoutTemplateDetailPage.idParameter: workout.workoutId,
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Row(
            spacing: AppSpacing.m,
            children: [
              if (workout.imageUrl case final url? when showsPicture)
                RowThumbnail(url),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(workout.name, style: AppTextStyles.sectionTitle),
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowDetail.secondary(context),
                      ),
                    if (workout.exercises.isNotEmpty)
                      MuscleChips(
                        TemplateSummary.muscleTags(workout, l10n.muscleName),
                      ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  AppSymbols.disclosure,
                  size: AppIconSize.small.of(context),
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
