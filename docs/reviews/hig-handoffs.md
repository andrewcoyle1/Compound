# HIG hand-offs to feature owners (2026-09-28)

The shared-component and shell fixers could not edit feature folders. These are the exact sites
they left for whoever owns each folder. Line numbers are from when they were written and may
have moved. Paths are relative to `DialedIn/`. "F" is `hig-foundations.md`, "S" is
`hig-shell-navigation.md`; the number is the finding.

## New shared helpers to use

| Helper | Where | Use it for |
|---|---|---|
| `.tapTarget()` / `.chipTapTarget()` | `Components/DesignSystem/Chip.swift` | Any tappable label under 44 pt |
| `.rowActions(edge:allowsFullSwipe:_:)` | `Components/ViewModifiers/View+EXT.swift` | Replaces `.swipeActions`; adds the same buttons to a context menu |
| `ImageLoaderView(imageDescription:)` | `Components/Images/` | Images are hidden from VoiceOver unless described |
| `router.showDiscardChangesDialog(onDiscard:)` | `Root/RIBs/GlobalRouter.swift` | Close buttons on forms with unsaved input |
| `router.showConfirmationDialog(…)` | `Root/RIBs/GlobalRouter.swift` | Choices that were alerts with many buttons |
| `router.showDraftMealDialog(onContinue:onStartNew:)` | `Root/RIBs/` | Every "you already have a draft meal" prompt |
| `router.showAlert(title:error:)` | `Root/RIBs/GlobalRouter.swift` | Error alerts; title says what failed ("Unable to …") |
| `Double.typed(_:locale:)` | `Extensions/Double+EXT.swift` | Parsing any typed number |

## Unsaved input (S5)

Each presenter exposes `hasUnsavedChanges`. Its view adds
`.interactiveDismissDisabled(presenter.hasUnsavedChanges)`, and the close button calls
`router.showDiscardChangesDialog { router.dismissScreen() }` when the flag is set.

- `Core/Nutrition/Foods/CreateFood/CreateFoodPresenter.swift:71` (+ `CreateFoodView.swift:211`)
- `Core/Nutrition/Recipes/CreateRecipe/CreateRecipePresenter.swift:49`
- `Core/Challenges/CreateChallenge/CreateChallengePresenter.swift:102`
- `Core/Training/Subviews/AddTraining/CreateExercise/CreateExercisePresenter.swift:92`
- `Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:126-141` (+ `WorkoutSessionDetailView.swift:241`)

## Core/Training

