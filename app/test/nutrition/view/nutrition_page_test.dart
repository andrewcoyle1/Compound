import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/view/widgets/calendar_strip.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/nutrition/view/widgets/meal_timeline.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'uid';
  // Monday 21 September 2026, after lunch.
  final now = DateTime(2026, 9, 21, 13, 45);
  final monday = DateTime(2026, 9, 21);
  final sampleMeals = sampleMealLogs(uid: uid, now: now);
  final samplePlan = sampleDietPlan(uid: uid, now: now);

  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
  });

  /// The view over a real bloc on [repository], opened at [now].
  Future<void> pumpView(
    WidgetTester tester, {
    List<MealLogModel>? meals,
    DietPlan? plan,
    FoodLogSettings? settings,
    NutritionRepository? repository,
  }) async {
    final nutritionRepository =
        repository ??
        InMemoryNutritionRepository(
          meals: meals ?? sampleMeals,
          dietPlan: plan ?? samplePlan,
          foodLogSettings: settings,
        );
    await tester.pumpApp(
      BlocProvider(
        create: (_) => NutritionDayBloc(
          nutritionRepository: nutritionRepository,
          uid: uid,
          now: () => now,
        )..add(const NutritionDaySubscriptionRequested()),
        child: const NutritionView(),
      ),
      appBloc: appBloc,
    );
    await tester.pump();
  }

  MealLogModel meal(String id, DateTime day, double calories) => MealLogModel(
    mealId: id,
    authorId: uid,
    dayKey:
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}',
    date: DateTime(day.year, day.month, day.day, 9),
    items: [
      MealItemModel(
        itemId: '$id-item',
        sourceType: MealItemSourceType.quickAdd,
        sourceId: 'quick_add',
        displayName: 'Food $id',
        amount: 1.5,
        unit: 'serving',
        nutrients: NutrientMap({NutrientKey.calories: calories}),
      ),
    ],
  );

  DietPlan flatPlan(double calories) => DietPlan(
    planId: uid,
    createdAt: monday,
    tdeeEstimate: 2500,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'strength',
    calorieDistribution: 'even',
    proteinIntake: 'high',
    days: List.filled(
      7,
      DailyMacroTarget(
        calories: calories,
        proteinGrams: 150,
        carbGrams: 200,
        fatGrams: 60,
      ),
    ),
  );

  /// The calendar cell values a screen reader hears.
  Iterable<String> cellValues(WidgetTester tester) => tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byType(CalendarStrip),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
        ),
      )
      .map((semantics) => semantics.properties.value ?? '');

  group(NutritionPage, () {
    testWidgets("reads the signed-in user's meals", (tester) async {
      await tester.pumpApp(
        const NutritionPage(),
        appBloc: appBloc,
        nutritionRepository: InMemoryNutritionRepository(),
      );
      await tester.pump();

      expect(find.byType(NutritionView), findsOneWidget);
      expect(find.byType(CalendarStrip), findsOneWidget);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const NutritionPage(), appBloc: appBloc);

      expect(find.byType(NutritionView), findsNothing);
    });
  });

  group(NutritionView, () {
    testWidgets('shows progress until the meals arrive', (tester) async {
      final repository = MockNutritionRepository();
      when(() => repository.watchMeals(uid))
          .thenAnswer((_) => const Stream.empty());
      when(() => repository.watchDietPlan(uid))
          .thenAnswer((_) => const Stream.empty());
      when(() => repository.watchFoodLogSettings(uid))
          .thenAnswer((_) => const Stream.empty());
      await pumpView(tester, repository: repository);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says when the meals cannot be loaded', (tester) async {
      final repository = MockNutritionRepository();
      when(() => repository.watchMeals(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      when(() => repository.watchDietPlan(uid))
          .thenAnswer((_) => const Stream.empty());
      when(() => repository.watchFoodLogSettings(uid))
          .thenAnswer((_) => const Stream.empty());
      await pumpView(tester, repository: repository);

      expect(find.text("Your meals couldn't be loaded."), findsOneWidget);
    });

    testWidgets('shows the day: date, strip, macros and the timeline', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Sep 21, 2026'), findsOneWidget);
      expect(find.byType(CalendarStrip), findsOneWidget);
      expect(find.byType(MacroHeader), findsOneWidget);
      // Monday is a training day: 2,550 kcal.
      expect(find.textContaining(' / 2,550'), findsOneWidget);
      expect(find.text('7:00 AM'), findsOneWidget);
      // Breakfast, with its time beside its first food only.
      expect(find.text('Rolled Oats'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('7:30 AM'), findsOneWidget);
      expect(find.textContaining('kcal · '), findsWidgets);
      expect(find.textContaining('85 g'), findsOneWidget);
      // On today, there is no way back to it.
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('turns the macro header to what is left, and back', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byType(MacroHeader));
      await tester.pump();
      expect(find.textContaining(' left'), findsNWidgets(4));

      await tester.fling(find.byType(MacroHeader), const Offset(-200, 0), 800);
      await tester.pump();
      expect(find.textContaining(' left'), findsNothing);
    });

    testWidgets('picks another day, and returns to today', (tester) async {
      await pumpView(tester);

      await tester.tap(find.bySemanticsLabel('Sunday, September 20'));
      await tester.pump();
      expect(find.text('Sep 20, 2026'), findsOneWidget);
      expect(find.text('Whole Egg'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(find.text('Sep 21, 2026'), findsOneWidget);
    });

    testWidgets('swipes between weeks', (tester) async {
      await pumpView(tester);
      expect(find.bySemanticsLabel('Saturday, September 19'), findsNothing);

      await tester.fling(find.byType(CalendarStrip), const Offset(300, 0), 800);
      await tester.pump();
      expect(find.bySemanticsLabel('Saturday, September 19'), findsOneWidget);

      await tester.fling(
        find.byType(CalendarStrip),
        const Offset(-300, 0),
        800,
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Monday, September 21'), findsOneWidget);
    });

    testWidgets('marks days by their progress toward the goal', (tester) async {
      await pumpView(
        tester,
        meals: [
          meal('half', DateTime(2026, 9, 20), 1000),
          meal('met', monday, 2060),
          meal('over', DateTime(2026, 9, 22), 2500),
        ],
        plan: flatPlan(2000),
      );

      final values = cellValues(tester).toList();
      expect(values, contains('50% of goal'));
      expect(values, contains('Today, 103% of goal, Goal met'));
      expect(values, contains('125% of goal, Over goal'));
    });

    testWidgets('marks days as logged without a plan, with no header', (
      tester,
    ) async {
      await pumpView(
        tester,
        meals: [meal('m', monday, 500)],
        plan: flatPlan(0),
      );

      expect(cellValues(tester), contains('Today, Logged'));
      // A target of zero calories is still a target for the header.
      expect(find.byType(MacroHeader), findsOneWidget);
    });

    testWidgets('hides the header without a plan', (tester) async {
      await pumpView(
        tester,
        repository: InMemoryNutritionRepository(meals: sampleMeals),
      );

      expect(find.byType(MacroHeader), findsNothing);
      expect(find.text('Rolled Oats'), findsOneWidget);
    });

    testWidgets('says when nothing is logged and empty hours are hidden', (
      tester,
    ) async {
      await pumpView(
        tester,
        meals: const [],
        settings: const FoodLogSettings(authorId: uid, hideEmptyHours: true),
      );

      expect(find.text('Nothing Logged'), findsOneWidget);
      expect(
        find.text('Meals you log for this day appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('follows the display settings', (tester) async {
      await pumpView(
        tester,
        meals: [meal('m', monday, 500)],
        settings: const FoodLogSettings(
          authorId: uid,
          hideEmptyHours: true,
          showCalendarWeekBanner: false,
          hideFoodDetails: true,
          showHourlyMacroTotals: false,
          timestampSide: TimestampSide.right,
          showCaloriesRing: false,
          showProteinRing: false,
          showFatRing: false,
          showCarbsRing: false,
        ),
      );

      expect(find.byType(CalendarStrip), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(AppStat), findsNothing);
      // Only the amount is left of the details.
      expect(find.text('1.5 serving'), findsOneWidget);
      expect(find.byIcon(AppSymbols.meal), findsNothing);
      // The time sits after the food.
      final time = tester.getCenter(find.text('9:00 AM').last);
      final food = tester.getCenter(find.text('Food m'));
      expect(time.dx, greaterThan(food.dx));
    });

    testWidgets("totals each hour's meals", (tester) async {
      await pumpView(
        tester,
        meals: [meal('a', monday, 300.6), meal('b', monday, 199.9)],
        settings: const FoodLogSettings(authorId: uid, hideEmptyHours: true),
      );

      expect(find.byType(MealHourHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MealHourHeader),
          matching: find.text('500'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('counts past zero when overages are shown', (tester) async {
      await pumpView(
        tester,
        meals: [meal('m', monday, 2700)],
        plan: flatPlan(2000),
        settings: const FoodLogSettings(authorId: uid, showOverages: true),
      );

      await tester.tap(find.byType(MacroHeader));
      await tester.pump();
      expect(find.text('-700 left'), findsOneWidget);
    });
  });

  group('MacroStyle', () {
    test("uses the app's macro colours", () {
      const colors = AppColors.light;
      expect(Macro.calories.colour(colors), colors.calories);
      expect(Macro.protein.colour(colors), colors.protein);
      expect(Macro.carbs.colour(colors), colors.carbs);
      expect(Macro.fat.colour(colors), colors.fat);
    });
  });
}
