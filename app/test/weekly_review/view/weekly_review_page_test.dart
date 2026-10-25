import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/weekly_review/weekly_review.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'me';
  // A system exercise: it trains the chest, triceps and front delts.
  const bench = 'system-barbell-bench-press';
  late AppBloc appBloc;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
  });

  BodyMeasurementEntry weighIn(double kg, int day) => BodyMeasurementEntry(
    id: 'w$day',
    authorId: uid,
    weightKg: kg,
    date: DateTime(2026, 3, day, 7),
    source: WeightSource.manual,
    dateCreated: DateTime(2026, 3, day, 7),
  );

  MealLogModel meal(int day) => MealLogModel(
    mealId: 'm$day',
    authorId: uid,
    dayKey: '2026-03-${day.toString().padLeft(2, '0')}',
    date: DateTime(2026, 3, day, 12),
    items: [
      MealItemModel(
        itemId: 'i$day',
        sourceType: MealItemSourceType.ingredient,
        sourceId: 'x',
        displayName: 'Food',
        amount: 1,
        unit: 'serving',
        nutrients: const NutrientMap({NutrientKey.calories: 2000}),
      ),
    ],
  );

  Future<WeeklyReviewBloc> pumpView(
    WidgetTester tester, {
    List<WorkoutSessionModel>? sessions,
    bool withPlan = true,
    ShareRecorder? shares,
    AnalyticsRepository analytics = const AnalyticsRepository(),
  }) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = WeeklyReviewBloc(
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions:
            sessions ??
            [
              fixtureSession(
                'old',
                day: 3,
                author: uid,
                exercises: [
                  fixtureExercise(bench, sets: [fixtureSet(weightKg: 90)]),
                ],
              ),
              fixtureSession(
                'this',
                day: 10,
                author: uid,
                exercises: [
                  fixtureExercise(bench, sets: [fixtureSet(rpe: 8)]),
                ],
              ),
            ],
      ),
      nutritionRepository: InMemoryNutritionRepository(
        meals: [meal(10)],
        dietPlan: withPlan
            ? sampleDietPlan(uid: uid, now: DateTime(2026))
            : null,
      ),
      bodyRepository: InMemoryBodyRepository(
        measurements: [weighIn(80, 5), weighIn(79.5, 11)],
      ),
      trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
      userRepository: InMemoryUserRepository(
        users: {uid: const UserModel(userId: uid)},
      ),
      analyticsRepository: analytics,
      uid: uid,
      firstDayOfWeek: 1,
      now: () => DateTime(2026, 3, 12, 9),
    )..add(const WeeklyReviewSubscriptionRequested());
    await tester.pumpApp(
      // The provider closes the bloc with the tree.
      BlocProvider(create: (_) => bloc, child: const WeeklyReviewView()),
      appBloc: appBloc,
      shareSheet: shares ?? ShareRecorder(),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  group(WeeklyReviewView, () {
    // WeeklyReviewPresenter.onSharePressed
    testWidgets('shares the week as a Stories image', (tester) async {
      final shares = ShareRecorder();
      final analytics = AnalyticsRecorder();
      await pumpView(tester, shares: shares, analytics: analytics);

      await tester.tap(find.byTooltip('Share'));
      for (var i = 0; i < 5 && shares.images.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        // Elapses the capture's zero-length delay.
        await tester.pump(Duration.zero);
      }
      expect(shares.images.single.$1, 'compound-week.png');
      expect(shares.images.single.$2, isNotEmpty);
      expect(analytics.names, contains('WeeklyReviewView_Share_Pressed'));
    });

    testWidgets('shows the week', (tester) async {
      await pumpView(tester);

      expect(find.text('Weekly Review'), findsOneWidget);
      expect(find.text('Mar 9 – Mar 15'), findsOneWidget);
      // The hero: the sessions against the goal, missed, so no badge.
      expect(
        find.bySemanticsLabel('1/3, Sessions, Volume up 11% on last week.'),
        findsOneWidget,
      );
      expect(find.text('SESSIONS'), findsOneWidget);
      expect(find.text('Goal Met'), findsNothing);
      expect(find.text('+11%'), findsOneWidget);
      expect(find.text('VS LAST WEEK'), findsOneWidget);
      expect(find.text('500\u00a0kg'), findsOneWidget);
      expect(find.text('AVERAGE RPE'), findsOneWidget);
      for (final text in [
        'Sets per Muscle',
        'Chest',
        bench,
        'Personal Records',
        '100\u00a0kg × 5',
        'Body & Nutrition',
      ]) {
        await tester.scrollUntilVisible(find.text(text), 100);
        expect(find.text(text), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.textContaining('logged days on target'),
        100,
      );
      expect(find.textContaining('kg (−'), findsOneWidget);
    });

    testWidgets('celebrates a week that met its goal', (tester) async {
      final haptics = <AppHaptic>[];
      AppHaptics.debugPlay = haptics.add;
      addTearDown(() => AppHaptics.debugPlay = null);
      await pumpView(
        tester,
        sessions: [
          for (final day in [9, 10, 11])
            fixtureSession(
              's$day',
              day: day,
              author: uid,
              exercises: [
                fixtureExercise(bench, sets: [fixtureSet()]),
              ],
            ),
        ],
      );

      expect(find.text('Goal Met'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(haptics, [AppHaptic.success]);
    });

    testWidgets('moves between weeks', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      expect(find.text('Mar 2 – Mar 8'), findsOneWidget);
      expect(find.text('No sessions logged this week.'), findsNothing);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(find.text('Mar 9 – Mar 15'), findsOneWidget);
    });

    testWidgets('an empty week says so, without a plan or records', (
      tester,
    ) async {
      await pumpView(tester, sessions: const [], withPlan: false);

      expect(find.text('No sessions logged this week.'), findsOneWidget);
      expect(find.text('Personal Records'), findsNothing);
      await tester.scrollUntilVisible(find.text('Body & Nutrition'), 100);
      expect(find.text('Body & Nutrition'), findsOneWidget);
      expect(find.text('Calories'), findsNothing);
    });

    test('names every takeaway', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        WeeklyReviewView.takeawayText(
          l10n,
          const GoalAndRecordsTakeaway(2),
          'en',
        ),
        'Goal hit and 2 PRs set. Great week.',
      );
      expect(
        WeeklyReviewView.takeawayText(l10n, const GoalHitTakeaway(3, 3), 'en'),
        'Goal hit: 3 of 3 sessions.',
      );
      expect(
        WeeklyReviewView.takeawayText(l10n, const VolumeUpTakeaway(0.2), 'en'),
        'Volume up 20% on last week.',
      );
    });
  });

  group(WeeklyReviewPage, () {
    testWidgets('builds its bloc from the repositories', (tester) async {
      await tester.pumpApp(
        const WeeklyReviewPage(),
        appBloc: appBloc,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        userRepository: InMemoryUserRepository(),
      );
      await tester.pumpAndSettle();
      expect(find.text('No sessions logged this week.'), findsOneWidget);
    });

    testWidgets('shows nothing while signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const WeeklyReviewPage(), appBloc: appBloc);
      expect(find.byType(WeeklyReviewView), findsNothing);
    });
  });
}