- `TrainingView.swift:61`: remove `.background(.bar)`. (F9)
- `TrainingPresenter.swift:175`: alert used as a picker → `showConfirmationDialog`. (S8)
- `Components/ExerciseListBuilder/ExerciseListBuilderView.swift:131`, `:259`: `.glassEffect(.clear.interactive())` → `.regular.interactive()`. (F9)
- `Components/RowChipButton.swift:24-27`: `.chipTapTarget()`. (F4)
- `Components/ProgramColourIconGrid.swift:53-63`: `.tapTarget()` on the 40 pt swatch (F4); `:31`, `:45` localized colour and icon names; `:39` fewer columns at accessibility sizes (F3).
- `Components/WorkoutStreakCard/WorkoutStreakCard.swift:71-72`: use `calendar.dateInterval(of: .weekOfYear, for:)`.
- `Subviews/WorkoutTracker/WorkoutTrackerView.swift:196-236`: add a `.cancellationAction` toolbar item, `Button(role: .close) { presenter.minimizeSession() }` labelled "Minimize workout"; guard the `try?` build at `:261` (S7). `:73`: fewer grid columns at accessibility sizes (F3).
- `Subviews/WorkoutTracker/WorkoutTrackerPresenter.swift:277`: wrap the alert literals in `String(localized:)`. (F6)
- `…/SetTracker/SetTrackerPresenter.swift:243`, `:267`: → `showConfirmationDialog` (S8). `:187` and `SetTrackerRowPresenter.swift:144`: the `primaryButtonAction { router.dismissModal() }` passed to `showWarmupSetInfoModal` is dead; drop it.
- `…/SetTrackerRow/SetTrackerRowView.swift:238-252`: `.tapTarget()` on the set-complete label (F4); `:43-59` `.swipeActions` → `.rowActions` (F5).
- `…/SetTrackerRow/SetTrackerRowRouter.swift:14-55`: Set Rest → a `.sheetConfig(config: .compact)` sheet with `role: .close` and `role: .confirm`, replacing `CustomModalView`. (S4)
- `…/SetKeyboard/SetKeyboardPresenter.swift:174`, `:178`: use `Locale.current.decimalSeparator` in place of "." and parse with `Double.typed`. (F1)
- `…/MuscleGroupPicker/MuscleGroupPickerView.swift:52`, `:66`: fewer grid columns at accessibility sizes. (F3)
- `Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:202`, `:236`: wrap alert literals (F6); `:471` loading modal over a read → open at once, load with `.redacted` (S2).
- `Subviews/WorkoutTemplateDetail/WorkoutTemplateDetailPresenter.swift:98` and `Subviews/ActiveTrainingProgram/ActiveTrainingProgramPresenter.swift:214`: → `showConfirmationDialog`. (S8)
- `Subviews/ExerciseSettings/ExerciseSettingsPresenter.swift:81`: the value should be an in-row `Picker` or `Menu`, not a presentation. (S8)
- `…/ProgramDesign/ProgramDesignView.swift:55`, `:203-211`: drop the hand-drawn back chevron; `role: .close` plus `showDiscardChangesDialog`; `:207` `chevron.forward`. (S12, F10)
- `.swipeActions` → `.rowActions`: `ActiveTrainingProgram/ActiveTrainingProgramView.swift:33`, `…/CreateWorkout/DefineWorkout/DefineWorkoutView.swift:83`, `…/CreateWorkout/SetTarget/SetTargetView.swift:57`. (F5)
- `CreateWorkout/CreateWorkoutView.swift:24`, `CreateProgram/CreateProgram/CreateProgramView.swift:20`: pass `imageDescription:` or leave decorative. (F7)

## Core/Nutrition

- `NutritionView.swift:124-135`, `MealLog/AddMeal/AddMealView.swift:128`: `.rowActions`. (F5)
- `MealLog/AddMeal/AddMealView.swift:243-289`: slim the toolbar. (S17)
- `Components/MealHourHeader/MealHourHeaderView.swift:25`: add an alternative to the long-press. (F5)
- `Foods/FoodDetail/FoodDetailView.swift:154`: the 38 `LabeledContent(label, …)` nutrient labels never reach the catalog (F6); `:52` and `Recipes/RecipeDetail/RecipeDetailView.swift:43`: `imageDescription:` (F7).
- `MealLog/MealDetail/MealDetailPresenter.swift:37-40`: localize, and use `Format.grams`. (F6)
- `NutritionPresenter.swift:206`, `:227`, `:244`: `showAlert(error:)` → `showAlert(title:error:)`. (S9)
- `TimelineActions/TimelineActionsPresenter.swift:57`, `:102`: disable Copy and Clear when the day has no meals. (S16)
- `…/FoodLogSettingsPresenter.swift:134`: in-row `Picker` or `Menu`. (S8)

## Core/Dashboard

- `DashboardView.swift:88-90`: the carousel height is fixed at `contentHeight + carouselTitleHeight`; it has to grow for `DashboardCard`'s new `minHeight` to take effect. (F3)
- `DashboardPresenter.swift:368`: draft-meal alert → `showDraftMealDialog`. `DashboardPresenterTests.swift:541` then expects "Draft Meal", with the double recording `showConfirmationDialog`. (S8)
- `Components/NutritionCard.swift`: stack the ring and macro bars at accessibility sizes (F3); `:33-35` localize the literals (F6).
- `WorkoutSessionRow/WorkoutSessionRowView.swift:160-219`: move `.frame(maxWidth: .infinity)` inside the button labels. (F4)
- `WorkoutSessionRow/WorkoutSessionRowPresenter.swift:179`: loading modal over a read; put the spinner in the tapped button. (S2)
- `WorkoutSessionRow/Comments/CommentsView.swift:102-122`: `.tapTarget()` on like (F4); `:37-59` `.rowActions` plus visible Reply and Report (F5); `:86`, `:130` localize fallbacks (F6).
- `CircleActivityStripView.swift:154-160`: drop `.controlSize(.small)` (F4); `:91-93` the label is built with `+` (F6).
- `SocialProfile/FollowersList/FollowersListView.swift:40`: `.rowActions`. (F5)
- `CircleGoals/CircleLeaderboardView.swift:46`, `:66`: localize fallbacks. (F6)
- `WeeklyReview/WeeklyReviewCard.swift:25`, `WeeklyReview/WeeklyReviewView.swift:94`, `:103`: `chevron.forward` / `.backward`. (F10)

