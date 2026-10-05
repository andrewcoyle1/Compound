# Analytics coverage audit

5 Oct 2026, `development` at `a76358e6`. Every `*Presenter` class in `Compound/` (201) was read by
a script, which:

- classifies a module as a **screen** if a `CoreRouter.show…` that something actually calls
  presents it, or it is a tab root, and as a **component** if a parent's `CoreBuilder` function
  builds it inline. Seven modules are both.
- for screens, checks that the presenter has `onViewAppear`/`onViewDisappear`, that each one
  tracks an event, and that the view calls it.
- for every presenter function containing `try`, checks for `…Start`, `…Success` and
  `…Fail` events, following the existing convention (`AddMealView_SaveMeal_Start`, Fail carrying
  `error.eventParameters` at `.severe`).

It is a static read. A function whose events are logged by its caller shows up here as a gap.

## Summary

| | Covered | Total |
|---|---|---|
| Screens logging Appear | 106 | 172 |
| Screens logging Disappear | 87 | 172 |
| Throwing operations with Start + Success + Fail | 42 | 170 |
| Throwing operations with no event at all | 66 | 170 |
| `try?` sites whose failures are never logged | 0 | 31 |

The biggest blind spots, in order of how much they hide:

1. **Onboarding has no funnel.** 21 of the 23 steps (Auth, Subscription, Health Disclaimer, every
   account-setup and goal question, Completed) log no Appear, so it is impossible to see where
   people drop out. 20 of them log `_Navigate` when leaving, which shows who got past a step but
   not who reached it.
2. **The workout loop is dark.** `WorkoutTracker`, `WorkoutSessionDetail`,
   `WorkoutTemplateDetail`, `Workouts`, `Exercises` and the session editors log no screen
   events. `startWorkout`, `attemptSave` (finishing a workout), `saveWorkoutProgress` and
   `deleteWorkout` log no Start, Success or Fail.
3. **Progress screens.** 20 screens under `Core/Analytics` log no Appear or no Disappear, among
   them both loggers (`LogWeight`, `LogMeasurement`). Saving a weight or measurement logs nothing.
4. **The food logger is counted by its parts.** `NutritionLibraryPicker`, the screen people log
   food from, logs no Appear. Its embedded tabs (`FoodLibrary`, `FoodItemSearch`, `MealDescribe`,
   `FoodPhotoScanner`, `BarcodeScanner`, `FoodItemQuickAdd`) each log their own `_Appear`, so
   screen counts there are inflated and attributed to the wrong place.
5. **Social writes.** Likes, comments, nudges, follow responses, block and unblock,
   `removeFollower` and every `load…` fetch log nothing on failure.

## Decisions needed before filling the gaps

- **Components that are also screens** (`NameMesocycle`, `BarcodeScanner`,
  `IngredientListBuilder`): their Appear should fire only when routed. Proposal: an
  `isEmbedded` flag on the delegate, set by the parent's builder, with the presenter skipping
  screen events when it is set.
- **Embedded components' own Appear/Disappear** (table below): remove them, and log a
  `…_Tab_Selected` (or similar) on the parent where the component is a tab.
- **Disappear fires when a screen is covered by a push**, not only when it is dismissed. That
  is SwiftUI's `onDisappear`. If session time per screen matters, add `scenePhase` handling or
  accept the noise. It does not fire under a sheet.
- **Read operations** (`load…`, `fetch…`): log Fail only, not Start and Success, or the event
  volume triples for no insight.

## Unused routes

`showShortcutsView`, `showEnumPickerView` and `showAddIngredientView` have no callers, so
`ShortcutsPresenter`, `EnumPickerPresenter` and `AddFoodPresenter` may be dead modules. Check
before adding logging to them.

## Screens missing Appear or Disappear


**Analytics**

