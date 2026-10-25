import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/recipes/cubit/recipe_detail_cubit.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// A recipe from the library (Swift `RecipeDetailView`): a stepper that
/// scales its nutrition and ingredients, a favourite toggle, Start, and
/// Delete for its author. Read by its id, so it stays current.
class RecipeDetailPage extends StatelessWidget {
  const new({required this.recipeId, super.key});

  static const path = ':$idParameter';
  static const name = 'recipeDetail';
  static const idParameter = 'recipeId';

  /// Opens [recipe].
  static Future<void> show(BuildContext context, RecipeTemplateModel recipe) =>
      context.pushNamed<void>(
        name,
        pathParameters: {idParameter: recipe.recipeId},
      );

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => RecipeDetailCubit(
        uid: app.user.uid,
        recipeId: recipeId,
        foods: context.read<FoodRepository>(),
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const RecipeDetailView(),
    );
  }
}

class RecipeDetailView extends StatelessWidget {
  const new({super.key});

  Future<void> _delete(BuildContext context, RecipeTemplateModel recipe) async {
    final l10n = context.l10n;
    final cubit = context.read<RecipeDetailCubit>();
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.recipeDetailDeleteTitle,
      message: l10n.recipeDetailDeleteMessage(recipe.name),
      confirmLabel: l10n.recipeDetailDeleteConfirm,
    );
    if (confirmed) await cubit.deleteConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RecipeDetailCubit>();
    final state = context.watch<RecipeDetailCubit>().state;
    final recipe = state.recipe;
    return MultiBlocListener(
      listeners: [
        BlocListener<RecipeDetailCubit, RecipeDetailState>(
          listenWhen: (previous, current) =>
              previous.deleteStatus != current.deleteStatus,
          listener: (context, state) {
            if (state.deleteStatus == RecipeDetailDeleteStatus.deleted) {
              unawaited(AppHaptics.success());
              context.pop();
            }
          },
        ),
        BlocListener<RecipeDetailCubit, RecipeDetailState>(
          listenWhen: (previous, current) =>
              current.deleteFailures > previous.deleteFailures,
          listener: (context, _) {
            unawaited(AppHaptics.error());
            unawaited(
              showFailureAlert(
                context,
                l10n.recipeDetailDeleteFailed,
                l10n.recipeDetailDeleteTryLater,
              ),
            );
          },
        ),
        BlocListener<RecipeDetailCubit, RecipeDetailState>(
          listenWhen: (previous, current) =>
              current.favouriteFailures > previous.favouriteFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(context, l10n.recipeDetailFavouriteFailed),
          ),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(recipe?.name ?? ''),
          actions: [
            if (recipe != null)
              AppToolbarButton(
                icon: state.isFavourited
                    ? AppSymbols.heartFilled
                    : AppSymbols.heart,
                semanticLabel: state.isFavourited
                    ? l10n.recipeDetailRemoveFavourite
                    : l10n.recipeDetailAddFavourite,
                onPressed: () => unawaited(cubit.favouriteToggled()),
              ),
            if (recipe != null && cubit.canDelete)
              PopupMenuButton<VoidCallback>(
                icon: Icon(AppSymbols.more),
                onSelected: (action) => action(),
                tooltip: l10n.recipeDetailOptions,
                enabled: state.deleteStatus == RecipeDetailDeleteStatus.idle,
                itemBuilder: (_) => [
                  AppMenuItem(
                    value: () => unawaited(_delete(context, recipe)),
                    icon: AppSymbols.delete,
                    label: l10n.recipeDetailDelete,
                    isDestructive: true,
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: recipe == null
            ? null
            : AppBottomCta(
                children: [
                  AppCtaButton(
                    label: l10n.recipeDetailStart,
                    onPressed: () =>
                        unawaited(RecipeStartPage.show(context, recipe)),
                  ),
                ],
              ),
        body: switch (recipe) {
          _ when !state.loaded => AppLoadingView(label: l10n.launchLoading),
          null => AppEmptyState(
            icon: AppSymbols.recipe,
            title: l10n.recipeDetailNotFound,
          ),
          final recipe => _Details(recipe: recipe, state: state),
        },
      ),
    );
  }
}

/// The servings, their nutrition and the scaled ingredients.
class _Details extends StatelessWidget {
  const new({required this.recipe, required this.state});

  final RecipeTemplateModel recipe;
  final RecipeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RecipeDetailCubit>();
    final servings = state.servings;
    final nutrients = state.scaledNutrients.values;
    final description = recipe.description;
    String figure(NutrientKey key, String unit) {
      final value = nutrients[key];
      return value == null
          ? AppFormat.placeholder
          : unit == 'kcal'
          ? AppFormat.kcal(value.round())
          : AppFormat.grams(value);
    }

    void step(double to) {
      unawaited(AppHaptics.selection());
      cubit.servingsChanged(to);
    }

    String servingsLabel(double value) => l10n.recipeDetailServingCount(
      AppFormat.number(value, maxFractionDigits: 1),
      value,
    );
    final servingsText = servingsLabel(servings);
    final canDecrease = servings > minimumServings;
    final canIncrease = servings < maximumServings;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        if (recipe.imageUrl case final url?) ...[
          StoredHeroImage(url),
          const SizedBox(height: AppSpacing.l),
        ],
        if (description != null && description.isNotEmpty) ...[
          Text(description, style: AppTextStyles.rowDetail.secondary(context)),
          const SizedBox(height: AppSpacing.l),
        ],
        AppSection(
          header: l10n.recipeDetailServings,
          children: [
            Semantics(
              label: l10n.recipeDetailServings,
              value: servingsText,
              increasedValue: canIncrease
                  ? servingsLabel(servings + servingsStep)
                  : null,
              decreasedValue: canDecrease
                  ? servingsLabel(servings - servingsStep)
                  : null,
              onIncrease: canIncrease
                  ? () => step(servings + servingsStep)
                  : null,
              onDecrease: canDecrease
                  ? () => step(servings - servingsStep)
                  : null,
              child: ExcludeSemantics(
                child: AppListRow(
                  title: servingsText,
                  accessory: AppListRowCustom(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.xs,
                      children: [
                        AppIconButton(
                          key: const Key('RecipeDetail.decrease'),
                          icon: AppSymbols.decrease,
                          semanticLabel: l10n.editorDecrease,
                          onPressed: canDecrease
                              ? () => step(servings - servingsStep)
                              : null,
                        ),
                        AppIconButton(
                          key: const Key('RecipeDetail.increase'),
                          icon: AppSymbols.add,
                          semanticLabel: l10n.editorIncrease,
                          onPressed: canIncrease
                              ? () => step(servings + servingsStep)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AppListRow(
              title: l10n.recipeDetailCalories,
              accessory: AppListRowValue(figure(NutrientKey.calories, 'kcal')),
            ),
            AppListRow(
              title: l10n.nutritionMacroProtein,
              accessory: AppListRowValue(figure(NutrientKey.protein, 'g')),
            ),
            AppListRow(
              title: l10n.nutritionMacroCarbs,
              accessory: AppListRowValue(figure(NutrientKey.carbs, 'g')),
            ),
            AppListRow(
              title: l10n.nutritionMacroFat,
              accessory: AppListRowValue(figure(NutrientKey.fatTotal, 'g')),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.recipeDetailIngredients,
          children: [
            for (final ingredient in recipe.ingredients)
              AppListRow(
                title: ingredient.name,
                subtitle: switch (ingredient.ingredient.description) {
                  final text? when text.isNotEmpty => text,
                  _ => null,
                },
                accessory: AppListRowValue(
                  _amount(state.scaledAmount(ingredient), ingredient.unit),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Making a recipe (Swift `RecipeStartView`): its ingredients and how much
/// of each, as written.
class RecipeStartPage extends StatefulWidget {
  const new({required this.recipe, super.key});

  static const path = 'start';
  static const name = 'recipeStart';

  /// Opens [recipe]'s start page.
  static Future<void> show(BuildContext context, RecipeTemplateModel recipe) =>
      context.pushNamed<void>(
        name,
        pathParameters: {RecipeDetailPage.idParameter: recipe.recipeId},
        extra: recipe,
      );

  final RecipeTemplateModel recipe;

  @override
  State<RecipeStartPage> createState() => _RecipeStartPageState();
}

class _RecipeStartPageState extends State<RecipeStartPage> {
  late final AnalyticsRepository _analytics = context
      .read<AnalyticsRepository>();

  @override
  void initState() {
    super.initState();
    _analytics.appear('RecipeStartView');
  }

  @override
  void dispose() {
    _analytics.disappear('RecipeStartView');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipe = widget.recipe;
    return AppScaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: l10n.recipeDetailIngredients,
            children: [
              for (final ingredient in recipe.ingredients)
                AppListRow(
                  title: ingredient.name,
                  accessory: AppListRowValue(
                    _amount(ingredient.amount, ingredient.unit),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An ingredient's amount and unit, to one decimal place.
String _amount(double amount, IngredientAmountUnit unit) =>
    '${AppFormat.number(amount, maxFractionDigits: 1)} ${unitLabel(unit)}';
