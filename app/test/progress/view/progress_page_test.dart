import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/progress/view/progress_carousel.dart';
import 'package:compound/progress/view/progress_metric_pages.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound_charts/compound_charts.dart';
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

class _MockProgramsCubit extends MockCubit<ProgramsState>
    implements ProgramsCubit;

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
    ProgramsCubit? programsCubit,
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
            checkInRepository: InMemoryCheckInRepository(),
            uid: uid,
            firstWeekday: DateTime.monday,
            now: () => now,
          )..add(const ProgressSubscriptionRequested()),
          child: const ProgressView(),
        ),
      ),
      appBloc: appBloc,
      textScale: textScale,
      programsCubit: programsCubit,
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
      // Each card's title is an overline; Weight Trend is the hero's.
      for (final title in [
        'Weight Trend',
        'Goal Progress',
        'Expenditure',
        'Energy Balance',
        'Weigh In',
        'Macros',
        'Protein',
        'Scale Weight',
        'Visual Body Fat',
        'Steps',
      ]) {
        expect(find.text(title.toUpperCase()), findsOneWidget);
      }
      // One in Insights, one in Habits.
      expect(find.text('WORKOUTS'), findsNWidgets(2));
      // The workouts card and two exercise cards.
      expect(find.text('Last 7 Workouts'), findsNWidgets(3));
      expect(find.text('Last 30 Days'), findsNWidgets(2));
      expect(find.text('Toward Target'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(MuscleSetsCard), findsNWidgets(2));
      expect(find.byType(ExerciseOneRepMaxCard), findsNWidgets(2));
      expect(find.byType(ProgressCard), findsNWidgets(15));
      expect(find.byType(Sparkline), findsNWidgets(7));
      expect(find.byType(HabitGridChart), findsNWidgets(2));
      expect(find.byType(StackedBars), findsNWidgets(5));
      // Goal Progress and Protein.
      expect(
        find.descendant(
          of: find.byType(ProgressCard),
          matching: find.byType(BulletBar),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('leads with the trend weight, its change and the goal', (
      tester,
    ) async {
      await pumpView(tester);

      final hero = find.ancestor(
        of: find.text('WEIGHT TREND'),
        matching: find.byType(AppSummaryCard),
      );
      expect(
        find.descendant(of: hero, matching: find.textContaining(' in 7 days')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.textContaining('of the way to your goal'),
        ),
        findsOneWidget,
      );
      // The goal's bar is the accent: the user's own progress.
      expect(
        find.descendant(of: hero, matching: find.byType(BulletBar)),
        findsOneWidget,
      );
      // Energy Balance's number stands alone, deficit or surplus its unit.
      expect(find.textContaining(RegExp('KCAL (DEFICIT|SURPLUS)')), findsOne);
    });

    testWidgets('an empty tab reads as absent, not zero', (tester) async {
      await pumpView(tester, empty: true);

      expect(find.text('No Workouts'), findsOneWidget);
      expect(find.text('No Entries'), findsNWidgets(2));
      expect(find.text('Log a weigh-in to see your trend.'), findsOneWidget);
      expect(find.text('No Goal Set'), findsOneWidget);
      expect(find.text('No Data'), findsNWidgets(3));
      // Workouts, the trend hero, goal, energy balance, macros, protein,
      // weight, body fat, steps and the two exercises; the muscles show 0
      // sets.
      // Expenditure still has the profile's formula.
      expect(find.textContaining(AppFormat.placeholder), findsNWidgets(11));
    });

    testWidgets('leaves out hidden sections', (tester) async {
      await pumpView(tester, hidden: ['habits', 'body_metrics']);

      // Only in the More list, which keeps a hidden section reachable.
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Body Metrics'), findsOneWidget);
      expect(find.text('Weigh In'), findsNothing);
      expect(find.text('Insights & Analytics'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      await tester.ensureVisible(find.text('Habits'));
      await tester.tap(find.text('Habits'));
      verify(() => router.goNamed(HabitsPage.name)).called(1);
    });

    testWidgets('opens the weight screens', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('WEIGHT TREND'));
      verify(() => router.goNamed(WeightMetric.weightTrend.name)).called(1);
      await tester.tap(find.text('SCALE WEIGHT'));
      verify(() => router.goNamed(WeightMetric.scaleWeight.name)).called(1);
      await tester.ensureVisible(find.text('STEPS'));
      await tester.tap(find.text('STEPS'));
      verify(() => router.goNamed(StepsPage.name)).called(1);
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
      expect(seeAll, findsNWidgets(6));
      await tester.ensureVisible(seeAll.at(4));
      await tester.tap(seeAll.at(4));
      verify(() => router.goNamed(MuscleGroupsPage.name)).called(1);
      await tester.ensureVisible(seeAll.last);
      await tester.tap(seeAll.last);
      verify(() => router.goNamed(ExerciseAnalyticsPage.name)).called(1);
    });

    testWidgets('summarises its charts for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpView(tester);

      // Each card reads its chart's summary after its figure: the workouts
      // card and two muscles.
      Finder heard(String text) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.value?.contains(text) ?? false),
      );
      expect(heard('Working sets'), findsNWidgets(3));
      expect(heard('Macros, last 7 days'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('adds columns with width', (tester) async {
      await pumpView(tester, width: 1000);

      final workouts = tester.getTopLeft(find.text('WORKOUTS').first);
      final balance = tester.getTopLeft(find.text('ENERGY BALANCE'));
      // Four across: Energy Balance sits beside Workouts.
      expect(balance.dy, workouts.dy);
      expect(balance.dx, greaterThan(workouts.dx));
      // The hero beside the carousel.
      expect(
        tester.getTopLeft(find.byType(AppCarousel)).dx,
        greaterThan(tester.getTopRight(find.text('WEIGHT TREND')).dx),
      );
    });

    testWidgets('goes to one column at large text sizes', (tester) async {
      await pumpView(tester, textScale: 2);

      final workouts = tester.getTopLeft(find.text('Last 7 Workouts').first);
      // Expenditure's footer.
      final expenditure = tester.getTopLeft(find.text('Last 7 Days').first);
      expect(expenditure.dx, workouts.dx);
      expect(expenditure.dy, greaterThan(workouts.dy));
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

  group('carousel', () {
    Future<void> nextPage(WidgetTester tester) async {
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('the week against its targets selects a day', (tester) async {
      await pumpView(tester);
      expect(find.text('THIS WEEK AGAINST YOUR TARGETS'), findsOneWidget);
      // Opens on today; the week's label shows only with no day picked.
      expect(find.text('Week'), findsNothing);
      final bloc = tester
          .element(find.byType(ProgressView))
          .read<ProgressBloc>();
      final today = bloc.state.targetDay!;
      await tester.tap(find.bySemanticsLabel(RegExp('^Thursday, Calories')));
      await tester.pump();
      expect(bloc.state.targetDay, isNull);
      expect(find.text('Week'), findsOneWidget);
      expect(today, 3);
    });

    testWidgets('the key sits straight under the weekdays', (tester) async {
      await pumpView(tester);
      final chart = find.byType(NutritionTargetChart);
      final key = find.descendant(
        of: chart,
        matching: find.textContaining('Bar shows what you ate'),
      );
      final weekday = find.descendant(of: chart, matching: find.text('W'));
      expect(
        tester.getTopLeft(key).dy - tester.getBottomLeft(weekday).dy,
        lessThanOrEqualTo(AppSpacing.m),
      );
    });

    testWidgets("at 200% text the week puts each row's figures above "
        'full-width cells, with nothing clipped', (tester) async {
      await pumpView(tester, textScale: 2);
      final chart = find.byType(NutritionTargetChart);
      Finder inChart(Finder finder) =>
          find.descendant(of: chart, matching: finder);
      final bars = inChart(find.byType(BulletBar));
      final calories = inChart(find.byIcon(AppSymbols.calories));
      expect(
        tester.getBottomLeft(calories).dy,
        lessThanOrEqualTo(tester.getTopLeft(bars.first).dy),
      );
      expect(
        tester.getTopRight(bars.at(6)).dx,
        greaterThan(tester.getTopRight(chart).dx - AppSpacing.xl),
      );
      final key = inChart(find.textContaining('Bar shows what you ate'));
      // Taller than the page only in the test font; the page then scrolls
      // to it rather than cutting it off.
      await tester.ensureVisible(key);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(key).dy,
        lessThanOrEqualTo(tester.getBottomLeft(find.byType(PageView)).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a plan says so, and offers to create one', (
      tester,
    ) async {
      when(() => router.pushNamed<void>(any())).thenAnswer((_) async {});
      await pumpView(tester, empty: true);
      expect(find.text('No Diet Plan'), findsOneWidget);
      await tester.tap(find.text('Create Diet Plan'));
      await tester.pump();
      verify(() => router.pushNamed<void>('dietPlan')).called(1);
    });

    testWidgets('pages through nutrition, energy, training and records', (
      tester,
    ) async {
      await pumpView(tester);

      await nextPage(tester);
      expect(find.text('DAILY NUTRITION'), findsOneWidget);
      expect(find.text('Consumed'), findsWidgets);
      await tester.tap(find.text('Remaining').last);
      await tester.pumpAndSettle();
      expect(find.text('Target'), findsOneWidget);

      await nextPage(tester);
      expect(find.text('Last 30 Days'), findsWidgets);
      expect(find.text('Difference'), findsOneWidget);
      await tester.tap(find.text('Targets'));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsWidgets);

      await nextPage(tester);
      expect(find.text('WEEKLY WORKOUTS'), findsOneWidget);
      expect(find.text('Muscles'), findsOneWidget);

      await nextPage(tester);
      expect(find.text('RECENT RECORDS'), findsOneWidget);
      await tester.tap(find.text('Reps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('reps'), findsWidgets);
      await tester.tap(find.text('1-RM'));
      await tester.pumpAndSettle();
      expect(find.textContaining('\u00a0kg'), findsWidgets);
    });

    // `WeeklyWorkoutsCard` with an active mesocycle: its targets on the
    // rings, and the Active Program / All Workouts toggle.
    testWidgets('weekly workouts aim at the active program, and the toggle '
        'counts its sessions or all of them', (tester) async {
      final mesocycle = fixtureMesocycle('block', [
        fixtureTemplate(
          'full body',
          exercises: [
            fixtureSlot(fixtureLibraryExercise('bench')),
            fixtureSlot(
              fixtureLibraryExercise(
                'row',
                muscles: const {Muscles.lats: MuscleTargetType.primary},
              ),
              sets: 4,
            ),
          ],
        ),
      ]);
      final programs = _MockProgramsCubit();
      when(() => programs.state).thenReturn(
        ProgramsState(
          status: ProgramsStatus.loaded,
          mesocycles: [mesocycle],
          activeMesocycleId: mesocycle.id,
        ),
      );
      await pumpView(tester, programsCubit: programs);
      for (var page = 0; page < 3; page++) {
        await nextPage(tester);
      }
      final bloc = tester
          .element(find.byType(ProgressView))
          .read<ProgressBloc>();
      String sets() => tester
          .getSemantics(find.bySemanticsLabel('Sets'))
          .getSemanticsData()
          .value;

      expect(find.text('WEEKLY WORKOUTS'), findsOneWidget);
      expect(find.text('7 target'), findsOneWidget);
      expect(find.text('2 target'), findsNWidgets(2));
      // The sample's sessions are not the program's.
      expect(find.text('7 left'), findsOneWidget);
      expect(sets(), '0 of 7');

      await tester.tap(find.text('All Workouts'));
      await tester.pumpAndSettle();
      final all = bloc.state.weekTally().sets;
      expect(all, greaterThan(0));
      expect(sets(), '$all of 7');
      expect(find.text('7 target'), findsOneWidget);
    });

    testWidgets('at 200% text on a phone, the gauge sits above '
        'its figures', (tester) async {
      await pumpView(tester, textScale: 2);
      await nextPage(tester);
      expect(
        tester.getBottomLeft(find.byType(ProgressArc)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Target')).dy),
      );
    });

    testWidgets('at 200% text with room, the rings grow in a row and no '
        'caption breaks a word', (tester) async {
      await pumpView(tester, textScale: 2, width: 800);
      for (var page = 0; page < 3; page++) {
        await nextPage(tester);
      }
      Finder inCarousel(Finder finder) =>
          find.descendant(of: find.byType(ProgressCarousel), matching: finder);
      final line = tester.getSize(inCarousel(find.text('Sets'))).height;
      for (final word in ['Muscles', 'Exercises']) {
        final caption = inCarousel(find.text(word));
        // One word, one line, level with the others.
        expect(tester.getSize(caption).height, line);
      }
      expect(
        tester.getSize(inCarousel(find.byType(ProgressArc)).at(1)).width,
        greaterThan(136),
      );
    });

    testWidgets('weekly workouts without a program have no targets or '
        'toggle', (tester) async {
      await pumpView(tester);
      for (var page = 0; page < 3; page++) {
        await nextPage(tester);
      }
      expect(find.text('Active Program'), findsNothing);
      expect(find.textContaining('target'), findsNothing);
    });

    testWidgets('the week runs a bar up each day to its target, a caret '
        'over any day well past it', (tester) async {
      await pumpView(tester);
      final bars = tester.widgetList<BulletBar>(
        find.descendant(
          of: find.byType(NutritionTargetChart),
          matching: find.byType(BulletBar),
        ),
      );
      // Four rows of seven days.
      expect(bars, hasLength(28));
      for (final bar in bars) {
        expect(bar.direction, Axis.vertical);
        expect(bar.over, showsCaret(bar.value, bar.target!));
      }
    });

    testWidgets("daily nutrition's macro bars show what is left", (
      tester,
    ) async {
      await pumpView(tester);
      await nextPage(tester);
      List<BulletBar> bars() => tester
          .widgetList<BulletBar>(
            find.descendant(
              of: find.byType(ProgressCarousel),
              matching: find.byType(BulletBar),
            ),
          )
          .toList();
      final eaten = [for (final bar in bars()) bar.value];
      expect(eaten, hasLength(3));
      await tester.tap(find.text('Remaining').last);
      await tester.pumpAndSettle();
      for (final (i, bar) in bars().indexed) {
        expect(bar.from, eaten[i]);
        expect(bar.value, 1);
      }
    });

    for (final (scale, beside) in [(1.0, true), (2.0, false)]) {
      testWidgets('records at ${scale * 100}% text put each name '
          '${beside ? 'beside' : 'above'} its bar, and nothing '
          'overflows', (tester) async {
        await pumpView(tester, textScale: scale);
        for (var page = 0; page < 4; page++) {
          await nextPage(tester);
        }
        final name = find.text('Cable Y-Raise');
        final bar = find
            .descendant(
              of: find.byType(ProgressCarousel),
              matching: find.byType(BulletBar),
            )
            .first;
        if (beside) {
          expect(
            tester.getCenter(name).dy,
            closeTo(tester.getCenter(bar).dy, 1),
          );
        } else {
          expect(
            tester.getBottomLeft(name).dy,
            lessThanOrEqualTo(tester.getTopLeft(bar).dy),
          );
        }
        // Whole rows only, the last clear of the toggle: all seven at the
        // default size, the latest that fit at 200%.
        final bars = find.descendant(
          of: find.byType(ProgressCarousel),
          matching: find.byType(BulletBar),
        );
        expect(bars.evaluate().length, beside ? 7 : inExclusiveRange(0, 7));
        expect(
          tester.getBottomLeft(bars.last).dy,
          lessThan(tester.getTopLeft(find.text('Volume')).dy),
        );
        expect(
          tester.getBottomLeft(bars.last).dy,
          lessThanOrEqualTo(
            tester
                .getBottomLeft(
                  find.descendant(
                    of: find.byType(ProgressCarousel),
                    matching: find.byType(SingleChildScrollView),
                  ),
                )
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('records without a workout say so', (tester) async {
      await pumpView(tester, empty: true);
      for (var page = 0; page < 4; page++) {
        await nextPage(tester);
      }
      expect(find.text('No Records Yet'), findsOneWidget);
    });
  });

  group('menus', () {
    testWidgets('More lists Weekly Review and Customize Analytics', (
      tester,
    ) async {
      await pumpView(tester);
      expect(find.text('More'), findsOneWidget);
      await tester.ensureVisible(find.text('Weekly Review'));
      await tester.tap(find.text('Weekly Review'));
      verify(() => router.goNamed('weeklyReview')).called(1);
      expect(find.text('Customize Analytics'), findsOneWidget);
    });

    testWidgets('+ offers Log Weight and every measurement', (tester) async {
      await pumpView(tester);
      await tester.tap(find.byTooltip('Log body metrics'));
      await tester.pumpAndSettle();
      expect(find.text('Log Weight'), findsOneWidget);
      await tester.tap(find.text('Log Measurement'));
      await tester.pumpAndSettle();
      expect(find.text('Upper Body'), findsOneWidget);
      expect(find.text('Right Ankle'), findsOneWidget);
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
