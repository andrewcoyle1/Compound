import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/recipes/view/create_recipe_pages.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

// The whole app on the staging flavor's in-memory data, signed in as the
// sample user: Recipes, Create Recipe, a recipe's detail and start, logging
// one from the meal logger, and finding one with the Nutrition tab's search.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  late InMemoryNutritionRepository nutrition;
  late InMemoryFoodRepository foods;

  Future<void> pumpApp(WidgetTester tester, {FoodLogSettings? settings}) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    nutrition = InMemoryNutritionRepository(foodLogSettings: settings);
    final library = sampleFoods(uid: uid, now: now);
    foods = InMemoryFoodRepository(
      foods: library,
      recipes: sampleRecipes(uid: uid, now: now, foods: library),
    );
    await tester.pumpWidget(
      App(
        purchasesRepository: FakePurchasesRepository(),
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openRecipes(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('Nutrition.recipes')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(NutritionView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tap(tester, find.byKey(const Key('Nutrition.recipes')));
    expect(find.byType(RecipesView), findsOneWidget);
  }

  Future<List<RecipeTemplateModel>> stored() => foods.watchRecipes(uid).first;

  group('Recipes', () {
    testWidgets('lists, filters and opens a recipe, then starts it', (
      tester,
    ) async {
      await pumpApp(tester);
      await openRecipes(tester);
      expect(find.text('Custom Recipes'), findsOneWidget);
      expect(find.text('Chicken Rice Bowl'), findsOneWidget);
      expect(find.text('Overnight Oats'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('Recipes.filter')),
          matching: find.byType(TextField),
        ),
        'broccoli',
      );
      await tester.pumpAndSettle();
      expect(find.text('Chicken Rice Bowl'), findsOneWidget);
      expect(find.text('Overnight Oats'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('Recipes.filter')),
          matching: find.byType(TextField),
        ),
        'nothing like it',
      );
      await tester.pumpAndSettle();
      expect(find.text('No Results for “nothing like it”'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('Recipes.filter')),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.pumpAndSettle();

      await tap(tester, find.text('Overnight Oats'));
      expect(find.byType(RecipeDetailView), findsOneWidget);
      expect(find.text('2 servings'), findsOneWidget);
      // 80 g of oats in two servings.
      expect(find.text('80 g'), findsOneWidget);

      await tap(tester, find.byKey(const Key('RecipeDetail.increase')));
      expect(find.text('2.5 servings'), findsOneWidget);
      expect(find.text('100 g'), findsOneWidget);
      await tap(tester, find.byKey(const Key('RecipeDetail.decrease')));
      await tap(tester, find.byKey(const Key('RecipeDetail.decrease')));
      await tap(tester, find.byKey(const Key('RecipeDetail.decrease')));
      expect(find.text('1 serving'), findsOneWidget);

      await tap(tester, find.text('Start'));
      expect(find.byType(RecipeStartPage), findsOneWidget);
      // The amounts as written, whatever the stepper said.
      expect(find.text('80 g'), findsOneWidget);
      expect(find.text('300 ml'), findsOneWidget);
    });

    testWidgets('favourites a recipe and deletes it', (tester) async {
      await pumpApp(tester);
      await openRecipes(tester);
      await tap(tester, find.text('Salmon Avocado Toast'));

      await tap(tester, find.byTooltip('Add to favorites'));
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(
        (await nutrition.watchFoodLogSettings(uid).first).favouriteRecipeIds,
        ['sample-recipe-salmon-avocado-toast'],
      );

      await tap(tester, find.byTooltip('Recipe options'));
      await tap(tester, find.text('Delete Recipe'));
      expect(
        find.text(
          "Are you sure you want to delete 'Salmon Avocado Toast'? This "
          'action cannot be undone.',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('Delete'));

      expect(find.byType(RecipesView), findsOneWidget);
      expect(find.text('Salmon Avocado Toast'), findsNothing);
      expect(await stored(), hasLength(2));
    });

    testWidgets('an empty library offers Create a Recipe', (tester) async {
      await pumpApp(tester);
      for (final recipe in await stored()) {
        await foods.deleteRecipe(uid, recipe.recipeId);
      }
      await openRecipes(tester);
      expect(find.text('No Recipes'), findsOneWidget);
      await tap(tester, find.text('Create a Recipe'));
      expect(find.byType(CreateRecipeView), findsOneWidget);
    });
  });

  group('Create Recipe', () {
    testWidgets('builds a recipe from foods, with its method', (tester) async {
      await pumpApp(tester);
      await openRecipes(tester);
      await tap(tester, find.byTooltip('Add recipe'));
      expect(find.byType(CreateRecipeView), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('CreateRecipe.name')),
        'chicken traybake',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('CreateRecipe.servings')),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();

      // The ingredient picker: a row opens its amount, a + adds a portion.
      await tap(tester, find.byKey(const Key('CreateRecipe.addIngredient')));
      expect(find.text('Custom Foods'), findsOneWidget);
      await tap(tester, find.text('Chicken Breast'));
      expect(find.byType(RecipeIngredientAmountSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(RecipeIngredientAmountSheet),
          matching: find.byType(TextField),
        ),
        '450',
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add'));
      expect(find.byType(RecipeIngredientAmountSheet), findsNothing);
      await tap(tester, find.byTooltip('Quick add Broccoli'));
      await tap(tester, find.byType(CloseButton));

      expect(find.text('Chicken Breast'), findsOneWidget);
      expect(find.text('Broccoli'), findsOneWidget);
      // 450 g of chicken and Broccoli's 100 g.
      expect(find.text('Weight of ingredients is 550 g'), findsOneWidget);

      await tap(tester, find.text('Next'));
      expect(find.byType(RecipePreparationView), findsOneWidget);
      expect(find.text('Chicken Traybake'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('RecipePreparation.step.0')),
        'Roast everything for 25 minutes.',
      );
      await tap(tester, find.byKey(const Key('RecipePreparation.addStep')));
      await tap(tester, find.text('Create'));

      expect(find.byType(CreateRecipeView), findsNothing);
      expect(find.byType(RecipesView), findsOneWidget);
      expect(find.text('Chicken Traybake'), findsOneWidget);
      final created = (await stored()).firstWhere(
        (recipe) => recipe.name == 'Chicken Traybake',
      );
      expect(created.servingQuantity, 3);
      expect(created.ingredients.map((i) => (i.name, i.amount)), [
        ('Chicken Breast', 450.0),
        ('Broccoli', 100.0),
      ]);
      expect(created.preparationSteps, ['Roast everything for 25 minutes.']);
    });

    testWidgets('closing with something typed asks first', (tester) async {
      await pumpApp(tester);
      await openRecipes(tester);
      await tap(tester, find.byTooltip('Add recipe'));
      await tester.enterText(find.byKey(const Key('CreateRecipe.name')), 'S');
      await tester.pumpAndSettle();

      await tap(tester, find.byTooltip('Close'));
      expect(find.text('Discard this recipe?'), findsOneWidget);
      await tap(tester, find.text('Discard Recipe'));
      expect(find.byType(CreateRecipeView), findsNothing);
      expect(await stored(), hasLength(3));
    });
  });

  group('The meal logger', () {
    Future<void> openLogger(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Log Meal'));
      await tester.pumpAndSettle();
    }

    testWidgets('logs recipes from the library, by servings and by +', (
      tester,
    ) async {
      await pumpApp(tester);
      await openLogger(tester);
      await tap(tester, find.text('Library'));
      // With no favourites the library opens on recipes.
      expect(find.text('Custom Recipes'), findsOneWidget);

      await tap(tester, find.text('Overnight Oats'));
      expect(find.byType(RecipeServingsSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(RecipeServingsSheet),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add to Plate'));
      expect(find.text('1 on plate'), findsOneWidget);

      await tap(tester, find.byTooltip('Quick add Chicken Rice Bowl'));
      expect(find.text('2 on plate'), findsOneWidget);

      await tap(tester, find.text('Log'));
      final meal = (await nutrition.watchMeals(uid).first).single;
      expect(meal.items.map((item) => (item.displayName, item.amount)), [
        ('Overnight Oats', 2.0),
        ('Chicken Rice Bowl', 1.0),
      ]);
      expect(
        meal.items.every(
          (item) => item.sourceType == MealItemSourceType.recipe,
        ),
        isTrue,
      );
    });

    testWidgets('the search finds a recipe, and favourites list it', (
      tester,
    ) async {
      await pumpApp(
        tester,
        settings: const FoodLogSettings(
          authorId: uid,
          favouriteRecipeIds: ['sample-recipe-chicken-rice-bowl'],
        ),
      );
      await openLogger(tester);
      await tester.enterText(find.byType(TextField).first, 'bowl');
      await tester.pumpAndSettle();
      expect(find.text('My Recipes'), findsOneWidget);
      expect(find.text('Chicken Rice Bowl'), findsOneWidget);

      await tap(tester, find.text('Library'));
      // With a favourite the library opens on favourites.
      expect(find.text('Chicken Rice Bowl'), findsOneWidget);
      expect(find.text('Overnight Oats'), findsNothing);

      await tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('FoodPicker.segments')),
          matching: find.text('Recipes'),
        ),
      );
      expect(find.text('Overnight Oats'), findsOneWidget);
    });
  });

  group('The Nutrition tab search', () {
    testWidgets('finds recipes and foods and opens a recipe', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('Nutrition.search')),
          matching: find.byType(TextField),
        ),
        'oats',
      );
      await tester.pumpAndSettle();
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Overnight Oats'), findsOneWidget);
      expect(find.text('Foods'), findsOneWidget);
      expect(find.text('Rolled Oats'), findsOneWidget);

      await tap(tester, find.text('Overnight Oats'));
      expect(find.byType(RecipeDetailView), findsOneWidget);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('Nutrition.search')),
          matching: find.byType(TextField),
        ),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });
  });
}
