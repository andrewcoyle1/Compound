# List vs Form, and iPad/Mac wide layouts — 1 Oct 2026

Checked: iPad Pro 13-inch (M5) simulator in portrait (1032 pt), light and dark; Mac Catalyst
Mock build at its default 1024×768 window, in the dark appearance. Default text size only. Every
`STARTSCREEN_*` screen in `AppViewForUITesting.swift` (65) was captured before and after.

## List or Form

The contract's rule (`wave-3-checklist.md`): settings use `List`, `Form` is for pure data entry.
Read as: **`Form` when every row is an input and the screen ends in one confirm or CTA**.
Everything else stays a `List`: settings (toggles that save as you go), feeds, libraries,
pickers, details, and editable collections (swipe-to-delete or reorder rows).

Converted to `Form` (26):

| Area | Screens |
|---|---|
| Gym profile editors | `AddBand`, `AddBodyWeight`, `AddFixedWeightBar`, `AddFreeWeight`, `AddLoadableBar`, `AddCableMachineRange`, `AddPinLoadedMachineRange`, `EditWeightRange`, `CreateGymProfile` |
| Naming and goals | `EditUsername`, `NameMesocycle`, `NameWorkout`, `SetTarget`, `WeeklyGoal` |
| Logging | `LogMeasurement`, `LogWeight` |
| Amount sheets (all four, per WP-08) | `IngredientAmount`, `RecipeAmount`, `RecipeIngredientAmount`, `MealItemAmountView` |
| Create flows | `FoodItemQuickAdd`, `CreateFood`, `FoodDefinition`, `PortionDefinition`, `CreateExercise`, `FinalExerciseDetails` |

Already `Form` and correct: `RenameDayPlan`, `CreateChallenge`, `WorkoutSessionTimingSheets`,
`InviteCodeSheet`, the barcode manual-entry sheet.

Deliberately left as `List`, though they hold inputs:

- Settings (`NotificationSettings`, `WorkoutSettings`, `FoodLogSettings`, `RestTimerSettings`,
  `StrategySettings`, `ExpenditureSettings`, `Units`, …): the contract puts settings in `List`.
- `AccountView`: a settings screen with navigation rows and sign-out, not one form.
- `CreateRecipe`, `RecipePreparation`: their ingredient and step rows are an editable collection.
- `FoodPackaging`: photo buttons, no inputs. `CheckIn`: each step is a set of choices.
- `MacrocycleDetail`, `GymProfile`, `DevSettings`: mixed editors over a collection.

## Wide layouts

### Fixed

| Severity | Where | Finding | Fix |
|---|---|---|---|
| Crash | Mac, every `showScreen(.fullScreenCover)` (workout tracker, create flows, add meal, paywall) | `Fatal error: No ObservableObject of type RouterViewModel found`. Catalyst does not carry environment objects into a presentation. | SwiftfulRouting fork: sheet and cover content get `.environmentObject(viewModel)`. |
| Crash | iPad, `MuscleGroupPickerView` | UIKit assertion in `-[UICollectionView _updateVisibleCellsNow:]`: tiles sized by the loaded image's intrinsic ratio never settled at iPad widths. | Tiles are a fixed square (`MuscleGroupPickerView.swift:103`). |
| Collision | Mac, `CustomPaywallView` | Catalyst draws no scroll-edge effect under the bottom `safeAreaBar` (`.hard` included), so the Included rows read through the renewal line and the Subscribe button. | The bar gets a `Color.canvas` backdrop on Catalyst only. |
| Layout | Every screen, iPad and Mac | Rows, cards, charts and bottom CTAs stretch the full width: labels sit 900 pt from their values, the Progress target grid and Today's macro bars blow up, CTAs run edge to edge. | Each routed screen wider than `ContentWidth.readable` (700 pt) pads its horizontal safe area to centre a 700 pt column (SwiftfulRouting fork, `readableContentWidth`, set once in `CompoundApp`). Backgrounds and full-bleed heroes still reach the edges; `.bottomCTA` follows the column; a sheet measures itself, so it is not squeezed by a wider presenter. |

The HIG basis: the system's layout guides exist to "apply standard margins around content and
restrict the width of text for optimal readability", and "windows can be very wide and short or
tall and narrow" (https://developer.apple.com/design/human-interface-guidelines/layout, read
through the `apple-hig` skill, iPadOS).

### Not fixed

- The large navigation title stays at the leading edge while content is centred. That is the
  system's behaviour (Settings on iPad does the same).
- The custom set keyboard (`SET_KEYBOARD`) spans the full width, as the system keyboard does.
- Dashboards (Today, Progress) are now a single 700 pt column. A two-column layout at regular
  width would use the space better; that is a design change, not a fix.
- Mac: the create-flow covers' close button sits against the window's leading edge, with the
  traffic lights drawn over the full-bleed hero. Unchanged by this pass.
- The Mac window title reads "Compound - Dev" in the Mock build.
- The deck harness: the mock scenario's rest timer asks for notification permission, and its
  alert lands on some captures.