| Presenter | Appear | Disappear |
|---|---|---|
| [`LogMeasurementPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogMeasurementPresenter.swift) | missing | missing |
| [`LogWeightPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView/LogWeightPresenter.swift) | missing | missing |
| [`BodyMeasurementDetailPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/MeasurementDetails/BodyMeasurementDetail.swift) | missing | missing |
| [`BodyRatioPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/MeasurementDetails/BodyRatioMetric.swift) | missing | missing |
| [`VisualBodyFatPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/MeasurementDetails/VisualBodyFatMetric.swift) | missing | missing |
| [`ProgressPhotosPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/ProgressPhotos/ProgressPhotosPresenter.swift) | ok | missing |
| [`ScaleWeightPresenter`](../../Compound/Core/Analytics/Subviews/BodyMetrics/ScaleWeight/ScaleWeightPresenter.swift) | missing | missing |
| [`ExerciseDetailPresenter`](../../Compound/Core/Analytics/Subviews/ExerciseAnalytics/ExerciseDetail/ExerciseDetailPresenter.swift) | missing | missing |
| [`FoodLoggingConsistencyPresenter`](../../Compound/Core/Analytics/Subviews/FoodLoggingConsistency/FoodLoggingConsistencyPresenter.swift) | missing | missing |
| [`EnergyBalancePresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/EnergyBalance/EnergyBalancePresenter.swift) | missing | missing |
| [`ExpenditureDetailPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/ExpenditureDetail/ExpenditureDetailPresenter.swift) | missing | missing |
| [`GoalProgressPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/GoalProgress/GoalProgressPresenter.swift) | missing | missing |
| [`MuscleGroupDetailPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/MuscleGroupDetail/MuscleGroupDetailPresenter.swift) | missing | missing |
| [`StepsPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/Steps/StepsPresenter.swift) | missing | missing |
| [`WeightTrendPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/WeightTrend/WeightTrendPresenter.swift) | missing | missing |
| [`WorkoutPresenter`](../../Compound/Core/Analytics/Subviews/InsightsAndAnalytics/Workouts/WorkoutPresenter.swift) | missing | missing |
| [`MuscleBalancePresenter`](../../Compound/Core/Analytics/Subviews/MuscleBalance/MuscleBalancePresenter.swift) | ok | missing |
| [`NutritionMetricDetailPresenter`](../../Compound/Core/Analytics/Subviews/NutritionAnalytics/NutritionMetricDetail/NutritionMetricDetailPresenter.swift) | missing | missing |
| [`WeighInConsistencyPresenter`](../../Compound/Core/Analytics/Subviews/WeighInConsistency/WeighInConsistencyPresenter.swift) | missing | missing |
| [`WorkoutConsistencyPresenter`](../../Compound/Core/Analytics/Subviews/WorkoutConsistency/WorkoutConsistencyPresenter.swift) | missing | missing |

**Challenges**

| Presenter | Appear | Disappear |
|---|---|---|
| [`ChallengeDetailPresenter`](../../Compound/Core/Challenges/ChallengeDetail/ChallengeDetailPresenter.swift) | ok | missing |
| [`CreateChallengePresenter`](../../Compound/Core/Challenges/CreateChallenge/CreateChallengePresenter.swift) | ok | missing |

**Components**

| Presenter | Appear | Disappear |
|---|---|---|
| [`CalendarPresenter`](../../Compound/Components/Views/CalendarHeader/Calendar/CalendarPresenter.swift) | missing | missing |

**Notifications**

| Presenter | Appear | Disappear |
|---|---|---|
| [`NotificationSettingsPresenter`](../../Compound/Core/Notifications/NotificationSettings/NotificationSettingsPresenter.swift) | ok | missing |

**Nutrition**

| Presenter | Appear | Disappear |
|---|---|---|
| [`FoodsPresenter`](../../Compound/Core/Nutrition/Foods/FoodsPresenter.swift) | missing | missing |
| [`IngredientAmountPresenter`](../../Compound/Core/Nutrition/MealLog/IngredientAmount/IngredientAmountPresenter.swift) | no event | missing |
| [`MealDetailPresenter`](../../Compound/Core/Nutrition/MealLog/MealDetail/MealDetailPresenter.swift) | ok | missing |
| [`NutritionLibraryPickerPresenter`](../../Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/NutritionLibraryPickerPresenter.swift) | missing | missing |
| [`RecipeAmountPresenter`](../../Compound/Core/Nutrition/MealLog/RecipeAmount/RecipeAmountPresenter.swift) | missing | missing |
| [`CreateRecipePresenter`](../../Compound/Core/Nutrition/Recipes/CreateRecipe/CreateRecipePresenter.swift) | missing | missing |
| [`RecipeIngredientAmountPresenter`](../../Compound/Core/Nutrition/Recipes/CreateRecipe/RecipeIngredientAmount/RecipeIngredientAmountPresenter.swift) | missing | missing |
| [`RecipeDetailPresenter`](../../Compound/Core/Nutrition/Recipes/RecipeDetail/RecipeDetailPresenter.swift) | no event | missing |
| [`RecipeStartPresenter`](../../Compound/Core/Nutrition/Recipes/RecipeStart/RecipeStartPresenter.swift) | missing | missing |

**Onboarding**

