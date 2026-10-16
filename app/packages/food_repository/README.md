# food_repository

The signed-in user's food library, Open Food Facts search and barcode lookup, and a food as a meal
item (Swift `FoodManager`, `OpenFoodFactsService`, `FoodModel+MealItem.swift`).

- `FirestoreFoodRepository` takes `FirebaseFirestore` through its constructor. `watchFoods` reads
  every document in `users/{uid}/foods`, skipping (and reporting to `onDecodeError`) any that does
  not decode. `saveFood` merges the food into `users/{authorId}/foods/{ingredientId}` and throws an
  `ArgumentError`, writing nothing, when the food has no `author_id`: the rules refuse it.
  A merge combines nested maps key by key, so a nutrient left out of a save is kept, as in Swift.
- `InMemoryFoodRepository` does the same in memory for staging and tests; seed it with
  `sampleFoods(uid:, now:)` (a dozen foods whose ids match `nutrition_repository`'s sample meals).
- `RemoteOpenFoodFacts` takes `FirebaseFunctions` (`instanceFor(region: 'us-central1')`, with App
  Check active: the `foodSearch` callable enforces it) and an `http.Client`. Search calls
  `foodSearch` with `{query, country?, lang?}`; barcodes are read from
  `https://world.openfoodfacts.org/api/v2/product/{code}.json` with a `User-Agent`. Failures are
  `FoodDataException`s carrying a `FoodDataFailure` (`notFound`, `unauthenticated`,
  `rateLimited`, `unavailable`). `FakeOpenFoodFacts` serves canned products for staging.
- `lookUpBarcode` is the scanner's order: the user's library first, then Open Food Facts, whose
  product is saved to the library as the user (a failed save is reported, not thrown).
- `FoodMealItem` turns a food into a `MealItemModel` (`mealItem`, `quickAddItem`) and gives its
  portions (`defaultPortion`, `defaultPortionAmount`, `loggedUnitLabel`, `rowNutrientScale`).
  Nutrients are per 100 g or ml; a negative or non-finite amount is logged as 0.
