# Dead settings audit

Every stored property on every settings model in the app, and whether anything outside the screen
that writes it ever reads it.

## Summary

- **69 stored settings** across six documents: `WorkoutSettings` (23), `FoodLogSettings` (29),
  `NutritionStrategySettings` (13), `ExerciseSettingsModel` (2), `AnalyticsSettings` (1),
  `ShortcutSettings` (1).
- **26 were dead** when this audit was written — saved to Firestore and read by nothing outside
  the screen that writes them.
- **Twenty-four have since been wired** and are live: `restDurationOverride`,
  `restTimerPlaySound`, `restTimerVibrate`, `previousWorkoutReference`, `autoSetCurrentTime`,
  `quickAddEnabled`, `supersetAutoScroll`, `note`, `showOverages`, `estimationMethod`; the five
  the adaptive expenditure engine brought with it: `calculationMode`, `calculationStartDate`,
  `algorithmVersion`, `stepInformedUpdates` and `predictiveGoalAdjustments`; the three the
  smart-progression engine reads: `smartProgressionApplyInSession`,
  `smartProgressionInitialLogFill` and `smartProgressionAdjustmentMode`; and the six the weekly
  check-in reads: `checkInWeekday`, `fastCheckIn`, `partialLoggingEnabled`, `weighInEnabled`,
  `fastingEnabled` and `loggingBreakEnabled`.
- **Two remain dead.** `favouriteMeasurements` needs a feature built first and `premove` needs a
  decision. Both are listed below with what is missing.
- **67 are live.**
- Time Selection, Optimisation, **Expenditure Settings**, **Strategy Settings** and **Smart
  Progression Settings** are all live in full: `ExpenditureEngine`, the check-in flow and
  `ProgressionEngine` read every field on them. **Favourite Measurements** still is inert: its
  list of nine units has no picker anywhere in the app to order.

### What "read by" means here

A read counts only if it is production code that is **not** the settings screen that writes the
value. Reads in `#Preview` blocks, in tests, and in the writing screen's own presenter or view are
excluded: a toggle that renders its own state and nothing else is still a toggle that does nothing.
Where a setting is surfaced through a helper (`AnalyticsSettings.isVisible(_:)`,
`ShortcutSettings.quickActions`) the helper's callers are what was traced, not the stored property.

### Verdicts

- `live` — production code outside the writing screen reads it.
- `feature` — the behaviour it describes does not exist. Reading the flag would change nothing;
  honouring it means building the thing it names. The row says what is missing.
- `decide` — the product owner has to say what it should mean before either is possible.

Nothing here is marked `remove`. The instruction standing over this work is that no setting,
control or screen is to be deleted however dead — including `algorithmVersion`, whose single case
cannot change anything even once there is an engine to change.

---

## Workout Settings