| Presenter | Appear | Disappear |
|---|---|---|
| [`AuthPresenter`](../../Compound/Core/Onboarding/2%20-%20AuthView/AuthPresenter.swift) | missing | missing |
| [`SubscriptionPresenter`](../../Compound/Core/Onboarding/3%20-%20Subscription/SubscriptionPresenter.swift) | missing | missing |
| [`NamePhotoPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/1%20-%20NamePhoto/NamePhotoPresenter.swift) | missing | missing |
| [`DateOfBirthPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/3%20-%20DateOfBirth/DateOfBirthPresenter.swift) | missing | missing |
| [`HeightPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/4%20-%20Height/HeightPresenter.swift) | missing | missing |
| [`WeightPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/5%20-%20Weight/WeightPresenter.swift) | missing | missing |
| [`ExerciseFrequencyPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/6%20-%20ExerciseFrequency/ExerciseFrequencyPresenter.swift) | missing | missing |
| [`ActivityPresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/7%20-%20Activity/ActivityPresenter.swift) | missing | missing |
| [`ExpenditurePresenter`](../../Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/9%20-%20Expenditure/ExpenditurePresenter.swift) | missing | missing |
| [`HealthDisclaimerPresenter`](../../Compound/Core/Onboarding/5%20-%20HealthDisclaimer/HealthDisclaimerPresenter.swift) | missing | missing |
| [`OverarchingObjectivePresenter`](../../Compound/Core/Onboarding/6%20-%20GoalSetting/1%20-%20OverarchingObjective/OverarchingObjectivePresenter.swift) | missing | missing |
| [`TargetWeightPresenter`](../../Compound/Core/Onboarding/6%20-%20GoalSetting/2%20-%20TargetWeight/TargetWeightPresenter.swift) | missing | missing |
| [`WeightRatePresenter`](../../Compound/Core/Onboarding/6%20-%20GoalSetting/3%20-%20WeightRate/WeightRatePresenter.swift) | missing | missing |
| [`GoalSummaryPresenter`](../../Compound/Core/Onboarding/6%20-%20GoalSetting/4%20-%20GoalSummary/GoalSummaryPresenter.swift) | missing | missing |
| [`PreferredDietPresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/1%20-%20PreferredDiet/PreferredDietPresenter.swift) | missing | missing |
| [`CalorieFloorPresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/2%20-%20CalorieFloor/CalorieFloorPresenter.swift) | missing | missing |
| [`CalorieDistributionPresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/4%20-%20CalorieDistribution/CalorieDistributionPresenter.swift) | missing | missing |
| [`ProteinIntakePresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/5%20-%20ProteinIntake/ProteinIntakePresenter.swift) | missing | missing |
| [`DietPlanPresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/6%20-%20DietPlan/DietPlanPresenter.swift) | missing | missing |
| [`CustomisingDietProgramPresenter`](../../Compound/Core/Onboarding/8%20-%20OnboardingDiet/CustomisingDietProgramPresenter.swift) | missing | missing |
| [`OnboardingCompletedPresenter`](../../Compound/Core/Onboarding/9%20-%20OnboardingCompleted/OnboardingCompletedPresenter.swift) | missing | missing |

**Profile**

| Presenter | Appear | Disappear |
|---|---|---|
| [`ProfilePresenter`](../../Compound/Core/Profile/ProfilePresenter.swift) | missing | missing |
| [`DeleteAccountPresenter`](../../Compound/Core/Profile/Subviews/Account/DeleteAccount/DeleteAccountPresenter.swift) | ok | missing |
| [`EditUsernamePresenter`](../../Compound/Core/Profile/Subviews/Account/EditUsername/EditUsernamePresenter.swift) | ok | missing |
| [`FavouriteMeasurementsPresenter`](../../Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements/FavouriteMeasurementsPresenter.swift) | ok | missing |
| [`LoggerBannerPresenter`](../../Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerBanner/LoggerBannerPresenter.swift) | ok | missing |
| [`LoggerFoodTilesPresenter`](../../Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles/LoggerFoodTilesPresenter.swift) | ok | missing |
| [`TimelineFoodTilesPresenter`](../../Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles/TimelineFoodTilesPresenter.swift) | ok | missing |

**Sharing**

| Presenter | Appear | Disappear |
|---|---|---|
| [`ShareToFollowerPresenter`](../../Compound/Core/Sharing/ShareToFollower/ShareToFollowerPresenter.swift) | ok | missing |
| [`SharedItemPresenter`](../../Compound/Core/Sharing/SharedItem/SharedItemPresenter.swift) | ok | missing |

**Social**

| Presenter | Appear | Disappear |
|---|---|---|
| [`WeeklyGoalPresenter`](../../Compound/Core/Social/CircleGoals/WeeklyGoal/WeeklyGoalPresenter.swift) | ok | missing |
| [`FollowersListPresenter`](../../Compound/Core/Social/SocialProfile/FollowersList/FollowersListPresenter.swift) | missing | missing |
| [`CommentsPresenter`](../../Compound/Core/Social/WorkoutSessionRow/Comments/CommentsPresenter.swift) | no event | missing |

**TabBar**

| Presenter | Appear | Disappear |
|---|---|---|
| [`TabBarPresenter`](../../Compound/Core/TabBar/TabBarPresenter.swift) | no event | missing |

**Today**

| Presenter | Appear | Disappear |
|---|---|---|
| [`WeeklyReviewPresenter`](../../Compound/Core/Today/WeeklyReview/WeeklyReviewPresenter.swift) | ok | missing |

**Training**

| Presenter | Appear | Disappear |
|---|---|---|
| [`EditDayOrderPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDayOrder/EditDayOrderPresenter.swift) | missing | missing |
| [`EditDeloadPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDeload/EditDeloadPresenter.swift) | missing | missing |
| [`EditMesocycleColourIconPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditMesocycleColourIcon/EditMesocycleColourIconPresenter.swift) | missing | missing |
| [`RenameWorkoutTemplateModelPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/RenameDayPlan/RenameDayPlanPresenter.swift) | missing | missing |
| [`ExercisesPickerPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateWorkout/ExercisesPicker/ExercisesPickerPresenter.swift) | missing | missing |
| [`NameWorkoutPresenter`](../../Compound/Core/Training/Subviews/AddTraining/CreateWorkout/NameWorkout/NameWorkoutPresenter.swift) | missing | missing |
| [`ExerciseModelDetailPresenter`](../../Compound/Core/Training/Subviews/Exercises/ExerciseTemplateDetail/ExerciseTemplateDetailPresenter.swift) | no event | missing |
| [`ExercisesPresenter`](../../Compound/Core/Training/Subviews/Exercises/ExercisesPresenter.swift) | missing | missing |
| [`MacrocycleDetailPresenter`](../../Compound/Core/Training/Subviews/Macrocycles/MacrocycleDetail/MacrocycleDetailPresenter.swift) | ok | missing |
| [`MacrocyclesPresenter`](../../Compound/Core/Training/Subviews/Macrocycles/MacrocyclesPresenter.swift) | ok | missing |
| [`PrebuiltMesocycleDetailPresenter`](../../Compound/Core/Training/Subviews/MesocycleLibrary/PrebuiltMesocycleDetail/PrebuiltMesocycleDetailPresenter.swift) | ok | missing |
| [`WorkoutSessionDetailPresenter`](../../Compound/Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift) | missing | missing |
| [`WorkoutTemplateDetailPresenter`](../../Compound/Core/Training/Subviews/WorkoutTemplateDetail/WorkoutTemplateDetailPresenter.swift) | missing | missing |
| [`WorkoutNotesPresenter`](../../Compound/Core/Training/Subviews/WorkoutTracker/WorkoutNotes/WorkoutNotesPresenter.swift) | missing | missing |
| [`WorkoutTrackerPresenter`](../../Compound/Core/Training/Subviews/WorkoutTracker/WorkoutTrackerPresenter.swift) | missing | missing |
| [`WorkoutsPresenter`](../../Compound/Core/Training/Subviews/Workouts/WorkoutsPresenter.swift) | missing | missing |
| [`TrainingPresenter`](../../Compound/Core/Training/TrainingPresenter.swift) | not called | not called |

