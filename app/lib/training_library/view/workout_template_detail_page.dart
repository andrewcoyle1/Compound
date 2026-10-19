import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/integrations/link_opener.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_editor/cubit/delete_workout_cubit.dart';
import 'package:compound/workout_editor/view/workout_wizard_pages.dart';
import 'package:compound/workout_tracker/view/start_workout.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart'
    show workoutCopyName;
import 'package:training_library_repository/training_library_repository.dart'
    show TrainingLibraryRepository, WorkoutEditorRules;
import 'package:training_session/training_session.dart' show weekOf;

/// One workout template (Swift `WorkoutTemplateDetailView`): the muscles it
/// plans sets for and each exercise's plan, and Start Workout. Opened from
/// a program's day it shows, and starts on, that microcycle's targets, cut
/// to a deload's in a deload week; a later microcycle's day is a preview
/// with no Start. A day of the user's own mesocycle offers Edit Mesocycle
/// and Save a Copy to Workouts; the user's own library workout offers Edit
/// Workout and Delete Workout. Sharing comes with its slice.
class WorkoutTemplateDetailPage extends StatelessWidget {
  const new({
    required this.workoutId,
    this.mesocycleId,
    this.microcycleIndex,
    this.isDeload = false,
    this.allowsStart = true,
    super.key,
  });

  /// Builds the page from [state]'s path and query.
  factory fromRoute(GoRouterState state) {
    final query = state.uri.queryParameters;
    return WorkoutTemplateDetailPage(
      workoutId: state.pathParameters[idParameter]!,
      mesocycleId: query[mesocycleParameter],
      microcycleIndex: int.tryParse(query[microcycleParameter] ?? ''),
      isDeload: query[deloadParameter] == '1',
      allowsStart: query[previewParameter] != '1',
    );
  }

  /// The query parameter naming the mesocycle the day belongs to.
  static const mesocycleParameter = 'mesocycle';

  /// The query parameter holding the microcycle, from 1.
  static const microcycleParameter = 'microcycle';

  /// The query parameter set to `1` in a deload week.
  static const deloadParameter = 'deload';

  /// The query parameter set to `1` for a preview without Start.
  static const previewParameter = 'preview';

  /// Opens [workoutId], as a day of [mesocycleId]'s [microcycleIndex]
  /// (from 1) when given.
  static Future<void> open(
    BuildContext context,
    String workoutId, {
    String? mesocycleId,
    int? microcycleIndex,
    bool isDeload = false,
    bool allowsStart = true,
  }) => context.pushNamed(
    name,
    pathParameters: {idParameter: workoutId},
    queryParameters: {
      mesocycleParameter: ?mesocycleId,
      if (microcycleIndex != null) microcycleParameter: '$microcycleIndex',
      if (isDeload) deloadParameter: '1',
      if (!allowsStart) previewParameter: '1',
    },
  );

  /// The path under the workout library.
  static const path = ':$idParameter';

  /// The route name.
  static const name = 'workoutTemplateDetail';

  /// The path parameter holding the template's `workoutId`.
  static const idParameter = 'workoutId';

  final String workoutId;
  final String? mesocycleId;
  final int? microcycleIndex;
  final bool isDeload;
  final bool allowsStart;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: BlocProvider(
        create: (context) => DeleteWorkoutCubit(
          library: context.read<TrainingLibraryRepository>(),
          analytics: context.read<AnalyticsRepository>(),
        ),
        child: WorkoutTemplateDetailView(
          workoutId: workoutId,
          mesocycleId: mesocycleId,
          microcycleIndex: microcycleIndex,
          isDeload: isDeload,
          allowsStart: allowsStart,
        ),
      ),
    );
  }
}

class WorkoutTemplateDetailView extends StatelessWidget {
  const new({
    required this.workoutId,
    this.mesocycleId,
    this.microcycleIndex,
    this.isDeload = false,
    this.allowsStart = true,
    super.key,
  });