`DialedIn/Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift` — document
`workout_settings`, one per user.

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `propagateChanges` | `WorkoutSettings` | `WorkoutSettingsPresenter.propagateChanges` | `WorkoutTrackerPresenter.propagateChanges(_:)` | live |
| `rirTracking` | `WorkoutSettings` | `WorkoutSettingsPresenter.rirTracking` | `WorkoutTrackerPresenter.showRIRTracking` | live |
| `exerciseAutoNext` | `WorkoutSettings` | `WorkoutSettingsPresenter.exerciseAutoNext` | `WorkoutTrackerPresenter.advanceAfterExerciseCompletion(exerciseIndex:in:)` | live |
| `keepAlive` | `WorkoutSettings` | `WorkoutSettingsPresenter.keepAlive` | `WorkoutTrackerPresenter` (sets `isIdleTimerDisabled`) | live |
| `showWorkoutTimer` | `WorkoutSettings` | `WorkoutSettingsPresenter.showWorkoutTimer` | `WorkoutTrackerPresenter.showWorkoutTimer` | live |
| `showBodyweightContribution` | `WorkoutSettings` | `WorkoutSettingsPresenter.showBodyweightContribution` | `WorkoutTrackerPresenter` | live |
| `addSmartWarmUps` | `WorkoutSettings` | `WorkoutSettingsPresenter.addSmartWarmUps` | `WorkoutTrackerPresenter` (warm-up seeding guard) | live |
| `supersetAutoScroll` | `WorkoutSettings` | `WorkoutSettingsPresenter.supersetAutoScroll` | `WorkoutTrackerPresenter.advanceWithinSuperset(exerciseIndex:in:)` | live — **wired**. Not at `advanceAfterExerciseCompletion` as the audit guessed: the toggle says *after set completion*, which is the round-robin step between two members, not finishing an exercise. New rule in `WorkoutTrackerPresenter+Superset`. **Default `true`, so this changes behaviour for every existing user** — a release note, not a silent improvement. |
| **`previousWorkoutReference`** | `WorkoutSettings` | `PrevWORefSettingsPresenter.previousWorkoutReference` | `CoreInteractor.previousSessions(forExerciseTemplateId:…)`, read by `WorkoutTrackerPresenter.loadPreviousWorkoutSession()` and by smart progression | live — **wired**, and now three scopes rather than two: `.anyExercise` (the last time the exercise was performed in any workout), `.sameWorkout` (the last completed session of this template, in any program — the default, and still the stored raw value `"anyWorkout"`) and `.workoutsInProgram` (the same, restricted to this workout's program). The two template scopes fall back to the any-exercise lookup when this template has no history for an exercise, so a new template built from long-trained exercises still shows their figures. |
| `smartProgressionApplyInSession` | `WorkoutSettings` | `SmartProgressionSettingsPresenter.applyInSession` | `SetTrackerRowPresenter.onSetComplete` → `WorkoutTrackerPresenter.applyLiveProgression` | live — **wired** by the smart-progression engine (`docs/specs/smart-progression.md` §4): live set-to-set re-suggestion. |
| `smartProgressionInitialLogFill` | `WorkoutSettings` | `SmartProgressionSettingsPresenter.initialLogFill` | `CoreInteractor.sessionPrefill(for:…)` | live — **wired**; all three options, including the default, once the engine existed (§5). |
| `smartProgressionAdjustmentMode` | `WorkoutSettings` | `SmartProgressionSettingsPresenter.adjustmentMode` | `ProgressionEngine.classify` via `ProgressionPlanner` | live — **wired**; weight-first needs a majority of sets at the top of the range, reps-first needs all of them (§3.2). |

### What `smartProgressionInitialLogFill` took (historical)

Worth writing down, because it is the one dead setting whose wiring looks like plumbing and is not.

Its three options are `.smartProgression` (the default), `.previousValues` and `.empty`.
`WorkoutSessionModel.init(template:previousWorkoutSession:…)` already prefills each working set
from the matching set of the previous session, rounded to the gym's increments — that is exactly
`.previousValues`, and an inline comment there mislabels it "smart progression". `.empty` is a
few lines away.

But `.smartProgression` is the default, and it is the one that needs the engine. Wiring the other
two would make the screen *look* finished while the option most users are sitting on quietly meant
something else. That is worse than leaving all three honest, so all three wait for the engine.
| `useRestTimers` | `WorkoutSettings` | `RestTimerSettingsPresenter.useRestTimers` | `SetTrackerRowPresenter` (set-completion handler) | live |
| `restAfterLastWarmUp` | `WorkoutSettings` | `RestTimerSettingsPresenter.restAfterLastWarmUp` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| `restBetweenExercises` | `WorkoutSettings` | `RestTimerSettingsPresenter.restBetweenExercises` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| `restBetweenSideSets` | `WorkoutSettings` | `RestTimerSettingsPresenter.restBetweenSideSets` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| `warmUpRestScaling` | `WorkoutSettings` | `RestTimerSettingsPresenter.warmUpRestScaling` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| `betweenExercisesRestScaling` | `WorkoutSettings` | `RestTimerSettingsPresenter.betweenExercisesRestScaling` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| `sideSetRestScaling` | `WorkoutSettings` | `RestTimerSettingsPresenter.sideSetRestScaling` | `SetTrackerRowPresenter.restAfterCompleting(_:in:)` | live |
| **`restTimerPlaySound`** | `WorkoutSettings` | `RestTimerSettingsPresenter.restTimerPlaySound` | **nothing** | `wire` — `HKWorkoutManager.startRest(durationSeconds:session:currentExerciseIndex:)`, the one place a rest is started and therefore the one place its end can be announced. |
| **`restTimerVibrate`** | `WorkoutSettings` | `RestTimerSettingsPresenter.restTimerVibrate` | **nothing** | `wire` — same place as `restTimerPlaySound`. |
| `restDurationsByExerciseType` | `WorkoutSettings` | `TimerDurationPresenter.saveEdit()` | `SetTrackerRowPresenter.baseRestDuration(for:)` | live |
| `defaultRestDurationSeconds` | `WorkoutSettings` | `RestTimerSettingsPresenter` | `SetTrackerRowPresenter.baseRestDuration(for:)`, `WorkoutTrackerPresenter.restDurationSeconds`, `WorkoutRestTimerIntents` | live |

## Exercise Settings (per exercise)

`DialedIn/Managers/Training/Exercise/ExerciseSettings/Models/ExerciseSettingsModel.swift` — one
document per exercise template.

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `note` | `ExerciseSettingsModel` | `ExerciseSettingsPresenter.onNotePressed()` | `ExerciseTrackerPresenter.note(for:)` → the card header | live — **wired**. No note is still no note, so a user who never wrote one sees the header unchanged. |
| **`restDurationOverride`** | `ExerciseSettingsModel` | `ExerciseSettingsPresenter.onRestTimerPressed()` **and** `TimerDurationPresenter.saveExerciseEdit()` | **nothing** — both screens only read back their own writes | `wire` — `SetTrackerRowPresenter.baseRestDuration(for:)`, which today falls straight from the per-type override to the global default and never consults the per-exercise one. This is the setting with the most obvious missing line in the app. |

## Food Log Settings

`DialedIn/Managers/Nutrition/FoodLogSettings/Models/FoodLogSettings.swift` — document
`food_log_settings`. Seven screens write it.

### Food Log Settings (the parent screen)

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `showOverages` | `FoodLogSettings` | `FoodLogSettingsPresenter.showOverages` | `NutritionPresenter.showOverages` → `MacroHeader.remaining(total:target:showOverages:)` | live — **wired**. The remaining page clamped at zero, so a target passed read "0 left" whatever the excess; on, it counts past zero. Default `false` keeps the clamp. The row's subtitle described the opposite state and was fixed alongside. |
| `showsFoodTimestamps` | `FoodLogSettings` | `FoodLogSettingsPresenter.showsFoodTimestamps` | `NutritionPresenter.showsFoodTimestamps` → `MealItemRowStyle` | live |
| `showHourlyMacroTotals` | `FoodLogSettings` | `FoodLogSettingsPresenter.showHourlyMacroTotals` | `MealHourHeaderPresenter.showHourlyMacroTotals` | live |
| `showCalendarWeekBanner` | `FoodLogSettings` | `FoodLogSettingsPresenter.showCalendarWeekBanner` | `NutritionPresenter` → `NutritionView` | live |
| **`premove`** | `FoodLogSettings` | `FoodLogSettingsPresenter.premove` | **nothing** | `decide` — unchanged. The name says nothing about what it should do, and no code or comment explains it. The product owner has to say what it means before anyone can wire it. |
| `timestampSide` | `FoodLogSettings` | `FoodLogSettingsPresenter.timestampSide` | `NutritionPresenter.timestampSide` → `MealItemRowStyle` | live |
| `showAddFoodsButton` | `FoodLogSettings` | `FoodLogSettingsPresenter.showAddFoodsButton` | `MealHourHeaderPresenter.showAddFoodsButton` | live |
| `startHour` | `FoodLogSettings` | `FoodLogSettingsPresenter.startHour` | `NutritionPresenter` (timeline range) | live |
| `endHour` | `FoodLogSettings` | `FoodLogSettingsPresenter.endHour` | `NutritionPresenter` (timeline range) | live |
| `showBrandedFoods` | `FoodLogSettings` | `FoodLogSettingsPresenter.showBrandedFoods` | `FoodItemSearchPresenter`, `IngredientListBuilderPresenter` | live |
| `showOpenFoodFactsFoods` | `FoodLogSettings` | `FoodLogSettingsPresenter.showOpenFoodFactsFoods` | `FoodItemSearchPresenter` | live |

### Timeline Actions (nutrition tab)

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `hideFoodDetails` | `FoodLogSettings` | `TimelineActionsPresenter.hideFoodDetails` | `NutritionPresenter` | live |
| `hideEmptyHours` | `FoodLogSettings` | `TimelineActionsPresenter.hideEmptyHours` | `NutritionPresenter` | live |

### Timeline Food Tiles

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `showFoodImageInTimeline` | `FoodLogSettings` | `TimelineFoodTilesPresenter` | `NutritionPresenter` | live |
| `showCaloriesInTimeline` | `FoodLogSettings` | `TimelineFoodTilesPresenter` | `NutritionPresenter` | live |
| `showMacrosInTimeline` | `FoodLogSettings` | `TimelineFoodTilesPresenter` | `NutritionPresenter` | live |

### Logger Food Tiles

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `showFoodImageInLogger` | `FoodLogSettings` | `LoggerFoodTilesPresenter` | `IngredientListBuilderPresenter`, `RecipeListBuilderPresenter` | live |
| `showCaloriesInLogger` | `FoodLogSettings` | `LoggerFoodTilesPresenter` | `IngredientListBuilderPresenter`, `RecipeListBuilderPresenter` | live |
| `showMacrosInLogger` | `FoodLogSettings` | `LoggerFoodTilesPresenter` | `IngredientListBuilderPresenter`, `RecipeListBuilderPresenter` | live |
| `showPortionInLogger` | `FoodLogSettings` | `LoggerFoodTilesPresenter` | `IngredientListBuilderPresenter`, `RecipeListBuilderPresenter` | live |

### Logger Banner

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `showCaloriesRing` | `FoodLogSettings` | `LoggerBannerPresenter` | `NutritionPresenter` → `MacroHeader` | live |
| `showProteinRing` | `FoodLogSettings` | `LoggerBannerPresenter` | `NutritionPresenter` → `MacroHeader` | live |
| `showFatRing` | `FoodLogSettings` | `LoggerBannerPresenter` | `NutritionPresenter` → `MacroHeader` | live |
| `showCarbsRing` | `FoodLogSettings` | `LoggerBannerPresenter` | `NutritionPresenter` → `MacroHeader` | live |

### Time Selection

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `autoSetCurrentTime` | `FoodLogSettings` | `TimeSelectionPresenter.autoSetCurrentTime` | `MealHourHeaderPresenter.mealTime(for:)` | live — **wired**. A timeline row is the start of its hour, so the `+` on it filed a meal at 13:00 when tapped at 13:42. On, the exact time is used instead. Only for a row on today: "now" is not inside a past day, and presetting it there would move the meal rather than sharpen it. Default `false`, so nothing changes for an existing user. |

### Favourite Measurements — **wholly inert**

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| **`favouriteMeasurements`** | `FoodLogSettings` | `FavouriteMeasurementsPresenter.toggleMeasurement(_:)` | **nothing** | `feature` — corrected from `wire`. **The serving-unit picker this was to order does not exist.** A food is logged in one unit fixed by its `measurementMethod` (`IngredientAmountPresenter.unitLabel(ingredient:)` returns "g" or "ml" and nothing else offers a choice), and of the nine units on the screen only `g` and `ml` appear anywhere. Missing: a unit choice in the logger, plus the conversions behind `oz`, `cup`, `tbsp`, `tsp` and `serving`. |

### Favourites (written from the nutrition tab, not a settings screen)

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `favouriteFoodIds` | `FoodLogSettings` | `CoreInteractor.setFavouriteFood(id:isFavourite:)` | `FoodLibraryPresenter` | live |
| `favouriteRecipeIds` | `FoodLogSettings` | `CoreInteractor.setFavouriteRecipe(id:isFavourite:)` | `FoodLibraryPresenter` | live |

### Optimisation

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `quickAddEnabled` | `FoodLogSettings` | `OptimisationPresenter.quickAddEnabled` | `NutritionLibraryPickerPresenter.navToIngredientAmount(_:onPick:)`, `FoodLibraryPresenter.onFavouriteFoodPressed(_:onPick:)` | live — **wired**. The audit read this as needing a quick-add feature built. It did not: the toggle's own subtitle says "use default portion and skip the amount entry screen", and both halves already existed — `FoodModel.portionGramsCalculated` / `portionMillilitersCalculated` for the portion, and the item construction in `IngredientAmountPresenter.add`, now shared as `FoodModel.mealItem(amount:)`. Default `false`, so the amount step still shows for everyone who has not asked otherwise. |

## Nutrition Strategy Settings

`DialedIn/Managers/Nutrition/NutritionStrategySettings/Models/NutritionStrategySettings.swift` —
document `nutrition_strategy_settings`. Two screens write it.

### Strategy Settings — live in full

All six configure the weekly check-in, which now exists. See
`docs/specs/weekly-check-in.md`. They are one feature rather than six, and were built as one.

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| **`checkInWeekday`** | `NutritionStrategySettings` | `StrategySettingsPresenter.checkInWeekday` | `CheckInSchedule.state` | live — the day the card comes due, and it stays due for the rest of that week. |
| **`fastCheckIn`** | `NutritionStrategySettings` | `StrategySettingsPresenter.fastCheckInEnabled` | `CheckInPresenter.buildSteps` | live — drops the introduction and collapses the two lists to the suspicious days. |
| **`partialLoggingEnabled`** | `NutritionStrategySettings` | `StrategySettingsPresenter.partialLoggingEnabled` | `CheckInPresenter.buildSteps` | live — the step that writes `NutritionDayAnnotation.isPartiallyLogged`, which the engine reads as an excluded day. |
| **`weighInEnabled`** | `NutritionStrategySettings` | `StrategySettingsPresenter.weighInEnabled` | `CheckInPresenter.buildSteps` | live — the check-in asks for a weigh-in when the last is more than three days old. |
| **`fastingEnabled`** | `NutritionStrategySettings` | `StrategySettingsPresenter.fastingEnabled` | `CheckInPresenter.buildSteps` | live — a fasting day is a logged zero rather than a day that went missing. |
| **`loggingBreakEnabled`** | `NutritionStrategySettings` | `StrategySettingsPresenter.loggingBreakEnabled` | `CheckInPresenter.buildSteps` | live — starts and ends `LoggingBreak`, which freezes the estimate and the card. |

### Expenditure Settings — live in full

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `bmrEquation` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.bmrEquation` | `NutritionManager` (BMR calculation) | live |
| `estimationMethod` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.estimationMethod` | `NutritionStrategySettings.resolvedBMREquation(bodyFatPercentage:)` → `CoreInteractor.estimateTDEE(user:)` | live — **wired**, as the audit guessed. `.bodyFatAware` runs Cunningham 1980 (it replaced Katch-McArdle; stored as `katchMcArdle`), the one equation in the app that reads body fat, when a usable percentage is logged. `.standard`, the default, leaves `bmrEquation` alone. |
| `calculationStartDate` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.calculationStartDate` | `ExpenditureEngine` (samples before it are discarded and the replay restarts) | live — **wired** |
| `calculationMode` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.calculationMode` | `ExpenditureEngine`, `TargetProposal.make(...)` | live — **wired**. `.fixed` holds every day at the prior and suppresses the proposal; `.dynamic` runs the algorithm. |
| `algorithmVersion` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.algorithmVersion` | `ExpenditureEngine.history(...)` (the version `switch`) | live — **wired**, and still one case. It selects v1 rather than changing it, which is the seam a v2 arrives through. Not to be removed. |
| `stepInformedUpdates` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.stepInformedUpdates` | `ExpenditureEngine` (the step nowcast) | live — **wired**. Off by default, so this changes nothing for an existing user until they turn it on. |
| `predictiveGoalAdjustments` | `NutritionStrategySettings` | `ExpenditureSettingsPresenter.predictiveGoalAdjustments` | `TargetProposal.make(...)` (the rate correction) | live — **wired**. **Default `true`**, so it is on for every existing user the first time a proposal appears. |

## Analytics Settings

`DialedIn/Managers/Analytics/AnalyticsSettings/Models/AnalyticsSettings.swift` — document
`analytics_settings`.

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `hiddenSectionIds` | `AnalyticsSettings` | `CustomiseAnalyticsPresenter.setVisible(_:for:)` | `AnalyticsPresenter.isVisible(_:)` → `AnalyticsView` | live |

## Shortcut Settings

`DialedIn/Managers/Shortcuts/Models/ShortcutSettings.swift` — document `shortcut_settings`.

| Setting | Defined in | Written by | Read by | Verdict |
|---|---|---|---|---|
| `quickActionIds` | `ShortcutSettings` | `ShortcutsPresenter.apply(_:event:)` | `SearchPresenter.quickActions` → `SearchView` | live |

---

## Bugs found and fixed alongside this audit

These are defects regardless of which way the wire-or-remove decision goes, so they were fixed here
rather than left with the audit.

1. **Two screens disagreed on what an empty rest picker means.**
   `ExerciseSettingsPresenter.onRestTimerPressed()` treats 0:00 as "clear the override" and stores
   `nil`; `TimerDurationPresenter.saveExerciseEdit()` stored a literal zero-second override, which
   then showed in the override list as a row reading "0:00". `TimerDurationPresenter` now clears on
   zero, matching the other screen.

2. **Eleven settings screens wrote a stale copy of their document.**
   Each holds a snapshot of the whole settings document taken at `init` and saves the whole thing
   back, so a copy that was never refreshed reverts whatever another screen saved in the meantime.
   Five workout-settings screens had already been fixed by re-reading in `onViewAppear`; the same
   shape remained in:
   - `FoodLogSettings` (seven writers): `TimelineFoodTilesPresenter`, `LoggerFoodTilesPresenter`,
     `LoggerBannerPresenter`, `TimeSelectionPresenter`, `FavouriteMeasurementsPresenter`,
     `OptimisationPresenter`, `TimelineActionsPresenter`. This one also loses the user's favourite
     foods and recipes, which live in the same document and are written from the nutrition tab.
   - `NutritionStrategySettings` (two writers): `StrategySettingsPresenter`,
     `ExpenditureSettingsPresenter` — each reverts the other.
   - `AnalyticsSettings` and `ShortcutSettings` have one writer each, so no sibling screen can
     revert them, but a change arriving from another device while the screen sits open still can.
     `CustomiseAnalyticsPresenter` and `ShortcutsPresenter` were given the same re-read.

## What is left

Every setting whose behaviour already existed has been wired, and the three features the audit
called for have been built. What remains is one setting behind one unbuilt feature, and it should
be tracked as a feature rather than as plumbing:

1. ~~**A smart-progression engine**~~ — built. `ProgressionEngine` and `ProgressionPlanner`;
   see `docs/specs/smart-progression.md`.
2. ~~**A weekly check-in**~~ — built. `CheckInSchedule` and the `CheckIn` module;
   see `docs/specs/weekly-check-in.md`.
3. ~~**An adaptive expenditure engine**~~ — built. `ExpenditureEngine` and `TargetProposal`;
   see `docs/specs/adaptive-expenditure.md`.
4. **A unit choice in the food logger** — `favouriteMeasurements`.

Plus `premove`, which needs the product owner to say what it is before it can be sorted into any
of these.

A thin implementation of any of them would be worse than the honest gap: a control that half
works reads as finished.
