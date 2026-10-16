import 'dart:async';

import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/l10n/gen/app_localizations.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:compound_models/compound_models.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

/// What Siri and Shortcuts do in the app, and the sentences they answer
/// with (Swift `AppIntentsInteractor` and `AppIntentsPhrasing`). A launch
/// made for an intent waits a little for someone to be signed in.
class AppIntents implements AppIntentHandler {
  /// Answers from the app's blocs and repositories; Start Workout and
  /// Browse Recipes go through the deep-link inbox, as a tapped
  /// notification does.
  new({
    required this._app,
    required this._programs,
    required this._workouts,
    required this._library,
    required this._users,
    required this._saveMeasurement,
    required this._links,
    required this._l10n,
    required this._firstWeekday,
    this._clock = DateTime.now,
    this._newId = newUuid,
  });

  final AppBloc _app;
  final ProgramsCubit _programs;
  final ActiveWorkoutCubit _workouts;
  final TrainingLibraryRepository _library;
  final UserRepository _users;
  final Future<void> Function(BodyMeasurementEntry) _saveMeasurement;
  final DeepLinkInbox _links;
  final AppLocalizations Function() _l10n;

  /// ISO, as `ActiveWorkoutCubit.finish` takes it.
  final int Function() _firstWeekday;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// How long an intent waits for the profile.
  static const signInWait = Duration(seconds: 10);

  Future<UserModel> _user() async {
    UserModel? profile(AppState state) =>
        state is AppAuthenticated ? state.profile : null;
    final user =
        profile(_app.state) ??
        await _app.stream
            .map(profile)
            .firstWhere((user) => user != null)
            .timeout(signInWait, onTimeout: () => null);
    if (user == null) throw AppIntentRefusal(_l10n().intentNotSignedIn);
    return user;
  }

  /// The library plus the active programme's day plans, which are not
  /// always saved as templates; the library's copy wins.
  Future<List<WorkoutTemplateModel>> _startable(String uid) async {
    final library = await _library
        .watchUserWorkoutTemplates(uid)
        .first
        .timeout(signInWait, onTimeout: () => const []);
    final program = [
      for (final plan
          in _programs.state.activeMesocycle?.workoutTemplates ??
              const <WorkoutTemplateModel>[])
        if (plan.exercises.isNotEmpty) plan,
    ];
    final seen = <String>{};
    return [
      for (final template in [...library, ...program])
        if (seen.add(template.workoutId)) template,
    ];
  }

  @override
  Future<List<IntentWorkout>> workouts() async => [
    for (final template in await _startable((await _user()).userId))
      IntentWorkout(id: template.workoutId, name: template.name),
  ];

  /// Starts it and opens the tracker; a workout under way is opened, never
  /// replaced. A programme day starts in the first microcycle where it is
  /// still open.
  @override
  Future<String> startWorkout(String id) async {
    final user = await _user();
    final l10n = _l10n();
    final active = _workouts.state.session;
    if (_workouts.state.isActive && active != null) {
      _links.store(const WorkoutLink());
      return l10n.intentAlreadyInProgress(active.name);
    }
    final template = (await _startable(user.userId))
        .where((t) => t.workoutId == id)
        .firstOrNull;
    if (template == null) throw AppIntentRefusal(l10n.intentWorkoutNotFound);
    final run = _programs.state.activeRun;
    final inProgram =
        run != null &&
        run.mesocycle.workoutTemplates.any((t) => t.workoutId == id);
    int? microcycle;
    if (inProgram) {
      final progress = MesocycleSchedule.progress(
        run,
        _programs.state.sessions,
        now: _clock(),
      );
      final open = progress.cycles
          .expand((slots) => slots)
          .where((s) => s.isOpenWorkout && s.dayPlan.workoutId == id)
          .firstOrNull;
      microcycle = (open?.cycleIndex ?? progress.currentCycleIndex) + 1;
    }
    await _workouts.start(
      template: template,
      eventPrefix: 'AppIntents_StartWorkout',
      mesocycleId: inProgram ? run.mesocycle.id : null,
      microcycleIndex: microcycle,
      isDeload:
          microcycle != null &&
          MesocycleSchedule.isDeload(microcycle, run!.mesocycle),
    );
    _links.store(const WorkoutLink());
    return l10n.intentStarted(template.name);
  }

  /// Writes the weigh-in and the profile's weight, as Log Weight does.
  @override
  Future<String> logWeight(double value, {bool? pounds}) async {
    final user = await _user();
    final unit = switch (pounds) {
      true => WeightUnitPreference.pounds,
      false => WeightUnitPreference.kilograms,
      null =>
        user.submittedWeightUnitPreference ?? WeightUnitPreference.kilograms,
    };
    final isPounds = unit == WeightUnitPreference.pounds;
    final weightKg = isPounds ? value * 0.45359237 : value;
    final l10n = _l10n();
    if (weightKg < 20 || weightKg > 400) {
      throw AppIntentRefusal(l10n.intentWeightOutOfRange);
    }
    final now = _clock();
    await _saveMeasurement(
      BodyMeasurementEntry(
        id: _newId(),
        authorId: user.userId,
        weightKg: weightKg,
        date: now,
        source: WeightSource.manual,
        dateCreated: now,
      ),
    );
    await _users.updateUserFields(user.userId, [
      UserField.submittedWeightKilograms(weightKg),
      UserField.submittedWeightUnitPreference(unit),
    ]);
    return l10n.intentLoggedWeight(
      '${value.toStringAsFixed(1)} ${isPounds ? 'lb' : 'kg'}',
    );
  }

  @override
  Future<({int count, String sentence})> workoutsThisWeek() async {
    final user = await _user();
    final count = CircleWeek.sessionsInWeek(
      user.userId,
      _clock(),
      _programs.state.sessions,
      _firstWeekday() % 7,
    ).length;
    final goal = weeklySessionGoal(user.weeklySessionGoal);
    final l10n = _l10n();
    final remaining = CircleWeek.remaining(count, goal);
    return (
      count: count,
      sentence: count == 0
          ? l10n.intentWorkoutsNone(goal)
          : remaining == 0
          ? l10n.intentWorkoutsMet(count, goal)
          : l10n.intentWorkoutsToGo(count, remaining, goal),
    );
  }

  @override
  Future<({IntentWorkout? workout, String sentence})> todaysWorkout() async {
    await _user();
    final l10n = _l10n();
    final state = _programs.state;
    final mesocycle = state.activeMesocycle;
    final today = MesocycleSchedule.todayItem(
      state.activeRun,
      state.sessions,
      now: _clock(),
    );
    if (mesocycle == null || today == null) {
      return (workout: null, sentence: l10n.intentNoMesocycle);
    }
    final plan = today.dayPlan;
    if (plan.exercises.isEmpty) {
      return (workout: null, sentence: l10n.intentRestDay(mesocycle.name));
    }
    final workout = IntentWorkout(id: plan.workoutId, name: plan.name);
    return (
      workout: workout,
      sentence: today.isCompleted
          ? l10n.intentAlreadyDone(plan.name)
          : l10n.intentToday(plan.name, plan.exercises.length),
    );
  }

  @override
  Future<void> browseRecipes() async {
    await _user();
    _links.store(const RecipesLink());
  }
}
