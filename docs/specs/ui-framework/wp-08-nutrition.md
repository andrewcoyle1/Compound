# WP-08 · Migrate Nutrition

**Wave 3. Size: large.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Nutrition/**`
- `Components/Views/Nutrition/**` (moves to `Core/Nutrition/Components/`)
- `Components/Views/MealItemLabel/`
- `Components/Views/Nutrition/ServingUnitPicker.swift`

`NutritionCard` is shown on the Dashboard and belongs to WP-11; leave it where it is.

## Specific issues

- **Primary action lives in four places.** Unify it:
  - Flows (`CreateFood`, `CreateRecipe`, `FoodDefinition`, `AddMeal`) use `.bottomCTA`.
  - Amount sheets (`MealItemAmount`, `RecipeAmount`, `IngredientAmount`, `RecipeIngredientAmount`)
    use a confirm-role toolbar button.
  - Retire the `.bottomBar` primary buttons in `MealItemAmountViewView.swift:88-94`,
    `FoodLibraryView.swift:121` and `MealDescribeView.swift:62`.
  - Use one verb: "Log".
- **Amount screens mix `Form` and `List`.** Pick one for all four.
- **The library picker** (`FoodPhotoScanner`, `BarcodeScanner`, `MealDescribe`, `FoodItemSearch`)
  switches between `ScrollView`, `Form` and `List` under one chip bar. Unify it.
  - The mode chips become `Chip(isSelected:)`.
  - The three private `macroChip` helpers become `Chip` with macro tints.
- **`MacroStatCard`** (`Core/Nutrition/MealLog/Subviews/MacroStatCard.swift`) becomes `Stat.tile`.
  Its green→blue→orange→red progress grading uses status tokens plus a symbol.
- **Search.** Use one pattern for every food search: `.searchable` with toolbar placement, like
  `SearchView`.
- **Spelling.** The app mixes US and UK spelling ("Favourites", "Analysing" vs "Fiber"). Report
  the mix and do not change it. It is a product decision; the strings are listed for WP-15.
- **`AddMealView`** reuses `AnalyticsCard` with empty `subsubtitle`s for non-tappable cards. Use
  `Stat.tile`, or the renamed card with `showsChevron: false`.
- **`CreateFoodView.swift:95,98`** and **`CreateRecipeView.swift:112`** use fixed-size images.
  Switch them to `.iconSize(.hero)`.