## Core/Challenges

- `ChallengesDashboardSection.swift:78` ("You"), `ChallengeDetail/ChallengeDetailView.swift:78`, `:96`: localize fallbacks (F6); `:60` `chevron.forward` (F10).
- `ChallengeRing.swift:33`: replace `minimumScaleFactor`. (F3)

## Core/Notifications

- `NotificationsView.swift:122`: drop `.controlSize(.small)` (F4); `:281` `.rowActions` (F5); `:87` copy still says "DialedIn".
- `NotificationsPresenter.swift:216`: loading modal over a read (S2); `:82`, `:125`, `:138`, `:323`, `:387`: `showAlert(title:error:)` (S9).

## Core/Profile and Core/Paywalls

- `Subviews/Account/AccountPresenter.swift:29`: parse height with `Double.typed` (F1); `:53`, `:209`, `:255`: `showAlert(title:error:)` (S9).
- `Subviews/Account/AccountView.swift:75-77`: `imageDescription:` for the profile photo. (F7)
- `ProfilePresenter.swift:99`, `:113`, `:121`: wrap the alert literals. (F6)
- `Subviews/TrainingSettings/GymProfiles/GymProfilesView.swift:43`, `:59`, `:66` and `…/RestTimerSettings/TimerDuration/TimerDurationView.swift:44`: `.rowActions`. (F5)
- `…/GymProfiles/GymProfile/GymProfileView.swift:94`, `:323-330`: keep the system back button, save on edit or in `onDisappear` (S12); `:126` `imageDescription:` (F7).
- `Subviews/GeneralSettings/Integrations/IntegrationsPresenter.swift:49`: success → `interactor.showAppToast(AppToast(style: .success, …))`. (S16)
- `Core/Paywalls/Paywall/PaywallPresenter.swift:70`, `:126`, `:155`: `showAlert(title:error:)`. (S9)

## Core/Onboarding

- `0 - WelcomeView/WelcomeView.swift:58`: pass `isLoading:` while there is no `currentUser`. (S10)
- `2 - AuthView/AuthPresenter.swift:66`, `:107` and `4 - CompleteAccountSetup/9 - Expenditure/ExpenditurePresenter.swift:245`: add `role: .cancel`.
- `5 - HealthDisclaimer/HealthDisclaimerRouter.swift:20-40`: replace `CustomModalView` with `router.showAlert`; localize the consent text and both buttons; "DialedIn" → "Compound". (S4, F6)

## Core/Analytics

- `Subviews/BodyMetrics/ProgressPhotos/ProgressPhotosView.swift:115` and `ProgressPhotoCompareView.swift:53`: `imageDescription:` (pose and date) (F7); `:78-94` add `ToolbarSpacer(.fixed, placement: .topBarTrailing)`, `:73` move close to `.cancellationAction` (S17).
- `Subviews/InsightsAndAnalytics/EnergyBalance/EnergyBalancePresenter.swift:45`: draft-meal alert → `showDraftMealDialog`. (S8)
- `Subviews/BodyMetrics/LogMeasurement/LogWeightView/LogWeightPresenter.swift:77`: `showAlert(title:error:)`. (S9)

## Core/AppView (shell owner, second pass)

- `AppViewBuilder.swift:20-26`: `.reducedMotionAnimation(.standard, value: activeModuleId)`, opacity transition under Reduce Motion. (F11)
- `ActivityNotificationBannerView.swift:35`, `:37`: localize the English fallbacks. (F6)

