import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Foods, a food's detail and a logged meal, under the Nutrition tab, as the
/// Swift app pushes them.
final nutritionRoutes = <RouteBase>[
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
