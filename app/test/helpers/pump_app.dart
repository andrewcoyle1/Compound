import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
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
    AnalyticsRepository analyticsRepository = const AnalyticsRepository(),
    AppBloc? appBloc,
    double textScale = 1,
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
          RepositoryProvider.value(value: analyticsRepository),
        ],
        child: BlocProvider.value(
          value: appBloc ?? MockAppBloc(),
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