## App-wide

- The remaining `showAlert(error:)` sites (32 in total) → `showAlert(title: String(localized: "Unable to …"), error:)`. (S9)
- The remaining bare-literal alert titles across 17 files → `String(localized:)`, title-cased. (F6)
- The report flow's noun ("workout", "comment", "profile") is passed in as an English literal, so Spanish shows the English noun.

## Outside Core (central, not an area)

- `Root/LaunchScreen.storyboard`: a single `systemGroupedBackground` view, no image and no label. (F8, S11)
- `.swiftlint.yml`: a custom rule for bare `.animation(` that excludes `ReducedMotionViewModifier.swift`. (F11)
- Delete `Components/Modals/CustomModalView.swift` once Health Disclaimer, Set Rest and the ratings card have moved off it. (S4)

## Unverified, needs a device

- A toast raised while a sheet is up may appear behind it, because the overlay is on the root view.
- The navigation and tab bars may still be tappable above the loading overlay.
- Calendar month titles no longer stay pinned while scrolling.

## From the second batch (profile, active workout, training library)

### Managers and root (central, not an area)

- **Account deletion does not revoke the Sign in with Apple token.**
  `Root/RIBs/Core/CoreInteractor.swift:237` passes `revokeToken: false`. Do not simply switch it
  on: in the `SwiftfulAuthenticatingFirebase` fork, `deleteAccountWithReauthentication` removes
  the user document first and revokes second, so a failed revocation would leave a half-deleted
  account. Fix the fork first (wrap the revocation in `do/catch`, log, carry on to
  `user.delete()`), then pass `revokeToken: auth.authProviders.contains(.apple)`.
- **Strava** (`Managers/Strava/StravaManager.swift`): make `isConnected` a stored property set in
  `storeTokens` and `disconnect`; call `disconnect()` from `CoreInteractor.signOut()` and
  `deleteAccount()`; deauthorize at Strava (`POST /oauth/deauthorize`); rename the test activity
  "DialedIn Test Upload" to Compound.
- **Rating**: add an App Store ID to `Utilities/Constants.swift` once the listing exists and open
  the write-review URL from `ProfilePresenter.onRatingsButtonPressed`. `CoreRouter.showRatingsModal`
  and `CoreBuilder.ratingsModal` have no caller from Profile any more; delete them if nothing
  else uses them.
- `Root/RIBs/Core/CoreRouter.swift:19`: `showWarmupSetInfoModal`'s `primaryButtonAction` parameter
  is now always `{ }`. Remove it from `CoreRouter`, `SetTrackerRouter`, `SetTrackerRowRouter` and
  the test doubles.
- `Components/DesignSystem/Symbols.swift`: add `Symbol.distance`. The Distance Unit row borrows
  `Symbol.cardio`.
- `Components/Views/DashboardCard.swift`: `contentHeight` is still fixed, so the Training today
  card can clip at accessibility sizes.
- The catalog string "Unable to add" is now unused.

### Packages

- **SwiftfulPurchasing fork**: make `StoreKitPurchaseService.Error` public with a distinct
  `pending` case. `PaywallPresenter.outcome(of:)` matches the error by case name until then.
- **QuickCharts**: see the items marked "needs a package change" in `hig-analytics-charts.md`.

### Assumptions to check when the unit suite runs

- The paywall tests build `NSError(domain: "RevenueCat.ErrorCode", …)` by hand.
- The Food Log hour test strips the narrow no-break space iOS puts before AM/PM.

### Unverified, needs a device

- The set tracker's new control sizes and column widths (Set and Done 44 pt, Prev 78 pt).
- The set keyboard's background and sizing.
- The Live Activity's tinted look, and that tapping it opens the tracker.

## From the third batch (analytics, dashboard and social, onboarding)

### Shared components (central)

- `Components/Views/AnalyticsCard.swift`, `AnalyticsSection.swift`: card titles truncate to one
  line; the card's VoiceOver label is built from its children.
- `Components/Views/Charts/MacroStackedBarChart.swift`: add `Spacing.xxs` between stacked segments,
  which differ by colour alone.
