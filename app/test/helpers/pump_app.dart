import 'dart:typed_data';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
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
    ProposalDismissals? proposalDismissals,
    MealDraftCubit? mealDraftCubit,
    AppBloc? appBloc,
    SocialRepository? socialRepository,
    CircleBloc? circleBloc,
    InboxBloc? inboxBloc,
    ChallengesCubit? challengesCubit,
    InviteCubit? inviteCubit,
    ShareSheet shareSheet = const ShareSheet(),
    ImageRepository? imageRepository,
    PhotoPicker? photoPicker,
    NotificationsRepository? notificationsRepository,
    ProgramsCubit? programsCubit,
    ActiveWorkoutCubit? activeWorkoutCubit,
    CoachRepository? coachRepository,
    PurchasesRepository? purchasesRepository,
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
          RepositoryProvider.value(
            value: proposalDismissals ?? ProposalDismissals(),
          ),
          RepositoryProvider<CoachRepository>.value(
            value:
                coachRepository ??
                CoachRepository(
                  firestore: FakeFirebaseFirestore(),
                  users: userRepository ?? MockUserRepository(),
                  coachChat: (_, {chatId, context}) => Stream.error(
                    const CoachException(CoachFailure.unavailable),
                  ),
                ),
          ),
          RepositoryProvider<PurchasesRepository>.value(
            value: purchasesRepository ?? FakePurchasesRepository(),
          ),
          RepositoryProvider.value(value: shareSheet),
          RepositoryProvider<ImageRepository>.value(
            value: imageRepository ?? InMemoryImageRepository(),
          ),
          RepositoryProvider<PhotoPicker>.value(
            value: photoPicker ?? SamplePhotoPicker(() async => Uint8List(0)),
          ),
          RepositoryProvider<NotificationsRepository>.value(
            value: notificationsRepository ?? FakeNotificationsRepository(),
          ),
          RepositoryProvider(
            create: (context) => ProgramService(
              programs: context.read(),
              users: context.read(),
              sessions: context.read(),
            ),
          ),
          RepositoryProvider(
            create: (context) => TrainingSetupService(
              programs: context.read(),
              library: context.read(),
              users: context.read(),
            ),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: appBloc ?? MockAppBloc()),
            BlocProvider.value(value: mealDraftCubit ?? MealDraftCubit()),
            if (activeWorkoutCubit != null)
              BlocProvider.value(value: activeWorkoutCubit),
            // Following nobody unless a test passes one that does.
            BlocProvider<ProgramsCubit>(
              create: (context) =>
                  programsCubit ??
                  ProgramsCubit(
                    programs: context.read(),
                    users: context.read(),
                    sessions: context.read(),
                    service: ProgramService(
                      programs: context.read(),
                      users: context.read(),
                      sessions: context.read(),
                    ),
                    setup: TrainingSetupService(
                      programs: context.read(),
                      library: context.read(),
                      users: context.read(),
                    ),
                    analytics: analyticsRepository,
                  ),
            ),
            BlocProvider<CircleBloc>(
              create: (context) =>
                  circleBloc ??
                  CircleBloc(
                    social: context.read(),
                    sessions: context.read(),
                    analytics: analyticsRepository,
                  ),
            ),
            BlocProvider<ChallengesCubit>(
              create: (context) =>
                  challengesCubit ??
                  ChallengesCubit(
                    social: context.read(),
                    analytics: analyticsRepository,
                  ),
            ),
            BlocProvider<InviteCubit>(
              create: (context) =>
                  inviteCubit ??
                  InviteCubit(
                    social: context.read(),
                    analytics: analyticsRepository,
                  ),
            ),
            BlocProvider<InboxBloc>(
              create: (context) =>
                  inboxBloc ??
                  InboxBloc(
                    social: context.read(),
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
