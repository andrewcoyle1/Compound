import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/foods/cubit/foods_cubit.dart';
import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/recipes/cubit/create_recipe_cubit.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Creating a recipe (Swift `CreateRecipeView`, then
/// `RecipePreparationView`, pushed with the same cubit). Over the tabs, as
/// the Swift app's full-screen cover.
class CreateRecipePage extends StatelessWidget {
  const new({super.key});

  static const path = '/create-recipe';
  static const name = 'createRecipe';

  /// Opens the flow.
  static Future<void> show(BuildContext context) =>
      context.pushNamed<void>(name);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    return BlocProvider(
      create: (context) => CreateRecipeCubit(
        uid: app is AppAuthenticated ? app.user.uid : null,
        foods: context.read<FoodRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
      ),
      child: const CreateRecipeView(),
    );
  }
}

/// Logs a step appearing and going, under its Swift view's name.
mixin _TrackedStep<T extends StatefulWidget> on State<T> {
  String get screen;
  late final CreateRecipeCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = context.read<CreateRecipeCubit>()..appeared(screen);
  }

  @override
  void dispose() {
    cubit.disappeared(screen);
    super.dispose();
  }
}

/// Pushes [page] over the flow, sharing its cubit.
Future<void> _push(
  BuildContext context,
  Widget page, {
  bool fullscreenDialog = false,
}) {
  final cubit = context.read<CreateRecipeCubit>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => BlocProvider.value(value: cubit, child: page),
    ),
  );
}

InputDecoration _plain(String hint, {String? helper}) => InputDecoration(
  hintText: hint,
  helperText: helper,
  border: InputBorder.none,
  filled: false,
);

/// The name, servings, weight and ingredients.
class CreateRecipeView extends StatefulWidget {
  const new({super.key});

  @override
  State<CreateRecipeView> createState() => _CreateRecipeViewState();
}

