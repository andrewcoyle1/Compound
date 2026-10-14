# Swift app findings from the Flutter port

Writing contracts and porting logic means reading every Swift model and rule closely. These issues
were found along the way. **None was changed**: Swift app code is outside the Flutter run. Each
needs the owner's decision.

- **FoodLogSettings decodes strictly (synthesized Codable).** Fields added later (`favourite_food_ids`, `favourite_recipe_ids`, `hide_food_details`, `hide_empty_hours`) make documents written before them fail to decode. iOS then quietly shows defaults, and the user's next save overwrites their old settings. Found by M2-3 (#91). The fix is a lenient `init(from:)` in Swift, which is outside the Flutter run.
- `firestore.rules` has a stale comment giving the meal path as `meal_logs/{dayKey}/meals/{mealId}` (M2-3).
- SetTarget: a null `set_type` reads as standard, but a *missing* one fails the decode. Sessions before 30 Sep 2026 carry `training_program_id`, which Swift no longer reads (M2-1).
- **Clearing a body value never reaches Firestore.** `BodyMeasurementEntry.withCleared(…)` is saved as a merge, and a merge skips nil (omitted) fields, so the old value comes back on the next sync. This breaks deleting a weigh-in on Scale Weight, Weight Trend and Weigh-in Consistency, clearing values on the measurement detail screens, and the HealthKit day-clearing import. Found by M2-5 (#94). The fix is in Swift: write `FieldValue.delete()` for cleared fields, or save without merge. Outside the Flutter run.
- **Swift sends `uauth_email` (and display name) as analytics parameters and user properties to Firebase Analytics and Crashlytics.** Google Analytics' terms forbid personal data. The Flutter app sends name and email to Mixpanel's identify only. Found by the analytics slice (#96). Worth fixing in Swift.