  final String workoutId;
  final String? mesocycleId;
  final int? microcycleIndex;
  final bool isDeload;
  final bool allowsStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TrainingLibraryBloc>().state;
    final found = switch (state) {
      TrainingLibraryLoaded(:final library) => library.template(workoutId),
      _ => null,
    };
    final template = found?.$1;
    final description = template?.description;
    final app = context.read<AppBloc>().state;
    // A day of the user's own mesocycle lives there, not in the library: it
    // is changed there, and kept apart only as a copy the user asks for.
    final owning = switch (found?.$2) {
      final mesocycle?
          when app is AppAuthenticated && mesocycle.authorId == app.user.uid =>
        mesocycle,
      _ => null,
    };
    // The user's own library workout is changed here (Swift `isAuthor`).
    final ownWorkout = switch (template) {
      final template?
          when found?.$2 == null &&
              app is AppAuthenticated &&
              template.authorId == app.user.uid =>
        template,
      _ => null,
    };
    final deleting =
        context.watch<DeleteWorkoutCubit>().state ==
        DeleteWorkoutStatus.deleting;
    return BlocListener<DeleteWorkoutCubit, DeleteWorkoutStatus>(
      listener: (context, status) => unawaited(_deleted(context, status)),
      child: AppScaffold(
        appBar: AppBar(
          actions: [
            if (ownWorkout != null)
              PopupMenuButton<VoidCallback>(
                key: const Key('WorkoutTemplateDetail.options'),
                icon: Icon(AppSymbols.more),
                tooltip: l10n.editorWorkoutOptions,
                enabled: !deleting,
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => unawaited(
                      NameWorkoutPage.edit(context, ownWorkout.workoutId),
                    ),
                    child: Text(l10n.editorEditWorkout),
                  ),
                  PopupMenuItem(
                    value: () => unawaited(
                      showShareToFollower(
                        context,
                        TemplateSharePayload(ownWorkout),
                      ),
                    ),
                    child: Text(l10n.shareWithFriends),
                  ),
                  AppMenuItem(
                    value: () => unawaited(_delete(context, ownWorkout)),
                    label: l10n.editorDeleteWorkout,
                    icon: AppSymbols.delete,
                    isDestructive: true,
                  ),
                ],
              ),
            if (owning != null && template != null)
              PopupMenuButton<VoidCallback>(
                icon: Icon(AppSymbols.more),
                tooltip: l10n.programMesocycleOptions,
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () =>
                        unawaited(MesocycleDesignPage.edit(context, owning.id)),
                    child: Text(l10n.programEditMesocycle),
                  ),
                  PopupMenuItem(
                    value: () => unawaited(_saveCopy(context, template)),
                    child: Text(l10n.programSaveCopy),
                  ),
                  PopupMenuItem(
                    value: () => unawaited(
                      showShareToFollower(
                        context,
                        TemplateSharePayload(template),
                      ),
                    ),
                    child: Text(l10n.shareWithFriends),
                  ),
                ],
              ),
          ],
          title: template == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name),
                    if (description != null && description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowDetail.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
        ),
        body: SafeArea(
          bottom: false,
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
            TrainingLibraryLoaded(:final library) when template != null =>
              _Plan(
                template: weekOf(template, microcycleIndex),
                library: library,
              ),
            TrainingLibraryLoaded() => Center(
              child: LibraryEmptyState(
                icon: AppSymbols.workout,
                title: l10n.workoutNotFound,
              ),
            ),
          },
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            if (allowsStart &&
                template != null &&
                template.exercises.isNotEmpty)
              AppCtaButton(
                label: l10n.startWorkout,
                onPressed: () => unawaited(
                  startWorkout(
                    context,
                    template: template,
                    eventPrefix: 'WorkoutTemplateDetailView_StartWorkout',
                    mesocycleId: mesocycleId,
                    microcycleIndex: microcycleIndex,
                    isDeload: isDeload,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks, then deletes the user's [workout] (Swift
/// `showDeleteConfirmation`).
Future<void> _delete(BuildContext context, WorkoutTemplateModel workout) async {
  final l10n = context.l10n;
  final cubit = context.read<DeleteWorkoutCubit>();
  final app = context.read<AppBloc>().state;
  final confirmed = await confirmDestructive(
    context,
    title: l10n.editorDeleteWorkout,
    message: l10n.editorDeleteMessage(workout.name),
    confirmLabel: l10n.editorDelete,
  );
  if (!confirmed || app is! AppAuthenticated) return;
  await cubit.delete(app.user.uid, workout.workoutId);
}

/// Leaves once the workout is deleted, or says it could not be.
Future<void> _deleted(BuildContext context, DeleteWorkoutStatus status) async {
  final l10n = context.l10n;
  switch (status) {
    case DeleteWorkoutStatus.deleted:
      unawaited(HapticFeedback.successNotification());
      if (context.canPop()) context.pop();
    case DeleteWorkoutStatus.failed:
      unawaited(HapticFeedback.errorNotification());
      await showFailureAlert(
        context,
        l10n.editorDeleteFailed,
        l10n.editorTryAgain,
      );
    case DeleteWorkoutStatus.idle || DeleteWorkoutStatus.deleting:
      break;
  }
}

/// Saves [day] as a library workout of the user's own, and says so.
Future<void> _saveCopy(BuildContext context, WorkoutTemplateModel day) async {
  final l10n = context.l10n;
  final library = switch (context.read<TrainingLibraryBloc>().state) {
    TrainingLibraryLoaded(:final library) => [
      ...library.systemWorkoutTemplates,
      ...library.userWorkoutTemplates,
    ],
    _ => const <WorkoutTemplateModel>[],
  };
  final ok = await context.read<ProgramsCubit>().succeeded(
    (cubit) => cubit.saveWorkoutCopy(
      day,
      library: library,
      copyName: l10n.programCopyName,
    ),
  );
  if (!ok) {
    unawaited(HapticFeedback.errorNotification());
    if (context.mounted) {
      await showFailureAlert(
        context,
        l10n.programCopyFailed,
        l10n.programTryAgain,
      );
    }
    return;
  }
  unawaited(HapticFeedback.successNotification());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          l10n.programCopySaved(
            workoutCopyName(day.name, library, l10n.programCopyName),
          ),
        ),
      ),
    );
}

