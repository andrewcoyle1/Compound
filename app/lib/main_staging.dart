import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:compound_models/compound_models.dart'
    show ExerciseWeightUnit, WorkoutSessionModel, WorkoutSessionModelKeys;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:food_repository/food_repository.dart';
import 'package:health_repository/health_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:strava_repository/strava_repository.dart';
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

/// `false` starts staging without a subscription. The sample user, already
/// signed in, reaches the tabs, where the coach's See Plans and Settings'
/// Subscription row open the paywall; anyone who signs in, or an account
/// still in onboarding (`STAGING_ONBOARDING`), is held at "Why
/// Subscribe?".
const _premium = bool.fromEnvironment('STAGING_PREMIUM', defaultValue: true);

/// What the fake store does, in turn, comma-separated: `cancelled`,
/// `pending`, `failed` or `owned` for the next purchases and restores, and
/// `loadFailed` or `noProducts` for loading the plans. Each later purchase
/// or restore succeeds, so every paywall state can be seen in one run.
const _purchases = String.fromEnvironment('STAGING_PURCHASES');

/// The fake store for [_premium] and [_purchases].
FakePurchasesRepository stagingPurchases() {
  final outcomes = _purchases.split(',').map((outcome) => outcome.trim());
  return FakePurchasesRepository(
    // Redundant only while the define is unset.
    // ignore: avoid_redundant_argument_values
    premium: _premium,
    products: outcomes.contains('noProducts')
        ? const []
        : FakePurchasesRepository.sampleProducts,
    failedLoads: outcomes.where((outcome) => outcome == 'loadFailed').length,
    failures: [
      for (final outcome in outcomes)
        ?switch (outcome) {
          'cancelled' => const PurchaseCancelled(),
          'pending' => const PurchasePending(),
          'failed' => const PurchasesFailure('Staging: the store refused.'),
          'owned' => const ProductAlreadyOwned(),
          _ => null,
        },
    ],
  );
}

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
  final foods = sampleFoods(uid: sampleUserId, now: now);
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
  // Followed people with workouts, likes and comments, a follow request,
  // followers and every handle reserved, over an in-memory Firestore.
  final socialRepository = await inMemorySocialRepository(
    users: userRepository,
    now: now,
  );
  // The sample chat, and canned answers streamed word by word once the
  // coach is allowed to read the data.
  final coachRepository = await inMemoryCoachRepository(
    users: userRepository,
    now: now,
  );
  final workoutSessionRepository = InMemoryWorkoutSessionRepository(
    sessions: [
      ...sampleEarlierWorkoutSessions(uid: sampleUserId, now: now),
      ...sampleWorkoutSessions(uid: sampleUserId, now: now),
      ..._programSessions(now),
      ?finished,
    ],
  );
  final nutritionRepository = InMemoryNutritionRepository(
    meals: [
      ...sampleMealLogs(uid: sampleUserId, now: now),
      ...sampleMealHistory(uid: sampleUserId, now: now),
    ],
    dietPlan: sampleDietPlan(uid: sampleUserId, now: now),
  );
  final bodyRepository = InMemoryBodyRepository(
    measurements: sampleBodyMeasurements(uid: sampleUserId, now: now),
    steps: sampleSteps(uid: sampleUserId, now: now),
    goals: [sampleWeightGoal(uid: sampleUserId, now: now)],
    progressPhotos: sampleProgressPhotos(uid: sampleUserId, now: now),
  );
  final trainingLibraryRepository = InMemoryTrainingLibraryRepository(
    exercises: sampleUserExercises,
    workoutTemplates: sampleUserWorkoutTemplates,
    gymProfiles: sampleGymProfiles,
    exerciseSettings: sampleExerciseSettings,
    workoutSettings: sampleWorkoutSettings,
  );
  const analyticsRepository = AnalyticsRepository(services: [ConsoleService()]);
  // Strava and its server on the device (Swift's MockStravaService): not
  // connected at first; connecting imports a run and a ride, which
  // disconnecting removes. Nothing leaves the device.
  final stravaFirestore = FakeFirebaseFirestore();
  final stravaRepository = StravaRepository(
    firestore: stravaFirestore,
    api: FakeStravaApi(
      firestore: stravaFirestore,
      uid: sampleUserId,
      activities: sampleStravaActivities(now),
    ),
    sessions: workoutSessionRepository,
    store: InMemoryStravaAccountStore(),
    clientId: 'staging',
    uploadContext: stravaUploadContext(
      users: userRepository,
      library: trainingLibraryRepository,
    ),
    onEvent: stravaEvents(analyticsRepository),
  );
  await bootstrap(
    () async => App(
      appVersion: await AppVersion.load(),
      // The Live Activity and the home-screen widgets are the device's own,
      // with nothing leaving it, so staging drives the real ones, as the
      // Swift Mock build does.
      liveActivityRepository: await _liveActivity(),
      homeWidgetRepository: MethodChannelHomeWidgetRepository(),
      appIntentsRepository: MethodChannelAppIntentsRepository(),
      // Two weeks of steps, a week of weigh-ins with body fat, two days of
      // food from other apps, and the onboarding fill values, in memory.
      healthRepository: HealthRepository(
        platform: sampleHealthPlatform(now),
        body: bodyRepository,
        nutrition: nutritionRepository,
      ),
      stravaRepository: stravaRepository,
      stravaAuthorizer: FakeStravaAuthorizer(),
      // Premium unless `STAGING_PREMIUM=false`, as the Swift Mock build
      // starts with "Simulate Premium" on. Staging has no store.
      purchasesRepository: stagingPurchases(),
      coachRepository: coachRepository,
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
      workoutSessionRepository: workoutSessionRepository,
      nutritionRepository: nutritionRepository,
      bodyRepository: bodyRepository,
      // Uploads stay in memory, and the camera and library return a bundled
      // picture.
      imageRepository: InMemoryImageRepository(),
      photoPicker: samplePhotoPicker(),
      // Canned answers, as Swift's MockAIService gives; nothing leaves the
      // device.
      aiRepository: AiRepository(callFunction: stagingAiCall),
      programRepository: InMemoryProgramRepository(
        mesocycles: sampleMesocycles(now: now),
        macrocycles: sampleMacrocycles(now: now),
      ),
      trainingLibraryRepository: trainingLibraryRepository,
      analyticsRepository: analyticsRepository,
      foodRepository: InMemoryFoodRepository(
        foods: foods,
        recipes: sampleRecipes(uid: sampleUserId, now: now, foods: foods),
      ),
      openFoodFacts: FakeOpenFoodFacts(),
      socialRepository: socialRepository,
      checkInRepository: InMemoryCheckInRepository(
        settings: [sampleStrategySettings(uid: sampleUserId)],
        annotations: sampleDayAnnotations(uid: sampleUserId, now: now),
        loggingBreaks: [sampleLoggingBreak(uid: sampleUserId, now: now)],
        records: [sampleCheckInRecord(uid: sampleUserId, now: now)],
      ),
    ),
  );
}