## Embedded components that log screen events

| Presenter | Embedded in |
|---|---|
| `InactiveMesocyclePresenter` | MesocycleManagementView |
| `MesocycleDisclosureGroupPresenter` | InactiveMesocycleView, MesocycleManagementView |
| `SetTrackerRowPresenter` | SetTrackerView, WarmupSetsView |
| `ActiveMesocyclePresenter` | TrainingView |
| `DefineWorkoutPresenter` | DefineWorkoutWrapperView, MesocycleDesignView |
| `NameMesocyclePresenter` (also routed as a screen) | CreateMesocycleView |
| `ExerciseListBuilderPresenter` | ExercisesPickerView, ExercisesView |
| `ShortcutsPresenter` | nothing: its only route is unused |
| `FoodItemQuickAddPresenter` | NutritionLibraryPickerView |
| `MealDescribePresenter` | NutritionLibraryPickerView |
| `BarcodeScannerPresenter` (also routed as a screen) | NutritionLibraryPickerView |
| `FoodItemSearchPresenter` | NutritionLibraryPickerView |
| `FoodPhotoScannerPresenter` | NutritionLibraryPickerView |
| `FoodLibraryPresenter` | NutritionLibraryPickerView |
| `IngredientListBuilderPresenter` (also routed as a screen) | FoodLibraryView, FoodsView |
| `RecipeListBuilderPresenter` | FoodLibraryView, RecipesView |
| `EnumPickerPresenter` | nothing: its only route is unused |


