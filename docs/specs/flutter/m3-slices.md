# M3: first writes, slice plan

Researched on 15 Oct 2026; paths are relative to `Compound/`. M3 is the first milestone that
**writes** to Firestore. Every model written must pass its contract on both sides first
(`firestore-contract.md`). Writes merge, as Swift's do, and partial updates take field names only
from the models' `…Keys` constants.

| # | Slice | Depends on | Size |
|---|---|---|---|
| 1 | Library and gym contracts: `ExerciseModel`, `ExerciseSettings`, `WorkoutTemplate(+Exercise)`, `WorkoutSettings`, `GymProfile` and equipment | — | L |
| 2 | `Mesocycle`, `Macrocycle` and `FoodModel` (+ `ServingUnit`) contracts | 1 (same files) | M |
| 3 | Writes in the existing repositories: user (create the new-user document, keyed updates, private-settings merge), body (save a measurement), goal (save; abandon the old one), nutrition (save a meal, save the diet plan) | — | M |
| 4 | Weigh-in screen (`LogWeightPresenter.swift:78-90`: save the measurement, then update `submitted_weight_*`) | 3 | S |
| 5 | Onboarding shell: AppBloc onboarding gate, `inferredOnboardingStep` and `OnboardingStepRouter`, new-user document, account setup, health disclaimer | 3 | L |
| 6 | Onboarding: goal setting, diet steps, completed | 5 | M |
| 7 | `training_library_repository` (exercises, templates, settings, gyms) and the bundled seed JSON (byte-identical to the Swift files) | 1 | M |
| 8 | Onboarding: minimal gym profile (named, with defaults) and starting a prebuilt program (`startPrebuiltMesocycle`, macrocycle) | 2, 6, 7 | M |
| 9 | Exercise library: list, detail, picker (read-only; the Create Exercise flow waits for M5) | 7 | M |
| 10 | Tracker glue (a package): map `compound_models` onto `training_rules`, build a session from a template, prefill (`plannedSession`, `sessionLoads`), the local active session, session save, `WeeklyStreak` and the `week_streak_count` and private-settings streak writes | 1, 7 | L |
| 11 | Tracker UI: start, sets, keyboard, correction, notes, finish, summary, discard | 9, 10 | L |
| 12 | Rest timer and notifications (`flutter_local_notifications`), Android ongoing notification, haptics, wakelock | 11 | M |
| 13 | Food search and logging: foods repository, `foodSearch` callable client, AddMeal, picker, quick add, amounts, `FoodModel` → `MealItem` | 2, 3 | L |
| 14 | Barcode scanner (`mobile_scanner`): local lookup, then Open Food Facts, save the food, manual entry | 13 | M |

**Parallel lanes:**
- Package-only and parallel-safe: 1, 3, 7, 10.
- 1 and 2 share the contract files, so they run one after the other.
- Every UI slice (4, 5, 6, 8, 9, 11, 13, 14) touches the router, the bootstrap, the ARB files and `pump_app.dart`, so they run one after another.

**Left out of M3:**
- the Subscription step (M4)
- the profile photo (M5)
- Apple Health / Health Connect prefill and export (M5)
- Live Activity (M6)
- Strava, macrocycle advance and mesocycle notes (M5)
- the nutrition label scanner (M5)
- the Create Exercise flow (M5)
