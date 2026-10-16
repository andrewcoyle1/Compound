import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/coach.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/metric_detail/view/metric_chart.dart';
import 'package:compound/metric_detail/view/metric_detail_view.dart'
    show MetricChartPanel;
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_library/bloc/exercise_history_bloc.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/cubit/delete_exercise_cubit.dart';
import 'package:compound/training_library/logic/exercise_detail_stats.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart'
    show UnitPreferenceStore;
import 'package:workout_session_repository/workout_session_repository.dart';

/// One exercise from the library (Swift `ExerciseModelDetailView`): what
/// it is and how it is done, the sessions it was logged in, its charts and
/// its records. The user's own exercise can be deleted.
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
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ExerciseHistoryBloc(
              repository: context.read<WorkoutSessionRepository>(),
              uid: state.user.uid,
              exerciseId: exerciseId,
              analytics: context.read<AnalyticsRepository>(),
            )..add(const ExerciseHistorySubscriptionRequested()),
          ),
          BlocProvider(
            create: (context) => DeleteExerciseCubit(
              library: context.read<TrainingLibraryRepository>(),
              analytics: context.read<AnalyticsRepository>(),
            ),
          ),
        ],
        child: ExerciseDetailView(
          exerciseId: exerciseId,
          // The exercise's own unit, else the profile's
          // (`ExerciseModelDetailPresenter.unitPreference`).
          weightUnit: WorkoutText.weightUnit(
            context
                .read<UnitPreferenceStore>()
                .of(state.user.uid, exerciseId, user: state.profile)
                .weightUnit,
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
          ExerciseAbout(exercise: exercise, library: library),
          _History(weightUnit: weightUnit),
          _Charts(weightUnit: weightUnit),
          _Records(weightUnit: weightUnit),
        ],
      ),
      TrainingLibraryLoaded() => Center(
        child: LibraryEmptyState(
          icon: AppSymbols.exercise,
          title: l10n.exerciseNotFound,
        ),
      ),
    };
    final app = context.read<AppBloc>().state;
    // Only the author's own exercises can go; the bundled library is
    // everyone's.
    final canDelete =
        exercise != null &&
        !exercise.isSystemExercise &&
        app is AppAuthenticated &&
        exercise.authorId == app.user.uid;
    final deleting =
        context.watch<DeleteExerciseCubit>().state ==
        DeleteExerciseStatus.deleting;
    final scaffold = DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (exercise != null)
              AskCoachButton(
                CoachContext(
                  kind: CoachContextKind.exercise,
                  id: exercise.id,
                  title: exercise.name,
                ),
              ),
            if (canDelete)
              PopupMenuButton<VoidCallback>(
                key: const Key('ExerciseDetail.options'),
                icon: Icon(AppSymbols.more),
                tooltip: l10n.exerciseOptions,
                enabled: !deleting,
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => unawaited(_delete(context, exercise)),
                    child: Text(
                      l10n.exerciseDeleteTitle,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                ],
              ),
          ],
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
                    Tab(text: l10n.exerciseChartsTab),
                    Tab(text: l10n.exerciseRecordsTab),
                  ],
                ),
        ),
        body: SafeArea(bottom: false, child: body),
      ),
    );
    return BlocListener<DeleteExerciseCubit, DeleteExerciseStatus>(
      listener: (context, status) => unawaited(_deleted(context, status)),
      child: scaffold,
    );
  }
}

/// Asks, then deletes the user's [exercise] (Swift
/// `showDeleteConfirmation`).
Future<void> _delete(BuildContext context, ExerciseModel exercise) async {
  final l10n = context.l10n;
  final cubit = context.read<DeleteExerciseCubit>();
  final confirmed = await confirmDestructive(
    context,
    title: l10n.exerciseDeleteTitle,
    message: l10n.exerciseDeleteMessage(exercise.name),
    confirmLabel: l10n.editorDelete,
  );
  if (confirmed) await cubit.delete(exercise.id);
}

