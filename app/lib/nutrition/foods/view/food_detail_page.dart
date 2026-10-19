import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/foods/cubit/food_detail_cubit.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// A food from the library (Swift `FoodDetailView`): its nutrients per
/// 100 g, when it was made, a favourite toggle, and Delete for its author.
/// Under Foods; the food is read by its id, so it stays current.
class FoodDetailPage extends StatelessWidget {
  const new({required this.foodId, super.key});

  static const path = ':$idParameter';
  static const name = 'foodDetail';
  static const idParameter = 'foodId';

  /// Opens [food].
  static Future<void> show(BuildContext context, FoodModel food) => context
      .pushNamed<void>(name, pathParameters: {idParameter: food.ingredientId});

  final String foodId;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => FoodDetailCubit(
        uid: app.user.uid,
        foodId: foodId,
        foods: context.read<FoodRepository>(),
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const FoodDetailView(),
    );
  }
}

class FoodDetailView extends StatelessWidget {
  const new({super.key});

  Future<void> _delete(BuildContext context, FoodModel food) async {
    final l10n = context.l10n;
    final cubit = context.read<FoodDetailCubit>();
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.foodDetailDelete,
      message: l10n.foodDetailDeleteMessage(food.name),
      confirmLabel: l10n.foodDetailDeleteConfirm,
    );
    if (confirmed) await cubit.deleteConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FoodDetailCubit>();
    final state = context.watch<FoodDetailCubit>().state;
    final food = state.food;
    return MultiBlocListener(
      listeners: [
        BlocListener<FoodDetailCubit, FoodDetailState>(
          listenWhen: (previous, current) =>
              previous.deleteStatus != current.deleteStatus &&
              current.deleteStatus == FoodDetailDeleteStatus.deleted,
          listener: (context, _) => context.pop(),
        ),
        BlocListener<FoodDetailCubit, FoodDetailState>(
          listenWhen: (previous, current) =>
              current.deleteFailures > previous.deleteFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(
              context,
              l10n.foodDetailDeleteFailed,
              l10n.foodDetailDeleteFailedMessage,
            ),
          ),
        ),
        BlocListener<FoodDetailCubit, FoodDetailState>(
          listenWhen: (previous, current) =>
              current.favouriteFailures > previous.favouriteFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(context, l10n.foodDetailFavoriteFailed),
          ),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(food?.name ?? ''),
          actions: [
            if (food != null)
              AppToolbarButton(
                icon: state.isFavourited
                    ? AppSymbols.heartFilled
                    : AppSymbols.heart,
                semanticLabel: state.isFavourited
                    ? l10n.foodDetailRemoveFavorite
                    : l10n.foodDetailAddFavorite,
                onPressed: () => unawaited(cubit.favouriteToggled()),
              ),
            if (food != null && cubit.canDelete)
              PopupMenuButton<VoidCallback>(
                icon: Icon(AppSymbols.more),
                onSelected: (action) => action(),
                tooltip: l10n.foodDetailOptions,
                enabled: state.deleteStatus == FoodDetailDeleteStatus.idle,
                itemBuilder: (_) => [
                  AppMenuItem(
                    value: () => unawaited(_delete(context, food)),
                    icon: AppSymbols.delete,
                    label: l10n.foodDetailDelete,
                    isDestructive: true,
                  ),
                ],
              ),
          ],
        ),
        body: switch (food) {
          _ when !state.loaded => AppLoadingView(label: l10n.launchLoading),
          null => AppEmptyState(
            icon: AppSymbols.food,
            title: l10n.foodDetailMissing,
          ),
          final food => _Nutrients(food: food),
        },
      ),
    );
  }
}

/// The food's sections (Swift `FoodDetailView`'s), in its order.
class _Nutrients extends StatelessWidget {
  const new({required this.food});

  final FoodModel food;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final values = food.nutrients.values;
    final description = food.description;
    Widget row(String label, NutrientKey key, String unit) {
      final value = values[key];
      return AppListRow(
        title: label,
        accessory: AppListRowValue(
          value == null
              ? AppFormat.placeholder
              : unit == 'kcal'
              ? AppFormat.kcal(value, locale: locale)
              : AppFormat.nutrient(value, unit: unit, locale: locale),
        ),
      );
    }

