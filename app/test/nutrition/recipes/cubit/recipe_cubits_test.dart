// Ported from the Swift `RecipeFlowPresenterTests` (`CreateRecipePresenter
// Tests`, `RecipeDetailPresenterTests`), `RecipeScalingPresenterTests`
// (`RecipeDetailServingsPresenterTests`), `RecipePreparationPresenterTests`
// and the search cases of `NutritionPresenterTests`.
import 'package:compound/nutrition/recipes/cubit/create_recipe_cubit.dart';
import 'package:compound/nutrition/recipes/cubit/recipe_detail_cubit.dart';
import 'package:compound/nutrition/recipes/cubit/recipes_cubit.dart';
import 'package:compound/nutrition/search/nutrition_search_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../../helpers/helpers.dart';

class _MockFoodRepository extends Mock implements FoodRepository;

class _MockNutritionRepository extends Mock implements NutritionRepository;

class _FakeSettings extends Fake implements FoodLogSettings;

class _FakeRecipe extends Fake implements RecipeTemplateModel;

void main() {
  const uid = 'user-1';
  final now = DateTime.utc(2026, 9, 14, 12);

  FoodModel food(
    String id, {
    String? name,
    double? calories,
    double? protein,
    String? description,
  }) => FoodModel(
    ingredientId: id,
    authorId: uid,
    name: name ?? id,
    description: description,
    nutrients: NutrientMap({
      NutrientKey.calories: ?calories,
      NutrientKey.protein: ?protein,
    }),
    dateCreated: now,
    dateModified: now,
  );

  RecipeIngredientModel ingredient(
    String name, {
    double amount = 100,
    IngredientAmountUnit unit = IngredientAmountUnit.grams,
  }) =>
      RecipeIngredientModel(ingredient: food(name), amount: amount, unit: unit);

  /// Makes 4 servings from 400 g of a 150 kcal/100 g mince and 100 g of a
  /// 20 g-protein bean.
  RecipeTemplateModel chilli({String id = 'chilli', String? authorId = uid}) =>
      RecipeTemplateModel(
        recipeId: id,
        authorId: authorId,
        name: 'Chilli',
        description: 'Hot',
        dateCreated: now,
        dateModified: now,
        ingredients: [
          RecipeIngredientModel(
            ingredient: food('mince', name: 'Mince', calories: 150),
            amount: 400,
            unit: IngredientAmountUnit.grams,
          ),
          RecipeIngredientModel(
            ingredient: food('beans', name: 'Beans', protein: 20),
            amount: 100,
            unit: IngredientAmountUnit.grams,
          ),
        ],
        servingQuantity: 4,
      );

  late AnalyticsRecorder analytics;

  setUpAll(() {
    registerFallbackValue(_FakeSettings());
    registerFallbackValue(_FakeRecipe());
  });
  setUp(() => analytics = AnalyticsRecorder());

  group(RecipesCubit, () {
    Future<RecipesCubit> build(List<RecipeTemplateModel> recipes) async {
      final cubit = RecipesCubit(
        uid: uid,
        foods: InMemoryFoodRepository(recipes: recipes),
        nutrition: InMemoryNutritionRepository(),
        analytics: analytics,
      );
      await pumpEventQueue();
      return cubit;
    }

    RecipeTemplateModel named(String id, String name, {String? description}) =>
        RecipeTemplateModel(
          recipeId: id,
          authorId: uid,
          name: name,
          description: description,
          dateCreated: now,
          dateModified: now,
        );

    test('lists the recipes by name and logs the screen', () async {
      final cubit = await build([
        named('b', 'stew'),
        named('a', 'Bake'),
        named('c', 'Curry'),
      ]);

      expect(cubit.state.visibleRecipes.map((r) => r.name), [
        'Bake',
        'Curry',
        'stew',
      ]);
      await cubit.close();
      expect(analytics.names, ['RecipesView_Appear', 'RecipesView_Disappear']);
    });

    test('filters on name, description or an ingredient, ignoring case', () {
      return build([
        named('a', 'Bake', description: 'Sunday'),
        chilli(),
        named('c', 'Curry'),
      ]).then((cubit) {
        cubit.filterChanged('sun');
        expect(cubit.state.visibleRecipes.map((r) => r.name), ['Bake']);
        cubit.filterChanged('BEANS');
        expect(cubit.state.visibleRecipes.map((r) => r.name), ['Chilli']);
        cubit.filterChanged('nothing');
        expect(cubit.state.visibleRecipes, isEmpty);
      });
    });

    test('an unreadable library lists nothing rather than loading', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchRecipes(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = RecipesCubit(
        uid: uid,
        foods: failing,
        nutrition: InMemoryNutritionRepository(),
        analytics: analytics,
      );
      await pumpEventQueue();

      expect(cubit.state.recipes, isEmpty);
    });

    test('rows show pictures as the logger’s Show Food Image says '
        '(RecipeListBuilderView)', () async {
      final cubit = RecipesCubit(
        uid: uid,
        foods: InMemoryFoodRepository(),
        nutrition: InMemoryNutritionRepository(
          foodLogSettings: const FoodLogSettings(
            authorId: uid,
            showFoodImageInLogger: false,
          ),
        ),
        analytics: analytics,
      );
      expect(cubit.state.showImage, isTrue);
      await pumpEventQueue();

      expect(cubit.state.showImage, isFalse);
      await cubit.close();
    });

    test('an unreadable setting leaves pictures shown', () async {
      final nutrition = _MockNutritionRepository();
      when(() => nutrition.watchFoodLogSettings(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = RecipesCubit(
        uid: uid,
        foods: InMemoryFoodRepository(),
        nutrition: nutrition,
        analytics: analytics,
      );
      await pumpEventQueue();

      expect(cubit.state.showImage, isTrue);
      await cubit.close();
    });
  });

  group(RecipeDetailCubit, () {
    late InMemoryFoodRepository foods;
    late InMemoryNutritionRepository nutrition;

    Future<RecipeDetailCubit> build({
      String recipeId = 'chilli',
      FoodRepository? foodRepository,
      NutritionRepository? nutritionRepository,
    }) async {
      final cubit = RecipeDetailCubit(
        uid: uid,
        recipeId: recipeId,
        foods: foodRepository ?? foods,
        nutrition: nutritionRepository ?? nutrition,
        analytics: analytics,
      );
      await pumpEventQueue();
      return cubit;
    }

    setUp(() {
      foods = InMemoryFoodRepository(
        recipes: [
          chilli(),
          chilli(id: 'shared', authorId: 'someone-else'),
        ],
      );
      nutrition = InMemoryNutritionRepository(
        foodLogSettings: const FoodLogSettings(
          authorId: uid,
          favouriteRecipeIds: ['stew'],
          startHour: 5,
        ),
      );
    });

    test("a recipe's favourite state is read on appear", () async {
      nutrition = InMemoryNutritionRepository(
        foodLogSettings: const FoodLogSettings(
          authorId: uid,
          favouriteRecipeIds: ['chilli'],
        ),
      );
      final cubit = await build();

      expect(cubit.state.recipe?.name, 'Chilli');
      expect(cubit.state.isFavourited, isTrue);
      await cubit.close();
      expect(analytics.names, [
        'RecipeDetailView_Appear',
        'RecipeDetailView_Disappear',
      ]);
    });

    test('a recipe that is not in the library is missing', () async {
      final cubit = await build(recipeId: 'gone');
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.recipe, isNull);
      expect(cubit.state.scaledNutrients.values, isEmpty);
    });

    test('an unreadable library still finishes loading', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchRecipes(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = await build(foodRepository: failing);
      expect(cubit.state.loaded, isTrue);
    });

    test('favouriting flips at once and is written', () async {
      final cubit = await build();

      await cubit.favouriteToggled();

      final settings = await nutrition.watchFoodLogSettings(uid).first;
      expect(settings.favouriteRecipeIds, ['stew', 'chilli']);
      expect(settings.startHour, 5);
      expect(cubit.state.isFavourited, isTrue);
      expect(analytics.names, [
        'RecipeDetailView_Appear',
        'RecipeDetailView_Favourite_Start',
        'RecipeDetailView_Favourite_Success',
      ]);
    });

    test('unfavouriting writes the removal', () async {
      final cubit = await build();
      await cubit.favouriteToggled();

      await cubit.favouriteToggled();

      expect(
        (await nutrition.watchFoodLogSettings(uid).first).favouriteRecipeIds,
        ['stew'],
      );
      expect(cubit.state.isFavourited, isFalse);
    });

    test('a failed favourite flips back and is reported', () async {
      final failing = MockNutritionRepository();
      when(
        () => failing.watchFoodLogSettings(uid),
      ).thenAnswer((_) => Stream.value(const FoodLogSettings(authorId: uid)));
      when(() => failing.saveFoodLogSettings(any()))
          .thenThrow(StateError('offline'));
      final cubit = await build(nutritionRepository: failing);

      await cubit.favouriteToggled();

      expect(cubit.state.isFavourited, isFalse);
      expect(cubit.state.favouriteFailures, 1);
      expect(analytics.names.last, 'RecipeDetailView_Favourite_Fail');
    });

    test('favouriting waits for the settings', () async {
      final silent = MockNutritionRepository();
      when(() => silent.watchFoodLogSettings(uid))
          .thenAnswer((_) => const Stream.empty());
      final cubit = await build(nutritionRepository: silent);

      await cubit.favouriteToggled();

      verifyNever(() => silent.saveFoodLogSettings(any()));
    });

    test('the stepper starts on the recipe as written', () async {
      final cubit = await build();
      final state = cubit.state;

      expect(state.servings, 4);
      expect(state.scaledAmount(state.recipe!.ingredients[0]), 400);
      expect(state.scaledNutrients.values[NutrientKey.calories], 600);
    });

    test('stepping scales every ingredient and the nutrition', () async {
      final cubit = await build()
        ..servingsChanged(6);
      final state = cubit.state;

      expect(state.scaledAmount(state.recipe!.ingredients[0]), 600);
      expect(state.scaledAmount(state.recipe!.ingredients[1]), 150);
      expect(state.scaledNutrients.values[NutrientKey.calories], 900);
      expect(state.scaledNutrients.values[NutrientKey.protein], 30);
    });

    test('a fractional serving rounds the amounts', () async {
      final cubit = await build()
        ..servingsChanged(1.5);

      expect(cubit.state.servings, 1.5);
      expect(
        cubit.state.scaledAmount(cubit.state.recipe!.ingredients[1]),
        37.5,
      );
    });

    test('servings cannot step below half or to something not a number', () {
      return build().then((cubit) {
        cubit.servingsChanged(0);
        expect(cubit.state.servings, 0.5);
        cubit.servingsChanged(double.nan);
        expect(cubit.state.servings, 0.5);
        cubit.servingsChanged(500);
        expect(cubit.state.servings, 100);
      });
    });

    test("only the author's recipe can be deleted", () async {
      expect((await build()).canDelete, isTrue);
      expect((await build(recipeId: 'shared')).canDelete, isFalse);
      expect((await build(recipeId: 'gone')).canDelete, isFalse);
    });

    test('a confirmed delete removes the recipe, then leaves', () async {
      final cubit = await build();

      await cubit.deleteConfirmed();

      // The other author's recipe is stored under them, not this user.
      expect(await foods.watchRecipes(uid).first, isEmpty);
      expect(cubit.state.deleteStatus, RecipeDetailDeleteStatus.deleted);
      expect(analytics.names, [
        'RecipeDetailView_Appear',
        'RecipeDetailView_Delete_Start',
        'RecipeDetailView_Delete_Success',
      ]);
      await cubit.deleteConfirmed();
      expect(analytics.names, hasLength(3));
    });

    test('a failed delete says so and stays', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchRecipes(uid))
          .thenAnswer((_) => Stream.value([chilli()]));
      when(() => failing.deleteRecipe(uid, 'chilli'))
          .thenThrow(StateError('offline'));
      final cubit = await build(foodRepository: failing);

      await cubit.deleteConfirmed();

      expect(cubit.state.deleteStatus, RecipeDetailDeleteStatus.idle);
      expect(cubit.state.deleteFailures, 1);
      expect(analytics.names.last, 'RecipeDetailView_Delete_Fail');
    });
  });

  group(CreateRecipeCubit, () {
    late InMemoryFoodRepository foods;
    late InMemoryImageRepository images;
    late FakePhotoPicker picker;

    CreateRecipeCubit build({String? user = uid, FoodRepository? repository}) =>
        CreateRecipeCubit(
          uid: user,
          foods: repository ?? foods,
          analytics: analytics,
          images: images,
          picker: picker,
          now: () => now,
          newId: () => 'RECIPE',
        );

    Future<RecipeTemplateModel?> saved() async =>
        (await foods.watchRecipes(uid).first).firstOrNull;

    setUp(() {
      foods = InMemoryFoodRepository();
      images = InMemoryImageRepository();
      picker = FakePhotoPicker();
    });

    group('photo (RecipePreparationView.photoSection, '
        'RecipeTemplateManager.saveRecipeTemplate)', () {
      CreateRecipeCubit filled({ImageRepository? store}) =>
          CreateRecipeCubit(
              uid: uid,
              foods: foods,
              analytics: analytics,
              images: store ?? images,
              picker: picker,
              now: () => now,
              newId: () => 'RECIPE',
            )
            ..nameChanged('Chilli')
            ..servingsChanged(4);

      test('a photo is picked from the library, logging nothing', () async {
        final cubit = filled();

        await cubit.photoPressed();

        expect(cubit.state.photo, picker.photo);
        expect(picker.picks, [(PhotoSource.library, PhotoSize.recipeImage)]);
        expect(analytics.names, isEmpty);
      });

      test('a cancel or an unreadable photo changes nothing', () async {
        final cubit = filled();
        picker.photo = null;
        await cubit.photoPressed();
        picker.error = Exception('unreadable');
        await cubit.photoPressed();

        expect(cubit.state.photo, isNull);
      });

      test('Create uploads the photo to Swift’s path before saving its '
          'address', () async {
        final cubit = filled();
        await cubit.photoPressed();

        await cubit.create();

        expect(images.images.keys, ['recipe_templates/RECIPE']);
        expect((await saved())?.imageUrl, startsWith('data:image/jpeg'));
      });

      test('without a photo nothing is uploaded', () async {
        final cubit = filled();

        await cubit.create();

        expect(images.images, isEmpty);
        expect((await saved())?.imageUrl, isNull);
      });

      test('a failed upload saves nothing and stays open', () async {
        final cubit = filled(store: FailingImageRepository());
        await cubit.photoPressed();

        await cubit.create();

        expect(await saved(), isNull);
        expect(cubit.state.status, CreateRecipeStatus.failed);
        expect(analytics.names.last, 'RecipePreparationView_CreateRecipe_Fail');
      });
    });

    test('a recipe cannot be saved without a name', () {
      final cubit = build()
        ..nameChanged('   ')
        ..servingsChanged(4);
      expect(cubit.state.canContinue, isFalse);
    });

    test('moving on without servings goes nowhere', () {
      final cubit = build()..nameChanged('Chilli');
      expect(cubit.state.canContinue, isFalse);
      expect(cubit.buildRecipe(), isNull);
      cubit.servingsChanged(0);
      expect(cubit.state.canContinue, isFalse);
    });

    test('only an edited recipe has something to lose', () {
      final cubit = build();
      expect(cubit.state.hasUnsavedChanges, isFalse);
      cubit.ingredientConfirmed(ingredient('Mince'));
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect(
        (build()..totalWeightChanged(1200)).state.hasUnsavedChanges,
        isTrue,
      );
      expect((build()..servingsChanged(2)).state.hasUnsavedChanges, isTrue);
      expect((build()..nameChanged('C')).state.hasUnsavedChanges, isTrue);
    });

    test('an ingredient can be removed', () {
      final cubit = build()
        ..ingredientConfirmed(ingredient('Mince'))
        ..ingredientConfirmed(ingredient('Beans'))
        ..ingredientRemoved(0);
      expect(cubit.state.ingredients.map((i) => i.name), ['Beans']);
    });

    test('a confirmed ingredient joins the list', () {
      final cubit = build()..ingredientConfirmed(ingredient('Mince'));
      expect(cubit.state.ingredients.map((i) => i.name), ['Mince']);
    });

    test('reconfirming an ingredient replaces it', () {
      final cubit = build()
        ..ingredientConfirmed(ingredient('Mince'))
        ..ingredientConfirmed(ingredient('Mince', amount: 400));
      expect(cubit.state.ingredients.single.amount, 400);
    });

    test('an amount and unit change in the list', () {
      final cubit = build()
        ..ingredientConfirmed(ingredient('Mince'))
        ..ingredientAmountChanged(0, 250)
        ..ingredientUnitChanged(0, IngredientAmountUnit.units);
      expect(cubit.state.ingredients.single.amount, 250);
      expect(cubit.state.ingredients.single.unit, IngredientAmountUnit.units);
      cubit.ingredientAmountChanged(0, null);
      expect(cubit.state.ingredients.single.amount, 0);
    });

    test('the ingredient weight adds up the weighed ingredients', () {
      final cubit = build();
      expect(cubit.state.ingredientsWeight, isNull);
      cubit
        ..ingredientConfirmed(ingredient('Mince', amount: 400))
        ..ingredientConfirmed(ingredient('Beans', amount: 120))
        ..ingredientConfirmed(
          ingredient(
            'Milk',
            amount: 250,
            unit: IngredientAmountUnit.milliliters,
          ),
        );
      expect(cubit.state.ingredientsWeight, 520);
    });

    test('the steps list starts with one empty row', () {
      expect(build().state.steps, ['']);
    });

    test('adding, editing, removing and moving steps', () {
      final cubit = build()
        ..stepChanged(0, 'One')
        ..stepAdded()
        ..stepChanged(1, 'Two')
        ..stepAdded()
        ..stepChanged(2, 'Three');
      expect(cubit.state.steps, ['One', 'Two', 'Three']);
      cubit.stepMoved(2, 0);
      expect(cubit.state.steps, ['Three', 'One', 'Two']);
      cubit.stepRemoved(1);
      expect(cubit.state.steps, ['Three', 'Two']);
    });

    test('the recipe carries everything, cleaned as Swift saves it', () async {
      final cubit = build()
        ..nameChanged('chilli con carne')
        ..servingsChanged(4)
        ..totalWeightChanged(1200)
        ..ingredientConfirmed(ingredient('Mince'))
        ..stepChanged(0, 'Brown the mince')
        ..stepAdded()
        ..stepAdded()
        ..stepChanged(2, '   ')
        ..stepAdded()
        ..stepChanged(3, 'Simmer')
        ..prepTimeChanged(15)
        ..cookTimeChanged(40)
        ..sourceUrlChanged('https://example.com/chilli');

      await cubit.create();

      final recipe = (await saved())!;
      expect(recipe.recipeId, 'RECIPE');
      expect(recipe.authorId, uid);
      expect(recipe.name, 'Chilli Con Carne');
      expect(recipe.servingQuantity, 4);
      expect(recipe.totalWeight, 1200);
      expect(recipe.ingredients.map((i) => i.name), ['Mince']);
      expect(recipe.preparationSteps, ['Brown the mince', 'Simmer']);
      expect(recipe.prepTimeMins, 15);
      expect(recipe.cookTimeMins, 40);
      expect(recipe.sourceUrl, 'https://example.com/chilli');
      expect(recipe.dateCreated, now);
      expect(recipe.clickCount, 0);
      expect(cubit.state.status, CreateRecipeStatus.created);
      expect(analytics.names, [
        'RecipePreparationView_CreateRecipe_Start',
        'RecipePreparationView_CreateRecipe_Success',
      ]);
    });

    test('an empty source, and a zero or absent weight, are absent', () async {
      final cubit = build()
        ..nameChanged('Chilli')
        ..servingsChanged(4)
        ..totalWeightChanged(0);

      await cubit.create();

      final recipe = (await saved())!;
      expect(recipe.sourceUrl, isNull);
      expect(recipe.totalWeight, isNull);
      expect(recipe.preparationSteps, isEmpty);
    });

    test('nothing is saved without a user', () async {
      final cubit = build(user: null)
        ..nameChanged('Chilli')
        ..servingsChanged(4);

      await cubit.create();

      expect(await saved(), isNull);
      expect(analytics.names, isEmpty);
    });

    test('a failed save is reported and the form stays', () async {
      final failing = _MockFoodRepository();
      when(() => failing.saveRecipe(any())).thenThrow(StateError('offline'));
      final cubit = build(repository: failing)
        ..nameChanged('Chilli')
        ..servingsChanged(4);

      await cubit.create();

      expect(cubit.state.status, CreateRecipeStatus.failed);
      expect(analytics.names, [
        'RecipePreparationView_CreateRecipe_Start',
        'RecipePreparationView_CreateRecipe_Fail',
      ]);
    });

    test('a second Create while saving saves nothing more', () async {
      final cubit = build()
        ..nameChanged('Chilli')
        ..servingsChanged(4);

      final first = cubit.create();
      await cubit.create();
      await first;

      expect(analytics.names.where((n) => n.endsWith('_Start')), hasLength(1));
    });

    test('the steps log their screens', () {
      build()
        ..appeared('CreateRecipeView')
        ..disappeared('CreateRecipeView');
      expect(analytics.names, [
        'CreateRecipeView_Appear',
        'CreateRecipeView_Disappear',
      ]);
    });
  });

  group(NutritionSearchCubit, () {
    Future<NutritionSearchCubit> build({FoodRepository? repository}) async {
      final cubit = NutritionSearchCubit(
        uid: uid,
        foods:
            repository ??
            InMemoryFoodRepository(
              foods: [
                food('oats', name: 'Oats', description: 'Rolled'),
                food('beans', name: 'Beans'),
              ],
              recipes: [chilli()],
            ),
      );
      await pumpEventQueue();
      return cubit;
    }

    test('matches foods and recipes', () async {
      final cubit = await build();
      expect(cubit.state.isSearching, isFalse);
      expect(cubit.state.matchingFoods, isEmpty);

      cubit.queryChanged('bean');
      expect(cubit.state.isSearching, isTrue);
      expect(cubit.state.matchingFoods.map((f) => f.name), ['Beans']);
      // By an ingredient's name.
      expect(cubit.state.matchingRecipes.map((r) => r.name), ['Chilli']);

      cubit.queryChanged('rolled ');
      expect(cubit.state.matchingFoods.map((f) => f.name), ['Oats']);
      expect(cubit.state.matchingRecipes, isEmpty);
      await cubit.close();
    });

    test('a library that fails to load searches as empty', () async {
      final failing = _MockFoodRepository();
      when(() => failing.watchFoods(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      when(() => failing.watchRecipes(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = await build(repository: failing);

      cubit.queryChanged('bean');
      expect(cubit.state.matchingFoods, isEmpty);
      expect(cubit.state.matchingRecipes, isEmpty);
    });
  });
}