/// Leaves once the exercise is deleted, or says it could not be.
Future<void> _deleted(BuildContext context, DeleteExerciseStatus status) async {
  final l10n = context.l10n;
  switch (status) {
    case DeleteExerciseStatus.deleted:
      if (context.canPop()) context.pop();
    case DeleteExerciseStatus.failed:
      unawaited(HapticFeedback.errorNotification());
      await showFailureAlert(
        context,
        l10n.exerciseDeleteFailed,
        l10n.exerciseDeleteTryLater,
      );
    case DeleteExerciseStatus.idle || DeleteExerciseStatus.deleting:
      break;
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

/// What [exercise] is and how it is done: the detail's About tab, and the
/// create flow's review.
class ExerciseAbout extends StatelessWidget {
  const new({required this.exercise, required this.library, super.key});

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
          ExerciseRatingRow(
            title: l10n.filterRangeOfMotion,
            rating: exercise.rangeOfMotion,
          ),
          ExerciseRatingRow(
            title: l10n.filterStability,
            rating: exercise.stability,
          ),
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
            text: switch (exercise.description) {
              final String text when text.isNotEmpty => text,
              _ => none,
            },
          ),
        ],
      ),
    ];
    return LibrarySections(children: sections);
  }
}

/// A rating out of five as five bars, read out as "3 of 5", with
/// [trailing] controls after the bars.
class ExerciseRatingRow extends StatelessWidget {
  const new({
    required this.title,
    required this.rating,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final int rating;

  /// Such as buttons that change the rating; shown outside the merged
  /// label so each stays reachable.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bars = Semantics(
      label: title,
      value: context.l10n.ratingOutOfFive(rating),
      excludeSemantics: true,
      child: SizedBox(
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
    );
    return AppListRow(
      title: title,
      accessory: AppListRowCustom(
        Row(mainAxisSize: MainAxisSize.min, children: [bars, ...trailing]),
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

/// The tabs that read the history: loading, a failure with Try Again, Not
/// Logged Yet, or [builder] with the stats.
class _StatsTab extends StatelessWidget {
  const new({required this.builder});

  final Widget Function(ExerciseDetailStats stats) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
      ExerciseHistoryLoaded(:final stats) when stats.isEmpty => Center(
        child: LibraryEmptyState(
          icon: AppSymbols.history,
          title: l10n.exerciseNotLoggedTitle,
          message: l10n.exerciseNotLoggedMessage,
        ),
      ),
      ExerciseHistoryLoaded(:final stats) => builder(stats),
    };
  }
}

/// Charts: each session's heaviest set as a line, and its reps as bars,
/// over a month, six months or a year (Swift `weightSeries` and
/// `repsSeries`).
class _Charts extends StatefulWidget {
  const new({required this.weightUnit});

  final AppWeightUnit weightUnit;

  @override
  State<_Charts> createState() => _ChartsState();
}

class _ChartsState extends State<_Charts> {
  static const List<MetricRange> _ranges = [
    MetricRange.month,
    MetricRange.sixMonths,
    MetricRange.year,
  ];

  MetricRange _weightRange = MetricRange.month;
  MetricRange _repsRange = MetricRange.month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final color = context.appColors.exercises;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final unit = widget.weightUnit;
    return _StatsTab(
      builder: (stats) {
        final sessions = stats.chronological;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            _ChartSection(
              title: l10n.exerciseTopSet,
              child: MetricChartPanel(
                title: l10n.exerciseTopSet,
                ranges: _ranges,
                range: _weightRange,
                today: today,
                onRangeSelected: (range) =>
                    setState(() => _weightRange = range),
                value: (v) =>
                    '${AppFormat.number(v, locale: locale)} ${unit.symbol}',
                series: [
                  MetricChartSeries(
                    label: l10n.exerciseTopSet,
                    color: color,
                    isLine: true,
                    points: [
                      for (final p in sessions)
                        (
                          date: p.date.toLocal(),
                          value: switch (unit) {
                            AppWeightUnit.kilograms => p.heaviestWeightKg,
                            AppWeightUnit.pounds =>
                              p.heaviestWeightKg * AppFormat.poundsPerKilogram,
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _ChartSection(
              title: l10n.exerciseRepsPerSession,
              child: MetricChartPanel(
                title: l10n.exerciseRepsPerSession,
                ranges: _ranges,
                range: _repsRange,
                today: today,
                onRangeSelected: (range) => setState(() => _repsRange = range),
                value: (v) =>
                    '${AppFormat.number(v, locale: locale)} '
                    '${l10n.exerciseRepsUnit}',
                series: [
                  MetricChartSeries(
                    label: l10n.metricReps,
                    color: color,
                    isBar: true,
                    points: [
                      for (final p in sessions)
                        (date: p.date.toLocal(), value: p.totalReps.toDouble()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartSection extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.s,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: child,
        ),
      ),
    ],
  );
}

/// Records: the heaviest set with the best estimated one-rep max, the
/// sessions that set a new best estimate, and the all-time totals (Swift
/// `ExerciseModelDetailView`'s records).
class _Records extends StatelessWidget {
  const new({required this.weightUnit});

  final AppWeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final colors = context.appColors;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    String weight(double kg) =>
        AppFormat.weight(kg, weightUnit, locale: locale);
    String date(DateTime at) => DateFormat.yMMMd(locale).format(at.toLocal());
    return _StatsTab(
      builder: (stats) {
        final best = stats.heaviest;
        final records = stats.oneRepMaxRecords;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          children: [
            MethodInfoHeader(
              title: l10n.exercisePersonalBest,
              info: MethodInfo.estimatedOneRepMax(l10n),
            ),
            AppSection(
              children: [
                if (best == null)
                  AppListRow(title: l10n.exerciseNoWorkingSets)
                else
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppSpacing.xs,
                            children: [
                              Text(
                                '${weight(best.heaviestWeightKg)} × '
                                '${l10n.repCount(best.repsAtHeaviest)}',
                                style: AppTextStyles.metric,
                              ),
                              Row(
                                spacing: AppSpacing.xs,
                                children: [
                                  Icon(
                                    AppSymbols.personalRecord,
                                    color: colors.personalRecord,
                                    size: AppIconSize.small.of(context),
                                  ),
                                  Flexible(
                                    child: Text(
                                      l10n.exerciseAchievedOn(date(best.date)),
                                      style: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppStat(
                          value: weight(stats.bestOneRepMaxKg),
                          label: l10n.exerciseOneRepMaxLabel,
                          size: AppStatSize.small,
                          alignment: CrossAxisAlignment.end,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            MethodInfoHeader(
              title: l10n.exerciseRecentRecords,
              info: MethodInfo.estimatedOneRepMax(l10n),
            ),
            AppSection(
              children: [
                if (records.isEmpty)
                  AppListRow(title: l10n.exerciseNoRecords)
                else
                  for (final record in records)
                    AppListRow(
                      title: date(record.date),
                      accessory: AppListRowValue(
                        weight(record.bestOneRepMaxKg),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            MethodInfoHeader(
              title: l10n.exerciseAllTimeStats,
              info: MethodInfo.tonnage(l10n),
            ),
            AppSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Row(
                    children: [
                      for (final (value, label) in [
                        (
                          AppFormat.number(stats.totalSets, locale: locale),
                          l10n.exerciseTotalSets,
                        ),
                        (
                          AppFormat.number(stats.totalReps, locale: locale),
                          l10n.exerciseTotalReps,
                        ),
                        (weight(stats.totalVolumeKg), l10n.exerciseTotalVolume),
                      ])
                        Expanded(
                          child: AppStat(
                            value: value,
                            label: label,
                            size: AppStatSize.small,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
