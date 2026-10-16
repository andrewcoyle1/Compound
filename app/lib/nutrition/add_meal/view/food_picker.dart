import 'dart:async';

import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/bloc/add_meal_bloc.dart';
import 'package:compound/nutrition/add_meal/bloc/food_search_bloc.dart';
import 'package:compound/nutrition/add_meal/cubit/barcode_scanner_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/label_scanner_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/meal_describe_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/quick_add_cubit.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/add_meal/view/barcode_camera.dart';
import 'package:compound/nutrition/foods/logic/create_food.dart';
import 'package:compound/nutrition/foods/view/create_food_pages.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/recipes/logic/recipe_logic.dart';
import 'package:compound/nutrition/recipes/view/create_recipe_pages.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart'
    show FoodLogSettings;

part 'ai_food_tabs.dart';
part 'label_panel.dart';

/// The food picker over the plate (Swift `NutritionLibraryPickerView`):
/// a tab per way of finding food, picks landing on the plate as they are
/// made, and Log pinned to the bottom once anything is on it.
class FoodPickerView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AddMealBloc>();
    final state = context.watch<AddMealBloc>().state;
    final count = state.meal.items.length;
    return Scaffold(
      appBar: AppBar(
        // Picks land on the plate as they are made, so there is nothing to
        // cancel: close goes back to the plate.
        leading: CloseButton(
          onPressed: () => bloc.add(const AddMealPickerClosed()),
        ),
        title: Column(
          children: [
            Text(l10n.addMealPickerTitle),
            Text(
              l10n.addMealOnPlate(count),
              style: AppTextStyles.label.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppControlSize.row),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Row(
              spacing: AppSpacing.s,
              children: [
                for (final mode in FoodPickerMode.values)
                  AppChip(
                    label: mode.title(l10n),
                    icon: mode.icon,
                    selected: mode == state.mode,
                    onPressed: () {
                      if (mode != state.mode) {
                        unawaited(HapticFeedback.selectionClick());
                      }
                      bloc.add(AddMealModeSelected(mode));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      body: switch (state.mode) {
        FoodPickerMode.search => const _SearchTab(),
        FoodPickerMode.quickAdd => const _QuickAddTab(),
        FoodPickerMode.barcode => const _BarcodeTab(),
        FoodPickerMode.library => const _LibraryTab(),
        FoodPickerMode.aiScanner => const _PhotoTab(),
        FoodPickerMode.describe => const _DescribeTab(),
      },
      // Quick add has its own Log beside Add to Plate.
      bottomNavigationBar: state.mode == FoodPickerMode.quickAdd || count == 0
          ? null
          : AppBottomCta(
              children: [
                AppCtaButton(
                  label: l10n.addMealLog,
                  isLoading: state.status == AddMealStatus.saving,
                  onPressed: () => bloc.add(const AddMealSaveRequested()),
                ),
              ],
            ),
    );
  }
}

extension on FoodPickerMode {
  String title(AppLocalizations l10n) => switch (this) {
    FoodPickerMode.barcode => l10n.addMealModeBarcode,
    FoodPickerMode.search => l10n.addMealModeSearch,
    FoodPickerMode.quickAdd => l10n.addMealModeQuickAdd,
    FoodPickerMode.library => l10n.addMealModeLibrary,
    FoodPickerMode.aiScanner => l10n.addMealModeAi,
    FoodPickerMode.describe => l10n.addMealModeDescribe,
  };

  IconData get icon => switch (this) {
    FoodPickerMode.barcode => AppSymbols.barcode,
    FoodPickerMode.search => AppSymbols.search,
    FoodPickerMode.quickAdd => AppSymbols.calories,
    FoodPickerMode.library => AppSymbols.library,
    FoodPickerMode.aiScanner => AppSymbols.camera,
    FoodPickerMode.describe => AppSymbols.describe,
  };
}

/// A row's tap (`NutritionLibraryPickerPresenter.navToIngredientAmount`):
/// the amount sheet, unless the Quick Add setting asks for the one-tap add.
Future<void> pickFood(BuildContext context, FoodModel food) async {
  final bloc = context.read<AddMealBloc>();
  if (bloc.state.effectiveSettings.quickAddEnabled) {
    quickAddFood(context, food);
    return;
  }
  final result = await showFoodAmountSheet(context, food);
  if (result == null) return;
  unawaited(HapticFeedback.successNotification());
  bloc.add(AddMealItemAdded(result.item, food: food));
  if (result.log) bloc.add(const AddMealSaveRequested());
}

/// A row's +: straight onto the plate at the amount last logged.
void quickAddFood(BuildContext context, FoodModel food) {
  unawaited(HapticFeedback.successNotification());
  context.read<AddMealBloc>().add(AddMealFoodQuickAdded(food));
}

/// A food in the picker (Swift `FoodLibraryPickerRowView`): its name and
/// brand, its figures for one portion as the Logger settings ask, and a +
/// that adds that portion, which becomes a checkmark and count once on the
/// plate.
class FoodRow extends StatelessWidget {
  const new({required this.food, super.key});

  final FoodModel food;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AddMealBloc>().state;
    final settings = state.effectiveSettings;
    final count = addedCount(state.meal.items, food.ingredientId);
    final scale = food.rowNutrientScale;
    double per(NutrientKey key) => (food.nutrients.values[key] ?? 0) * scale;
    final portion = food.defaultPortion;
    final detail = [
      ?food.brandName,
      if (settings.showCaloriesInLogger)
        AppFormat.kcal(per(NutrientKey.calories).round()),
      if (settings.showMacrosInLogger) ...[
        l10n.nutritionItemProtein(AppFormat.grams(per(NutrientKey.protein))),
        l10n.nutritionItemFat(AppFormat.grams(per(NutrientKey.fatTotal))),
        l10n.nutritionItemCarbs(AppFormat.grams(per(NutrientKey.carbs))),
      ],
      if (settings.showPortionInLogger)
        [
          AppFormat.number(portion.amount, maxFractionDigits: 2),
          portion.unit?.name ?? food.loggedUnitLabel,
        ].join(' '),
    ].join(' · ');
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => unawaited(pickFood(context, food)),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.l),
        child: Row(
          children: [
            // `FoodLibraryPickerRowView`'s image, on the logger setting.
            if (settings.showFoodImageInLogger)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.m),
                child: RowThumbnail(food.imageUrl),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(food.name, style: AppTextStyles.rowTitle),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: AppTextStyles.rowDetail.copyWith(
                          color: secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (count > 0)
              Text(
                AppFormat.number(count),
                style: AppTextStyles.label.copyWith(color: secondary),
                semanticsLabel: l10n.addMealOnPlate(count),
              ),
            IconButton(
              icon: Icon(count > 0 ? AppSymbols.selected : AppSymbols.add),
              tooltip: l10n.addMealQuickAddFood(food.name),
              onPressed: () => quickAddFood(context, food),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recipe row's tap (`NutritionLibraryPickerPresenter.navToRecipeAmount`):
/// the servings sheet, whatever the Quick Add setting.
Future<void> pickRecipe(
  BuildContext context,
  RecipeTemplateModel recipe,
) async {
  final bloc = context.read<AddMealBloc>();
  final result = await showRecipeServingsSheet(context, recipe);
  if (result == null) return;
  unawaited(HapticFeedback.successNotification());
  bloc.add(AddMealItemAdded(result.item));
  if (result.log) bloc.add(const AddMealSaveRequested());
}

/// A recipe in the picker (Swift `FoodLibraryPickerRowView` with a
/// recipe): its figures for one serving as the Logger settings ask, and a
/// + that adds the servings last logged, which becomes a checkmark and
/// count once on the plate.
class RecipeRow extends StatelessWidget {
  const new({required this.recipe, super.key});

  final RecipeTemplateModel recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AddMealBloc>().state;
    final settings = state.effectiveSettings;
    final count = addedRecipeCount(state.meal.items, recipe.recipeId);
    final perServing = recipe.perServing.values;
    double per(NutrientKey key) => perServing[key] ?? 0;
    final detail = [
      if (settings.showCaloriesInLogger)
        AppFormat.kcal(per(NutrientKey.calories).round()),
      if (settings.showMacrosInLogger) ...[
        l10n.nutritionItemProtein(AppFormat.grams(per(NutrientKey.protein))),
        l10n.nutritionItemFat(AppFormat.grams(per(NutrientKey.fatTotal))),
        l10n.nutritionItemCarbs(AppFormat.grams(per(NutrientKey.carbs))),
      ],
      if (settings.showPortionInLogger)
        l10n.recipeDetailServingCount(AppFormat.number(1), 1),
    ].join(' · ');
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => unawaited(pickRecipe(context, recipe)),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.l),
        child: Row(
          children: [
            // `FoodLibraryPickerRowView`'s image, on the logger setting.
            if (settings.showFoodImageInLogger)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.m),
                child: RowThumbnail(recipe.imageUrl),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(recipe.name, style: AppTextStyles.rowTitle),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: AppTextStyles.rowDetail.copyWith(
                          color: secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (count > 0)
              Text(
                AppFormat.number(count),
                style: AppTextStyles.label.copyWith(color: secondary),
                semanticsLabel: l10n.addMealOnPlate(count),
              ),
            IconButton(
              icon: Icon(count > 0 ? AppSymbols.selected : AppSymbols.add),
              tooltip: l10n.addMealQuickAddRecipe(recipe.name),
              onPressed: () {
                unawaited(HapticFeedback.successNotification());
                context.read<AddMealBloc>().add(
                  AddMealRecipeQuickAdded(recipe),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A list's section title.
class _Header extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.l,
      AppSpacing.l,
      AppSpacing.l,
      AppSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// An empty list's explanation.
class _Empty extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final message = this.message;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        spacing: AppSpacing.s,
        children: [
          Icon(icon, size: AppIconSize.hero.of(context), color: secondary),
          Text(
            title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          if (message != null)
            Text(
              message,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
          ?action,
        ],
      ),
    );
  }
}

/// A search field at the top of a tab.
class _SearchField extends StatelessWidget {
  const new({
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.l,
      AppSpacing.s,
      AppSpacing.l,
      0,
    ),
    child: TextField(
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(AppSymbols.search),
        hintText: hint,
      ),
      onChanged: onChanged,
    ),
  );
}

// MARK: - Search

class _SearchTab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // The device's region and language put local products first.
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return BlocProvider(
      create: (context) => FoodSearchBloc(
        openFoodFacts: context.read<OpenFoodFacts>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        country: countryTag(locale.countryCode),
        language: locale.languageCode,
      ),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meal = context.watch<AddMealBloc>().state;
    final search = context.watch<FoodSearchBloc>().state;
    final settings = meal.effectiveSettings;
    final query = search.query.trim();
    final library = libraryMatches(meal.foods, query);
    final recipes = recipeMatches(meal.recipes, query);
    final online = onlineResults(search.online, library);
    final recents = recentPicks(
      meal.meals ?? const [],
      meal.foods,
      meal.recipes,
    );
    // Neither the library nor the user's recipes found anything.
    final nothingSaved = library.isEmpty && recipes.isEmpty;
    return Column(
      children: [
        _SearchField(
          hint: l10n.addMealSearchPrompt,
          // Searching is what this tab is for: the keyboard comes up.
          autofocus: true,
          onChanged: (text) => context.read<FoodSearchBloc>().add(
            FoodSearchQueryChanged(
              text,
              searchOnline: settings.showOpenFoodFactsFoods,
              showBranded: settings.showBrandedFoods,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (query.isEmpty)
                if (recents.isEmpty)
                  _Empty(
                    icon: AppSymbols.search,
                    title: l10n.addMealSearchEmptyTitle,
                    message: l10n.addMealSearchEmptyMessage,
                  )
                else ...[
                  _Header(l10n.addMealRecent),
                  for (final pick in recents)
                    switch (pick) {
                      RecentFood(:final food) => FoodRow(food: food),
                      RecentRecipe(:final recipe) => RecipeRow(recipe: recipe),
                    },
                ]
              else ...[
                if (library.isNotEmpty) ...[
                  _Header(l10n.addMealMyFoods),
                  for (final food in library) FoodRow(food: food),
                ],
                if (recipes.isNotEmpty) ...[
                  _Header(l10n.addMealMyRecipes),
                  for (final recipe in recipes) RecipeRow(recipe: recipe),
                ],
                if (settings.showOpenFoodFactsFoods) ...[
                  _Header(l10n.addMealOpenFoodFacts),
                  switch (search.status) {
                    FoodSearchStatus.searching => Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Row(
                        spacing: AppSpacing.s,
                        children: [
                          const SizedBox.square(
                            dimension: AppSpacing.l,
                            child: CircularProgressIndicator.adaptive(),
                          ),
                          Text(l10n.addMealSearching),
                        ],
                      ),
                    ),
                    FoodSearchStatus.failure => Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: AppInlineMessage(
                        kind: AppInlineMessageKind.error,
                        text: l10n.addMealSearchFailed,
                        kindLabel: l10n.addMealErrorLabel,
                      ),
                    ),
                    FoodSearchStatus.idle when online.isEmpty =>
                      nothingSaved
                          ? _Empty(
                              icon: AppSymbols.search,
                              title: l10n.addMealNoResults(query),
                            )
                          : const SizedBox.shrink(),
                    FoodSearchStatus.idle => Column(
                      children: [
                        for (final food in online) FoodRow(food: food),
                      ],
                    ),
                  },
                ] else if (nothingSaved)
                  _Empty(
                    icon: AppSymbols.search,
                    title: l10n.addMealNoResults(query),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// MARK: - Library

/// The library's segments (Swift `FoodLibraryOption`).
enum LibrarySegment {
  /// The user's recipes.
  recipes,

  /// The user's foods.
  foods,

  /// The favourite recipes and foods.
  favourites,
}

/// Where the library opens (`FoodLibraryPresenter.init`): on favourites
/// once there are any, which is what the user keeps coming back to, else
/// on recipes.
LibrarySegment initialLibrarySegment(FoodLogSettings settings) =>
    settings.favouriteFoodIds.isEmpty && settings.favouriteRecipeIds.isEmpty
    ? LibrarySegment.recipes
    : LibrarySegment.favourites;

class _LibraryTab extends StatefulWidget {
  const new();

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  // The segment and filter are this screen's own view state, not the
  // meal's.
  late LibrarySegment _segment = initialLibrarySegment(
    context.read<AddMealBloc>().state.effectiveSettings,
  );
  String _filter = '';

  /// The filter belongs to the segment it was typed for, so changing
  /// segment clears it (`FoodLibraryPresenter.onLibraryOptionChanged`).
  void _select(LibrarySegment segment) {
    if (segment == _segment) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _segment = segment;
      _filter = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AddMealBloc>().state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            0,
          ),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<LibrarySegment>(
              key: const Key('FoodPicker.segments'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: LibrarySegment.recipes,
                  label: Text(l10n.addMealLibraryRecipes),
                ),
                ButtonSegment(
                  value: LibrarySegment.foods,
                  label: Text(l10n.addMealLibraryFoods),
                ),
                ButtonSegment(
                  value: LibrarySegment.favourites,
                  label: Text(l10n.addMealLibraryFavorites),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (selected) => _select(selected.single),
            ),
          ),
        ),
        _SearchField(
          // A new field per segment, so it starts empty.
          key: ValueKey(_segment),
          hint: switch (_segment) {
            LibrarySegment.recipes => l10n.addMealFilterRecipes,
            LibrarySegment.foods => l10n.addMealFilterFoods,
            LibrarySegment.favourites => l10n.addMealFilterFavorites,
          },
          onChanged: (text) => setState(() => _filter = text),
        ),
        Expanded(
          child: switch (_segment) {
            LibrarySegment.recipes => _recipes(context, state),
            LibrarySegment.foods => _foods(context, state),
            LibrarySegment.favourites => _favourites(context, state),
          },
        ),
      ],
    );
  }

  /// `RecipeListBuilderView` with a plate.
  Widget _recipes(BuildContext context, AddMealState state) {
    final l10n = context.l10n;
    final recipes = sortedByName([
      for (final recipe in state.recipes)
        if (matchesRecipeFilter(recipe, _filter.trim())) recipe,
    ], (recipe) => recipe.name);
    final create = ListTile(
      key: const Key('FoodPicker.createRecipe'),
      leading: const Icon(AppSymbols.add),
      title: Text(l10n.recipesCreate),
      onTap: () => unawaited(CreateRecipePage.show(context)),
    );
    if (state.recipes.isEmpty) {
      return SingleChildScrollView(
        child: _Empty(
          icon: AppSymbols.recipe,
          title: l10n.recipesEmptyTitle,
          message: l10n.recipesEmptyMessage,
          action: FilledButton(
            onPressed: () => unawaited(CreateRecipePage.show(context)),
            child: Text(l10n.recipesCreate),
          ),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_filter.trim().isEmpty) ...[create, _Header(l10n.recipesCustom)],
        for (final recipe in recipes) RecipeRow(recipe: recipe),
        if (recipes.isEmpty)
          _Empty(
            icon: AppSymbols.search,
            title: l10n.addMealNoResults(_filter.trim()),
          ),
      ],
    );
  }

  /// `IngredientListBuilderView` with a plate: branded foods only when the
  /// setting allows, matching on name or description.
  Widget _foods(BuildContext context, AddMealState state) {
    final l10n = context.l10n;
    final needle = _filter.trim().toLowerCase();
    bool has(String? text) =>
        text != null && text.toLowerCase().contains(needle);
    final showBranded = state.effectiveSettings.showBrandedFoods;
    final foods = sortedByName([
      for (final food in state.foods)
        if ((showBranded || food.brandName == null) &&
            (needle.isEmpty || has(food.name) || has(food.description)))
          food,
    ], (food) => food.name);
    if (state.foods.isEmpty) {
      return SingleChildScrollView(
        child: _Empty(
          icon: AppSymbols.food,
          title: l10n.addMealLibraryEmptyTitle,
          message: l10n.addMealLibraryEmptyMessage,
          action: FilledButton(
            onPressed: () => unawaited(_createFood(context)),
            child: Text(l10n.foodsCreate),
          ),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (needle.isEmpty) ...[
          ListTile(
            key: const Key('FoodPicker.createFood'),
            leading: const Icon(AppSymbols.add),
            title: Text(l10n.foodsCreate),
            onTap: () => unawaited(_createFood(context)),
          ),
          _Header(l10n.addMealFoods),
        ],
        for (final food in foods) FoodRow(food: food),
        if (foods.isEmpty)
          _Empty(
            icon: AppSymbols.search,
            title: l10n.addMealNoResults(_filter.trim()),
          ),
      ],
    );
  }

  /// The favourites (`FoodLibraryView.favouritesList`): recipes, then
  /// foods, each filtered by name. A favourite whose recipe or food has
  /// gone is dropped.
  Widget _favourites(BuildContext context, AddMealState state) {
    final l10n = context.l10n;
    final settings = state.effectiveSettings;
    if (settings.favouriteFoodIds.isEmpty &&
        settings.favouriteRecipeIds.isEmpty) {
      return SingleChildScrollView(
        child: _Empty(
          icon: AppSymbols.heart,
          title: l10n.addMealNoFavoritesTitle,
          message: l10n.addMealNoFavoritesMessage,
        ),
      );
    }
    final recipes = favourites(
      state.recipes,
      settings.favouriteRecipeIds,
      _filter,
      id: (recipe) => recipe.recipeId,
      name: (recipe) => recipe.name,
    );
    final foods = favourites(
      state.foods,
      settings.favouriteFoodIds,
      _filter,
      id: (food) => food.ingredientId,
      name: (food) => food.name,
    );
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (recipes.isNotEmpty) ...[
          _Header(l10n.addMealLibraryRecipes),
          for (final recipe in recipes) RecipeRow(recipe: recipe),
        ],
        if (foods.isNotEmpty) ...[
          _Header(l10n.addMealLibraryFoods),
          for (final food in foods) FoodRow(food: food),
        ],
      ],
    );
  }
}

/// The library's + (`IngredientListBuilderPresenter
/// .onAddIngredientPressed` with a plate): Create Food, whose Create & Add
/// puts the new food on the plate at 100, the basis its nutrients are
/// stored on (`FoodDefinitionPresenter.onCreateAndAddPressed`).
Future<void> _createFood(BuildContext context) async {
  final bloc = context.read<AddMealBloc>();
  context.read<AnalyticsRepository>().trackEvent(
    const AnalyticsEvent('IngredientsView_AddIngredientPressed'),
  );
  final food = await CreateFoodPage.showForPlate(context);
  if (food != null) bloc.add(AddMealItemAdded(food.mealItem(100)));
}

// MARK: - Quick add

class _QuickAddTab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => QuickAddCubit(),
    child: const _QuickAddView(),
  );
}

class _QuickAddView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<QuickAddCubit>();
    final state = context.watch<QuickAddCubit>().state;
    final bloc = context.read<AddMealBloc>();
    final saving = context.select<AddMealBloc, bool>(
      (bloc) => bloc.state.status == AddMealStatus.saving,
    );
    MealItemModel item() =>
        state.item(itemId: newDocumentId(), sourceId: newDocumentId());
    Widget macro(
      String label,
      double? value,
      ValueChanged<double?> onChanged,
    ) => AppNumberField.units(
      label: label,
      prompt: '0',
      value: value,
      onChanged: onChanged,
      unit: state.macroUnit.symbol,
      units: [for (final unit in MacroUnit.values) unit.symbol],
      unitsLabel: l10n.addMealUnit,
      onUnitChanged: (symbol) => cubit.macroUnitChanged(
        MacroUnit.values.firstWhere((unit) => unit.symbol == symbol),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
            children: [
              AppSection(
                header: l10n.addMealQuickAddName,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.addMealQuickAddName,
                        border: InputBorder.none,
                      ),
                      onChanged: cubit.nameChanged,
                    ),
                  ),
                ],
              ),
              AppSection(
                footer: l10n.addMealQuickAddMacroEnergy(
                  AppFormat.number(state.macroEnergyInUnit),
                  state.energyUnit.symbol,
                ),
                children: [
                  AppNumberField.units(
                    label: l10n.addMealQuickAddEnergy,
                    prompt: '0',
                    value: state.energy,
                    onChanged: cubit.energyChanged,
                    unit: state.energyUnit.symbol,
                    units: [for (final unit in EnergyUnit.values) unit.symbol],
                    unitsLabel: l10n.addMealUnit,
                    onUnitChanged: (symbol) => cubit.energyUnitChanged(
                      EnergyUnit.values.firstWhere(
                        (unit) => unit.symbol == symbol,
                      ),
                    ),
                  ),
                ],
              ),
              AppSection(
                header: l10n.addMealQuickAddMacros,
                children: [
                  macro(
                    l10n.nutritionMacroProtein,
                    state.protein,
                    cubit.proteinChanged,
                  ),
                  macro(
                    l10n.nutritionMacroCarbs,
                    state.carbs,
                    cubit.carbsChanged,
                  ),
                  macro(l10n.nutritionMacroFat, state.fat, cubit.fatChanged),
                  macro(
                    l10n.addMealQuickAddAlcohol,
                    state.alcohol,
                    cubit.alcoholChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
        AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.addMealLog,
              isLoading: saving,
              onPressed: state.canSubmit
                  ? () {
                      if (!state.addedForLog) {
                        cubit.addedForLog();
                        bloc.add(AddMealItemAdded(item()));
                      }
                      bloc.add(const AddMealSaveRequested());
                    }
                  : null,
            ),
            AppCtaButton(
              label: l10n.addMealAddToPlate,
              variant: AppCtaVariant.secondary,
              onPressed: state.canSubmit
                  ? () {
                      context.read<AnalyticsRepository>().trackEvent(
                        AnalyticsEvent(
                          'FoodItemQuickAddView_QuickAdd',
                          parameters: {'food_name': state.trimmedName},
                        ),
                      );
                      unawaited(HapticFeedback.successNotification());
                      bloc
                        ..add(AddMealItemAdded(item()))
                        ..add(const AddMealPickerClosed());
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

// MARK: - Barcode

/// The Barcode tab, in Barcode or Label mode (Swift `ScanningMode`). A
/// change of mode starts over: each mode's cubit is made afresh.
class _BarcodeTab extends StatefulWidget {
  const new();

  @override
  State<_BarcodeTab> createState() => _BarcodeTabState();
}

class _BarcodeTabState extends State<_BarcodeTab> {
  bool _label = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = context.read<AddMealBloc>().state.meal.authorId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            0,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Semantics(
              label: l10n.labelScanningMode,
              child: SegmentedButton<bool>(
                key: const Key('FoodPicker.scanningMode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.addMealModeBarcode),
                  ),
                  ButtonSegment(value: true, label: Text(l10n.labelModeLabel)),
                ],
                selected: {_label},
                onSelectionChanged: (selected) {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _label = selected.single);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: _label
              ? BlocProvider(
                  create: (context) => LabelScannerCubit(
                    uid: uid,
                    ai: context.read<AiRepository>(),
                    foodRepository: context.read<FoodRepository>(),
                    analytics: context.read<AnalyticsRepository>(),
                  ),
                  child: const _LabelView(),
                )
              : BlocProvider(
                  create: (context) => BarcodeScannerCubit(
                    uid: uid,
                    openFoodFacts: context.read<OpenFoodFacts>(),
                    foodRepository: context.read<FoodRepository>(),
                    analyticsRepository: context.read<AnalyticsRepository>(),
                  ),
                  child: const _BarcodeView(),
                ),
        ),
      ],
    );
  }
}

class _BarcodeView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BarcodeScannerCubit>();
    final state = context.watch<BarcodeScannerCubit>().state;
    void detected(String code) => unawaited(
      cubit.detected(code, library: context.read<AddMealBloc>().state.foods),
    );
    final food = state.food;
    return BlocListener<BarcodeScannerCubit, BarcodeScannerState>(
      listenWhen: (previous, current) =>
          current.status != previous.status &&
          current.status != BarcodeStatus.scanning &&
          current.status != BarcodeStatus.lookingUp,
      listener: (context, state) {
        final food = state.food;
        if (state.status == BarcodeStatus.found && food != null) {
          // A found product goes straight on to its amount; the row stays
          // behind it, with Scan Again, for a wrong match.
          unawaited(pickFood(context, food));
        } else {
          unawaited(HapticFeedback.errorNotification());
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: BarcodeCamera(onDetect: detected),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          switch (state.status) {
            BarcodeStatus.scanning => Text(
              l10n.addMealBarcodeHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.rowDetail,
            ),
            BarcodeStatus.lookingUp => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppSpacing.s,
              children: [
                const SizedBox.square(
                  dimension: AppSpacing.l,
                  child: CircularProgressIndicator.adaptive(),
                ),
                Text(l10n.addMealBarcodeLookingUp(state.code ?? '')),
              ],
            ),
            BarcodeStatus.notFound => AppInlineMessage(
              kind: AppInlineMessageKind.error,
              text: l10n.addMealBarcodeNotFound,
              kindLabel: l10n.addMealErrorLabel,
            ),
            BarcodeStatus.unavailable => AppInlineMessage(
              kind: AppInlineMessageKind.error,
              text: l10n.addMealBarcodeUnavailable,
              kindLabel: l10n.addMealErrorLabel,
            ),
            BarcodeStatus.found =>
              food == null
                  ? const SizedBox.shrink()
                  : AppCard(
                      style: AppCardStyle.tile,
                      child: FoodRow(food: food),
                    ),
          },
          const SizedBox(height: AppSpacing.m),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.s,
            children: [
              TextButton.icon(
                icon: const Icon(AppSymbols.edit),
                label: Text(l10n.addMealBarcodeEnter),
                onPressed: () async {
                  final code = await enterBarcode(context, state.code);
                  if (code != null && context.mounted) {
                    cubit.rescan();
                    detected(code);
                  }
                },
              ),
              if (state.status != BarcodeStatus.scanning &&
                  state.status != BarcodeStatus.lookingUp)
                TextButton.icon(
                  icon: const Icon(AppSymbols.logAgain),
                  label: Text(l10n.addMealBarcodeScanAgain),
                  onPressed: cubit.rescan,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Typing a barcode, the fallback when the camera cannot read it; prefilled
/// with whatever it did catch. Null when cancelled.
Future<String?> enterBarcode(BuildContext context, String? scanned) =>
    showDialog<String>(
      context: context,
      builder: (_) => _BarcodeEntryDialog(scanned: scanned),
    );

/// The dialog owns its field's controller, so the controller outlives the
/// dialog's closing animation (disposing it when the future completed
/// broke the field mid-animation).
class _BarcodeEntryDialog extends StatefulWidget {
  const new({required this.scanned});

  final String? scanned;

  @override
  State<_BarcodeEntryDialog> createState() => _BarcodeEntryDialogState();
}

class _BarcodeEntryDialogState extends State<_BarcodeEntryDialog> {
  late final _controller = TextEditingController(text: widget.scanned);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addMealBarcodeEnter),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: l10n.addMealBarcodeField),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.addMealBarcodeLookUp)),
      ],
    );
  }
}
