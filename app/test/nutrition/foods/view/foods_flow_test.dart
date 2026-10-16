import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_page.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/timeline_actions/timeline_actions_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

// The whole app on the staging flavor's in-memory data, signed in as the
// sample user: Foods, Create Food, a food's detail, logging it, the meal,
// correcting an amount, Timeline Actions and the deletes.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  late InMemoryNutritionRepository nutrition;
  late InMemoryFoodRepository foods;

  Future<void> pumpApp(WidgetTester tester, {List<MealLogModel>? meals}) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    nutrition = InMemoryNutritionRepository(meals: meals ?? const []);
    foods = InMemoryFoodRepository(
      foods: sampleFoods(uid: uid, now: now),
    );
    await tester.pumpWidget(
      App(
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: now)},
          settings: {uid: sampleUserSettings(now: now)},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: nutrition,
        bodyRepository: InMemoryBodyRepository(),
        foodRepository: foods,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/nutrition');
    await tester.pumpAndSettle();
  }

  /// Scrolls the Nutrition day to [finder], which it builds lazily.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(NutritionView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Through Create Food's three steps: Oat Milk, a 250 g glass of 100 kcal.
  Future<void> createOatMilk(WidgetTester tester, {bool andAdd = false}) async {
    expect(find.byType(CreateFoodView), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('CreateFood.name')),
      'Oat Milk',
    );
    await tester.enterText(find.byKey(const Key('CreateFood.brand')), 'Oatly');
    await tester.pump();
    await tester.tap(find.byKey(const Key('CreateFood.next')));
    await tester.pumpAndSettle();

    expect(find.byType(PortionDefinitionView), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('PortionDefinition.weight')),
        matching: find.byType(TextField),
      ),
      '250',
    );
    await tester.enterText(
      find.byKey(const Key('PortionDefinition.name')),
      'glass',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('PortionDefinition.next')));
    await tester.pumpAndSettle();

    expect(find.byType(FoodDefinitionView), findsOneWidget);
    expect(find.text('Provide nutrition facts for serving'), findsOneWidget);
    expect(find.text('Serving Size: 1 glass'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('FoodDefinition.energy')),
        matching: find.byType(TextField),
      ),
      '100',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        Key(andAdd ? 'FoodDefinition.createAndAdd' : 'FoodDefinition.create'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Foods', () {
    testWidgets('creates a food, opens it, favourites it and deletes it', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapVisible(tester, find.byKey(const Key('Nutrition.foods')));
      expect(find.byType(FoodsView), findsOneWidget);
      expect(find.text('Custom Foods'), findsOneWidget);
      expect(find.text('Rolled Oats'), findsOneWidget);

      await tester.tap(find.byTooltip('Add ingredient'));
      await tester.pumpAndSettle();
      await createOatMilk(tester);

      // Back on Foods, with the new food in the library, per 100 g.
      expect(find.byType(FoodsView), findsOneWidget);
      final saved = (await foods.watchFoods(uid).first).singleWhere(
        (food) => food.name == 'Oat Milk',
      );
      expect(saved.brandName, 'Oatly');
      expect(saved.servingWeight, 250);
      expect(saved.portionName, 'glass');
      expect(saved.nutrients.values, {NutrientKey.calories: 40});

      await tester.enterText(find.byKey(const Key('Foods.filter')), 'oat m');
      await tester.pumpAndSettle();
      expect(find.text('Rolled Oats'), findsNothing);
      await tester.tap(find.text('Oat Milk'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodDetailView), findsOneWidget);
      expect(find.text('Nutrition Information (per 100g)'), findsOneWidget);
      expect(find.text('40 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(
        (await nutrition.watchFoodLogSettings(uid).first).favouriteFoodIds,
        [saved.ingredientId],
      );

      await tester.tap(find.byTooltip('Food options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Food'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Are you sure you want to delete 'Oat Milk'? This action cannot be "
          'undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodsView), findsOneWidget);
      expect(
        (await foods.watchFoods(uid).first).map((food) => food.name),
        isNot(contains('Oat Milk')),
      );
    });

    testWidgets('an empty library offers Create a Food', (tester) async {
      await pumpApp(tester);
      for (final food in await foods.watchFoods(uid).first) {
        await foods.deleteFood(uid, food.ingredientId);
      }
      await tapVisible(tester, find.byKey(const Key('Nutrition.foods')));
      expect(find.text('No Foods'), findsOneWidget);
      expect(find.text('Foods you create appear here.'), findsOneWidget);

      await tester.tap(find.text('Create a Food'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateFoodView), findsOneWidget);
    });

    testWidgets('a filter with no match says so', (tester) async {
      await pumpApp(tester);
      await tapVisible(tester, find.byKey(const Key('Nutrition.foods')));
      await tester.enterText(find.byKey(const Key('Foods.filter')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });

    testWidgets('closing Create Food asks first once something is typed', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapVisible(tester, find.byKey(const Key('Nutrition.foods')));
      await tester.tap(find.byTooltip('Add ingredient'));
      await tester.pumpAndSettle();

      // Untouched, it just closes.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateFoodView), findsNothing);

      await tester.tap(find.byTooltip('Add ingredient'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('CreateFood.name')), 'Oat');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this food?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateFoodView), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard Food'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateFoodView), findsNothing);
    });

    testWidgets('a barcode can be typed into a new food', (tester) async {
      await pumpApp(tester);
      await tapVisible(tester, find.byKey(const Key('Nutrition.foods')));
      await tester.tap(find.byTooltip('Add ingredient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Barcode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter Barcode'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '5012345678900',
      );
      await tester.tap(find.text('Look Up'));
      await tester.pumpAndSettle();

      expect(find.text('5012345678900'), findsOneWidget);
    });
  });

  group('Create & Add from the meal logger', () {
    testWidgets('puts the new food on the plate at 100 g', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Log Meal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.segments')),
          matching: find.text('Foods'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('FoodPicker.createFood')));
      await tester.pumpAndSettle();

      await createOatMilk(tester, andAdd: true);

      // Back in the logger, with the food on the plate.
      expect(find.byType(CreateFoodView), findsNothing);
      expect(find.text('1 on plate'), findsOneWidget);
    });
  });

  group('A logged meal', () {
    MealItemModel item(String id, String name) => MealItemModel(
      itemId: id,
      sourceType: MealItemSourceType.ingredient,
      sourceId: 'source-$id',
      displayName: name,
      amount: 100,
      unit: 'g',
      resolvedGrams: 100,
      nutrients: const NutrientMap({
        NutrientKey.calories: 120,
        NutrientKey.protein: 10,
      }),
    );
    final mealDate = DateTime(now.year, now.month, now.day, 12, 15);
    final meal = MealLogModel(
      mealId: 'lunch',
      authorId: uid,
      dayKey: dayKeyOf(mealDate),
      date: mealDate,
      items: [item('a', 'Soup'), item('b', 'Bread')],
      notes: 'Desk lunch',
    );

    testWidgets('opens from the timeline and deletes after asking', (
      tester,
    ) async {
      await pumpApp(tester, meals: [meal]);
      await tapVisible(tester, find.text('Soup'));

      expect(find.byType(MealDetailView), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete meal'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this meal?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(MealDetailView), findsNothing);
      expect(await nutrition.watchMeals(uid).first, isEmpty);
    });

    testWidgets("the pencil corrects a food's amount in its meal", (
      tester,
    ) async {
      await pumpApp(tester, meals: [meal]);
      await tapVisible(tester, find.byTooltip('Edit Bread'));
      expect(find.byType(ItemAmountSheet), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(ItemAmountSheet),
          matching: find.byType(TextField),
        ),
        '50',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await nutrition.watchMeals(uid).first).single;
      expect(saved.items.map((item) => item.amount), [100, 50]);
      expect(saved.items.last.nutrients.values[NutrientKey.calories], 60);
      expect(saved.notes, 'Desk lunch');
    });

    testWidgets('a long press offers View Meal, Log Meal Again and Delete', (
      tester,
    ) async {
      await pumpApp(tester, meals: [meal]);
      await reveal(tester, find.text('Soup'));
      await tester.longPress(find.text('Soup'));
      await tester.pumpAndSettle();
      expect(find.text('View Meal'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Log Meal Again'));
      await tester.pumpAndSettle();
      final meals = await nutrition.watchMeals(uid).first;
      expect(meals, hasLength(2));
      expect(meals.last.notes, 'Desk lunch');

      await tester.longPress(find.text('Bread').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Meal'));
      await tester.pumpAndSettle();
      expect(find.byType(MealDetailView), findsOneWidget);
    });

    testWidgets('swipes log the meal again or delete a food', (tester) async {
      await pumpApp(tester, meals: [meal]);
      await reveal(tester, find.text('Soup'));

      await tester.drag(find.text('Soup'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(await nutrition.watchMeals(uid).first, hasLength(2));

      await tester.drag(find.text('Bread').first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      final meals = await nutrition.watchMeals(uid).first;
      expect(
        meals.firstWhere((meal) => meal.mealId == 'lunch').items.length,
        1,
      );
    });

    testWidgets('Timeline Actions copies the day after asking where to', (
      tester,
    ) async {
      await pumpApp(tester, meals: [meal]);
      await tapVisible(
        tester,
        find.byKey(const Key('Nutrition.timelineActions')),
      );
      expect(find.byType(TimelineActionsView), findsOneWidget);

      await tester.tap(find.text('Copy Day'));
      await tester.pumpAndSettle();
      expect(find.text('Copy to'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineActionsView), findsNothing);
      final meals = await nutrition.watchMeals(uid).first;
      expect(meals, hasLength(2));
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(meals.last.dayKey, dayKeyOf(tomorrow));
    });

    testWidgets('Timeline Actions clears the day after asking', (tester) async {
      await pumpApp(tester, meals: [meal]);
      await tapVisible(
        tester,
        find.byKey(const Key('Nutrition.timelineActions')),
      );
      await tester.tap(find.text('Clear Day'));
      await tester.pumpAndSettle();
      expect(find.text('Clear this day?'), findsOneWidget);
      expect(
        find.text('1 logged meal will be deleted. This cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Clear Day').last);
      await tester.pumpAndSettle();

      expect(find.byType(TimelineActionsView), findsNothing);
      expect(await nutrition.watchMeals(uid).first, isEmpty);
    });

    testWidgets('Timeline Actions toggles Hide Food Details and Hide Empty '
        'Hours, and says when there is nothing to clear', (tester) async {
      await pumpApp(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('Nutrition.timelineActions')),
      );

      await tester.tap(find.text('Hide Food Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide Empty Hours'));
      await tester.pumpAndSettle();
      final settings = await nutrition.watchFoodLogSettings(uid).first;
      expect(settings.hideFoodDetails, isTrue);
      expect(settings.hideEmptyHours, isTrue);

      await tester.tap(find.text('Clear Day'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to Clear'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to Copy'), findsOneWidget);
    });
  });
}
