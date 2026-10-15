import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/exercise_history_bloc.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/logic/exercise_detail_stats.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:workout_session_repository/workout_session_repository.dart';

/// One exercise from the library (Swift `ExerciseModelDetailView`): what
/// it is and how it is done, and the sessions it was logged in. Read-only.
/// The Charts and Records tabs wait for the estimated one-rep max's method
/// info; deleting an exercise waits for M5.
class ExerciseDetailPage extends StatelessWidget {
  const new({required this.exerciseId, super.key});

  /// The path under the exercise library.
  static const path = ':$idParameter';

  /// The route name.
  static const name = 'exerciseDetail';

  /// The path parameter holding the exercise's id.
  static const idParameter = 'exerciseId';

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: BlocProvider(
        create: (context) => ExerciseHistoryBloc(
          repository: context.read<WorkoutSessionRepository>(),
          uid: state.user.uid,
          exerciseId: exerciseId,
          analytics: context.read<AnalyticsRepository>(),
        )..add(const ExerciseHistorySubscriptionRequested()),
        child: ExerciseDetailView(
          exerciseId: exerciseId,
          weightUnit: WorkoutText.preferredWeightUnit(
            state.profile?.submittedWeightUnitPreference,
          ),
        ),
      ),
    );
  }
}

class ExerciseDetailView extends StatelessWidget {
  const new({required this.exerciseId, required this.weightUnit, super.key});

  final String exerciseId;

  /// The unit the history's weights are shown in: the profile's.
  final AppWeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final libraryState = context.watch<TrainingLibraryBloc>().state;
    final exercise = switch (libraryState) {
      TrainingLibraryLoaded(:final library) => library.exercise(exerciseId),
      _ => null,
    };
    final body = switch (libraryState) {
      TrainingLibraryLoading() => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      TrainingLibraryFailure() => LibraryFailure(
        message: l10n.exercisesLoadFailure,
        onRetry: () => context.read<TrainingLibraryBloc>().add(
          const TrainingLibrarySubscriptionRequested(),
        ),
      ),
      TrainingLibraryLoaded(:final library) when exercise != null => TabBarView(
        children: [
          _About(exercise: exercise, library: library),
          _History(weightUnit: weightUnit),
        ],
      ),
      TrainingLibraryLoaded() => Center(
        child: LibraryEmptyState(
          icon: AppSymbols.exercise,
          title: l10n.exerciseNotFound,
        ),
      ),
    };
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: exercise == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(exercise.name), const _PerformedSubtitle()],
                ),
          bottom: exercise == null
              ? null
              : TabBar(
                  tabs: [
                    Tab(text: l10n.exerciseAboutTab),
                    Tab(text: l10n.exerciseHistoryTab),
                  ],
                ),
        ),
        body: SafeArea(bottom: false, child: body),
      ),
    );
  }
}

