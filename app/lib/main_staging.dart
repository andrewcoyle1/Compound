import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:compound_models/compound_models.dart'
    show ExerciseWeightUnit, WorkoutSessionModel, WorkoutSessionModelKeys;
import 'package:food_repository/food_repository.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart'
    show LogSetAction, NextExerciseAction;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Starts staging part-way through onboarding, as a new anonymous account
/// whose profile resumes at this step (an `OnboardingStep` raw value, such
/// as `completeAccountSetup` or `goalSetting`). Empty starts as the seeded
/// sample user, who has finished onboarding.
const _onboardingStep = String.fromEnvironment('STAGING_ONBOARDING');

/// Starts staging with a workout under way from this workout template id
/// (such as `user-workout-upper`), `STAGING_WORKOUT_LOGGED` of its sets
/// logged, for screenshots of the tracker: launch with
/// `--dart-define=INITIAL_LOCATION=/workout` to open it.
const _workout = String.fromEnvironment('STAGING_WORKOUT');
const _workoutLogged = int.fromEnvironment('STAGING_WORKOUT_LOGGED');

/// With `STAGING_WORKOUT`, finishes the workout into the history as
/// `staging-finished-workout`, for the summary at
/// `/workout-summary/staging-finished-workout`.
const _workoutFinished = bool.fromEnvironment('STAGING_WORKOUT_FINISHED');

/// The staging flavor, which is the Swift app's old Mock configuration:
/// in-memory repositories and no Firebase, for previews and demos. Starts
/// signed in as the seeded sample user; signing out and back in stays in
/// memory. Analytics only print to the console.
///
/// To go through onboarding, sign out and choose "Continue without an
/// account": the anonymous account has no profile, so one is created and
/// onboarding starts at account setup. Or launch with
/// `--dart-define=STAGING_ONBOARDING=<step>` to start at a later step.
Future<void> main() async {
  final now = DateTime.now();
  final step = OnboardingStep.values
      .where((step) => step.value == _onboardingStep)
      .firstOrNull;
  const anonymous = InMemoryAuthRepository.anonymousUser;
  final onboardingProfile = step == null
      ? null
      : stagingOnboardingProfile(step, uid: anonymous.uid, now: now);
  final userRepository = InMemoryUserRepository(
    users: {
      sampleUserId: sampleUser(now: now),
      anonymous.uid: ?onboardingProfile,
    },
    settings: {sampleUserId: sampleUserSettings(now: now)},
  );
  final activeSessionStore = InMemoryActiveSessionStore();
  final finished = _workout.isEmpty
      ? null
      : await _seedWorkout(activeSessionStore, now: now);
  await bootstrap(
    () => App(
      activeSessionStore: activeSessionStore,
      // Nothing reaches the platform: reminders and the rest timer's
      // notification are only recorded.
      notificationsRepository: FakeNotificationsRepository(
        permissionState: PushPermission.authorized,
      ),
      authRepository: InMemoryAuthRepository(
        user: step == null ? InMemoryAuthRepository.sampleUser : anonymous,
      ),
      userRepository: userRepository,
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: [
          ...sampleWorkoutSessions(uid: sampleUserId, now: now),
          ?finished,
        ],
      ),
      nutritionRepository: InMemoryNutritionRepository(
        meals: [
          ...sampleMealLogs(uid: sampleUserId, now: now),
          ...sampleMealHistory(uid: sampleUserId, now: now),
        ],
        dietPlan: sampleDietPlan(uid: sampleUserId, now: now),
      ),
      bodyRepository: InMemoryBodyRepository(
        measurements: sampleBodyMeasurements(uid: sampleUserId, now: now),
        steps: sampleSteps(uid: sampleUserId, now: now),
        goals: [sampleWeightGoal(uid: sampleUserId, now: now)],
      ),
      programRepository: InMemoryProgramRepository(
        mesocycles: sampleMesocycles(now: now),
        macrocycles: sampleMacrocycles(now: now),
      ),
      trainingLibraryRepository: InMemoryTrainingLibraryRepository(
        exercises: sampleUserExercises,
        workoutTemplates: sampleUserWorkoutTemplates,
        gymProfiles: sampleGymProfiles,
        exerciseSettings: sampleExerciseSettings,
        workoutSettings: sampleWorkoutSettings,
      ),
      analyticsRepository: const AnalyticsRepository(
        services: [ConsoleService()],
      ),
      foodRepository: InMemoryFoodRepository(
        foods: sampleFoods(uid: sampleUserId, now: now),
      ),
      openFoodFacts: FakeOpenFoodFacts(),
      checkInRepository: InMemoryCheckInRepository(
        settings: [sampleStrategySettings(uid: sampleUserId)],
        annotations: sampleDayAnnotations(uid: sampleUserId, now: now),
        loggingBreaks: [sampleLoggingBreak(uid: sampleUserId, now: now)],
        records: [sampleCheckInRecord(uid: sampleUserId, now: now)],
      ),
    ),
  );
}

