import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/progress/view/progress_metric_pages.dart'
    show StepsPage;
import 'package:compound/settings/dev/dev_settings_page.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/today/today.dart';
import 'package:compound/today/view/day_checklist_card.dart';
import 'package:compound/today/view/streak_card.dart';
import 'package:compound/training_library/view/workout_template_detail_page.dart';
import 'package:compound/weekly_review/weekly_review.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_maths/compound_maths.dart' show checkInWeekStart;
import 'package:compound_models/compound_models.dart' show WorkoutTemplateModel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';
import '../../programs/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

class _MockCircleBloc extends MockBloc<CircleEvent, CircleState>
    implements CircleBloc;

/// The Today list, under the large title's scroll view.
final Finder _list = find.byType(Scrollable).last;

void main() {
  const uid = 'mock_user_123';
  // Thursday 15 October 2026, 7pm: after the sample weigh-in and in time
  // for the evening protein reminder.
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
    when(
      () => router.goNamed(any(), pathParameters: any(named: 'pathParameters')),
    ).thenReturn(null);
    when(() => router.go(any())).thenReturn(null);
    when(() => router.pushNamed<Object?>(any())).thenAnswer((_) async => null);
    when(
      () => router.pushNamed<Object?>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => null);
  });

  Future<void> pumpView(
    WidgetTester tester, {
    List<WorkoutSessionModel>? sessions,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    WorkoutSessionRepository? workoutSessionRepository,
    int firstWeekday = DateTime.monday,
    // This week's check-in done, unless a test wants the card.
    bool checkInDue = false,
    ProgramsCubit? programsCubit,
    CircleBloc? circleBloc,
    AnalyticsRepository analytics = const AnalyticsRepository(),
    BodyRepository? bodyRepository,
    Size size = phoneSize,
  }) async {
    tester.useSize(size);
    final workouts =
        workoutSessionRepository ??
        InMemoryWorkoutSessionRepository(
          sessions: sessions ?? sampleWorkoutSessions(uid: uid, now: now),
        );
    final nutrition = InMemoryNutritionRepository(
      meals: meals ?? const [],
      dietPlan: sampleDietPlan(uid: uid, now: now),
    );
    final body =
        bodyRepository ??
        InMemoryBodyRepository(
          measurements:
              measurements ?? sampleBodyMeasurements(uid: uid, now: now),
          steps: sampleSteps(uid: uid, now: now),
          goals: [sampleWeightGoal(uid: uid, now: now)],
        );
    final checkIns = InMemoryCheckInRepository(
      records: [
        if (!checkInDue)
          CheckInRecord(
            authorId: uid,
            lastCompletedWeekStart: localMidnight(
              checkInWeekStart(localDayKey(now)),
            ),
          ),
      ],
    );
    final users = InMemoryUserRepository(users: {uid: sampleUser(now: now)});
    await tester.pumpApp(
      InheritedGoRouter(
        goRouter: router,
        child: BlocProvider(
          create: (_) => TodayBloc(
            workoutSessionRepository: workouts,
            nutritionRepository: nutrition,
            bodyRepository: body,
            userRepository: users,
            analyticsRepository: analytics,
            checkInRepository: checkIns,
            uid: uid,
            firstWeekday: firstWeekday,
            now: () => now,
          )..add(const TodaySubscriptionRequested()),
          child: const TodayView(),
        ),
      ),
      appBloc: appBloc,
      programsCubit: programsCubit,
      circleBloc: circleBloc,
      workoutSessionRepository: workouts,
      userRepository: users,
    );
    await tester.pump();
  }

  group(TodayView, () {
    Future<ProgramsCubit> programs(
      WidgetTester tester,
      List<WorkoutTemplateModel> days, {
      List<WorkoutSessionModel> history = const [],
    }) async {
      final mesocycle = fixtureMesocycle('m1', days);
      final world = ProgramWorld.seeded(
        mesocycles: [if (days.isNotEmpty) mesocycle],
        active: days.isEmpty ? null : 'm1',
        history: history,
      );
      final cubit = world.cubit()..userChanged(programUid);
      await tester.runAsync(
        () => cubit.stream.firstWhere(
          (state) => state.status == ProgramsStatus.loaded,
        ),
      );
      return cubit;
    }

    final push = fixtureTemplate(
      'push',
      name: 'Push Day',
      exercises: [fixtureSlot(fixtureLibraryExercise('bench'))],
    );

    // Swift `testTrainingStates` and `testTrainingItemRoutes`, through the
    // screen.
    testWidgets("plans today's workout and opens it", (tester) async {
      when(
        () => router.pushNamed<Object?>(
          any(),
          pathParameters: any(named: 'pathParameters'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => null);
      final analytics = AnalyticsRecorder();
      await pumpView(
        tester,
        sessions: const [],
        programsCubit: await programs(tester, [push]),
        analytics: analytics,
      );
      await tester.pump();
      expect(find.text('Train'), findsOneWidget);
      expect(find.text('Push Day'), findsWidgets);
      expect(find.text('1 of 4 done'), findsOneWidget);
      await tester.tap(find.text('Train'));
      verify(
        () => router.pushNamed<Object?>(
          WorkoutTemplateDetailPage.name,
          pathParameters: {WorkoutTemplateDetailPage.idParameter: 'push'},
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
      await tester.pump();
      expect(analytics.parameters('TodayView_ChecklistItem_Press'), {
        'item': 'training',
      });
    });

    testWidgets('a planned rest day counts as done', (tester) async {
      await pumpView(
        tester,
        sessions: const [],
        programsCubit: await programs(
          tester,
          [fixtureTemplate('rest'), push],
          history: [programSession('rest', now, rest: true)],
        ),
      );
      await tester.pump();
      expect(find.text('Rest day'), findsOneWidget);
      expect(find.text('2 of 4 done'), findsOneWidget);
    });

    testWidgets('marks a complete day once, with a haptic', (tester) async {
      final analytics = AnalyticsRecorder();
      final body = InMemoryBodyRepository(
        measurements: sampleBodyMeasurements(uid: uid, now: now),
      );
      final dayPlan = sampleDietPlan(uid: uid, now: now);
      final target = dayPlan.days.first;
      await pumpView(
        tester,
        sessions: const [],
        meals: [
          MealLogModel(
            mealId: 'm',
            authorId: uid,
            dayKey: localDayKey(now),
            date: DateTime(now.year, now.month, now.day, 12),
            items: [
              MealItemModel(
                itemId: 'i',
                sourceType: MealItemSourceType.ingredient,
                sourceId: 'food',
                displayName: 'Food',
                amount: 100,
                unit: 'g',
                nutrients: NutrientMap({
                  NutrientKey.calories: target.calories,
                  NutrientKey.protein: target.proteinGrams,
                }),
              ),
            ],
          ),
        ],
        bodyRepository: body,
        analytics: analytics,
        programsCubit: await programs(tester, const []),
      );
      await tester.pump();
      expect(find.text('Day Complete'), findsOneWidget);
      expect(analytics.names.where((n) => n == 'TodayView_DayComplete'), [
        'TodayView_DayComplete',
      ]);
    });

    // Swift `testSocialPulseTracked`.
    testWidgets('says who trained today and opens Social', (tester) async {
      final circle = _MockCircleBloc();
      final ended = DateTime(now.year, now.month, now.day, 10);
      when(() => circle.state).thenReturn(
        CircleState(
          followingUsers: const [
            UserModel(userId: 'sam', submittedFirstName: 'Sam'),
          ],
          followingSessions: [
            WorkoutSessionModel(
              id: 'f',
              authorId: 'sam',
              name: 'Legs',
              dateCreated: ended,
              dateModified: ended,
              endedAt: ended,
              exercises: const [],
            ),
          ],
        ),
      );
      final analytics = AnalyticsRecorder();
      await pumpView(tester, circleBloc: circle, analytics: analytics);
      await tester.scrollUntilVisible(
        find.text('Sam trained today'),
        200,
        scrollable: _list,
      );
      await tester.tap(find.text('Sam trained today'));
      verify(() => router.go(AppTab.social.path)).called(1);
      await tester.pump();
      expect(analytics.names, contains('TodayView_SocialPulse_Press'));
    });

    testWidgets('has no social row when nobody trained', (tester) async {
      await pumpView(tester);
      expect(find.textContaining('trained today'), findsNothing);
    });

    // Swift `testStepGoal`.
    testWidgets('the Steps item, held, chooses the step goal', (tester) async {
      await pumpView(tester);
      await tester.longPress(find.text('Steps'));
      await tester.pumpAndSettle();
      expect(find.text('Step Goal'), findsOneWidget);
      expect(find.text('15,000 steps'), findsOneWidget);
      await tester.tap(find.text('10,000 steps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step goal: 10,000 a day.'), findsOneWidget);

      // Closing the choice changes nothing.
      await tester.longPress(find.text('Steps'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step goal: 10,000 a day.'), findsOneWidget);
    });

    testWidgets('says when the step goal could not be saved', (tester) async {
      final body = _FailingBody(
        measurements: sampleBodyMeasurements(uid: uid, now: now),
        steps: sampleSteps(uid: uid, now: now),
      );
      await pumpView(tester, bodyRepository: body);
      await tester.longPress(find.text('Steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12,000 steps'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Save Step Goal'), findsOneWidget);
      expect(find.textContaining('Step goal: 8,000 a day.'), findsOneWidget);
    });

    testWidgets('shows the checklist, protein reminder and streak', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Your Day'), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
      expect(find.text('Eat to Target'), findsOneWidget);
      expect(find.text('Weigh In'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Train'), findsNothing);
      expect(find.textContaining('Step goal: 8,000 a day.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('protein to go today'),
        200,
        scrollable: _list,
      );
      expect(find.textContaining('protein to go today'), findsOneWidget);
      // Swift's CoachTests: Today asks about today, and the gap about
      // today's food.
      final contexts = [
        for (final button in tester.widgetList<AskCoachButton>(
          find.byType(AskCoachButton),
        ))
          button.coachContext,
      ];
      expect(
        contexts.map((context) => context.kind),
        unorderedEquals([
          CoachContextKind.today,
          CoachContextKind.nutritionDay,
        ]),
      );
      final food = contexts.firstWhere(
        (context) => context.kind == CoachContextKind.nutritionDay,
      );
      expect(food.date, localDayKey(DateTime.now()));
      expect(food.title, "Today's Food");
      await tester.scrollUntilVisible(
        find.text('Get Started · 3 of 4'),
        -200,
        scrollable: _list,
      );
      // No meals logged: the starter card offers the first meal.
      expect(find.text('Get Started · 3 of 4'), findsOneWidget);
      expect(find.text('Log your first meal'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Total workouts'),
        200,
        scrollable: _list,
      );
      expect(find.text('Weekly Streak'), findsOneWidget);
      expect(find.text('3 of 3 this week'), findsOneWidget);
      expect(find.text('Goal Met'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday'), findsOneWidget);
    });

    testWidgets('opens the screens behind the items', (tester) async {
      final sessions = [
        fixtureSession('today', author: uid).copyWithDates(now),
      ];
      await pumpView(tester, sessions: sessions);

      await tester.tap(find.text('Train'));
      verify(
        () => router.goNamed(
          WorkoutSessionDetailPage.name,
          pathParameters: {
            WorkoutSessionDetailPage.sessionIdParameter: 'today',
          },
        ),
      ).called(1);
      await tester.tap(find.text('Weigh In'));
      verify(() => router.goNamed(WeightMetric.scaleWeight.name)).called(1);
      await tester.tap(find.text('Eat to Target'));
      verify(() => router.go(AppTab.nutrition.path)).called(1);
      await tester.tap(find.text('Steps'));
      verify(() => router.goNamed(StepsPage.name)).called(1);
    });

    testWidgets('logs a weigh-in until one is in today', (tester) async {
      await pumpView(tester, measurements: const []);

      await tester.tap(find.text('Weigh In'));
      verify(() => router.pushNamed<Object?>(LogWeightPage.name)).called(1);
      await tester.tap(find.text('Log your weight'));
      verify(() => router.pushNamed<Object?>(LogWeightPage.name)).called(1);
      verifyNever(() => router.goNamed(WeightMetric.scaleWeight.name));
    });

    testWidgets(
      'marks a streak at risk, and no reminder once protein is eaten',
      (tester) async {
        // A streak from last week, nothing this week, Sunday-first: Thursday
        // leaves three days for three sessions.
        final sessions = [
          for (final day in [5, 6, 7])
            fixtureSession(
              's$day',
              author: uid,
            ).copyWithDates(DateTime(2026, 10, day, 9)),
        ];
        await pumpView(
          tester,
          sessions: sessions,
          firstWeekday: DateTime.sunday,
          meals: [_meal(uid, now, calories: 2550, protein: 165)],
        );
        expect(find.textContaining('protein to go'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('At Risk'),
          200,
          scrollable: _list,
        );
        expect(find.text('At Risk'), findsOneWidget);
      },
    );

    testWidgets('lays its sections out in two columns on a tablet', (
      tester,
    ) async {
      await pumpView(tester, size: tabletSize);
      final lefts = {
        for (final type in [DayChecklistCard, TodaysWorkoutCard, StreakCard])
          tester.getTopLeft(find.byType(type)).dx,
      };
      // The sections alternate between the two columns.
      expect(lefts, hasLength(2));
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('offers the weekly check-in while it is due', (tester) async {
      await pumpView(tester, checkInDue: true);
      expect(find.text('Weekly Check-In Ready'), findsOneWidget);
      await tester.ensureVisible(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      verify(
        () => router.pushNamed<Object?>(
          'checkIn',
          queryParameters: {'week': '2026-10-12'},
        ),
      ).called(1);

      await tester.tap(find.text('Skip This Week'));
      await tester.pump();
      expect(find.text('Weekly Check-In Ready'), findsNothing);
    });

    testWidgets('shows a failure when the sessions cannot be read', (
      tester,
    ) async {
      final repository = MockWorkoutSessionRepository();
      when(() => repository.watchSessions(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      await pumpView(tester, workoutSessionRepository: repository);
      expect(find.text("Today couldn't be loaded."), findsOneWidget);
    });

    testWidgets("offers last week's review until it is opened", (tester) async {
      final lastWeek = DateTime(now.year, now.month, now.day - 7, 12);
      await pumpView(
        tester,
        sessions: [
          WorkoutSessionModel(
            id: 'last-week',
            authorId: uid,
            name: 'Push',
            dateCreated: lastWeek,
            dateModified: lastWeek,
            endedAt: lastWeek.add(const Duration(hours: 1)),
            exercises: const [],
          ),
        ],
      );
      final card = find.text('Your weekly review is ready');
      await tester.scrollUntilVisible(card, 200, scrollable: _list);
      await tester.tap(card);
      await tester.pump();
      verify(() => router.goNamed(WeeklyReviewPage.name)).called(1);
      expect(card, findsNothing);
    });

    testWidgets('hides getting started for good', (tester) async {
      await pumpView(tester);
      final header = find.text('Get Started · 3 of 4');
      await tester.scrollUntilVisible(header, -200, scrollable: _list);
      await tester.tap(find.byKey(const Key('Today.hideStarter')));
      await tester.pump();
      expect(header, findsNothing);
      expect(find.text('Log your first meal'), findsNothing);
    });

    testWidgets('offers the quick logs and developer settings', (tester) async {
      await pumpView(tester);
      await tester.tap(find.byTooltip('Developer Settings'));
      await tester.pump();
      verify(() => router.pushNamed<Object?>(DevSettingsPage.name)).called(1);
      await tester.tap(find.byTooltip('Log'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Log Meal'), findsOneWidget);
      expect(
        find.widgetWithText(MenuItemButton, 'Start Empty Workout'),
        findsOneWidget,
      );
      await tester.tap(find.text('Log Weight'));
      await tester.pumpAndSettle();
      verify(() => router.pushNamed<Object?>(LogWeightPage.name)).called(1);
    });

    testWidgets('has no review card when last week was empty', (tester) async {
      await pumpView(tester, sessions: const []);
      expect(find.text('Your weekly review is ready'), findsNothing);
    });

    testWidgets('waits for the data', (tester) async {
      final repository = MockWorkoutSessionRepository();
      when(() => repository.watchSessions(uid))
          .thenAnswer((_) => const Stream.empty());
      await pumpView(tester, workoutSessionRepository: repository);
      expect(find.byType(AppLoadingView), findsOneWidget);
    });
  });

  group(TodayPage, () {
    testWidgets('builds its bloc for the signed-in user', (tester) async {
      await tester.pumpApp(
        const TodayPage(),
        appBloc: appBloc,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        userRepository: InMemoryUserRepository(),
      );
      await tester.pump();
      expect(find.byType(TodayView), findsOneWidget);
      expect(find.text('Get Started · 0 of 4'), findsOneWidget);
    });

    testWidgets('is empty when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const TodayPage(), appBloc: appBloc);
      expect(find.byType(TodayView), findsNothing);
    });
  });
}

MealLogModel _meal(
  String uid,
  DateTime at, {
  required double calories,
  required double protein,
}) => MealLogModel(
  mealId: 'meal',
  authorId: uid,
  dayKey:
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}',
  date: DateTime(at.year, at.month, at.day, 12),
  items: [
    MealItemModel(
      itemId: 'item',
      sourceType: MealItemSourceType.ingredient,
      sourceId: 'food',
      displayName: 'Food',
      amount: 100,
      unit: 'g',
      nutrients: NutrientMap({
        NutrientKey.calories: calories,
        NutrientKey.protein: protein,
      }),
    ),
  ],
);

extension on WorkoutSessionModel {
  /// This session moved to start at [start], finishing an hour later.
  WorkoutSessionModel copyWithDates(DateTime start) => WorkoutSessionModel(
    id: id,
    authorId: authorId,
    name: name,
    dateCreated: start.subtract(const Duration(hours: 1)),
    dateModified: start,
    endedAt: start,
    exercises: exercises,
  );
}

class _FailingBody extends InMemoryBodyRepository {
  new({super.measurements, super.steps});

  @override
  Future<void> saveStepGoal(String uid, int goal) =>
      Future.error(Exception('denied'));
}
