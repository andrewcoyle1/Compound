# nutrition_repository

The signed-in user's meal logs, diet plan and food log settings, **read-only** (M2).

- `FirestoreNutritionRepository` takes `FirebaseFirestore` through its constructor and watches:
  - `users/{uid}/meal_logs` where `author_id` is the user, as the Swift app's listener does;
  - `diet_plans/{uid}` (null when absent);
  - `users/{uid}/food_log_settings/food_log_settings` (Swift's defaults when absent).

  Timestamps become UTC `DateTime`s. A document that does not decode is skipped and reported to
  `onDecodeError` (or `dart:developer`'s log), as Swift's sync engine skips it.
- `withoutDuplicateHealthImports` is Swift's `MealLogManager.userMeals` rule: on a day with a meal
  logged in Compound, that day's Apple Health import is dropped. `watchMeals` applies it.
  `mealsByDay` groups meals by `day_key`.
- `InMemoryNutritionRepository` serves fixed data for the staging flavor and tests; seed it with
  `sampleMealLogs(uid:, now:)` and `sampleDietPlan(uid:, now:)`. With no settings given it serves
  the defaults.

The models are `compound_models'`, held to the Firestore contract in
[`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
There are no write methods.
