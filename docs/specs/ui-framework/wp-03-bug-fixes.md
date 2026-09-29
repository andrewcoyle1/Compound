# WP-03 · Bugs found by the audit

**Wave 1. Depends on nothing. Size: medium.**

**Goal:** fix every behavioural bug the audit found. Each fix is one `[Fix]` commit, with a
presenter or unit test that fails before the fix and passes after it where the logic is testable.
The commit message says what the user saw ("Restore Subscription did nothing").

**Owns:** only the files named below, plus their presenters, and their tests in `DialedInUnitTests/`.

**Verify before fixing.** Items marked *unverified* came from auditors reading code. Trace the call
sites first, and drop any item that turns out not to be a bug, saying why in the report.

| # | Bug | Where | Status |
|---|---|---|---|
| 1 | Restore Subscription button has an empty action | `Core/Paywalls/Paywalls/CustomPaywallView.swift:99-101`; wire to the presenter's restore method (the auditor named `onRestorePurchasePressed`; confirm the real name) | verified |
| 2 | "+" in the template detail exercises header does nothing (action commented out) | `Core/Training/Subviews/WorkoutTemplateDetail/WorkoutTemplateDetailView.swift:188-190`. Implement the add-exercise flow if the presenter or router already supports it; otherwise remove the button and report | verified |
| 3 | Subscribe can be tapped with no product selected and silently does nothing | `CustomPaywallView.swift:~94`. Disable until a product is selected | unverified |
| 4 | Paywall error title uses the background colour as its foreground, so it is invisible | `Core/Paywalls/Paywall/PaywallView.swift:18` | unverified |
| 5 | Session detail passes the exercise count as the set count, and hardcodes "kg volume" | `Core/Training/Subviews/WorkoutSessionDetail/WorkoutSessionDetailView.swift:~218` | unverified |
| 6 | `SetDetailRow` hardcodes `"%.1f kg"`, ignoring the user's unit | `Components/Views/Training/SetDetailRow.swift:36`. Use the exercise unit preference that sibling screens use | unverified |
| 7 | Rest-timer bar shows workout elapsed time under "Rest Timer" when no rest is running | `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerView.swift:~203`. Hide the bar, or relabel it, when no rest is active | unverified |
| 8 | Ingredient and recipe list-builder search-empty states can never appear: `searchText` is never bound to a search field | `Components/Views/Nutrition/IngredientListBuilder/`, `RecipeListBuilder/`. Add the missing `.searchable` if search is intended; otherwise delete the dead branch | unverified |
| 9 | Nutrition target chart swaps colours: carbs yellow, fat green | `Core/Analytics/Subviews/NutritionTargetChart/NutritionTargetChartPresenter.swift:131-134`. Use `Macro.<x>.colour` | unverified |
| 10 | Health data onboarding sets conflicting title display modes | `Core/Onboarding/4 - CompleteAccountSetup/*/HealthDataView.swift:22,29` | unverified |
| 11 | Delete-account alert has no Cancel button | `Core/Profile/**/AccountPresenter.swift:~222` | unverified |
| 12 | Swipe-to-delete a gym profile has no confirmation | `Core/Profile/**/GymProfilesView.swift:~51` | unverified |
| 13 | `Label("Warmup Set", systemImage: "")` renders an empty image when not a warmup | `SetTrackerRowView.swift:~73` | unverified |

Items 1, 3, 5, 6, 7 and 11 need tests. Items 4, 10 and 13 are view-only and need no test.

**Not in scope:**
- The `CustomLabelButtonView` chevron-only tap target. WP-06 replaces the component.
- The dead-mode CTA modifier. WP-02 deletes it.
- The hidden Finish Workout button. That is a UX change, owned by WP-09.

**Done when:** each fix is its own commit, its tests pass under `-only-testing`, and `swiftlint`
is clean.
