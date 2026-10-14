import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);
  UserRepository seededUsers() => InMemoryUserRepository(
    users: {sampleUserId: sampleUser(now: now)},
    settings: {sampleUserId: sampleUserSettings(now: now)},
  );

  WorkoutSessionRepository seededSessions() => InMemoryWorkoutSessionRepository(
    sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
  );

  group(App, () {
    testWidgets('signs in, then out, through the router', (tester) async {
      await tester.pumpWidget(
        App(
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
      expect(find.byType(SignInPage), findsOneWidget);

      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text("Your profile couldn't be loaded."), findsOneWidget);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('starts signed in as the sample user, as staging does, and '
        'shows their profile over the tabs', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('@alice.cooper'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);

      // Closing returns to the tab underneath.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('switches between the five tabs', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in ['Training', 'Nutrition', 'Progress', 'Social']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(title),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
        // Nutrition and Progress are ported; the others are still
        // placeholders.
        expect(
          find.byType(NutritionView),
          title == 'Nutrition' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(ProgressPage),
          title == 'Progress' ? findsOneWidget : findsNothing,
        );
      }

      // Tapping the current tab again stays on it.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Social'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Social'), findsOneWidget);
    });

    testWidgets('opens the workout history and a workout from Training', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Training'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout History'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryView), findsOneWidget);

      // Newest first: yesterday's Push B.
      await tester.tap(find.text('Push B'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Push B'), findsOneWidget);
      expect(find.text('Dumbbell Seated Shoulder Press'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryView), findsOneWidget);
    });

    testWidgets('opens Weight Trend and its recorded data from Progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(
            measurements: sampleBodyMeasurements(uid: sampleUserId, now: now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Progress'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weight Trend'));
      await tester.pumpAndSettle();
      expect(find.byType(WeightMetricView), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Weight Trend'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Show All Data'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(MetricDetailView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Show All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'All Recorded Data'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Weight Trend'), findsOneWidget);
    });
  });
}
