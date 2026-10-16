import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/add_meal/view/food_picker.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../../helpers/helpers.dart';

void main() {
  const uid = 'uid';
  final now = DateTime.now();
  final mealDate = DateTime(now.year, now.month, now.day, 8);

  late AppBloc appBloc;
  late InMemoryNutritionRepository nutrition;
  late InMemoryFoodRepository foods;
  late MealDraftCubit drafts;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    nutrition = InMemoryNutritionRepository(
      meals: sampleMealLogs(uid: uid, now: now),
    );
    foods = InMemoryFoodRepository(
      foods: sampleFoods(uid: uid, now: now),
    );
    drafts = MealDraftCubit();
  });

  /// The logger over a home screen, on [meal].
  Future<void> pumpLogger(WidgetTester tester, {MealLogModel? meal}) async {
    final router = GoRouter(
      initialLocation: '/log',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: [
            GoRoute(
              path: 'log',
              builder: (_, _) => AddMealPage(
                meal: meal ?? newMeal(uid: uid, date: mealDate, mealId: 'MEAL'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpApp(
      const SizedBox.shrink(),
      router: router,
      appBloc: appBloc,
      nutritionRepository: nutrition,
      foodRepository: foods,
      mealDraftCubit: drafts,
    );
    await tester.pumpAndSettle();
  }

  Future<List<MealLogModel>> savedMeals() => nutrition.watchMeals(uid).first;

  group(AddMealPage, () {
    testWidgets('a new meal opens on the picker with recent foods', (
      tester,
    ) async {
      await pumpLogger(tester);
      expect(find.byType(FoodPickerView), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
      expect(find.text('0 on plate'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.byType(FoodRow), findsWidgets);
    });

    testWidgets('closing the picker over an empty plate leaves', (
      tester,
    ) async {
      await pumpLogger(tester);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(drafts.state, isNull);
    });

    testWidgets('search finds the library and Open Food Facts', (tester) async {
      await pumpLogger(tester);
      await tester.enterText(find.byType(TextField), 'bread');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('My Foods'), findsOneWidget);
      expect(find.text('Wholemeal Bread'), findsWidgets);
      expect(find.text('Open Food Facts'), findsOneWidget);
    });

    testWidgets('a food goes on the plate through the amount sheet, then is '
        'logged', (tester) async {
      await pumpLogger(tester);
      await tester.enterText(find.byType(TextField), 'oats');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rolled Oats').first);
      await tester.pumpAndSettle();
      expect(find.byType(FoodAmountSheet), findsOneWidget);
      expect(find.text('Estimated Macros'), findsOneWidget);

      await tester.tap(find.text('Add to Plate'));
      await tester.pumpAndSettle();
      expect(find.text('1 on plate'), findsOneWidget);
      expect(drafts.state?.items, hasLength(1));

      await tester.tap(find.widgetWithText(AppCtaButton, 'Log'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      final saved = (await savedMeals()).singleWhere(
        (meal) => meal.mealId == 'MEAL',
      );
      expect(saved.items.single.sourceId, 'sample-food-rolled-oats');
      expect(
        saved.dayKey,
        newMeal(uid: uid, date: mealDate, mealId: '').dayKey,
      );
      expect(drafts.state, isNull);
    });

    testWidgets("a row's + adds without the sheet", (tester) async {
      await pumpLogger(tester);
      await tester.tap(find.byIcon(AppSymbols.add).first);
      await tester.pumpAndSettle();
      expect(find.text('1 on plate'), findsOneWidget);
      expect(find.byIcon(AppSymbols.selected), findsOneWidget);
    });

    testWidgets('quick add puts a serving on the plate and returns to it', (
      tester,
    ) async {
      await pumpLogger(tester);
      await tester.tap(find.text('Quick Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Snack');
      await tester.enterText(find.byType(TextField).at(1), '250');
      await tester.pump();
      await tester.tap(find.text('Add to Plate'));
      await tester.pumpAndSettle();
      expect(find.text('Log Meal'), findsOneWidget);
      expect(find.text('Snack'), findsOneWidget);
    });

    testWidgets('the library lists the foods', (tester) async {
      await pumpLogger(tester);
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.segments')),
          matching: find.text('Foods'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foods'), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'salmon');
      await tester.pump();
      expect(find.text('Atlantic Salmon'), findsOneWidget);
    });

    group('the plate', () {
      final draft = withItems(
        newMeal(uid: uid, date: mealDate, mealId: 'MEAL'),
        [sampleFoods(uid: uid, now: now).first.mealItem(40, itemId: 'a')],
      );

      testWidgets('shows a draft with its totals', (tester) async {
        await pumpLogger(tester, meal: draft);
        expect(find.text('Log Meal'), findsOneWidget);
        expect(find.text('Rolled Oats'), findsOneWidget);
        expect(find.text('Plate'), findsWidgets);
      });

      testWidgets('an item is corrected in the amount sheet', (tester) async {
        await pumpLogger(tester, meal: draft);
        await tester.tap(find.text('Rolled Oats'));
        await tester.pumpAndSettle();
        expect(find.byType(ItemAmountSheet), findsOneWidget);
        await tester.enterText(find.byType(TextField), '80');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(drafts.state?.items.single.amount, 80);
      });

      testWidgets('an item swipes off', (tester) async {
        await pumpLogger(tester, meal: draft);
        await tester.drag(find.text('Rolled Oats'), const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(find.text('Nothing on the plate yet'), findsOneWidget);
      });

      testWidgets('Add Food opens the picker; back returns to the plate', (
        tester,
      ) async {
        await pumpLogger(tester, meal: draft);
        await tester.tap(find.text('Add Food'));
        await tester.pumpAndSettle();
        expect(find.byType(FoodPickerView), findsOneWidget);
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.text('Log Meal'), findsOneWidget);
      });

      testWidgets('closing keeps the draft', (tester) async {
        await pumpLogger(tester, meal: draft);
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      });

      testWidgets('a failed save says so and keeps the plate', (tester) async {
        final failing = MockNutritionRepository();
        when(() => failing.watchMeals(uid))
            .thenAnswer((_) => Stream.value(const []));
        when(() => failing.watchDietPlan(uid))
            .thenAnswer((_) => Stream.value(null));
        when(
          () => failing.watchFoodLogSettings(uid),
        ).thenAnswer((_) => Stream.value(const FoodLogSettings(authorId: uid)));
        when(() => failing.saveMeal(draft))
            .thenAnswer((_) async => throw Exception('refused'));
        nutrition = InMemoryNutritionRepository();
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => AddMealPage(meal: draft),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          appBloc: appBloc,
          nutritionRepository: failing,
          foodRepository: foods,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppCtaButton, 'Log'));
        await tester.pumpAndSettle();
        expect(find.text('Unable to Save Meal'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Rolled Oats'), findsOneWidget);
      });
    });
  });

  group('openMealLogger', () {
    Future<void> pumpOpener(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () => openMealLogger(context, date: mealDate),
              child: const Text('open'),
            ),
          ),
          GoRoute(
            path: AddMealPage.path,
            name: AddMealPage.name,
            builder: (_, state) =>
                AddMealPage(meal: state.extra! as MealLogModel),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        appBloc: appBloc,
        nutritionRepository: nutrition,
        foodRepository: foods,
        mealDraftCubit: drafts,
      );
    }

    final draft = withItems(
      newMeal(uid: uid, date: mealDate, mealId: 'DRAFT'),
      [sampleFoods(uid: uid, now: now).first.mealItem(40, itemId: 'a')],
    );

    testWidgets('opens a new meal when there is no draft', (tester) async {
      await pumpOpener(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(FoodPickerView), findsOneWidget);
    });

    testWidgets('offers to continue the draft', (tester) async {
      drafts.keep(draft);
      await pumpOpener(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('You have an unlogged meal'), findsOneWidget);
      await tester.tap(find.text('Continue Meal'));
      await tester.pumpAndSettle();
      expect(find.text('Rolled Oats'), findsOneWidget);
    });

    testWidgets('or discards it and starts again', (tester) async {
      drafts.keep(draft);
      await pumpOpener(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and Start New'));
      await tester.pumpAndSettle();
      expect(drafts.state, isNull);
      expect(find.byType(FoodPickerView), findsOneWidget);
    });
  });
}
