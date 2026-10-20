# ai_repository

The AI callables as typed calls (Swift `AIManager`, `GoogleAIService` and the decoding in its
presenters). No UI.

- `AiRepository` takes a `CallFunction`: `callAiFunction(FirebaseFunctions.instanceFor(region:
  aiFunctionsRegion))` (`us-central1`, App Check active) or, in staging, `stagingAiCall`, which
  answers as Swift's `MockAIService`.
- `analyzeFood(jpeg)` (`foodAnalyze`, `{imageBase64}`) and `describeMeal(text)` (`mealDescribe`,
  `{description}`) return `FoodAnalysisItem`s, each with `mealItem()` (the estimate as is) and
  `estimatedFood(now:)` (scaled to per 100 g for the amount screen).
- `analyzeNutritionLabel(text, authorId:)` (`nutritionLabelAnalyze`, `{labelText}`) returns an
  unsaved `FoodModel`. The function takes recognized text only, as Swift sends.
- `generateImage(prompt)` (`imageGenerate`) returns the image bytes.
- Failures are `AiException`s: `unauthenticated` (sign-in or App Check), `permissionDenied`,
  `rateLimited`, `unavailable`, and `invalidResponse` when the model's JSON does not decode.
