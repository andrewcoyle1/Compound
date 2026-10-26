import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:compound/profile/profile.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/training/logic/training_calendar.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:compound/workout_editor/view/workout_wizard_pages.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound/workout_history/view/workout_history_page.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Training tab's root (Swift `TrainingView`): a search over exercises
/// and workouts, the active mesocycle's schedule (or a way to choose one),
/// and the Library, with a + menu, under a week of finished workouts: tap
/// a day to open its session.
class TrainingPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => LibrarySearchCubit(
              analytics: context.read<AnalyticsRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => CalendarHeaderCubit(
              analytics: context.read<AnalyticsRepository>(),
              today: startOfDay(DateTime.now()),
            ),
          ),
        ],
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
      child: AppSearchField(
        clearLabel: l10n.clearSearch,
        hint: l10n.trainingSearchHint,
        onChanged: context.read<LibrarySearchCubit>().queryChanged,
      ),
    );
    final programs = context.watch<ProgramsCubit>().state;
    final markers = loggedWorkoutMarkersByDay(
      programs.sessions,
      programs.mesocycles,
    );
    final today = startOfDay(DateTime.now());
    void open(DateTime day) => unawaited(openWorkoutsOn(context, day));
    return AppScaffold(
      maxWidth: AppContentWidth.dashboard,
      largeTitle: l10n.tabTraining,
      actions: [
        AppToolbarButton(
          icon: AppSymbols.calendar,
          semanticLabel: l10n.calendarShow,
          onPressed: () => unawaited(
            CalendarHeader.showCalendar(
              context,
              today: today,
              markers: markers,
              onDaySelected: open,
            ),
          ),
        ),
        const _AddMenu(),
        const ProfileButton(),
      ],
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarHeader(today: today, markers: markers, onDaySelected: open),
            searchField,
            Expanded(
              child: FuzzyMatch.isSearching(query) && library != null
                  ? _SearchResults(library: library, query: query)
                  : const _Library(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [day]'s finished workout, or asks which of several; a day without
/// one does nothing (Swift `TrainingPresenter.onDatePressed`).
@visibleForTesting
Future<void> openWorkoutsOn(BuildContext context, DateTime day) async {
  final sessions = loggedWorkoutsOn(
    context.read<ProgramsCubit>().state.sessions,
    day,
  );
  switch (sessions) {
    case []:
      return;
    case [final session]:
      _openCompletedSession(context, session.id);
    default:
      final chosen = await _chooseSession(context, sessions);
      if (chosen != null && context.mounted) {
        _openCompletedSession(context, chosen);
      }
  }
}

/// Opens the session [sessionId], between
/// `TrainingView_OpenCompletedSession_Start` and `_Success`, or `_Fail`
/// when it has gone since (`openCompletedSession`).
void _openCompletedSession(BuildContext context, String sessionId) {
  final cubit = context.read<ProgramsCubit>()
    ..pressed('TrainingView_OpenCompletedSession_Start');
  if (!cubit.state.sessions.any((s) => s.id == sessionId)) {
    cubit.pressed('TrainingView_OpenCompletedSession_Fail');
    return;
  }
  unawaited(
    context.pushNamed(
      WorkoutSessionDetailPage.name,
      pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: sessionId},
    ),
  );
  cubit.pressed('TrainingView_OpenCompletedSession_Success');
}

/// Multiple Workouts: which of [sessions] to open, by name and time.
Future<String?> _chooseSession(
  BuildContext context,
  List<WorkoutSessionModel> sessions,
) {
  final l10n = context.l10n;
  String time(DateTime at) => AppFormat.time(
    at,
    use24HourFormat: context.use24HourFormat,
    locale: context.dateLocale,
  );
  return showAppDialog<String>(
    context: context,
    title: l10n.trainingMultipleWorkouts,
    message: l10n.trainingWhichWorkout,
    actions: [
      for (final session in sessions)
        AppDialogAction(
          label: l10n.trainingSessionChoice(
            session.name,
            time(session.dateCreated.toLocal()),
          ),
          value: session.id,
        ),
      AppDialogAction(
        label: MaterialLocalizations.of(context).cancelButtonLabel,
        role: AppDialogRole.cancel,
      ),
    ],
  );
}

/// The + menu (Swift `TrainingView`'s toolbar).
class _AddMenu extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.start),
          onPressed: () => unawaited(
            startWorkout(context, eventPrefix: 'TrainingView_StartWorkout'),
          ),
          child: Text(l10n.startEmptyWorkout),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.macrocycle),
          onPressed: () => unawaited(
            MacrocycleDetailPage.open(context, MacrocycleDetailPage.newId),
          ),
          child: Text(l10n.programNewMacrocycle),
        ),
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.mesocycle),
          onPressed: () => unawaited(NameMesocyclePage.open(context)),
          child: Text(l10n.programNewMesocycle),
        ),
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.workout),
          onPressed: () => unawaited(NameWorkoutPage.create(context)),
          child: Text(l10n.editorNewWorkout),
        ),
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.exercise),
          onPressed: () => unawaited(CreateExercisePage.open(context)),
          child: Text(l10n.createExerciseNew),
        ),
      ],
      builder: (context, controller, _) => AppToolbarButton(
        icon: AppSymbols.add,
        semanticLabel: l10n.trainingAddTraining,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The dashboard: the active mesocycle's microcycle as the hero (or a way
/// to choose one), the last workout, then Start Empty Workout and the
/// Library.
class const _Library() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final programs = context.watch<ProgramsCubit>().state;
    final active = programs.activeMesocycle;
    final last = latestLoggedWorkout(programs.sessions);
    return AppDashboard(
      sections: [
        if (active != null)
          ActiveMesocycleSection(mesocycle: active)
        else if (programs.status == ProgramsStatus.loaded)
          AppSummaryCard(
            title: l10n.programNoActiveMesocycle,
            icon: AppSymbols.mesocycle,
            footer: l10n.programAddMesocycleMessage,
            actions: AppCtaButton(
              label: l10n.programChooseMesocycle,
              size: AppCtaSize.compact,
              onPressed: () => context.goNamed(MesocycleLibraryPage.name),
            ),
          ),
        if (last != null)
          _LastWorkoutCard(session: last, sessions: programs.sessions),
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

/// The most recent finished workout: its name in the display face over
/// its day, a personal-record chip when it set any, and what it came to.
/// Opens the session; See All opens the history.
class const _LastWorkoutCard({
  required final WorkoutSessionModel session,
  required final List<WorkoutSessionModel> sessions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final duration = session.activeDuration;
    final records = WorkoutSessionHighlights.personalRecords(
      session,
      priorSessions: sessions,
      limit: 1 << 20,
    );
    return AppSummaryCard(
      title: l10n.trainingLastWorkout,
      icon: AppSymbols.history,
      tint: colors.workouts,
      size: AppSummaryCardSize.large,
      value: session.name,
      unit: AppFormat.date(
        session.dateCreated.toLocal(),
        style: AppDateStyle.weekdayMedium,
        locale: context.dateLocale,
      ),
      delta: records.isEmpty
          ? null
          : AppChip(
              label: l10n.programPrCount(records.length),
              icon: AppSymbols.personalRecord,
              tint: colors.personalRecord,
            ),
      footer: [
        l10n.exerciseCount(session.doneExercises.length),
        l10n.setCount(session.loggedSetCount),
        ?WorkoutText.sessionVolume(session, locale: locale),
        if (duration != null) AppFormat.duration(duration),
      ].join(' · '),
      trailing: AppChip(
        label: l10n.seeAll,
        onPressed: () => context.goNamed(WorkoutHistoryPage.name),
      ),
      onTap: () => _openCompletedSession(context, session.id),
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
      return AppEmptyState(
        icon: AppSymbols.search,
        title: l10n.searchNoResults(query.trim()),
        description: l10n.searchNoResultsMessage,
      );
    }
    return LibrarySections(
      children: [
        if (exercises.isNotEmpty)
          AppSection(
            header: l10n.trainingExercisesRow,
            children: [
              for (final exercise in exercises)
                AppListRowButton(
                  title: exercise.name,
                  subtitle: exercise.description,
                  thumbnail: ExerciseImage(exercise),
                  onPressed: () => unawaited(
                    context.pushNamed(
                      ExerciseDetailPage.name,
                      pathParameters: {
                        ExerciseDetailPage.idParameter: exercise.id,
                      },
                    ),
                  ),
                ),
            ],
          ),
        if (workouts.isNotEmpty)
          AppSection(
            header: l10n.trainingWorkoutsRow,
            children: [
              for (final workout in workouts)
                WorkoutRow(workout, showsPicture: true),
            ],
          ),
      ],
    );
  }
}