/// The platform's Live Activity, once asked whether it is on.
Future<LiveActivityRepository> _liveActivity() async {
  final repository = MethodChannelLiveActivityRepository(
    copy: AppNotificationCopy(),
  );
  await repository.initialize();
  return repository;
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

/// The followed Push/Pull/Legs, a microcycle and two days in: every day of
/// the first microcycle, its rest day, then Push 1 and Pull 1 again, so
/// today is Legs 1 of microcycle 2.
List<WorkoutSessionModel> _programSessions(DateTime now) {
  final mesocycle = sampleMesocycles(now: now).first;
  final days = mesocycle.workoutTemplates;
  DateTime at(int daysAgo) {
    final day = now.subtract(Duration(days: daysAgo));
    return DateTime(day.year, day.month, day.day, 18);
  }

  WorkoutSessionModel done(int position, int daysAgo, int microcycle) {
    final start = at(daysAgo);
    final end = start.add(const Duration(minutes: 55));
    final session = sessionFromTemplate(
      authorId: sampleUserId,
      template: days[position],
      now: start,
      id: 'sample-program-$daysAgo',
      mesocycleId: mesocycle.id,
      microcycleIndex: microcycle,
    );
    return session.copyWith(
      endedAt: end,
      exercises: [
        for (final exercise in session.exercises)
          exercise.copyWith(
            sets: [
              for (final set in exercise.sets)
                set.copyWith(
                  weightKg: set.weightKg ?? (set.isWarmup ? 30 : 60),
                  reps: set.reps ?? 8,
                  completedAt: end,
                ),
            ],
          ),
      ],
    );
  }

  final rest = days.last;
  return [
    for (var position = 0; position < 6; position++)
      done(position, 13 - position, 1),
    WorkoutSessionModel(
      id: 'sample-program-rest',
      authorId: sampleUserId,
      name: rest.name,
      workoutTemplateId: rest.workoutId,
      mesocycleId: mesocycle.id,
      dateCreated: at(7),
      dateModified: at(7),
      endedAt: at(7),
      isRestDay: true,
      exercises: const [],
    ),
    done(0, 6, 2),
    done(1, 4, 2),
  ];
}