- `Components/Views/MetricDetailView.swift`: `MetricDetailPresenter` needs `isLoading` so eight
  analytics screens can show a loading state.
- `Components/Models/MetricConfiguration.swift` and `TimeSeries(name:)` take plain `String`, so
  about seventy chart labels never reach the string catalog. Change the type, not the call sites.
- `Components/Views/User/UserRowView.swift`: Follow, Accept and Decline use `.controlSize(.small)`.
- `Utilities/UnitConversion.swift:59`: `String(format:)` ignores the region's decimal separator.

### Managers, root and backend

- `Managers/Nutrition/NutritionManager/NutritionManager.swift:176` clamps height to 120...260 cm;
  the onboarding expenditure screen now clamps to 100...260 to match the height wheel. Someone
  between 100 and 119 cm sees one figure in onboarding and another afterwards. Align the manager.
- `Root/AppDelegate.swift:134-140`: every push shows a banner and plays a sound in the foreground.
- `Managers/Push/PushManager.swift` and `functions/lib.js`: notification copy (capitalization,
  emoji, no Spanish, generic titles).
- `Root/RIBs/FollowFlow.swift:83-85` and `Managers/Invites/CoreInteractor+Invites.swift:73-74`,
  `:92`: alert titles and literals not localized.
- Shared volume in the feed is always kilograms, whatever the reader's unit preference.

### Not reached in Core/Onboarding

- `Components/WeeklyMacroChart.swift`: hard-coded "Mon"…"Sun".
- `8 - OnboardingDiet/6 - DietPlan/DietPlanView.swift`: `rawValue.capitalized` shown as labels.
- The goal-summary alert has nowhere to route back to the weight step.

### Needs review by a person

- The Spanish for the two health consent texts is marked `needs_review` in the catalog.
- 113 catalog entries are `stale`. Check each is unused before deleting, because
  `CustomModalView` looks some titles up at runtime.

## From building the decisions (2026-09-29)

### Still to connect or finish

Connected since this list was first written: the meal and streak reminder offers, the pushes
inside the Notifications sheet, Strava after the first finished workout, paused time (app and
the shared page), the rest-over distance unit, the tenths wheel in the weekly check-in, and the
Close button on pushed metric detail screens, and Decision 6 on every tab: Food, Recipe,
Meal, Exercise and Workout Session detail, Weekly Review and the Workouts list push. The summary
after finishing a workout is pushed inside the tracker's cover as its last page, with Back hidden
and Done closing the cover. Saving a session's notes now stays on the screen. Weekly Goal is an
edit form, so it stays a sheet. The functions were deployed on 29 Sep 2026.

Still open:

- **Decision 11a, second step**: editing a finished workout's sets and exercises. Only
  "Edit Notes" is built; the editing code is kept behind a TODO.
- **Decision 12e, Time Sensitive**: the entitlement is left out until the capability is enabled
  for the App ID (see the release checklist). Until then "Rest Complete" is delivered as active.
- **W1 is unverified.** `UIBackgroundModes` = `processing` follows Apple's iOS 26 workout sample
  project; Apple's documentation does not name a background mode for iPhone workouts. Test a
  rest with the phone locked.
- `Components/Views/EnumPicker/` and `CoreRouter.showEnumPickerView` have no caller now.
- `DialedInUITests/CreateExerciseUITests.swift` taps `EnumPicker.Reps`, which is now a menu item.
- Health consent: the second toggle and both document links sit below the fold, under the
  Continue button. Check on a device that they scroll clear of it.

### Questions the builders raised for the owner

- A subscriber whose subscription lapses while using the app is not sent to the paywall.
- On the paywall, Sign Out and Account are in a toolbar menu, not visible buttons.
- Price wording: "$9.99 / 1 month" from the system, or a hand-written "$9.99 a month".
- Profile's "Rate Compound" row triggers the system prompt from a button, which Apple advises
  against. Hide it until there is an App Store ID to link to.
- Subscription status reads "Active" / "Inactive"; "Active" is also an activity level.
- The streak reminder stops for existing users who never turned it on.