## Throwing operations without Start / Success / Fail

`S`, `O`, `F` = Start, Success, Fail logged; `-` = missing. *untracked* = no event of any kind in the function.


**Analytics**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `AnalyticsPresenter` | `loadMacrosData` | `--- *untracked*` | getDailyTotals |
| `AnalyticsPresenter` | `loadDailyTarget` | `--- *untracked*` | getDailyTarget |
| `LogMeasurementPresenter` | `saveMeasurement` | `--- *untracked*` | saveBodyMeasurement |
| `LogWeightPresenter` | `saveWeight` | `--- *untracked*` | saveBodyMeasurement, updateWeight |
| `BodyMeasurementDetailPresenter` | `onDeleteEntry` | `--- *untracked*` | saveBodyMeasurement |
| `VisualBodyFatPresenter` | `onDeleteEntry` | `--- *untracked*` | saveBodyMeasurement |
| `ProgressPhotosPresenter` | `onLibraryItemChanged` | `--- *untracked*` |  |
| `ProgressPhotosPresenter` | `onDeleteConfirmed` | `-OF` | deleteProgressPhoto |
| `ScaleWeightPresenter` | `onDeleteEntry` | `--F` | saveBodyMeasurement |
| `HabitsPresenter` | `loadFoodLoggingData` | `--- *untracked*` | getDailyTotals |
| `InsightsAndAnalyticsPresenter` | `loadMacrosData` | `--- *untracked*` | getDailyTotals |
| `StepsPresenter` | `loadData` | `--- *untracked*` | canRequestHealthDataAuthorisation, requestHealthKitAuthorisation, syncStepsFromHealthKit |
| `StepsPresenter` | `onAddPressed` | `--- *untracked*` | canRequestHealthDataAuthorisation, requestHealthKitAuthorisation, syncStepsFromHealthKit |
| `WeightTrendPresenter` | `onDeleteEntry` | `--- *untracked*` | saveBodyMeasurement |
| `NutritionAnalyticsPresenter` | `loadData` | `--- *untracked*` | getDailyNutritionBreakdown, getDailyTarget, getDailyTotals |
| `NutritionAnalyticsPresenter` | `loadMacrosLast7Days` | `--- *untracked*` | getDailyTotals |
| `WeighInConsistencyPresenter` | `onDeleteEntry` | `--- *untracked*` | saveBodyMeasurement |

**DevSettings**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `DevSettingsPresenter` | `updateTest` | `--- *untracked*` | override |
| `DevSettingsPresenter` | `fetchSessionFromFirebase` | `--- *untracked*` | getWorkoutSession |

**Notifications**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `NotificationSettingsPresenter` | `checkPermissions` | `--- *untracked*` | checkPushNotificationAuthorisation |
| `NotificationSettingsPresenter` | `onRequestNotificationsPressed` | `--- *untracked*` | requestPushAuthorisation |
| `NotificationSettingsPresenter` | `onSocialPushToggled` | `---` | updateSocialNotificationPreferences |
| `NotificationSettingsPresenter` | `updateScheduledPush` | `--- *untracked*` | updatePrivateUserSettings |
| `NotificationSettingsPresenter` | `save` | `--- *untracked*` |  |
| `NotificationsPresenter` | `loadNotifications` | `--- *untracked*` | clearAllDeliveredNotifications, fetchActivityNotifications, markActivityNotificationsRead |
| `NotificationsPresenter` | `onNotificationDeleted` | `--F` | deleteActivityNotification |
| `NotificationsPresenter` | `onFollowBackPressed` | `---` | getUser |
| `NotificationsPresenter` | `respond` | `---` | respondToFollowRequest |
| `NotificationsPresenter` | `onNotificationPressed` | `---` | fetchChallenge, fetchShare, fetchWorkoutSession, getUser |
| `NotificationsPresenter` | `onLoadMorePressed` | `---` | fetchMoreActivityNotifications |