    bool has(List<NutrientKey> keys) => keys.any(values.containsKey);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        if (food.imageUrl case final url?) ...[
          StoredHeroImage(url),
          const SizedBox(height: AppSpacing.l),
        ],
        if (description != null && description.isNotEmpty) ...[
          Text(description, style: AppTextStyles.rowDetail),
          const SizedBox(height: AppSpacing.l),
        ],
        AppSection(
          header: l10n.foodDetailNutrition,
          children: [
            row(l10n.foodDetailCalories, NutrientKey.calories, 'kcal'),
            row(l10n.foodDetailProtein, NutrientKey.protein, 'g'),
            row(l10n.foodDetailCarbohydrates, NutrientKey.carbs, 'g'),
            row(l10n.foodDetailTotalFat, NutrientKey.fatTotal, 'g'),
            if (has(const [
              NutrientKey.fatSaturated,
              NutrientKey.fatMonounsaturated,
              NutrientKey.fatPolyunsaturated,
            ])) ...[
              row(l10n.foodDetailSaturatedFat, NutrientKey.fatSaturated, 'g'),
              row(
                l10n.foodDetailMonounsaturatedFat,
                NutrientKey.fatMonounsaturated,
                'g',
              ),
              row(
                l10n.foodDetailPolyunsaturatedFat,
                NutrientKey.fatPolyunsaturated,
                'g',
              ),
            ],
            if (has(const [NutrientKey.fiber, NutrientKey.sugar])) ...[
              row(l10n.foodDetailDietaryFiber, NutrientKey.fiber, 'g'),
              row(l10n.foodDetailTotalSugars, NutrientKey.sugar, 'g'),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailMacrominerals,
          children: [
            row(l10n.foodDetailCalcium, NutrientKey.calciumMg, 'mg'),
            row(l10n.foodDetailPhosphorus, NutrientKey.phosphorusMg, 'mg'),
            row(l10n.foodDetailMagnesium, NutrientKey.magnesiumMg, 'mg'),
            row(l10n.foodDetailSodium, NutrientKey.sodiumMg, 'mg'),
            row(l10n.foodDetailPotassium, NutrientKey.potassiumMg, 'mg'),
            row(l10n.foodDetailChloride, NutrientKey.chlorideMg, 'mg'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailTraceMinerals,
          children: [
            row(l10n.foodDetailIron, NutrientKey.ironMg, 'mg'),
            row(l10n.foodDetailZinc, NutrientKey.zincMg, 'mg'),
            row(l10n.foodDetailCopper, NutrientKey.copperMg, 'mg'),
            row(l10n.foodDetailManganese, NutrientKey.manganeseMg, 'mg'),
            row(l10n.foodDetailIodine, NutrientKey.iodineMcg, 'μg'),
            row(l10n.foodDetailSelenium, NutrientKey.seleniumMcg, 'μg'),
            row(l10n.foodDetailMolybdenum, NutrientKey.molybdenumMcg, 'μg'),
            row(l10n.foodDetailChromium, NutrientKey.chromiumMcg, 'μg'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailFatSoluble,
          children: [
            row(l10n.foodDetailVitaminA, NutrientKey.vitaminAMcg, 'mcg RAE'),
            row(l10n.foodDetailVitaminD, NutrientKey.vitaminDMcg, 'mcg'),
            row(
              l10n.foodDetailVitaminE,
              NutrientKey.vitaminEMg,
              'mg α-tocopherol',
            ),
            row(l10n.foodDetailVitaminK, NutrientKey.vitaminKMcg, 'mcg'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailWaterSoluble,
          children: [
            row(l10n.foodDetailThiamin, NutrientKey.thiaminMg, 'mg'),
            row(l10n.foodDetailRiboflavin, NutrientKey.riboflavinMg, 'mg'),
            row(l10n.foodDetailNiacin, NutrientKey.niacinMg, 'mg NE'),
            row(
              l10n.foodDetailPantothenicAcid,
              NutrientKey.pantothenicAcidMg,
              'mg',
            ),
            row(l10n.foodDetailVitaminB6, NutrientKey.vitaminB6Mg, 'mg'),
            row(l10n.foodDetailFolate, NutrientKey.folateMcg, 'mcg DFE'),
            row(l10n.foodDetailVitaminB12, NutrientKey.vitaminB12Mcg, 'mcg'),
            row(l10n.foodDetailBiotin, NutrientKey.biotinMcg, 'mcg'),
            row(l10n.foodDetailVitaminC, NutrientKey.vitaminCMg, 'mg'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailBioactive,
          children: [
            row(l10n.foodDetailCholesterol, NutrientKey.cholesterolMg, 'mg'),
            row(l10n.foodDetailCaffeine, NutrientKey.caffeineMg, 'mg'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.foodDetailDateCreated,
          children: [
            AppListRow(
              title: AppFormat.date(
                food.dateCreated.toLocal(),
                locale: context.dateLocale,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