/// A workout from [_workout] with [_workoutLogged] sets logged two minutes
/// apart, the last just now, kept in [store] for the app to resume.
Future<WorkoutSessionModel?> _seedWorkout(
  ActiveSessionStore store, {
  required DateTime now,
}) async {
  final template = [
    ...sampleUserWorkoutTemplates,
    ...PrebuiltCatalogue.instance.workoutTemplates,
  ].firstWhere((template) => template.workoutId == _workout);
  final settings = sampleWorkoutSettings.first;
  final gym = sampleGymProfiles.first;
  var clock = now.subtract(const Duration(minutes: 2 * _workoutLogged + 1));
  final session = plannedSession(
    authorId: sampleUserId,
    template: template,
    library: PrebuiltCatalogue.instance.exercises,
    history: SessionHistory(sampleWorkoutSessions(uid: sampleUserId, now: now)),
    settings: settings,
    gyms: sampleGymProfiles,
    workoutGym: gym,
    now: clock,
  );
  final controller = ActiveSessionController(
    state: ActiveSessionState(session: session),
    environment: TrackerEnvironment(
      authorId: sampleUserId,
      settings: settings,
      library: PrebuiltCatalogue.instance.exercises,
      gym: gym,
    ),
    store: store,
    clock: () => clock,
  );
  // The sample history has none of these exercises, so the sets start
  // empty; fill them as a lifter would.
  // Two working sets each, so the card stays on an exercise between them.
  for (final exercise in session.exercises) {
    controller.addSet(exercise.id);
  }
  for (final exercise in controller.session.exercises) {
    final pounds = exercise.weightUnit == ExerciseWeightUnit.pounds;
    for (final set in exercise.sets) {
      final weight = switch ((pounds, set.isWarmup)) {
        (true, true) => 45 / 2.20462,
        (true, false) => 95 / 2.20462,
        (false, true) => 20.0,
        (false, false) => 40.0,
      };
      controller
        ..editSet(
          set.copyWith(weightKg: set.weightKg ?? weight, reps: set.reps ?? 10),
        )
        ..commitEdit();
    }
  }
  for (var logged = 0; logged < _workoutLogged; logged++) {
    clock = clock.add(const Duration(minutes: 2));
    final action = controller.primaryAction;
    if (action is NextExerciseAction) {
      controller.selectExercise(action.exerciseId);
    }
    final next = controller.primaryAction;
    if (next is! LogSetAction) break;
    controller.logSet(next.setId);
    // The last set's rest is left running, as it would be mid-workout.
    if (logged < _workoutLogged - 1) controller.skipRest();
  }
  if (_workoutFinished) {
    clock = clock.add(const Duration(minutes: 3));
    final session = await controller.finish();
    await store.clear();
    return WorkoutSessionModel.fromFirestore({
      ...session.toFirestore(),
      WorkoutSessionModelKeys.id: 'staging-finished-workout',
    });
  }
  controller.flush();
  await controller.saved;
  return null;
}