class _CreateRecipeViewState extends State<CreateRecipeView>
    with _TrackedStep<CreateRecipeView> {
  @override
  String get screen => 'CreateRecipeView';

  /// Closing asks first when there is something to lose
  /// (`CreateRecipePresenter.onDismissPressed`).
  Future<void> _close() async {
    if (cubit.state.hasUnsavedChanges) {
      final l10n = context.l10n;
      final discard = await confirmDestructive(
        context,
        title: l10n.createRecipeDiscardTitle,
        confirmLabel: l10n.createRecipeDiscard,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateRecipeCubit>().state;
    final weight = state.ingredientsWeight;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return PopScope(
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppSymbols.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _close,
          ),
          title: Text(l10n.createRecipeTitle),
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.createRecipeName,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('CreateRecipe.name'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: _plain(
                      l10n.createRecipeNamePrompt,
                      helper: l10n.createRecipeRequired,
                    ),
                    onChanged: cubit.nameChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.createRecipeServings,
              footer: l10n.createRecipeRequired,
              children: [
                AppNumberField(
                  key: const Key('CreateRecipe.servings'),
                  value: state.servings,
                  prompt: l10n.createRecipeServingsPrompt,
                  onChanged: cubit.servingsChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.createRecipeTotalWeight,
              children: [
                AppNumberField(
                  key: const Key('CreateRecipe.totalWeight'),
                  value: state.totalWeight,
                  prompt: l10n.createRecipeTotalWeightPrompt,
                  unit: 'g',
                  onChanged: cubit.totalWeightChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.createRecipeIngredients,
                          style: AppTextStyles.label.copyWith(color: secondary),
                        ),
                      ),
                      if (weight != null)
                        Text(
                          l10n.createRecipeIngredientsWeight(
                            AppFormat.grams(weight),
                          ),
                          style: AppTextStyles.label.copyWith(color: secondary),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('CreateRecipe.addIngredient'),
                  icon: const Icon(AppSymbols.add),
                  tooltip: l10n.createRecipeAddIngredient,
                  onPressed: () => unawaited(
                    _push(
                      context,
                      const IngredientPickerPage(),
                      fullscreenDialog: true,
                    ),
                  ),
                ),
              ],
            ),
            if (state.ingredients.isNotEmpty)
              AppSection(
                children: [
                  for (final (index, ingredient) in state.ingredients.indexed)
                    _IngredientRow(
                      key: ValueKey(ingredient.id),
                      index: index,
                      ingredient: ingredient,
                    ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.createRecipeNext,
              onPressed: state.canContinue
                  ? () =>
                        unawaited(_push(context, const RecipePreparationView()))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// An ingredient in the list: its amount and unit editable in place, and a
/// swipe, or a screen reader's action, to remove it.
class _IngredientRow extends StatelessWidget {
  const new({required this.index, required this.ingredient, super.key});

  final int index;
  final RecipeIngredientModel ingredient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CreateRecipeCubit>();
    final remove = l10n.createRecipeRemoveIngredient(ingredient.name);
    String label(IngredientAmountUnit unit) => switch (unit) {
      IngredientAmountUnit.units => l10n.createRecipeUnits,
      _ => unitLabel(unit),
    };
    return AppSwipeActions(
      trailing: [
        AppSwipeAction(
          label: remove,
          icon: AppSymbols.delete,
          isDestructive: true,
          onPressed: () => cubit.ingredientRemoved(index),
        ),
      ],
      child: Row(
        children: [
          Expanded(
            child: AppListRow(
              title: ingredient.name,
              subtitle: ingredient.ingredient.description,
              thumbnail: StoredThumbnail(ingredient.ingredient.imageUrl),
            ),
          ),
          SizedBox(
            width: 120,
            child: AppNumberField(
              key: Key('CreateRecipe.amount.${ingredient.id}'),
              value: ingredient.amount,
              prompt: l10n.createRecipeAmount,
              onChanged: (amount) =>
                  cubit.ingredientAmountChanged(index, amount),
            ),
          ),
          DropdownButton<IngredientAmountUnit>(
            key: Key('CreateRecipe.unit.${ingredient.id}'),
            value: ingredient.unit,
            underline: const SizedBox.shrink(),
            items: [
              for (final unit in IngredientAmountUnit.values)
                DropdownMenuItem(value: unit, child: Text(label(unit))),
            ],
            onChanged: (unit) {
              if (unit != null) cubit.ingredientUnitChanged(index, unit);
            },
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
    );
  }
}

/// Choosing a recipe's ingredients from the library (Swift
/// `IngredientListBuilderView` with a recipe callback): a food's row opens
/// its amount, its + adds its portion, and either replaces a food already
/// in the recipe. Stays open to add the next.
class IngredientPickerPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => FoodsCubit(
        uid: app.user.uid,
        foods: context.read<FoodRepository>(),
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        screen: 'IngredientsView',
      ),
      child: const _IngredientPickerView(),
    );
  }
}

class _IngredientPickerView extends StatelessWidget {
  const new();

  Future<void> _amount(BuildContext context, FoodModel food) async {
    final recipe = context.read<CreateRecipeCubit>();
    context.read<FoodsCubit>().foodSelected(food);
    final ingredient = await showRecipeIngredientAmountSheet(context, food);
    if (ingredient == null) return;
    unawaited(HapticFeedback.successNotification());
    recipe.ingredientConfirmed(ingredient);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final foodsCubit = context.read<FoodsCubit>();
    final state = context.watch<FoodsCubit>().state;
    final chosen = {
      for (final ingredient
          in context.watch<CreateRecipeCubit>().state.ingredients)
        ingredient.id,
    };
    final foods = state.visibleFoods;
    void create() {
      foodsCubit.addPressed();
      unawaited(CreateFoodPage.show(context));
    }

    return AppScaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(l10n.createRecipeAddIngredient),
        actions: [
          IconButton(
            icon: const Icon(AppSymbols.add),
            tooltip: l10n.foodsCreate,
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
              hint: l10n.foodsFilter,
              onChanged: foodsCubit.filterChanged,
            ),
          ),
          Expanded(
            child: switch (state.foods) {
              null => const Center(child: CircularProgressIndicator.adaptive()),
              _ when foods.isNotEmpty => ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  AppSection(
                    header: state.filter.isEmpty ? l10n.foodsCustomFoods : null,
                    children: [
                      for (final food in foods)
                        _PickerRow(
                          food: food,
                          chosen: chosen.contains(food.ingredientId),
                          onPressed: () => unawaited(_amount(context, food)),
                          onAdd: () {
                            foodsCubit.foodSelected(food, method: 'quickAdd');
                            context
                                .read<CreateRecipeCubit>()
                                .ingredientConfirmed(quickAddIngredient(food));
                          },
                        ),
                    ],
                  ),
                ],
              ),
              _ when state.filter.isNotEmpty => LibraryEmptyState(
                icon: AppSymbols.search,
                title: l10n.foodsNoResults(state.filter),
              ),
              _ => SingleChildScrollView(
                child: Column(
                  children: [
                    LibraryEmptyState(
                      icon: AppSymbols.food,
                      title: l10n.foodsEmptyTitle,
                      message: l10n.foodsEmptyMessage,
                    ),
                    FilledButton(
                      onPressed: create,
                      child: Text(l10n.foodsCreate),
                    ),
                  ],
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// A food in the ingredient picker: a tap for its amount, and a + for its
/// portion that becomes a check once the food is in the recipe.
class _PickerRow extends StatelessWidget {
  const new({
    required this.food,
    required this.chosen,
    required this.onPressed,
    required this.onAdd,
  });

  final FoodModel food;
  final bool chosen;
  final VoidCallback onPressed;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calories =
        (food.nutrients.values[NutrientKey.calories] ?? 0) *
        food.rowNutrientScale;
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Expanded(
            child: AppListRow(
              title: food.name,
              subtitle: [
                ?food.brandName,
                AppFormat.kcal(calories.round()),
              ].join(' · '),
              thumbnail:
                  context.select<FoodsCubit, bool>(
                    (cubit) => cubit.state.showFoodImage,
                  )
                  ? StoredThumbnail(food.imageUrl)
                  : null,
            ),
          ),
          IconButton(
            icon: Icon(chosen ? AppSymbols.selected : AppSymbols.add),
            tooltip: l10n.addMealQuickAddFood(food.name),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// The timing, link and method, then Create (Swift
/// `RecipePreparationView`).
class RecipePreparationView extends StatefulWidget {
  const new({super.key});

  @override
  State<RecipePreparationView> createState() => _RecipePreparationViewState();
}

class _RecipePreparationViewState extends State<RecipePreparationView>
    with _TrackedStep<RecipePreparationView> {
  @override
  String get screen => 'RecipePreparationView';

  /// A key per step, kept in step with the cubit's list, so a field keeps
  /// its text when the steps around it move or go.
  final _keys = <int>[0];
  var _nextKey = 1;

  void _add() {
    _keys.add(_nextKey++);
    cubit.stepAdded();
  }

  void _remove(int index) {
    _keys.removeAt(index);
    cubit.stepRemoved(index);
  }

  void _move(int from, int to) {
    _keys.insert(to, _keys.removeAt(from));
    cubit.stepMoved(from, to);
  }

  Future<void> _done(CreateRecipeState state) async {
    if (state.status == CreateRecipeStatus.created) {
      unawaited(HapticFeedback.successNotification());
      // Every step of the flow, its first included.
      Navigator.of(context)
        ..popUntil(
          (route) =>
              route.settings.name == CreateRecipePage.name || route.isFirst,
        )
        ..pop();
      return;
    }
    unawaited(HapticFeedback.errorNotification());
    final l10n = context.l10n;
    await showFailureAlert(
      context,
      l10n.recipePreparationFailed,
      l10n.recipePreparationFailedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateRecipeCubit>().state;
    return BlocListener<CreateRecipeCubit, CreateRecipeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == CreateRecipeStatus.created ||
              current.status == CreateRecipeStatus.failed),
      listener: (_, state) => unawaited(_done(state)),
      child: AppScaffold(
        appBar: AppBar(title: Text(capitalizedName(state.name))),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.recipePreparationTiming,
              children: [
                AppNumberField(
                  key: const Key('RecipePreparation.prepTime'),
                  label: l10n.recipePreparationPrepTime,
                  prompt: l10n.recipePreparationPrepTimePrompt,
                  unit: l10n.recipePreparationMinutes,
                  value: state.prepTime,
                  onChanged: cubit.prepTimeChanged,
                ),
                AppNumberField(
                  key: const Key('RecipePreparation.cookTime'),
                  label: l10n.recipePreparationCookTime,
                  prompt: l10n.recipePreparationCookTimePrompt,
                  unit: l10n.recipePreparationMinutes,
                  value: state.cookTime,
                  onChanged: cubit.cookTimeChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.recipePreparationLink,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('RecipePreparation.link'),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: _plain(l10n.recipePreparationLinkPrompt),
                    onChanged: cubit.sourceUrlChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.recipePreparationSteps,
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: _move,
                  children: [
                    for (final (index, step) in state.steps.indexed)
                      Row(
                        key: ValueKey(_keys[index]),
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(AppSpacing.m),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              key: Key('RecipePreparation.step.$index'),
                              initialValue: step,
                              minLines: 2,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: _plain(
                                l10n.recipePreparationStep(index + 1),
                              ),
                              onChanged: (text) =>
                                  cubit.stepChanged(index, text),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(AppSymbols.decrease),
                            tooltip: l10n.recipePreparationRemoveStep(
                              index + 1,
                            ),
                            onPressed: () => _remove(index),
                          ),
                        ],
                      ),
                  ],
                ),
                AppListRowButton(
                  key: const Key('RecipePreparation.addStep'),
                  title: l10n.recipePreparationAddStep,
                  icon: AppSymbols.add,
                  accessory: null,
                  onPressed: _add,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.recipePreparationPhoto,
              children: [
                if (state.photo case final photo?)
                  Semantics(
                    button: true,
                    label: l10n.recipePreparationSelectPhoto,
                    excludeSemantics: true,
                    child: InkWell(
                      key: const Key('RecipePreparation.photo'),
                      onTap: () => unawaited(cubit.photoPressed()),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          child: SizedBox(
                            height: AppChartHeight.compact,
                            width: double.infinity,
                            child: Image.memory(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  AppListRowButton(
                    key: const Key('RecipePreparation.photo'),
                    title: l10n.recipePreparationSelectPhoto,
                    icon: AppSymbols.photoLibrary,
                    accessory: null,
                    onPressed: () => unawaited(cubit.photoPressed()),
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.recipePreparationCreate,
              isLoading: state.isSaving,
              onPressed: () => unawaited(cubit.create()),
            ),
          ],
        ),
      ),
    );
  }
}