**Nutrition**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `CheckInPresenter` | `onLogWeightPressed` | `---` | saveBodyMeasurement, updateWeight |
| `CheckInPresenter` | `onStartLoggingBreakPressed` | `---` | startLoggingBreak |
| `CheckInPresenter` | `onEndLoggingBreakPressed` | `---` | endLoggingBreak |
| `CheckInPresenter` | `onAcceptProposalPressed` | `---` | acceptTargetProposal |
| `CheckInPresenter` | `save` | `--- *untracked*` | saveNutritionDayAnnotations |
| `CheckInPresenter` | `perform` | `--- *untracked*` |  |
| `CheckInPresenter` | `complete` | `--F` | markCheckInCompleted |
| `CreateFoodPresenter` | `onImageSelectorChanged` | `-OF` |  |
| `FoodDefinitionPresenter` | `createFood` | `--- *untracked*` | saveFood |
| `FoodDetailPresenter` | `deleteFood` | `--- *untracked*` | deleteFood |
| `AddMealPresenter` | `saveDraftMeal` | `--- *untracked*` | updateDraftMeal |
| `BarcodeScannerPresenter` | `onTorchPressed` | `--F` |  |
| `BarcodeScannerPresenter` | `onParseLabelPressed` | `--F` | analyzeNutritionLabel, ensureOnline |
| `BarcodeScannerPresenter` | `onSaveIngredientPressed` | `--F` | saveFood |
| `BarcodeScannerPresenter` | `onBarcodeDetected` | `--F` | ensureOnline, findLocalFood, lookupBarcode, saveFood |
| `FoodItemSearchPresenter` | `onSearchTextChanged` | `--F` | searchOpenFoodFacts |
| `FoodPhotoScannerPresenter` | `onCapture` | `--F` | analyzeFood, ensureOnline |
| `MealDescribePresenter` | `onAnalysePressed` | `--F` | describeMeal, ensureOnline |
| `NutritionOverviewPresenter` | `onSkipCheckInPressed` | `---` | markCheckInSkipped |
| `NutritionOverviewPresenter` | `onAcceptProposalPressed` | `--F` | acceptTargetProposal |
| `RecipeDetailPresenter` | `onFavouritePressed` | `--- *untracked*` | setFavouriteRecipe |
| `RecipeDetailPresenter` | `deleteRecipe` | `--- *untracked*` | deleteRecipeTemplate |
| `TimelineActionsPresenter` | `save` | `--F` | saveFoodLogSettings |
| `TimelineActionsPresenter` | `onCopyDayConfirmed` | `--F` | getMeals, saveMeal |
| `TimelineActionsPresenter` | `clearDay` | `--F` | deleteMealAndSync |

**Paywalls**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `PaywallPresenter` | `restorePurchase` | `---` | restorePurchase |

**Profile**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `AccountPresenter` | `onPrivacyChanged` | `--- *untracked*` | updatePrivacy |
| `AccountPresenter` | `saveProfile` | `--- *untracked*` | ensureOnline, updateProfileImageUrl |
| `AccountPresenter` | `updateUser` | `--- *untracked*` | updateUser |
| `EditUsernamePresenter` | `onSavePressed` | `-OF` | claimUsername, ensureOnline |
| `CustomiseAnalyticsPresenter` | `save` | `--F` | saveAnalyticsSettings |
| `IntegrationsPresenter` | `onStravaConnectPressed` | `--- *untracked*` | stravaAuthenticate |
| `IntegrationsPresenter` | `onStravaTestUploadPressed` | `--- *untracked*` | showAppToast, stravaTestUpload |
| `ShortcutsPresenter` | `apply` | `--F` | saveShortcutSettings |
| `UnitsPresenter` | `save` | `--F` | updateUnitPreferences |
| `ExpenditureSettingsPresenter` | `save` | `--F` | saveNutritionStrategySettings |
| `FavouriteMeasurementsPresenter` | `save` | `--F` | saveFoodLogSettings |
| `FoodLogSettingsPresenter` | `save` | `--F` | saveFoodLogSettings |
| `LoggerBannerPresenter` | `save` | `--F` | saveFoodLogSettings |
| `LoggerFoodTilesPresenter` | `save` | `--F` | saveFoodLogSettings |
| `TimelineFoodTilesPresenter` | `save` | `--F` | saveFoodLogSettings |
| `StrategySettingsPresenter` | `save` | `--F` | saveNutritionStrategySettings |
| `RestTimerSettingsPresenter` | `save` | `--F` | saveWorkoutSettings |
| `TimerDurationPresenter` | `saveEdit` | `--F` |  |
| `TimerDurationPresenter` | `resetDefaults` | `--F` |  |
| `TimerDurationPresenter` | `saveExerciseEdit` | `--F` | setExerciseRestOverride |
| `TimerDurationPresenter` | `removeExerciseOverride` | `--F` | setExerciseRestOverride |
| `TimerDurationPresenter` | `save` | `--- *untracked*` | saveWorkoutSettings |
| `SmartProgressionSettingsPresenter` | `save` | `--F` | saveWorkoutSettings |
| `WorkoutSettingsPresenter` | `save` | `--F` | saveWorkoutSettings |

