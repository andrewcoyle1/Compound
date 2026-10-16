import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_page.dart';
import 'package:compound/nutrition/recipes/view/create_recipe_pages.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:flutter/material.dart';
import 'package:food_repository/food_repository.dart' show RecipeTemplateModel;
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Foods, recipes, their details and a logged meal, under the Nutrition
/// tab, as the Swift app pushes them.
final nutritionRoutes = <RouteBase>[
  GoRoute(
    path: RecipesPage.path,
    name: RecipesPage.name,
    builder: (_, _) => const RecipesPage(),
    routes: [
      GoRoute(
        path: RecipeDetailPage.path,
        name: RecipeDetailPage.name,
        builder: (_, state) => RecipeDetailPage(
          recipeId: state.pathParameters[RecipeDetailPage.idParameter]!,
        ),
        routes: [
          GoRoute(
            path: RecipeStartPage.path,
            name: RecipeStartPage.name,
            // Opened from the detail with its recipe; a link without one
            // shows the detail.
            builder: (_, state) => switch (state.extra) {
              final RecipeTemplateModel recipe => RecipeStartPage(
                recipe: recipe,
              ),
              _ => RecipeDetailPage(
                recipeId: state.pathParameters[RecipeDetailPage.idParameter]!,
              ),
            },
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: FoodsPage.path,
    name: FoodsPage.name,
    builder: (_, _) => const FoodsPage(),
    routes: [
      GoRoute(
        path: FoodDetailPage.path,
        name: FoodDetailPage.name,
        builder: (_, state) => FoodDetailPage(
          foodId: state.pathParameters[FoodDetailPage.idParameter]!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: MealDetailPage.path,
    name: MealDetailPage.name,
    builder: (_, state) => MealDetailPage(
      mealId: state.pathParameters[MealDetailPage.idParameter]!,
      meal: switch (state.extra) {
        final MealLogModel meal => meal,
        _ => null,
      },
    ),
  ),
];

/// Create Food, over the tabs as the Swift app's sheet, from Foods and from
/// the meal logger alike. The page carries its route name, which Create
/// pops back to.
final createFoodRoute = GoRoute(
  path: CreateFoodPage.path,
  name: CreateFoodPage.name,
  pageBuilder: (_, state) => MaterialPage(
    key: state.pageKey,
    name: CreateFoodPage.name,
    fullscreenDialog: true,
    child: CreateFoodPage(
      addToPlate: state.uri.queryParameters[CreateFoodPage.addParameter] == '1',
    ),
  ),
);

/// Create Recipe, over the tabs as the Swift app's full-screen cover. The
/// page carries its route name, which Create pops back to.
final createRecipeRoute = GoRoute(
  path: CreateRecipePage.path,
  name: CreateRecipePage.name,
  pageBuilder: (_, state) => MaterialPage(
    key: state.pageKey,
    name: CreateRecipePage.name,
    fullscreenDialog: true,
    child: const CreateRecipePage(),
  ),
);