class _Plan extends StatelessWidget {
  const new({required this.template, required this.library});

  final WorkoutTemplateModel template;
  final TrainingLibrary library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercises = template.exercises;
    final letters = TemplateSummary.supersetLetters(exercises);
    final allExercises = library.allExercises;
    return LibrarySections(
      children: [
        TargetMusclesSection(exercises: exercises),
        AppSection(
          header: l10n.workoutExercisesHeader(exercises.length),
          children: [
            for (final exercise in exercises) ...[
              _ExerciseRow(
                exercise: exercise,
                supersetLetter: letters[exercise.supersetGroupId],
                alternatives: TemplateSummary.alternativeNames(
                  exercise,
                  allExercises,
                ),
              ),
              if (planLink(exercise) case final link?)
                _WatchRow(name: exercise.exercise.name, link: link),
            ],
          ],
        ),
      ],
    );
  }
}

/// The muscles [exercises] plan sets for, with the method's info button
/// (Swift `TargetMusclesSection`): a tile per muscle, or a row saying there
/// are none yet.
class const TargetMusclesSection({
  required final List<WorkoutTemplateExercise> exercises,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summaries = TemplateSummary.targetMuscles(exercises, l10n.muscleName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        _HeaderWithInfo(
          title: l10n.exerciseTargetMusclesHeader,
          info: MethodInfo.plannedSetsPerMuscle(l10n),
        ),
        if (summaries.isEmpty)
          AppSection(
            children: [
              AppListRow(
                title: l10n.workoutNoTargetMuscles,
                icon: AppSymbols.muscleGroup,
                tint: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: AppSpacing.s,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final summary in summaries) _MuscleTile(summary)],
            ),
          ),
      ],
    );
  }
}

/// A section title with the method's info button at its trailing edge
/// (Swift `MethodInfoHeader`).
class _HeaderWithInfo extends StatelessWidget {
  const new({required this.title, required this.info});

  final String title;
  final MethodInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          MethodInfoButton(info),
        ],
      ),
    );
  }
}

/// A muscle's planned sets and how many exercises work it.
class _MuscleTile extends StatelessWidget {
  const new(this.summary);

