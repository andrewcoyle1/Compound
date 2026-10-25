import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_analytics/view/workout_consistency_page.dart'
    show ContributionGrid;
import 'package:compound_models/compound_models.dart'
    show BodyMeasurementEntryKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = sampleUserId;
  final now = DateTime.now();

  late AppBloc appBloc;
  late AnalyticsRecorder analytics;

  setUpAll(
    () => registerFallbackValue(
      BodyMeasurementEntry(
        id: 'fallback',
        authorId: uid,
        date: DateTime(2026),
        source: WeightSource.manual,
        dateCreated: DateTime(2026),
      ),
    ),
  );

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    analytics = AnalyticsRecorder();
  });

  BodyMeasurementEntry entry(
    String id, {
    int daysAgo = 1,
    double? weightKg,
    double? waist,
    double? hip,
    double? bodyFat,
  }) {
    final date = DateTime(now.year, now.month, now.day - daysAgo, 7);
    return BodyMeasurementEntry(
      id: id,
      authorId: uid,
      weightKg: weightKg,
      waistCircumference: waist,
      hipCircumference: hip,
      bodyFatPercentage: bodyFat,
      date: date,
      source: WeightSource.manual,
      dateCreated: date,
    );
  }

  /// [location] over the sample user's data, or what is given.
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    BodyRepository? body,
    NutritionRepository? nutrition,
    UserRepository? users,
    bool noGoal = false,
    HealthCubit? healthCubit,
  }) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox.shrink(),
      router: progressRouter(location),
      appBloc: appBloc,
      healthCubit: healthCubit,
      analyticsRepository: analytics,
      bodyRepository:
          body ??
          InMemoryBodyRepository(
            measurements: sampleBodyMeasurements(uid: uid, now: now),
            steps: sampleSteps(uid: uid, now: now),
            goals: noGoal ? const [] : [sampleWeightGoal(uid: uid, now: now)],
          ),
      nutritionRepository:
          nutrition ??
          InMemoryNutritionRepository(
            meals: [
              ...sampleMealLogs(uid: uid, now: now),
              ...sampleMealHistory(uid: uid, now: now),
            ],
            dietPlan: sampleDietPlan(uid: uid, now: now),
          ),
      userRepository:
          users ?? InMemoryUserRepository(users: {uid: sampleUser(now: now)}),
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: sampleWorkoutSessions(uid: uid, now: now),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  group('Body Metrics', () {
    testWidgets('groups every card and opens each history', (tester) async {
      await pumpAt(tester, '/progress/body-metrics');

      for (final header in [
        'Weight & Body Fat',
        'Upper Body',
        'Arms',
        'Legs',
        'Ratios',
      ]) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('LEFT ANKLE'), findsOneWidget);
      expect(analytics.names, contains('BodyMetricsView_Appear'));

      await tapText(tester, 'WAIST');
      expect(find.text('Waist Circumference'), findsWidgets);
      expect(find.byType(MetricDetailView), findsOneWidget);
      expect(analytics.parameters('BodyMeasurementDetailView_Appear'), {
        'measurement': 'waist',
      });
    });

    testWidgets('opens scale weight', (tester) async {
      await pumpAt(tester, '/progress/body-metrics');
      await tapText(tester, 'SCALE WEIGHT');
      expect(find.text('scaleWeight screen'), findsOneWidget);
    });

    testWidgets('without a waist the ratios say what they need', (
      tester,
    ) async {
      await pumpAt(
        tester,
        '/progress/body-metrics',
        body: InMemoryBodyRepository(measurements: [entry('w', weightKg: 70)]),
      );
      expect(
        find.text('Log a waist measurement to see your body ratios.'),
        findsOneWidget,
      );
      expect(find.text('No Entries'), findsWidgets);
    });

    testWidgets('a circumference shows in inches for an inches user', (
      tester,
    ) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waist',
        body: InMemoryBodyRepository(measurements: [entry('w', waist: 81.28)]),
        users: InMemoryUserRepository(
          users: {
            uid: const UserModel(
              userId: uid,
              submittedLengthUnitPreference: LengthUnitPreference.inches,
            ),
          },
        ),
      );
      expect(find.text('32 in'), findsWidgets);
    });

    testWidgets('deleting a reading clears only that measurement', (
      tester,
    ) async {
      final body = InMemoryBodyRepository(
        measurements: [entry('e', weightKg: 70, waist: 84)],
      );
      await pumpAt(tester, '/progress/body-metrics/waist/data', body: body);

      await tester.drag(find.text('84 cm'), const Offset(-700, 0));
      await tester.pumpAndSettle();

      final stored = (await body.watchMeasurements(uid).first).single;
      expect(stored.waistCircumference, isNull);
      expect(stored.weightKg, 70);
      expect(find.text('No waist measurement entries'), findsOneWidget);
      expect(
        analytics.names,
        containsAll([
          'BodyMeasurementDetailView_DeleteEntry_Start',
          'BodyMeasurementDetailView_DeleteEntry_Success',
        ]),
      );
    });

    testWidgets('an empty measurement offers to log one', (tester) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/leftCalf',
        body: InMemoryBodyRepository(),
      );
      expect(find.text('No left calf measurement entries'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Log Left Calf Measurement'), findsOneWidget);
    });

    testWidgets('visual body fat can be deleted but not added', (tester) async {
      final body = InMemoryBodyRepository(
        measurements: [entry('e', weightKg: 70, bodyFat: 18.5)],
      );
      await pumpAt(tester, '/progress/body-metrics/visualBodyFat', body: body);
      expect(find.text('Visual Body Fat'), findsOneWidget);
      expect(find.byTooltip('Add'), findsNothing);

      await tapText(tester, 'Show All Data');
      await tester.drag(find.text('18.5 %'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      final stored = (await body.watchMeasurements(uid).first).single;
      expect(stored.bodyFatPercentage, isNull);
      expect(stored.weightKg, 70);
    });

    testWidgets('waist to height screens against the NICE bands', (
      tester,
    ) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waistToHeight',
        body: InMemoryBodyRepository(measurements: [entry('w', waist: 80)]),
      );
      // 80 cm at the sample user's 175 cm.
      expect(find.text('0.46'), findsWidgets);
      expect(find.text('Under half your height'), findsOneWidget);
      expect(find.byType(MethodInfoButton), findsOneWidget);
      expect(find.textContaining('NICE bands'), findsOneWidget);
    });

    testWidgets('waist to hip uses the cut-off for the sex', (tester) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waistToHip',
        body: InMemoryBodyRepository(
          measurements: [entry('w', waist: 92, hip: 100)],
        ),
      );
      expect(find.text('Substantially increased risk'), findsOneWidget);
      expect(find.textContaining('WHO cut-off for men'), findsOneWidget);
    });

    testWidgets('waist to hip without a sex shows no band', (tester) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waistToHip',
        body: InMemoryBodyRepository(
          measurements: [entry('w', waist: 92, hip: 100)],
        ),
        users: InMemoryUserRepository(
          users: {uid: const UserModel(userId: uid)},
        ),
      );
      expect(find.text('Screening Band'), findsNothing);
      expect(find.textContaining('Set your sex'), findsOneWidget);
    });

    testWidgets('a ratio with no readings offers to log a waist', (
      tester,
    ) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waistToHeight',
        body: InMemoryBodyRepository(),
      );
      expect(
        find.text(
          'Log a waist measurement and set your height to see this ratio.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Log Waist'));
      await tester.pumpAndSettle();
      expect(find.text('Log Waist Measurement'), findsOneWidget);
    });

    testWidgets('a waist-to-hip ratio lists every entry', (tester) async {
      await pumpAt(
        tester,
        '/progress/body-metrics/waistToHip/data',
        body: InMemoryBodyRepository(
          measurements: [entry('w', waist: 80, hip: 100)],
        ),
      );
      expect(find.text('0.80'), findsOneWidget);
    });

    testWidgets('a failed read says so', (tester) async {
      final body = MockBodyRepository();
      when(() => body.watchMeasurements(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      when(() => body.watchSteps(uid)).thenAnswer((_) => Stream.value([]));
      when(
        () => body.watchAnalyticsSettings(uid),
      ).thenAnswer((_) => Stream.value(const AnalyticsSettings(authorId: uid)));
      when(
        () => body.watchCurrentGoal(
          uid,
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => Stream.value(null));
      await pumpAt(tester, '/progress/body-metrics', body: body);
      expect(find.text("Your progress couldn't be loaded."), findsOneWidget);
    });
  });

  group('Nutrition', () {
    testWidgets('shows every section and opens a nutrient', (tester) async {
      await pumpAt(tester, '/progress/nutrition-analytics');
      for (final header in [
        'Calories & Macros',
        'Carb Breakdown',
        'Fat Breakdown',
        'Vitamin Breakdown',
        'Mineral Breakdown',
        'Other Breakdown',
      ]) {
        await tester.scrollUntilVisible(find.text(header), 300);
        expect(find.text(header), findsOneWidget);
        if (header == 'Vitamin Breakdown') {
          await tester.scrollUntilVisible(find.text('B12, COBALAMIN'), 300);
        }
      }
      expect(analytics.names, contains('NutritionAnalyticsView_Appear'));

      // Back at the top.
      await pumpAt(tester, '/progress/nutrition-analytics');
      await tapText(tester, 'PROTEIN');
      expect(find.byType(MetricDetailView), findsOneWidget);
      expect(analytics.parameters('NutritionMetricDetailView_Appear'), {
        'metric': 'protein',
      });
    });

    testWidgets('nothing logged today reads as no data', (tester) async {
      await pumpAt(
        tester,
        '/progress/nutrition-analytics',
        nutrition: InMemoryNutritionRepository(),
      );
      expect(find.text('No Data'), findsWidgets);
    });

    testWidgets('Macros stacks the three and lists each day', (tester) async {
      await pumpAt(tester, '/progress/nutrition-analytics/macros');
      // Protein leads the header; the others follow it.
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('Carbs'), findsWidgets);
      expect(find.text('Fat'), findsWidgets);
      await tapText(tester, 'Show All Data');
      expect(find.textContaining('\u00a0P · '), findsWidgets);
    });

    testWidgets('an empty nutrient offers to log a meal', (tester) async {
      await pumpAt(
        tester,
        '/progress/nutrition-analytics/iron',
        nutrition: InMemoryNutritionRepository(),
      );
      expect(
        find.text('No iron data. Log meals to see your nutrition over time.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Log Meal'));
      await tester.pumpAndSettle();
      expect(find.text('logMeal screen'), findsOneWidget);
    });

    testWidgets('a nutrient lists its days with its unit', (tester) async {
      await pumpAt(tester, '/progress/nutrition-analytics/calories/data');
      expect(find.textContaining(' kcal'), findsWidgets);
    });

    testWidgets('an unknown metric shows every metric', (tester) async {
      await pumpAt(tester, '/progress/nutrition-analytics/starch');
      expect(find.text('Calories & Macros'), findsOneWidget);
    });

    testWidgets('food logging is a grid of the logged days', (tester) async {
      await pumpAt(tester, '/progress/food-logging-consistency');
      expect(find.byType(ContributionGrid), findsOneWidget);
      await tapText(tester, 'Show All Data');
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('no food logged says so and offers a meal', (tester) async {
      await pumpAt(
        tester,
        '/progress/food-logging-consistency',
        nutrition: InMemoryNutritionRepository(),
      );
      expect(
        find.text('No food logged. Log meals to see your consistency.'),
        findsOneWidget,
      );
    });
  });

  group('Habits and Insights', () {
    testWidgets('Habits shows the three habits and opens each', (tester) async {
      await pumpAt(tester, '/progress/habits');
      expect(find.byType(HabitGridChart), findsNWidgets(3));
      expect(find.textContaining('/7'), findsOneWidget);
      await tapText(tester, 'FOOD LOGGING');
      expect(find.byType(ContributionGrid), findsOneWidget);
    });

    testWidgets('Habits opens weigh-in and workout consistency', (
      tester,
    ) async {
      await pumpAt(tester, '/progress/habits');
      await tapText(tester, 'WORKOUTS');
      expect(find.text('workoutConsistency screen'), findsOneWidget);
    });

    testWidgets('Insights shows its four sections', (tester) async {
      await pumpAt(tester, '/progress/insights');
      for (final header in ['Activity', 'Energy', 'Body', 'Goals']) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.byType(MethodInfoButton), findsNWidgets(2));
      await tapText(tester, 'GOAL PROGRESS');
      expect(find.text('Lose weight'), findsOneWidget);
    });
  });

  group('Weigh-in consistency', () {
    testWidgets('a grid of weigh-ins whose weight can be deleted', (
      tester,
    ) async {
      final body = InMemoryBodyRepository(
        measurements: [entry('e', weightKg: 70, waist: 84)],
      );
      await pumpAt(tester, '/progress/weigh-in-consistency', body: body);
      expect(find.byType(ContributionGrid), findsOneWidget);

      await tapText(tester, 'Show All Data');
      await tester.drag(find.text('70 kg'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      final stored = (await body.watchMeasurements(uid).first).single;
      expect(stored.weightKg, isNull);
      expect(stored.waistCircumference, 84);
      expect(find.text('No weigh-ins logged'), findsOneWidget);
    });

    testWidgets('a failed delete says so and keeps the row', (tester) async {
      final body = MockBodyRepository();
      final weighIn = entry('e', weightKg: 70);
      when(() => body.watchMeasurements(uid))
          .thenAnswer((_) => Stream.value([weighIn]));
      when(() => body.watchSteps(uid)).thenAnswer((_) => Stream.value([]));
      when(
        () => body.watchAnalyticsSettings(uid),
      ).thenAnswer((_) => Stream.value(const AnalyticsSettings(authorId: uid)));
      when(
        () => body.watchCurrentGoal(
          uid,
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => Stream.value(null));
      when(
        () => body.clearMeasurementFields(uid, 'e', {
          BodyMeasurementEntryKeys.weightKg,
        }),
      ).thenThrow(Exception('offline'));
      await pumpAt(tester, '/progress/weigh-in-consistency/data', body: body);

      await tester.drag(find.text('70 kg'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Delete Entry'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('70 kg'), findsOneWidget);
    });

    testWidgets('an empty screen offers Log Weight', (tester) async {
      await pumpAt(
        tester,
        '/progress/weigh-in-consistency',
        body: InMemoryBodyRepository(),
      );
      await tester.tap(find.text('Log Weight'));
      await tester.pumpAndSettle();
      expect(find.text('logWeight screen'), findsOneWidget);
    });
  });

  group('Goal Progress', () {
    testWidgets('shows the goal, its weights and its method', (tester) async {
      await pumpAt(tester, '/progress/goal-progress');
      expect(find.text('Lose weight'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('68\u00a0kg'), findsOneWidget);
      expect(find.byType(MethodInfoButton), findsOneWidget);

      await tapText(tester, 'Show All Data');
      expect(find.textContaining('kg ('), findsWidgets);
    });

    testWidgets('without a goal says so, and Set Goal sets one', (
      tester,
    ) async {
      await pumpAt(tester, '/progress/goal-progress', noGoal: true);
      expect(find.text('No Active Weight Goal'), findsOneWidget);
      expect(find.byTooltip('Log Weight'), findsNothing);
      expect(find.byTooltip('Change Goal'), findsNothing);

      await tapText(tester, 'Set Goal');
      expect(find.text('weightGoal screen'), findsOneWidget);
    });

    // GoalProgressPresenter.onChangeGoalPressed and WeightGoalChoices.
    testWidgets('Change Goal offers editing the running goal or a fresh '
        'start', (tester) async {
      await pumpAt(tester, '/progress/goal-progress');
      await tester.tap(find.byTooltip('Change Goal'));
      await tester.pumpAndSettle();
      expect(find.text('Weight Goal'), findsOneWidget);
      expect(
        find.text(
          "Edit your target and pace, or start a new goal from today's "
          'weight.',
        ),
        findsOneWidget,
      );

      await tapText(tester, 'Cancel');
      expect(find.text('Weight Goal'), findsNothing);

      await tester.tap(find.byTooltip('Change Goal'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Edit Goal');
      expect(find.text('weightGoal screen edit=1'), findsOneWidget);
    });

    testWidgets('Start a New Goal starts one; a finished goal is replaced '
        'without asking', (tester) async {
      await pumpAt(tester, '/progress/goal-progress');
      await tester.tap(find.byTooltip('Change Goal'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Start a New Goal');
      expect(find.text('weightGoal screen'), findsOneWidget);

      final done = sampleWeightGoal(uid: uid, now: now);
      await pumpAt(
        tester,
        '/progress/goal-progress',
        body: InMemoryBodyRepository(
          measurements: sampleBodyMeasurements(uid: uid, now: now),
          goals: [
            WeightGoal.fromFirestore({
              ...done.toFirestore(),
              'status': 'completed',
            }),
          ],
        ),
      );
      await tester.tap(find.byTooltip('Change Goal'));
      await tester.pumpAndSettle();
      expect(find.text('weightGoal screen'), findsOneWidget);
    });
  });

  group('Steps', () {
    testWidgets('charts the stored steps and lists each day', (tester) async {
      await pumpAt(tester, '/progress/steps');
      expect(find.byType(MetricDetailView), findsOneWidget);
      expect(analytics.names, contains('StepsView_Appear'));
      await tapText(tester, 'Show All Data');
      expect(find.textContaining(' steps'), findsWidgets);
    });

    testWidgets('without steps says so', (tester) async {
      await pumpAt(tester, '/progress/steps', body: InMemoryBodyRepository());
      expect(find.text('No step data'), findsOneWidget);
    });

    testWidgets('asks Health on appearing, syncs on a tap, and says when '
        'access is refused', (tester) async {
      final body = InMemoryBodyRepository();
      final platform = sampleHealthPlatform(DateTime.now());
      final health = HealthCubit(
        health: HealthRepository(
          platform: platform,
          body: body,
          nutrition: InMemoryNutritionRepository(),
        ),
        analytics: analytics,
      );
      await tester.runAsync(() async {
        health.userChanged(uid);
        await Future<void>.delayed(Duration.zero);
      });
      await pumpAt(tester, '/progress/steps', body: body, healthCubit: health);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(platform.requested, [HealthScope.steps]);
      expect(find.text('No step data'), findsNothing);

      platform.granted = false;
      await tester.tap(find.byTooltip('Sync from Health Connect').first);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Access Health Connect'), findsOneWidget);
      expect(analytics.names, contains('StepsView_Sync_Fail'));
    });
  });

  group('Log Measurement', () {
    testWidgets('saves a reading and closes', (tester) async {
      final body = InMemoryBodyRepository();
      await pumpAt(tester, '/progress/body-metrics/neck', body: body);
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Neck Circumference'), findsWidgets);

      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('in').last);
      await tester.pumpAndSettle();
      expect(find.text('16'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Log Neck Measurement'), findsNothing);
      final stored = (await body.watchMeasurements(uid).first).single;
      expect(stored.neckCircumference, closeTo(16 * 2.54, 1e-9));
    });

    testWidgets('a failed save says so and stays open', (tester) async {
      final body = MockBodyRepository();
      when(() => body.watchMeasurements(uid))
          .thenAnswer((_) => Stream.value([]));
      when(() => body.saveMeasurement(any())).thenThrow(Exception('offline'));
      await pumpAt(tester, '/log-measurement/chest', body: body);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Save Measurement'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Log Chest Measurement'), findsOneWidget);
    });

    testWidgets('closing goes back to Progress when opened directly', (
      tester,
    ) async {
      await pumpAt(tester, '/log-measurement/elbow');
      expect(find.text('Log Waist Measurement'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Progress screen'), findsOneWidget);
    });
  });
}