/// "Performed 3 times · last 12 Oct 2026", or "No history yet".
class _PerformedSubtitle extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ExerciseHistoryBloc>().state;
    if (state is! ExerciseHistoryLoaded) return const SizedBox.shrink();
    final latest = state.stats.mostRecentFirst.firstOrNull;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Text(
      latest == null
          ? l10n.exerciseNoHistory
          : l10n.exercisePerformed(
              state.stats.performances.length,
              DateFormat.yMMMd(locale).format(latest.date.toLocal()),
            ),
      style: AppTextStyles.rowDetail.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _About extends StatelessWidget {
  const new({required this.exercise, required this.library});

  final ExerciseModel exercise;
  final TrainingLibrary library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final none = l10n.none;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final metrics = exercise.trackableMetrics.map(l10n.metricName).join(' × ');
    final type = exercise.type;
    final laterality = exercise.laterality;
    final variations = exercise.equipmentVariations;
    String equipment(EquipmentRef ref) =>
        library.equipmentName(ref) ?? l10n.removedEquipment;
    final sections = <Widget>[
      if (exercise.imageUrl?.isNotEmpty ?? false)
        ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 250),
            child: ExerciseImage(exercise),
          ),
        ),
      AppSection(
        header: l10n.exerciseDefinitionHeader,
        children: [
          AppListRow(
            title: l10n.exerciseNameRow,
            accessory: AppListRowValue(exercise.name),
          ),
          AppListRow(
            title: l10n.exerciseTrackableMetricsRow,
            accessory: AppListRowValue(metrics.isEmpty ? none : metrics),
          ),
          AppListRow(
            title: l10n.filterType,
            accessory: AppListRowValue(
              type == null ? none : l10n.exerciseTypeName(type),
            ),
          ),
          AppListRow(
            title: l10n.filterLaterality,
            accessory: AppListRowValue(
              laterality == null ? none : l10n.lateralityName(laterality),
            ),
          ),
          AppListRow(
            title: l10n.exerciseBodyweightRow,
            accessory: AppListRowValue(
              exercise.isBodyweight ? l10n.yes : l10n.no,
            ),
          ),
        ],
      ),
      if (exercise.muscleGroups.isNotEmpty)
        AppSection(
          header: l10n.exerciseTargetMusclesHeader,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: MuscleChips(
                TemplateSummary.sortedMuscles(
                  exercise.muscleGroups,
                  l10n.muscleName,
                ),
              ),
            ),
          ],
        ),
      AppSection(
        header: l10n.exerciseMovementQualityHeader,
        children: [
          _RatingRow(
            title: l10n.filterRangeOfMotion,
            rating: exercise.rangeOfMotion,
          ),
          _RatingRow(title: l10n.filterStability, rating: exercise.stability),
        ],
      ),
      if (variations.isEmpty)
        AppSection(
          header: l10n.exerciseEquipmentHeader,
          children: [AppListRow(title: none)],
        )
      else
        for (final (index, variation) in variations.indexed)
          AppSection(
            header: l10n.exerciseVariationHeader(index + 1),
            children: [
              if (variation.resistanceEquipment.isEmpty &&
                  variation.supportEquipment.isEmpty)
                AppListRow(title: l10n.exerciseNoEquipment),
              for (final ref in variation.resistanceEquipment)
                AppListRow(
                  title: equipment(ref),
                  subtitle: l10n.exerciseResistanceLabel,
                ),
              for (final ref in variation.supportEquipment)
                AppListRow(
                  title: equipment(ref),
                  subtitle: l10n.exerciseSupportLabel,
                ),
            ],
          ),
      AppSection(
        header: l10n.exerciseAboutDetailsHeader,
        children: [
          if (exercise.bodyWeightContribution > 0)
            AppListRow(
              title: l10n.exerciseBodyWeightContributionRow,
              accessory: AppListRowValue(
                AppFormat.percent(
                  exercise.bodyWeightContribution / 100,
                  locale: locale,
                ),
              ),
            ),
          _TextRow(
            title: l10n.exerciseAlternativeNamesRow,
            text: exercise.alternateNames.isEmpty
                ? none
                : exercise.alternateNames.join(', '),
          ),
          _TextRow(
            title: l10n.exerciseDescriptionRow,
            text: exercise.description ?? none,
          ),
        ],
      ),
    ];
    return LibrarySections(children: sections);
  }
}

/// A rating out of five as five bars, read out as "3 of 5".
class _RatingRow extends StatelessWidget {
  const new({required this.title, required this.rating});

  final String title;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      value: context.l10n.ratingOutOfFive(rating),
      excludeSemantics: true,
      child: AppListRow(
        title: title,
        accessory: AppListRowCustom(
          SizedBox(
            width: 120,
            child: Row(
              spacing: AppSpacing.xs,
              children: [
                for (var value = 1; value <= 5; value++)
                  Expanded(
                    child: Container(
                      height: AppSpacing.s,
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: value <= rating
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A title over text that is never cut short.
class _TextRow extends StatelessWidget {
  const new({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xxs,
          children: [
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              text,
              style: AppTextStyles.rowTitle.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const new({required this.weightUnit});

  final AppWeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final notLogged = LibraryEmptyState(
      icon: AppSymbols.history,
      title: l10n.exerciseNotLoggedTitle,
      message: l10n.exerciseNotLoggedMessage,
    );
    return switch (context.watch<ExerciseHistoryBloc>().state) {
      ExerciseHistoryLoading() => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      ExerciseHistoryFailure() => LibraryFailure(
        message: l10n.exerciseHistoryLoadFailure,
        onRetry: () => context.read<ExerciseHistoryBloc>().add(
          const ExerciseHistorySubscriptionRequested(),
        ),
      ),
      ExerciseHistoryLoaded(:final stats) => LibrarySections(
        children: [
          AppSection(
            header: l10n.exerciseHistoryTab,
            children: stats.isEmpty
                ? [notLogged]
                : [
                    for (final performance in stats.mostRecentFirst)
                      AppListRow(
                        title: performance.workoutName,
                        subtitle: _detail(l10n, performance, locale),
                        accessory: AppListRowValue(
                          DateFormat.yMMMd(locale)
                              .format(performance.date.toLocal()),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    };
  }

  /// "3 sets · 24 reps · top 100 kg".
  String _detail(
    AppLocalizations l10n,
    ExercisePerformance performance,
    String locale,
  ) => l10n.exerciseHistoryDetail(
    l10n.setCount(performance.workingSets),
    l10n.repCount(performance.totalReps),
    AppFormat.weight(performance.heaviestWeightKg, weightUnit, locale: locale),
  );
}
