import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/recipes/cubit/recipes_cubit.dart';
import 'package:compound/nutrition/recipes/view/create_recipe_pages.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The user's recipes (Swift `RecipesView`, with the
/// `RecipeListBuilderView` it embeds): filter, open one, or create one.
/// Under the Nutrition tab.
class RecipesPage extends StatelessWidget {
  const new({super.key});

  static const path = 'recipes';
  static const name = 'recipes';

  /// Opens Recipes from the Nutrition tab.
  static Future<void> show(BuildContext context) =>
      context.pushNamed<void>(name);

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => RecipesCubit(
        uid: app.user.uid,
        foods: context.read<FoodRepository>(),
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const RecipesView(),
    );
  }
}

class RecipesView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RecipesCubit>();
    final state = context.watch<RecipesCubit>().state;
    final recipes = state.visibleRecipes;
    void create() => unawaited(CreateRecipePage.show(context));

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.recipesTitle),
        actions: [
          AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.recipesAdd,
            onPressed: create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: AppSearchField(
              clearLabel: l10n.clearSearch,
              key: const Key('Recipes.filter'),
              hint: l10n.recipesFilter,
              onChanged: cubit.filterChanged,
            ),
          ),
          Expanded(
            child: switch (state.recipes) {
              null => AppLoadingView(label: l10n.launchLoading),
              _ when recipes.isNotEmpty => ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  AppSection(
                    header: state.filter.isEmpty ? l10n.recipesCustom : null,
                    children: [
                      for (final recipe in recipes)
                        AppListRowButton(
                          title: recipe.name,
                          subtitle: recipe.description,
                          thumbnail: state.showImage
                              ? StoredThumbnail(recipe.imageUrl)
                              : null,
                          onPressed: () =>
                              unawaited(RecipeDetailPage.show(context, recipe)),
                        ),
                    ],
                  ),
                ],
              ),
              _ when state.filter.isNotEmpty => AppEmptyState(
                icon: AppSymbols.search,
                title: l10n.recipesNoResults(state.filter),
              ),
              _ => AppEmptyState(
                icon: AppSymbols.recipe,
                title: l10n.recipesEmptyTitle,
                description: l10n.recipesEmptyMessage,
                actionLabel: l10n.recipesCreate,
                onAction: create,
              ),
            },
          ),
        ],
      ),
    );
  }
}