**Sharing**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `SharedItemPresenter` | `onAddToLibraryPressed` | `-OF` | saveExerciseModel, saveMesocycle, saveWorkoutTemplate, updateShareStatus |
| `SharedItemPresenter` | `onDismissSharePressed` | `-OF` | updateShareStatus |

**Social**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `WeeklyGoalPresenter` | `onSavePressed` | `---` | updateWeeklySessionGoal |
| `SocialPresenter` | `onNudgePressed` | `---` | nudgeUser |
| `FollowersListPresenter` | `removeFollower` | `--- *untracked*` | ensureOnline, removeFollower |
| `SocialProfilePresenter` | `loadSessions` | `--- *untracked*` | fetchWorkoutSessions |
| `SocialProfilePresenter` | `loadFollowers` | `--- *untracked*` | fetchFollowers |
| `SocialProfilePresenter` | `onFollowingPressed` | `--- *untracked*` | fetchUsers |
| `SocialProfilePresenter` | `onBlockConfirmed` | `---` | blockUser |
| `SocialProfilePresenter` | `onUnblockPressed` | `---` | unblockUser |
| `CommentsPresenter` | `loadComments` | `--- *untracked*` | fetchComments, getUser |
| `CommentsPresenter` | `onSendPressed` | `--- *untracked*` | addComment |
| `CommentsPresenter` | `onLikePressed` | `--- *untracked*` | toggleCommentLike |
| `CommentsPresenter` | `onDeleteConfirmed` | `--- *untracked*` | deleteComment |
| `WorkoutSessionRowPresenter` | `onLikeButtonPressed` | `--- *untracked*` | likeSession, unlikeSession |
| `WorkoutSessionRowPresenter` | `onShareImagePressed` | `--- *untracked*` |  |
| `WorkoutSessionRowPresenter` | `onSaveAsTemplatePressed` | `-OF` | saveWorkoutTemplate, showAppToast |

**Today**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `TodayPresenter` | `onRepeatMacrocyclePressed` | `---` | repeatCurrentMacrocycle |
| `TodayPresenter` | `startBlankWorkout` | `--- *untracked*` | startBlankWorkout |
| `TodayPresenter` | `onSkipCheckInPressed` | `---` | markCheckInSkipped |
| `WeeklyReviewPresenter` | `onSharePressed` | `---` |  |

**Training**

| Presenter | Function | Logged | Calls |
|---|---|---|---|
| `TodaysWorkoutCardPresenter` | `start` | `--F` | startWorkout |
| `TodaysWorkoutCardPresenter` | `skip` | `--F` | skipScheduledWorkout |
| `ActiveMesocyclePresenter` | `deleteMesocycle` | `--F` | deleteMesocycle |
| `MesocycleDesignPresenter` | `saveTemplatesAndActivate` | `--- *untracked*` | saveWorkoutTemplate |
| `MesocycleDesignPresenter` | `activateMesocycle` | `--- *untracked*` | saveMesocycle, setActiveMesocycle |
| `MesocycleDesignPresenter` | `deleteMesocycle` | `--- *untracked*` | deleteMesocycle |
| `MesocycleDesignPresenter` | `onSavePressed` | `--- *untracked*` | saveMesocycle |
| `MesocycleSettingsPresenter` | `onActivatePressed` | `--- *untracked*` | saveMesocycle, setActiveMesocycle |
| `MesocycleIconPresenter` | `onNextPressed` | `--- *untracked*` |  |
| `DefineWorkoutWrapperPresenter` | `onConfirmPressed` | `--- *untracked*` | saveWorkoutTemplate |
| `ExerciseModelDetailPresenter` | `deleteExercise` | `--- *untracked*` | deleteExerciseModel |
| `MacrocycleDetailPresenter` | `onSavePressed` | `--F` | saveMacrocycle |
| `MacrocycleDetailPresenter` | `onDeletePressed` | `--F` | deleteMacrocycle |
| `MacrocycleDetailPresenter` | `start` | `--F` | startMacrocycle |
| `MacrocycleDetailPresenter` | `run` | `--- *untracked*` |  |
| `WorkoutSessionDetailPresenter` | `persistTimingChange` | `--- *untracked*` | saveWorkoutSession |
| `WorkoutSessionDetailPresenter` | `saveChanges` | `--- *untracked*` | saveWorkoutSession |
| `WorkoutSessionDetailPresenter` | `deleteSession` | `--F` | deleteWorkoutSession |
| `WorkoutSessionDetailPresenter` | `onShareImagePressed` | `--- *untracked*` |  |
| `WorkoutTemplateDetailPresenter` | `deleteWorkout` | `--- *untracked*` | deleteWorkoutTemplate |
| `WorkoutTemplateDetailPresenter` | `performStartWorkout` | `--- *untracked*` | startWorkout |
| `WorkoutTrackerPresenter` | `onAppear` | `--- *untracked*` | canRequestHealthDataAuthorisation, needsAuthorisationForRequiredTypes, requestHealthKitAuthorisation, setWorkoutConfiguration, startWorkout |
| `WorkoutTrackerPresenter` | `saveWorkoutProgress` | `--- *untracked*` | updateActiveSession |
| `WorkoutTrackerPresenter` | `attemptSave` | `--- *untracked*` | endWorkoutSession |
| `TrainingPresenter` | `onStartEmptyWorkoutPressed` | `--- *untracked*` | startBlankWorkout |
| `TrainingPresenter` | `startThenShowTracker` | `--- *untracked*` |  |
| `TrainingPresenter` | `onStartWorkoutResultPressed` | `--- *untracked*` | startWorkout |

