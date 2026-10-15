import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository;

class MockAppBloc extends Mock implements AppBloc;

class MockUserRepository extends Mock implements UserRepository;

class MockWorkoutSessionRepository extends Mock
    implements WorkoutSessionRepository;
class MockNutritionRepository extends Mock implements NutritionRepository;

class MockBodyRepository extends Mock implements BodyRepository;

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthRepository? authRepository,
    UserRepository? userRepository,
    WorkoutSessionRepository? workoutSessionRepository,
    NutritionRepository? nutritionRepository,
    BodyRepository? bodyRepository,
    TrainingLibraryRepository? trainingLibraryRepository,
    ProgramRepository? programRepository,
    AnalyticsRepository analyticsRepository = const AnalyticsRepository(),
    FoodRepository? foodRepository,
    OpenFoodFacts? openFoodFacts,
    CheckInRepository? checkInRepository,
    MealDraftCubit? mealDraftCubit,
    AppBloc? appBloc,
    SocialRepository? socialRepository,
    CircleBloc? circleBloc,
    double textScale = 1,
    GoRouter? router,
  }) {
    return pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(
            value: authRepository ?? MockAuthRepository(),
          ),
          RepositoryProvider.value(
            value: userRepository ?? MockUserRepository(),
          ),
          RepositoryProvider.value(
            value: workoutSessionRepository ?? MockWorkoutSessionRepository(),
          ),
          RepositoryProvider.value(
            value: nutritionRepository ?? MockNutritionRepository(),
          ),
          RepositoryProvider.value(
            value: bodyRepository ?? MockBodyRepository(),
          ),
          RepositoryProvider.value(
            value:
                trainingLibraryRepository ??
                InMemoryTrainingLibraryRepository(),
          ),
          RepositoryProvider.value(
            value: programRepository ?? InMemoryProgramRepository(),
          ),
          RepositoryProvider.value(value: analyticsRepository),
          RepositoryProvider<FoodRepository>.value(
            value: foodRepository ?? InMemoryFoodRepository(),
          ),
          RepositoryProvider<OpenFoodFacts>.value(
            value: openFoodFacts ?? FakeOpenFoodFacts(),
          ),
          RepositoryProvider<CheckInRepository>.value(
            value: checkInRepository ?? InMemoryCheckInRepository(),
          ),
          RepositoryProvider<SocialRepository>.value(
            value:
                socialRepository ??
                SocialRepository(
                  firestore: FakeFirebaseFirestore(),
                  callFunction: (_, _) async => null,
                  users: userRepository ?? MockUserRepository(),
                ),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: appBloc ?? MockAppBloc()),
            BlocProvider.value(value: mealDraftCubit ?? MealDraftCubit()),
            BlocProvider<CircleBloc>(
              create: (context) =>
                  circleBloc ??
                  CircleBloc(
                    social: context.read(),
                    sessions: context.read(),
                    analytics: analyticsRepository,
                  ),
            ),
          ],
          // With a [router], [widget] is left out: the router's routes are
          // the app.
          child: router != null
              ? MaterialApp.router(
                  theme: AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                )
              : MaterialApp(
                  theme: AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: MediaQuery.withClampedTextScaling(
                    minScaleFactor: textScale,
                    maxScaleFactor: textScale,
                    child: widget,
                  ),
                ),
        ),
      ),
    );
  }
}