  final TargetMuscleSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return MergeSemantics(
      child: AppCard(
        style: AppCardStyle.tinted(secondary),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xxs,
            children: [
              Text(
                l10n.muscleName(summary.muscle),
                style: AppTextStyles.rowDetail.semibold,
              ),
              Text(
                l10n.targetSetsValue(
                  _sets(l10n, summary.weightedTargetSets, locale),
                ),
                style: AppTextStyles.label.copyWith(color: secondary),
              ),
              Text(
                l10n.exerciseCount(summary.exerciseCount),
                style: AppTextStyles.label.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 set", "3 sets", "2.5 sets": a fractional count is always plural.
String _sets(AppLocalizations l10n, double sets, String locale) =>
    sets == sets.roundToDouble()
    ? l10n.setCount(sets.round())
    : l10n.setCountDecimal(AppFormat.setCount(sets, locale: locale));

/// An exercise in the template: its picture and name, the plan's targets
/// and setup, and the muscles it works (Swift `TemplateExerciseRow` and
/// `TemplateExercisePlanDetails`). Opens the exercise.
class _ExerciseRow extends StatelessWidget {
  const new({
    required this.exercise,
    required this.supersetLetter,
    required this.alternatives,
  });

  final WorkoutTemplateExercise exercise;
  final String? supersetLetter;
  final List<String> alternatives;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final notes = exercise.notes?.trim() ?? '';
    final setup = [
      if (exercise.warmupSetCount case final count?) l10n.warmupCount(count),
      if (exercise.restSeconds case final rest? when rest > 0)
        l10n.restValue(AppFormat.duration(Duration(seconds: rest))),
    ].join(' · ');
    final supersetLetter = this.supersetLetter;
    final side = MediaQuery.textScalerOf(context).scale(60);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => unawaited(
          context.pushNamed(
            ExerciseDetailPage.name,
            pathParameters: {
              ExerciseDetailPage.idParameter: exercise.exercise.id,
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.m,
            children: [
              ExcludeSemantics(
                child: ClipRSuperellipse(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.s),
                  ),
                  child: SizedBox.square(
                    dimension: side,
                    child: ExerciseImage(exercise.exercise),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      exercise.exercise.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    if (exercise.setTargets.isNotEmpty)
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final target in exercise.setTargets)
                            SetTargetLabel(target),
                        ],
                      ),
                    Text(
                      templateTargetsText(context, exercise.setTargets),
                      style: secondary,
                    ),
                    if (supersetLetter != null)
                      AppChip(
                        label: l10n.supersetLabel(supersetLetter),
                        icon: AppSymbols.superset,
                        tint: context.appColors.superset,
                      ),
                    if (setup.isNotEmpty) Text(setup, style: secondary),
                    if (notes.isNotEmpty)
                      _Labelled(title: l10n.planNotesLabel, value: notes),
                    if (alternatives.isNotEmpty)
                      _Labelled(
                        title: l10n.alternativesLabel,
                        value: alternatives.join(', '),
                      ),
                    MuscleChips(
                      TemplateSummary.sortedMuscles(
                        exercise.exercise.muscleGroups,
                        l10n.muscleName,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An exercise's demonstration link, when it is a web address: trimmed,
/// `http` or `https` only (Swift `WorkoutTemplateExercise.planLink`).
Uri? planLink(WorkoutTemplateExercise exercise) =>
    switch (WorkoutEditorRules.validatedLink(exercise.linkUrl ?? '')) {
      final link? => Uri.parse(link),
      null => null,
    };

/// Watch: opens the exercise's link outside the app (Swift's `Link` row).
class _WatchRow extends StatelessWidget {
  const new({required this.name, required this.link});

  final String name;
  final Uri link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.templateWatchLabel(name),
      button: true,
      excludeSemantics: true,
      child: AppListRowButton(
        title: l10n.templateWatch,
        icon: AppSymbols.openExternally,
        onPressed: () => unawaited(context.read<LinkOpener>().open(link)),
      ),
    );
  }
}

/// "1  8–12 reps": a set's number in a small badge beside its rep target
/// (Swift `SetTargetLabel`).
class SetTargetLabel extends StatelessWidget {
  const new(this.target, {super.key});

  final SetTarget target;

  /// "8–12 reps", "1–12 reps" with only a ceiling, "8+ reps" with only a
  /// floor (`SetTarget.repTargetDescription`).
  static String describe(
    AppLocalizations l10n,
    SetTarget target, {
    String? locale,
  }) => switch ((target.minReps, target.maxReps)) {
    (final min?, final max?) => l10n.templateRepRange(
      AppFormat.repRange(min, max, locale: locale),
    ),
    (null, final max?) => l10n.templateRepRange(
      AppFormat.repRange(1, max, locale: locale),
    ),
    (final min?, null) => l10n.templateRepFloor(min),
    (null, null) => l10n.templateNoTarget,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final description = describe(l10n, target, locale: locale);
    return Semantics(
      label: l10n.templateSetLabel(target.setNumber, description),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          AppChip(
            label: AppFormat.number(target.setNumber),
            tint: scheme.onSurfaceVariant,
          ),
          Text(
            description,
            style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const new({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: AppTextStyles.rowDetail.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// "3 sets · 8–12 · RIR 1" for [setTargets], leaving out what the plan
/// doesn't set.
String templateTargetsText(BuildContext context, List<SetTarget> setTargets) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final targets = TemplateSummary.targets(setTargets);
  String range(int low, int high) => low == high
      ? AppFormat.number(low, locale: locale)
      : AppFormat.repRange(low, high, locale: locale);
  return [
    l10n.setCount(targets.sets),
    switch ((targets.repsLow, targets.repsHigh)) {
      (final low?, final high?) => range(low, high),
      (final low?, null) => '${AppFormat.number(low, locale: locale)}+',
      _ => null,
    },
    if ((targets.rirLow, targets.rirHigh) case (final low?, final high?))
      l10n.rirRange(range(low, high)),
  ].nonNulls.join(' · ');
}
