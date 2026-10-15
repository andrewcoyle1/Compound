import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Starts staging part-way through onboarding, as a new anonymous account
/// whose profile resumes at this step (an `OnboardingStep` raw value, such
/// as `completeAccountSetup` or `goalSetting`). Empty starts as the seeded
/// sample user, who has finished onboarding.
const _onboardingStep = String.fromEnvironment('STAGING_ONBOARDING');

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
  await bootstrap(
    () => App(
      authRepository: InMemoryAuthRepository(
        user: step == null ? InMemoryAuthRepository.sampleUser : anonymous,
      ),
      userRepository: InMemoryUserRepository(
        users: {
          sampleUserId: sampleUser(now: now),
          anonymous.uid: ?onboardingProfile,
        },
        settings: {sampleUserId: sampleUserSettings(now: now)},
      ),
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
      ),
      nutritionRepository: InMemoryNutritionRepository(
        meals: sampleMealLogs(uid: sampleUserId, now: now),
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
    ),
  );
}