## Errors swallowed with `try?` (31 functions)

Nothing is logged when these fail.

| Presenter | Function | Calls |
|---|---|---|
| `TodayPresenter` | `onStartEmptyWorkoutPressed` | deleteActiveSession |
| `TodayPresenter` | `onLogMealPressed` | deleteDraftMeal |
| `TodayPresenter` | `loadNutrition` | getDailyTarget, getDailyTotals |
| `TrainingPresenter` | `startAfterActiveSessionCheck` | deleteActiveSession |
| `WorkoutTemplateDetailPresenter` | `checkForActiveWorkout` | deleteActiveSession |
| `ExerciseSettingsPresenter` | `onRestTimerPressed` | setExerciseRestOverride |
| `ExerciseSettingsPresenter` | `onNotePressed` | setExerciseNote |
| `WorkoutSessionDetailPresenter` | `loadAuthor` | getUser |
| `WorkoutTrackerPresenter` | `onTask` | getGymProfile, setActiveWorkoutGymProfile |
| `WorkoutTrackerPresenter` | `discardWorkout` | deleteActiveSession, discardWorkout, endLiveActivity, setActiveWorkoutGymProfile |
| `ActiveMesocyclePresenter` | `checkForActiveWorkout` | deleteActiveSession |
| `TodaysWorkoutCardPresenter` | `onStartPressed` | deleteActiveSession |
| `ChallengeDetailPresenter` | `loadStandings` | getUser, refreshChallengeProgress |
| `SocialPresenter` | `loadSuggestedUsers` | fetchSuggestedUsers |
| `SocialPresenter` | `onOpenWorkoutSessionNotificationReceived` | fetchWorkoutSession |
| `SocialPresenter` | `loadNotifications` | fetchActivityNotifications |
| `SocialPresenter` | `loadChallenges` | refreshChallenges |
| `EditUsernamePresenter` | `onTextChanged` | isUsernameAvailable |
| `NutritionPresenter` | `importFromAppleHealth` | canRequestHealthDataAuthorisation, requestHealthKitAuthorisation, syncNutritionFromHealthKit |
| `NutritionPresenter` | `onLogMealPressed` | deleteDraftMeal |
| `TimelineActionsPresenter` | `onClearDayPressed` | getMeals |
| `AddMealPresenter` | `dismissScreen` | deleteDraftMeal |
| `MealHourHeaderPresenter` | `onAddMealPressed` | deleteDraftMeal |
| `NutritionOverviewPresenter` | `loadData` | getDailyNutritionBreakdown, getDailyTarget, getDailyTotals |
| `CheckInPresenter` | `buildWeek` | getMeals, nutritionDayAnnotation |
| `NotificationsPresenter` | `onPullToRefresh` | fetchIncomingFollowRequests |
| `NotificationsPresenter` | `onGroupPressed` | markActivityNotificationsRead |
| `NutritionTargetChartPresenter` | `loadCurrentWeekLoggedTotals` | getDailyTotals |
| `FoodLoggingConsistencyPresenter` | `onAppear` | getDailyTotals |
| `NutritionMetricDetailPresenter` | `onAppear` | getDailyNutritionBreakdown, getDailyTotals |
| `EnergyBalancePresenter` | `rebuildCaches` | estimateTDEE, getDailyTotals |
