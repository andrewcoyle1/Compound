import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/connectivity/offline_alert_cubit.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/helpers.dart';

// Swift `ensureOnline`: an action tried offline is recorded as
// `Offline_ActionBlocked` and answered with "You're offline", wherever the
// user is.
void main() {
  test('each blocked action counts once and is recorded', () async {
    final connectivity = FakeConnectivityRepository(offline: true);
    final analytics = AnalyticsRecorder();
    final cubit = OfflineAlertCubit(
      connectivity: connectivity,
      analytics: analytics,
    );

    connectivity
      ..ensureOnline()
      ..ensureOnline();
    await pumpEventQueue();

    expect(cubit.state, 2);
    expect(analytics.names, ['Offline_ActionBlocked', 'Offline_ActionBlocked']);
    await cubit.close();
    connectivity.ensureOnline();
    await pumpEventQueue();
    expect(analytics.names, hasLength(2));
  });

  testWidgets("the app says you're offline over whatever is showing", (
    tester,
  ) async {
    final connectivity = FakeConnectivityRepository(offline: true);
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        connectivityRepository: connectivity,
        purchasesRepository: FakePurchasesRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(),
        userRepository: InMemoryUserRepository(),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
      ),
    );
    await tester.pumpAndSettle();

    connectivity.ensureOnline();
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
    expect(
      find.text(
        "This needs an internet connection. Try again when you're back "
        'online.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsNothing);
  });
}
