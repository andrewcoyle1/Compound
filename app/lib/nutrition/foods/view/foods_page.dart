import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/foods/cubit/foods_cubit.dart';
import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The user's foods (Swift `FoodsView`, with the `IngredientListBuilderView`
/// it embeds): filter, open one, or create one. Under the Nutrition tab.
class FoodsPage extends StatelessWidget {
  const new({super.key});

  static const path = 'foods';
  static const name = 'foods';

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => FoodsCubit(
        uid: app.user.uid,
        foods: context.read<FoodRepository>(),
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const FoodsView(),
    );
  }
}

class FoodsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FoodsCubit>();
    final state = context.watch<FoodsCubit>().state;
    final foods = state.visibleFoods;
    void create() {
      cubit.addPressed();
      unawaited(CreateFoodPage.show(context));
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.foodsTitle),
        actions: [
          AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.foodsAdd,
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
              key: const Key('Foods.filter'),
              hint: l10n.foodsFilter,
              clearLabel: l10n.clearSearch,
              onChanged: cubit.filterChanged,
            ),
          ),
          Expanded(
            child: switch (state.foods) {
              null => AppLoadingView(label: l10n.launchLoading),
              _ when foods.isNotEmpty => ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  AppSection(
                    header: state.filter.isEmpty ? l10n.foodsCustomFoods : null,
                    children: [
                      for (final food in foods)
                        AppListRowButton(
                          title: food.name,
                          subtitle: [
                            ?food.brandName,
                            AppFormat.kcal(
                              (food.nutrients.values[NutrientKey.calories] ?? 0)
                                  .round(),
                            ),
                          ].join(' · '),
                          thumbnail: state.showFoodImage
                              ? StoredThumbnail(food.imageUrl)
                              : null,
                          onPressed: () {
                            cubit.foodSelected(food);
                            unawaited(FoodDetailPage.show(context, food));
                          },
                        ),
                    ],
                  ),
                ],
              ),
              _ when state.filter.isNotEmpty => AppEmptyState(
                icon: AppSymbols.search,
                title: l10n.foodsNoResults(state.filter),
              ),
              _ => AppEmptyState(
                icon: AppSymbols.food,
                title: l10n.foodsEmptyTitle,
                description: l10n.foodsEmptyMessage,
                actionLabel: l10n.foodsCreate,
                onAction: create,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Opens Foods from the Nutrition tab.
Future<void> showFoods(BuildContext context) =>
    context.pushNamed<void>(FoodsPage.name);
