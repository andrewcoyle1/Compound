import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  const uid = 'mock_user_123';
  final now = DateTime(2026, 10, 15, 19);

  late AppBloc appBloc;
  late GoRouter router;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    router = _MockGoRouter();
    when(() => router.goNamed(any())).thenReturn(null);
  });

  Future<void> pumpView(
    WidgetTester tester, {
    bool empty = false,
    List<String> hidden = const [],
    BodyRepository? bodyRepository,
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workouts = InMemoryWorkoutSessionRepository(
      sessions: empty ? const [] : sampleWorkoutSessions(uid: uid, now: now),
    );
    final nutrition = InMemoryNutritionRepository(
      meals: empty ? const [] : sampleMealLogs(uid: uid, now: now),
      dietPlan: empty ? null : sampleDietPlan(uid: uid, now: now),
    );
    final body =
        bodyRepository ??
        InMemoryBodyRepository(
          measurements: empty
              ? const []
              : sampleBodyMeasurements(uid: uid, now: now),
          steps: empty ? const [] : sampleSteps(uid: uid, now: now),
          goals: empty ? const [] : [sampleWeightGoal(uid: uid, now: now)],
          analyticsSettings: AnalyticsSettings(
            authorId: uid,
            hiddenSectionIds: hidden,
          ),
        );
    final users = InMemoryUserRepository(users: {uid: sampleUser(now: now)});
    await tester.pumpApp(
      InheritedGoRouter(
        goRouter: router,
        child: BlocProvider(
          create: (_) => ProgressBloc(
            workoutSessionRepository: workouts,
            nutritionRepository: nutrition,
            bodyRepository: body,
            userRepository: users,
            analyticsRepository: const AnalyticsRepository(),
            trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
            uid: uid,
            firstWeekday: DateTime.monday,
            now: () => now,
          )..add(const ProgressSubscriptionRequested()),
          child: const ProgressView(),
        ),
      ),
      appBloc: appBloc,
      textScale: textScale,
    );
    await tester.pump();
  }

  group(ProgressView, () {
    testWidgets('shows every ported card, in the Swift sections', (
      tester,
    ) async {
      await pumpView(tester);

      for (final header in [
        'Insights & Analytics',
        'Habits',
        'Nutrition',
        'Body Metrics',
        'Muscle Groups',
        'Exercises',
        'General',
      ]) {
        expect(find.text(header), findsOneWidget);
      }
      for (final title in [
        'Weight Trend',
        'Goal Progress',
        'Weigh In',
        'Macros',
        'Protein',
        'Scale Weight',
        'Visual Body Fat',
        'Steps',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      // One in Insights, one in Habits.
      expect(find.text('Workouts'), findsNWidgets(2));
      // The workouts card and two exercise cards.
      expect(find.text('Last 7 Workouts'), findsNWidgets(3));
      expect(find.text('Last 30 Days'), findsNWidgets(2));
      expect(find.text('Toward Target'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // Not yet: it needs the expenditure engine.
      expect(find.text('Expenditure'), findsNothing);
      expect(find.byType(MuscleSetsCard), findsNWidgets(2));
      expect(find.byType(ExerciseOneRepMaxCard), findsNWidgets(2));
      expect(find.byType(ProgressCard), findsNWidgets(14));
      expect(find.byType(Sparkline), findsNWidgets(6));
      expect(find.byType(HabitGridChart), findsNWidgets(2));
      expect(find.byType(StackedBars), findsNWidgets(4));
      expect(find.byType(ProgressBarChart), findsNWidgets(2));
    });

    testWidgets('an empty tab reads as absent, not zero', (tester) async {
      await pumpView(tester, empty: true);

      expect(find.text('No Workouts'), findsOneWidget);
      expect(find.text('No Entries'), findsNWidgets(3));
      expect(find.text('No Goal Set'), findsOneWidget);
      expect(find.text('No Data'), findsNWidgets(3));
      // Workouts, trend, goal, macros, protein, weight, body fat, steps and
      // the two exercises; the muscles show 0 sets.
      expect(find.text(AppFormat.placeholder), findsNWidgets(10));
    });

    testWidgets('leaves out hidden sections', (tester) async {
      await pumpView(tester, hidden: ['habits', 'body_metrics']);

      expect(find.text('Habits'), findsNothing);
      expect(find.text('Body Metrics'), findsNothing);
      expect(find.text('Insights & Analytics'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('opens the weight screens', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Weight Trend'));
      verify(() => router.goNamed(WeightMetric.weightTrend.name)).called(1);
      await tester.tap(find.text('Scale Weight'));
      verify(() => router.goNamed(WeightMetric.scaleWeight.name)).called(1);
      // Display only, for now.
      await tester.tap(find.text('Steps'));
      verifyNever(() => router.goNamed(any()));
    });

    testWidgets('opens the training screens', (tester) async {
      await pumpView(tester);
      when(
        () =>
            router.goNamed(any(), pathParameters: any(named: 'pathParameters')),
      ).thenReturn(null);

      await tester.tap(find.text('Last 7 Workouts').first);
      verify(() => router.goNamed(WorkoutMetricPage.name)).called(1);
      await tester.tap(find.text('Last 30 Days').last);
      verify(() => router.goNamed(WorkoutConsistencyPage.name)).called(1);
      final seeAll = find.text('See All');
      expect(seeAll, findsNWidgets(2));
      await tester.ensureVisible(seeAll.first);
      await tester.tap(seeAll.first);
      await tester.tap(seeAll.last);
      await tester.pump();
    });

    testWidgets('summarises its charts for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpView(tester);

      // The workouts card and two muscles.
      expect(find.bySemanticsLabel(RegExp('Working sets')), findsNWidgets(3));
      expect(
        find.bySemanticsLabel(RegExp('Macros, last 7 days')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('adds columns with width', (tester) async {
      await pumpView(tester, width: 1000);

      final trend = tester.getTopLeft(find.text('Weight Trend'));
      final goal = tester.getTopLeft(find.text('Goal Progress'));
      // Three across: Goal Progress sits beside Weight Trend.
      expect(goal.dy, trend.dy);
      expect(goal.dx, greaterThan(trend.dx));
    });

    testWidgets('goes to one column at large text sizes', (tester) async {
      await pumpView(tester, textScale: 2);

      final workouts = tester.getTopLeft(find.text('Last 7 Workouts').first);
      final trend = tester.getTopLeft(find.text('Weight Trend'));
      expect(trend.dx, workouts.dx);
      expect(trend.dy, greaterThan(workouts.dy));
    });

    testWidgets('says so when the data cannot be read', (tester) async {
      final body = MockBodyRepository();
      when(() => body.watchMeasurements(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      when(() => body.watchSteps(uid)).thenAnswer((_) => const Stream.empty());
      when(() => body.watchAnalyticsSettings(uid))
          .thenAnswer((_) => const Stream.empty());
      when(
        () => body.watchCurrentGoal(
          uid,
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => const Stream.empty());
      await pumpView(tester, bodyRepository: body);

      expect(find.text("Your progress couldn't be loaded."), findsOneWidget);
    });
  });

  group(ProgressPage, () {
    testWidgets('builds its bloc from the repositories', (tester) async {
      await tester.pumpApp(
        const ProgressPage(),
        appBloc: appBloc,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        userRepository: InMemoryUserRepository(),
      );
      await tester.pump();
      expect(find.byType(ProgressView), findsOneWidget);
    });

    testWidgets('shows nothing while signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const ProgressPage(), appBloc: appBloc);
      expect(find.byType(ProgressView), findsNothing);
    });
  });
}
