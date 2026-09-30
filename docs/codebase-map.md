# DialedIn codebase map

Read this before searching. The tree is regular enough that most paths can be **predicted**
from a name, and the tables below list every screen, manager, model, Cloud Function,
Firestore path and test suite with its file. Regenerate after moving or adding files:

```bash
python3 scripts/codebase-map.py
```

CLAUDE.md holds the rules (build, test, lint, architecture); this file holds the inventory.

## Predicting a path from a name

**A screen called `Foo`** is one folder containing exactly these files. Nothing else in the
app builds or routes it.

| File | Holds |
|---|---|
| `FooInteractor.swift` | `protocol FooInteractor: GlobalInteractor` listing the manager calls the screen needs, then `extension CoreInteractor: FooInteractor { }` (usually empty: `CoreInteractor` already has the members) |
| `FooPresenter.swift` | `@Observable @MainActor class FooPresenter` with `init(interactor:router:)`, every `onXxxPressed()`, and a nested `enum Event: LoggableEvent`. Large presenters split into `FooPresenter+Topic.swift` |
| `FooRouter.swift` | `protocol FooRouter: GlobalRouter` listing the screens this one navigates **to** as `func showBarView(delegate:)`, then `extension CoreRouter: FooRouter { }` |
| `FooView.swift` | `struct FooDelegate` (the inputs), `struct FooView: View` with `@State var presenter`, then `extension CoreBuilder { func fooView(router:delegate:) }` and `extension CoreRouter { func showFooView(delegate:) }` |

So: the `showFooView` a router protocol asks for is **defined at the bottom of `FooView.swift`**,
the builder that makes the screen is right above it, and `CoreRouter.swift` / `CoreBuilder.swift`
in `Root/RIBs/Core` are tiny (they only hold a few shared modals). Reusable VIPER components
(calendar header, exercise list builder, meal accessory) follow the same four-file shape under
`Components/Views`.

**A manager called `FooManager`** lives at `Managers/<Area>/Foo/FooManager.swift` (or
`Managers/Foo/FooManager.swift`), with its models in a sibling `Models/` folder and its
`Mock*`/`Production*`/`Firebase*` services in `Services/`. It is created and registered once in
`Root/Dependencies/Dependencies.swift` (one arm per `BuildConfiguration`) and exposed as a
`let fooManager` on `CoreInteractor`. Package-provided managers (`AuthManager`, `LogManager`,
`PurchaseManager`, `StreakManager`, `HapticManager`, `SoundEffectManager`, the sync engines)
have only an alias file here; see the table in CLAUDE.md.

**A test for `Foo`** is `DialedInUnitTests/**/FooTests.swift` or `FooPresenterTests.swift`, run with
`-only-testing:DialedInUnitTests/FooPresenterTests`. Shared doubles are in `DialedInUnitTests/Support`
(`TestManagers.swift` builds real managers on mock engines; `TestDoubles.swift` has `SpyGlobalInteractor` and
`SpyOnboardingRouter`).

**A Firestore collection** is named in `firestore.rules` (table below), wired in `Dependencies.swift`
through a `FirebaseRemoteCollectionService(collectionPath:)` closure that usually reads the signed-in
uid, and indexed in `firestore.indexes.json`. Adding one means all three plus a deploy.

## Cross-cutting flows

- **Launch**: `DialedInApp` → `AppDelegate.application(_:didFinishLaunchingWithOptions:)` picks
  `BuildConfiguration` from `MOCK`/`DEBUG` flags (or `Utilities.isUITesting`), calls
  `config.configure()` (Firebase, App Check, Google Sign-In's own App Check), builds
  `Dependencies(config:)` → `CoreInteractor` → `CoreBuilder.build()` → `AppView`.
  `AppState.startingModuleId` chooses `Constants.onboardingModuleId` or `tabBarModuleId`.
- **Sign-in and data**: every manager owns a `DocumentSyncEngine`/`CollectionSyncEngine`.
  `CoreInteractor.logIn()` awaits `signIn` on all of them, then seeds prebuilt exercises and
  workouts. `syncAllRemoteDataIfLoggedIn()` only posts `Constants.remoteDataSyncDidComplete`.
- **Navigation**: `SwiftfulRouting`. `GlobalRouter` (`Root/RIBs/GlobalRouter.swift`) gives every
  router `dismissScreen`, `showAlert`, `showLoadingModal`, etc. Cross-tab jumps and push/deep-link
  destinations go through `NotificationCenter` names in `Constants` (`selectTab`,
  `openWorkoutSession`, `openNotifications`, `acceptInvite`) and `Core/TabBar/DeepLink.swift`.
- **Onboarding resume**: `UserModel.inferredOnboardingStep` + `Core/Onboarding/OnboardingStepRouter.swift`.
- **Live Activity / widgets**: app side in `Managers/LiveActivities`, extension in
  `WorkoutSessionActivity/`, shared attributes and storage in `Shared/`. Intents from the island
  reach the app through `AppDelegate.registerLiveActivityIntentHandler`.
- **Siri / Shortcuts**: `Managers/AppIntents` (+ `AppIntentsBridge`), refreshed after data sync.
- **Backend**: `functions/index.js` (callables need App Check + auth, see CLAUDE.md), `firestore.rules`,
  `firestore.indexes.json`, Hosting in `hosting/` with `/s/**` rewritten to `sessionPage`.

## Recipes

- **New screen**: copy any four-file module (e.g. `Core/Onboarding/4 - CompleteAccountSetup/2 - Gender`),
  rename, add `func showFooView(delegate:)` to the *calling* screen's router protocol, add a
  `FooPresenterTests.swift`. Router doubles in tests must implement `showDevSettingsView` unguarded.
- **New manager with a Firestore collection**: model conforming to `DataSyncModelProtocol`, manager taking a sync engine, one registration per arm in
  `Dependencies.swift`, a `let` on `CoreInteractor`, a `Keys.swift.example` manager key, a rules
  block, an index if queried, `TestManagers.swift` wiring, then deploy rules.
- **New Cloud Function**: `onCall(CALLABLE_OPTIONS, …)` opening with `requireAuth(request)`; the
  source check in `functions/index.test.js` fails otherwise. Deploy with `firebase deploy --only functions`.
- **New body measurement**: one field on `BodyMeasurementEntry`, one line in `BodyMeasurementKind`
  (CLAUDE.md, Body Measurements).

<!-- generated below this line by scripts/codebase-map.py; edit PROLOGUE in the script, not here -->

## Areas

| Area | Files | Lines | Purpose |
|---|---:|---:|---|
| `DialedIn/Core/Analytics` | 118 | 9,991 | Progress tab: body metrics, exercise/nutrition analytics, insights, consistency |
| `DialedIn/Core/AppView` | 7 | 724 | Root view: onboarding-or-tabbar switch, toasts, notification banner |
| `DialedIn/Core/Challenges` | 11 | 802 | Group challenges (create, detail) |
| `DialedIn/Core/Social` | 38 | 4,414 | Social tab: workout feed, circle goals, challenges, people search, invites, share card, profiles |
| `DialedIn/Core/Today` | 12 | 1,249 | Today tab: today's workout, nutrition, weigh-in, streak, weekly check-in and weekly review |
| `DialedIn/Core/DevSettings` | 4 | 803 | DEV/MOCK-only developer tools screen |
| `DialedIn/Core/Notifications` | 10 | 1,279 | Activity notifications inbox |
| `DialedIn/Core/Nutrition` | 147 | 12,849 | Nutrition tab: meal log, foods, recipes, check-in, library picker, AI scanners |
| `DialedIn/Core/Onboarding` | 109 | 7,392 | Numbered onboarding steps 0–9 (see OnboardingStepRouter) |
| `DialedIn/Core/Paywalls` | 9 | 804 | Paywall screens |
| `DialedIn/Core/Profile` | 201 | 12,683 | Profile tab and every settings screen (training, nutrition, general, account, legal) |
| `DialedIn/Core/Sharing` | 8 | 502 | Share-to-follower and shared-item viewer |
| `DialedIn/Core/TabBar` | 5 | 473 | Tab bar, DeepLink parsing, tab selection |
| `DialedIn/Core/Training` | 218 | 18,370 | Training tab: workouts, tracker, programs, history, create flows |
| `DialedIn/Components` | 74 | 6,896 | Reusable views, buttons, modals, charts (QuickCharts alias), view modifiers |
| `DialedIn/Managers` | 243 | 30,388 | App-owned managers, models and services (see Managers table) |
| `DialedIn/Root` | 22 | 3,249 | AppDelegate, DialedInApp, Dependencies DI root, CoreInteractor/Builder/Router, Global protocols |
| `DialedIn/Utilities` | 14 | 950 | Constants, Keys, NetworkMonitor, App Check factory, unit conversion, helpers |
| `DialedIn/Extensions` | 13 | 638 | Foundation/SwiftUI type extensions (`X+EXT.swift`) |
| `DialedIn/SupportingFiles` | 190 | 3,258 | Assets, entitlements, GoogleService plists, privacy manifest, seed JSON |
| `Shared` | 5 | 600 | Code compiled into both the app and the Live Activity extension |
| `WorkoutSessionActivity` | 136 | 1,787 | Live Activity / Dynamic Island / home widget extension |
| `DialedInUnitTests` | 266 | 72,398 | Swift Testing unit suites (BlueprintName DialedInUnitTests) |
| `DialedInUITests` | 7 | 573 | XCUITest smoke and create-flow tests (launch via STARTSCREEN) |
| `functions` | 8 | 16,844 | Firebase Cloud Functions v2 (Node ESM, Genkit/Vertex) |
| `hosting` | 1 | 7 | Firebase Hosting landing page |
| `scripts` | 6 | 700 | Screenshot, contact-sheet, smoke-test generation, this map |
| `docs` | 45 | 10,076 | Specs, reviews, audits, this map |

## Screens and VIPER components

Each row is one folder holding `<Module>{Interactor,Presenter,Router,View}.swift`. *Routes to* is what the module's router protocol can open; *Delegate / entry* is the input struct and the `showXView` defined at the bottom of its View file; *Extra files* are presenter splits and helper views.
203 presenter-backed modules.

### `DialedIn/Components` (4 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **CalendarHeader** | [Views/CalendarHeader](DialedIn/Components/Views/CalendarHeader) | 834 | CalendarViewZoom | CalendarHeaderDelegate | CalendarDayCell.swift, CalendarDayMarker.swift | CalendarHeaderPresenterTests.swift |
| **Calendar** | [Views/CalendarHeader/Calendar](DialedIn/Components/Views/CalendarHeader/Calendar) | 388 |  | CalendarDelegate, `showCalendarView` |  | CalendarHeaderPresenterTests.swift |
| **EnumPicker** | [Views/EnumPicker](DialedIn/Components/Views/EnumPicker) | 198 |  | EnumPickerDelegate |  |  |
| **AuthorHeader** | [Views/User](DialedIn/Components/Views/User) | 276 | SocialProfile | AuthorHeaderDelegate | UserRowView.swift, UsernameLabel.swift |  |

### `DialedIn/Core/Analytics` (25 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Analytics** | [DialedIn/Core/Analytics](DialedIn/Core/Analytics) | 1419 | BodyMetrics, CustomiseAnalytics, EnergyBalance, ExerciseAnalytics, ExerciseDetail, ExpenditureDetail, GoalProgress, Habits, InsightsAndAnalytics, LogWeight, MuscleGroupDetail, MuscleGroups, NutritionAnalytics, NutritionMetricDetail, Paywall, ProfileViewZoom, ScaleWeight, Steps, VisualBodyFat, WeeklyReview, WeighInConsistency, WeightTrend, Workout, WorkoutConsistency | AnalyticsDelegate | AnalyticsPresenter+DataLoading.swift, MuscleGroupCardItem.swift | AnalyticsPresenterTests.swift |
| **BodyMetrics** | [Subviews/BodyMetrics](DialedIn/Core/Analytics/Subviews/BodyMetrics) | 559 | BodyMeasurementDetail, BodyRatio, LogMeasurement, ProgressPhotos, ScaleWeight, VisualBodyFat | BodyMetricsDelegate, `showBodyMetricsView` | BodyMetricCardView.swift, BodyMetricsModels.swift |  |
| **LogMeasurement** | [Subviews/BodyMetrics/LogMeasurement](DialedIn/Core/Analytics/Subviews/BodyMetrics/LogMeasurement) | 419 |  | `showLogMeasurementView` | BodyMeasurementKind.swift, DecimalWheelValue.swift |  |
| **LogWeight** | [Subviews/BodyMetrics/LogMeasurement/LogWeightView](DialedIn/Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView) | 344 |  | `showLogWeightView` | WeightPickerInput.swift |  |
| **ProgressPhotos** | [Subviews/BodyMetrics/ProgressPhotos](DialedIn/Core/Analytics/Subviews/BodyMetrics/ProgressPhotos) | 619 | ProgressPhotoCompare | ProgressPhotoCompareDelegate, `showProgressPhotoCompareView`, `showProgressPhotosView` | ProgressPhotoCameraPicker.swift, ProgressPhotoCompareView.swift | ProgressPhotosPresenterTests.swift |
| **ScaleWeight** | [Subviews/BodyMetrics/ScaleWeight](DialedIn/Core/Analytics/Subviews/BodyMetrics/ScaleWeight) | 209 | LogWeight | ScaleWeightDelegate, `showScaleWeightView` |  |  |
| **ExerciseAnalytics** | [Subviews/ExerciseAnalytics](DialedIn/Core/Analytics/Subviews/ExerciseAnalytics) | 311 | ExerciseDetail | ExerciseAnalyticsDelegate, `showExerciseAnalyticsView` | ExerciseCardItem.swift, ExerciseOneRMAggregator.swift |  |
| **ExerciseDetail** | [Subviews/ExerciseAnalytics/ExerciseDetail](DialedIn/Core/Analytics/Subviews/ExerciseAnalytics/ExerciseDetail) | 265 | Workouts | ExerciseDetailDelegate, `showExerciseDetailView` | ExerciseDetailEntry.swift |  |
| **FoodLoggingConsistency** | [Subviews/FoodLoggingConsistency](DialedIn/Core/Analytics/Subviews/FoodLoggingConsistency) | 146 |  | FoodLoggingConsistencyDelegate, `showFoodLoggingConsistencyView` |  |  |
| **Habits** | [Subviews/Habits](DialedIn/Core/Analytics/Subviews/Habits) | 414 | FoodLoggingConsistency, NutritionMetricDetail, ScaleWeight, WeighInConsistency, Workout, WorkoutConsistency | HabitsDelegate, `showHabitsView` |  | HabitsPresenterTests.swift |
| **InsightsAndAnalytics** | [Subviews/InsightsAndAnalytics](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics) | 498 | EnergyBalance, ExpenditureDetail, GoalProgress, WeightTrend, Workout | InsightsAndAnalyticsDelegate, `showInsightsAndAnalyticsView` |  |  |
| **EnergyBalance** | [Subviews/InsightsAndAnalytics/EnergyBalance](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/EnergyBalance) | 301 | AddMeal | EnergyBalanceDelegate, `showEnergyBalanceView` | EnergyBalanceEntry.swift | EnergyBalancePresenterTests.swift |
| **ExpenditureDetail** | [Subviews/InsightsAndAnalytics/ExpenditureDetail](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/ExpenditureDetail) | 238 | Account | ExpenditureDetailDelegate, `showExpenditureDetailView` | ExpenditureDetailEntry.swift |  |
| **GoalProgress** | [Subviews/InsightsAndAnalytics/GoalProgress](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/GoalProgress) | 293 |  | GoalProgressDelegate, `showGoalProgressView` | GoalProgressEntry.swift |  |
| **MuscleGroupDetail** | [Subviews/InsightsAndAnalytics/MuscleGroupDetail](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/MuscleGroupDetail) | 249 | Workouts | MuscleGroupDetailDelegate, `showMuscleGroupDetailView` | MuscleGroupDetailEntry.swift | MuscleGroupDetailPresenterTests.swift |
| **Steps** | [Subviews/InsightsAndAnalytics/Steps](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/Steps) | 247 |  | StepsDelegate, `showStepsView` | StepsEntry.swift |  |
| **WeightTrend** | [Subviews/InsightsAndAnalytics/WeightTrend](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/WeightTrend) | 257 |  | WeightTrendDelegate, `showWeightTrendView` | WeightTrendEntry.swift | WeightTrendPresenterTests.swift |
| **Workout** | [Subviews/InsightsAndAnalytics/Workouts](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/Workouts) | 239 | Workouts | WorkoutDelegate, `showWorkoutView` | WorkoutEntry.swift | WorkoutPresenterTests.swift |
| **MuscleBalance** | [Subviews/MuscleBalance](DialedIn/Core/Analytics/Subviews/MuscleBalance) | 274 |  | `showMuscleBalanceView`, `showsFooter` |  |  |
| **MuscleGroups** | [Subviews/MuscleGroups](DialedIn/Core/Analytics/Subviews/MuscleGroups) | 314 | MuscleBalance, MuscleGroupDetail | MuscleGroupsDelegate, `showMuscleGroupsView` | MuscleGroupSetsAggregator.swift |  |
| **NutritionAnalytics** | [Subviews/NutritionAnalytics](DialedIn/Core/Analytics/Subviews/NutritionAnalytics) | 513 | AddMeal, NutritionMetricDetail | NutritionAnalyticsDelegate, `showNutritionAnalyticsView` |  |  |
| **NutritionMetricDetail** | [Subviews/NutritionAnalytics/NutritionMetricDetail](DialedIn/Core/Analytics/Subviews/NutritionAnalytics/NutritionMetricDetail) | 570 |  | NutritionMetricDetailDelegate, `showNutritionMetricDetailView` | NutritionMetric.swift, NutritionMetricEntry.swift |  |
| **NutritionTargetChart** | [Subviews/NutritionTargetChart](DialedIn/Core/Analytics/Subviews/NutritionTargetChart) | 347 | PreferredDiet |  |  |  |
| **WeighInConsistency** | [Subviews/WeighInConsistency](DialedIn/Core/Analytics/Subviews/WeighInConsistency) | 162 |  | WeighInConsistencyDelegate, `showWeighInConsistencyView` |  |  |
| **WorkoutConsistency** | [Subviews/WorkoutConsistency](DialedIn/Core/Analytics/Subviews/WorkoutConsistency) | 163 |  | WorkoutConsistencyDelegate, `showWorkoutConsistencyView` |  |  |

### `DialedIn/Core/AppView` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **App** | [DialedIn/Core/AppView](DialedIn/Core/AppView) | 724 |  | `showAppToast` | ActivityNotificationBannerView.swift, AppToast.swift, AppToastView.swift, AppViewBuilder.swift | AppShellPresenterTests.swift |

### `DialedIn/Core/Challenges` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ChallengeDetail** | [ChallengeDetail](DialedIn/Core/Challenges/ChallengeDetail) | 306 | SocialProfile | ChallengeDetailDelegate, `showChallengeDetailView` |  |  |
| **CreateChallenge** | [CreateChallenge](DialedIn/Core/Challenges/CreateChallenge) | 294 |  | `showCreateChallengeView` |  |  |

### `DialedIn/Core/DevSettings` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **DevSettings** | [DialedIn/Core/DevSettings](DialedIn/Core/DevSettings) | 803 |  | `showDevSettingsView` |  |  |

### `DialedIn/Core/Notifications` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Notifications** | [DialedIn/Core/Notifications](DialedIn/Core/Notifications) | 891 | ChallengeDetail, NotificationSettings, SharedItem, SocialProfile, WorkoutSessionDetail, WorkoutSessionThreadPushed | `showNotificationsView`, `showWorkoutSessionThreadPushed`, `showsFollowBack` | NotificationGrouping.swift, ReminderOfferFlow.swift |  |
| **NotificationSettings** | [NotificationSettings](DialedIn/Core/Notifications/NotificationSettings) | 388 |  | NotificationSettingsDelegate, `showNotificationSettingsView` |  | NotificationSettingsPresenterTests.swift |

### `DialedIn/Core/Nutrition` (33 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Nutrition** | [DialedIn/Core/Nutrition](DialedIn/Core/Nutrition) | 824 | AddMeal, FoodDetail, FoodLogSettings, Foods, MealDetail, MealItemAmountView, NutritionOverview, ProfileViewZoom, RecipeDetail, Recipes, TimelineActions | NutritionDelegate, `showNutritionView` |  | NutritionPresenterTests.swift |
| **CheckIn** | [CheckIn](DialedIn/Core/Nutrition/CheckIn) | 807 |  | CheckInDelegate, `showCheckInView` | CheckInPresenter+Events.swift, CheckInStep.swift | CheckInPresenterTests.swift |
| **IngredientListBuilder** | [Components/IngredientListBuilder](DialedIn/Core/Nutrition/Components/IngredientListBuilder) | 377 | CreateFood, MealItemAmountView, RecipeIngredientAmount | IngredientListBuilderDelegate, `showIngredientListBuilderView` |  |  |
| **MealAccessory** | [Components/MealAccessory](DialedIn/Core/Nutrition/Components/MealAccessory) | 165 | AddMeal | MealAccessoryDelegate |  |  |
| **MealHourHeader** | [Components/MealHourHeader](DialedIn/Core/Nutrition/Components/MealHourHeader) | 233 | AddMeal | MealHourHeaderDelegate |  | MealHourHeaderPresenterTests.swift |
| **RecipeListBuilder** | [Components/RecipeListBuilder](DialedIn/Core/Nutrition/Components/RecipeListBuilder) | 323 | CreateRecipe, RecipeAmount, RecipeDetail | RecipeListBuilderDelegate, `showRecipeListBuilderView` |  |  |
| **Foods** | [Foods](DialedIn/Core/Nutrition/Foods) | 106 | FoodDetail, SimpleAlert | `showFoodsView` |  |  |
| **CreateFood** | [Foods/CreateFood](DialedIn/Core/Nutrition/Foods/CreateFood) | 455 | BarcodeScanner, FoodPackaging, PortionDefinition | CreateFoodDelegate, `showCreateFoodView` |  | CreateFoodFlowPresenterTests.swift |
| **FoodDefinition** | [Foods/CreateFood/FoodDefinition](DialedIn/Core/Nutrition/Foods/CreateFood/FoodDefinition) | 625 |  | FoodDefinitionDelegate, `showFoodDefinitionView` |  | FoodDefinitionPresenterTests.swift |
| **FoodPackaging** | [Foods/CreateFood/FoodPackaging](DialedIn/Core/Nutrition/Foods/CreateFood/FoodPackaging) | 261 | PortionDefinition | FoodPackagingDelegate, `showFoodPackagingView` |  |  |
| **PortionDefinition** | [Foods/CreateFood/PortionDefinition](DialedIn/Core/Nutrition/Foods/CreateFood/PortionDefinition) | 357 | FoodDefinition | PortionDefinitionDelegate, `showPortionDefinitionView` |  |  |
| **FoodDetail** | [Foods/FoodDetail](DialedIn/Core/Nutrition/Foods/FoodDetail) | 401 |  | FoodDetailDelegate, `showDeleteConfirmation`, `showFoodDetailView` |  |  |
| **AddMeal** | [MealLog/AddMeal](DialedIn/Core/Nutrition/MealLog/AddMeal) | 658 | MealItemAmountView, NutritionLibraryPicker | AddMealDelegate, `showAddMealView` |  | AddMealPresenterTests.swift |
| **IngredientAmount** | [MealLog/IngredientAmount](DialedIn/Core/Nutrition/MealLog/IngredientAmount) | 199 |  | IngredientAmountDelegate, `showIngredientAmountView` |  |  |
| **MealDetail** | [MealLog/MealDetail](DialedIn/Core/Nutrition/MealLog/MealDetail) | 275 |  | MealDetailDelegate, `showMealDetailView` |  |  |
| **MealItemAmountView** | [MealLog/MealItemAmountView](DialedIn/Core/Nutrition/MealLog/MealItemAmountView) | 309 |  | MealItemAmountViewDelegate, `showMealItemAmountViewView` |  |  |
| **NutritionLibraryPicker** | [MealLog/NutritionLibraryPicker](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker) | 289 | IngredientAmount, RecipeAmount | NutritionLibraryPickerDelegate, `showNutritionLibraryPickerView` |  |  |
| **BarcodeScanner** | [MealLog/NutritionLibraryPicker/BarcodeScanner](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/BarcodeScanner) | 892 |  | BarcodeScannerDelegate, `showBarcodeScannerView` |  | BarcodeScannerPresenterTests.swift |
| **FoodItemQuickAdd** | [MealLog/NutritionLibraryPicker/FoodItemQuickAdd](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemQuickAdd) | 343 |  | FoodItemQuickAddDelegate |  | FoodItemQuickAddPresenterTests.swift |
| **FoodItemSearch** | [MealLog/NutritionLibraryPicker/FoodItemSearch](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemSearch) | 286 |  | FoodItemSearchDelegate, `showFoodItemSearchView` |  |  |
| **FoodLibrary** | [MealLog/NutritionLibraryPicker/FoodLibrary](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodLibrary) | 315 | IngredientAmount, RecipeDetail | FoodLibraryDelegate, `showFoodLibraryView` |  | FoodLibraryPresenterTests.swift |
| **FoodPhotoScanner** | [MealLog/NutritionLibraryPicker/FoodPhotoScanner](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodPhotoScanner) | 444 | IngredientAmount | FoodPhotoScannerDelegate |  |  |
| **MealDescribe** | [MealLog/NutritionLibraryPicker/MealDescribe](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/MealDescribe) | 248 | IngredientAmount | MealDescribeDelegate, `showMealDescribeView` |  |  |
| **RecipeAmount** | [MealLog/RecipeAmount](DialedIn/Core/Nutrition/MealLog/RecipeAmount) | 191 |  | RecipeAmountDelegate, `showRecipeAmountView` |  |  |
| **NutritionOverview** | [NutritionOverview](DialedIn/Core/Nutrition/NutritionOverview) | 560 | CheckIn | NutritionOverviewDelegate, `showNutritionOverviewView` |  | NutritionOverviewPresenterTests.swift |
| **Recipes** | [Recipes](DialedIn/Core/Nutrition/Recipes) | 150 | CreateRecipe, RecipeDetail, SimpleAlert | `showRecipesView` |  |  |
| **AddFood** | [Recipes/AddFood](DialedIn/Core/Nutrition/Recipes/AddFood) | 170 |  | AddFoodDelegate, `showAddIngredientView` | AddFoodDelegate.swift |  |
| **CreateRecipe** | [Recipes/CreateRecipe](DialedIn/Core/Nutrition/Recipes/CreateRecipe) | 336 | IngredientListBuilder, RecipePreparation | `showCreateRecipeView` |  |  |
| **RecipeIngredientAmount** | [Recipes/CreateRecipe/RecipeIngredientAmount](DialedIn/Core/Nutrition/Recipes/CreateRecipe/RecipeIngredientAmount) | 124 |  | RecipeIngredientAmountDelegate, `showRecipeIngredientAmountView` |  |  |
| **RecipePreparation** | [Recipes/CreateRecipe/RecipePreparation](DialedIn/Core/Nutrition/Recipes/CreateRecipe/RecipePreparation) | 395 |  | RecipePreparationDelegate, `showRecipePreparationView` |  | RecipePreparationPresenterTests.swift |
| **RecipeDetail** | [Recipes/RecipeDetail](DialedIn/Core/Nutrition/Recipes/RecipeDetail) | 332 | StartRecipe | RecipeDetailDelegate, `showDeleteConfirmation`, `showRecipeDetailView` | RecipeDetailDelegate.swift |  |
| **RecipeStart** | [Recipes/RecipeStart](DialedIn/Core/Nutrition/Recipes/RecipeStart) | 120 |  | RecipeStartDelegate, `showStartRecipeView` | RecipeStartDelegate.swift |  |
| **TimelineActions** | [TimelineActions](DialedIn/Core/Nutrition/TimelineActions) | 365 |  | TimelineActionsDelegate, `showTimelineActionsView` |  | TimelineActionsPresenterTests.swift |

### `DialedIn/Core/Onboarding` (26 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Welcome** | [0 - WelcomeView](DialedIn/Core/Onboarding/0%20-%20WelcomeView) | 279 | Auth, Intro, Paywall, Subscription | WelcomeDelegate |  |  |
| **Intro** | [1 - IntroView](DialedIn/Core/Onboarding/1%20-%20IntroView) | 193 | Auth | `showIntroView` |  |  |
| **Auth** | [2 - AuthView](DialedIn/Core/Onboarding/2%20-%20AuthView) | 434 | Paywall, Subscription | `showAuthView` |  |  |
| **Subscription** | [3 - Subscription](DialedIn/Core/Onboarding/3%20-%20Subscription) | 171 | CompleteAccountSetup, Paywall | `showSubscriptionView` |  |  |
| **CompleteAccountSetup** | [4 - CompleteAccountSetup](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup) | 195 | NamePhoto | `showCompleteAccountSetupView` | CardioFitnessLevel.swift |  |
| **NamePhoto** | [4 - CompleteAccountSetup/1 - NamePhoto](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/1%20-%20NamePhoto) | 349 | Gender | `showNamePhotoView` |  |  |
| **Gender** | [4 - CompleteAccountSetup/2 - Gender](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/2%20-%20Gender) | 214 | DateOfBirth | `showGenderView` |  |  |
| **DateOfBirth** | [4 - CompleteAccountSetup/3 - DateOfBirth](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/3%20-%20DateOfBirth) | 200 | Height | DateOfBirthDelegate, `showDateOfBirthView` |  |  |
| **Height** | [4 - CompleteAccountSetup/4 - Height](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/4%20-%20Height) | 319 | Weight | HeightDelegate, `showHeightView` |  |  |
| **Weight** | [4 - CompleteAccountSetup/5 - Weight](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/5%20-%20Weight) | 321 | ExerciseFrequency | WeightDelegate, `showWeightView` |  | WeightTrendPresenterTests.swift |
| **ExerciseFrequency** | [4 - CompleteAccountSetup/6 - ExerciseFrequency](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/6%20-%20ExerciseFrequency) | 214 | Activity | ExerciseFrequencyDelegate, `showExerciseFrequencyView` |  |  |
| **Activity** | [4 - CompleteAccountSetup/7 - Activity](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/7%20-%20Activity) | 231 | Expenditure | ActivityDelegate, `showActivityView` |  |  |
| **Expenditure** | [4 - CompleteAccountSetup/9 - Expenditure](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/9%20-%20Expenditure) | 577 | HealthDisclaimer | ExpenditureDelegate, `showExpenditureView` |  |  |
| **HealthDisclaimer** | [5 - HealthDisclaimer](DialedIn/Core/Onboarding/5%20-%20HealthDisclaimer) | 255 | GoalSetting | `showHealthDisclaimerView` |  |  |
| **GoalSetting** | [6 - GoalSetting](DialedIn/Core/Onboarding/6%20-%20GoalSetting) | 148 | OverarchingObjective | `showGoalSettingView` |  |  |
| **OverarchingObjective** | [6 - GoalSetting/1 - OverarchingObjective](DialedIn/Core/Onboarding/6%20-%20GoalSetting/1%20-%20OverarchingObjective) | 206 | GoalSummary, TargetWeight | `showOverarchingObjectiveView` |  |  |
| **TargetWeight** | [6 - GoalSetting/2 - TargetWeight](DialedIn/Core/Onboarding/6%20-%20GoalSetting/2%20-%20TargetWeight) | 390 | WeightRate | TargetWeightDelegate, `showTargetWeightView` |  |  |
| **WeightRate** | [6 - GoalSetting/3 - WeightRate](DialedIn/Core/Onboarding/6%20-%20GoalSetting/3%20-%20WeightRate) | 407 | GoalSummary | WeightRateDelegate, `showWeightRateView` |  |  |
| **GoalSummary** | [6 - GoalSetting/4 - GoalSummary](DialedIn/Core/Onboarding/6%20-%20GoalSetting/4%20-%20GoalSummary) | 456 |  | GoalSummaryDelegate, `showGoalSummaryView` |  |  |
| **CustomisingDietProgram** | [8 - OnboardingDiet](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet) | 152 | PreferredDiet | `showCustomisingDietProgramView` |  |  |
| **PreferredDiet** | [8 - OnboardingDiet/1 - PreferredDiet](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/1%20-%20PreferredDiet) | 215 | CalorieDistribution, CalorieFloor | `showPreferredDietView` |  |  |
| **CalorieFloor** | [8 - OnboardingDiet/2 - CalorieFloor](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/2%20-%20CalorieFloor) | 219 | CalorieDistribution | CalorieFloorDelegate, `showCalorieFloorView` |  |  |
| **CalorieDistribution** | [8 - OnboardingDiet/4 - CalorieDistribution](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/4%20-%20CalorieDistribution) | 248 | ProteinIntake | CalorieDistributionDelegate, `showCalorieDistributionView` |  |  |
| **ProteinIntake** | [8 - OnboardingDiet/5 - ProteinIntake](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/5%20-%20ProteinIntake) | 220 | DietPlan | ProteinIntakeDelegate, `showProteinIntakeView` |  |  |
| **DietPlan** | [8 - OnboardingDiet/6 - DietPlan](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/6%20-%20DietPlan) | 298 | OnboardingCompleted | DietPlanDelegate, `showDietPlanView` |  |  |
| **OnboardingCompleted** | [9 - OnboardingCompleted](DialedIn/Core/Onboarding/9%20-%20OnboardingCompleted) | 197 |  | `showOnboardingCompletedView` |  |  |

### `DialedIn/Core/Paywalls` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Paywall** | [Paywall](DialedIn/Core/Paywalls/Paywall) | 495 |  | `showPaywall` |  | PaywallPresenterTests.swift |

### `DialedIn/Core/Profile` (49 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Profile** | [DialedIn/Core/Profile](DialedIn/Core/Profile) | 620 | About, Account, AppIcon, CustomiseAnalytics, ExpenditureSettings, FoodLogSettings, GymProfiles, Integrations, Legal, NotificationSettings, Notifications, Paywall, PreferredDiet, Siri, StrategySettings, Tutorials, Units, WorkoutSettings | `showProfileView`, `showProfileViewZoom` | ReviewMoment.swift, SignInCancellation.swift | ProfilePresenterTests.swift |
| **About** | [Subviews/About](DialedIn/Core/Profile/Subviews/About) | 149 | Licences | AboutDelegate, `showAboutView` |  |  |
| **Licences** | [Subviews/About/Licences](DialedIn/Core/Profile/Subviews/About/Licences) | 246 |  | LicencesDelegate, `showLicencesView` | Licence.swift |  |
| **Account** | [Subviews/Account](DialedIn/Core/Profile/Subviews/Account) | 598 | Auth, DeleteAccount, EditUsername | AccountDelegate, `showAccountView` |  |  |
| **DeleteAccount** | [Subviews/Account/DeleteAccount](DialedIn/Core/Profile/Subviews/Account/DeleteAccount) | 255 |  | `showDeleteAccountView` |  | DeleteAccountPresenterTests.swift |
| **EditUsername** | [Subviews/Account/EditUsername](DialedIn/Core/Profile/Subviews/Account/EditUsername) | 255 |  | `showEditUsernameView` |  |  |
| **AppIcon** | [Subviews/AppIcon](DialedIn/Core/Profile/Subviews/AppIcon) | 126 |  | AppIconDelegate, `showAppIconView` |  |  |
| **CustomiseAnalytics** | [Subviews/GeneralSettings/CustomiseAnalytics](DialedIn/Core/Profile/Subviews/GeneralSettings/CustomiseAnalytics) | 222 |  | CustomiseAnalyticsDelegate, `showCustomiseAnalyticsView` |  |  |
| **Integrations** | [Subviews/GeneralSettings/Integrations](DialedIn/Core/Profile/Subviews/GeneralSettings/Integrations) | 246 | SimpleAlert | IntegrationsDelegate, `showIntegrationsView` |  |  |
| **Shortcuts** | [Subviews/GeneralSettings/Shortcuts](DialedIn/Core/Profile/Subviews/GeneralSettings/Shortcuts) | 259 |  | ShortcutsDelegate, `showShortcutsView` |  |  |
| **Siri** | [Subviews/GeneralSettings/Siri](DialedIn/Core/Profile/Subviews/GeneralSettings/Siri) | 155 |  | SiriDelegate, `showSiriView` |  |  |
| **Units** | [Subviews/GeneralSettings/Units](DialedIn/Core/Profile/Subviews/GeneralSettings/Units) | 236 |  | UnitsDelegate, `showUnitsView` |  |  |
| **Legal** | [Subviews/Legal](DialedIn/Core/Profile/Subviews/Legal) | 162 |  | LegalDelegate, `showLegalView` |  |  |
| **ExpenditureSettings** | [Subviews/NutritionSettings/ExpenditureSettings](DialedIn/Core/Profile/Subviews/NutritionSettings/ExpenditureSettings) | 383 |  | ExpenditureSettingsDelegate, `showExpenditureSettingsView` |  |  |
| **FoodLogSettings** | [Subviews/NutritionSettings/FoodLogSettings](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings) | 409 | FavouriteMeasurements, LoggerBanner, LoggerFoodTiles, Optimisation, TimeSelection, TimelineFoodTiles | FoodLogSettingsDelegate, `showFavouriteMeasurementsView`, `showFoodLogSettingsView`, `showLoggerBannerView`, `showLoggerFoodTilesView`, `showOptimisationView`, `showTimeSelectionView`, `showTimelineFoodTilesView` |  |  |
| **FavouriteMeasurements** | [Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements) | 150 |  | FavouriteMeasurementsDelegate |  |  |
| **LoggerBanner** | [Subviews/NutritionSettings/FoodLogSettings/LoggerBanner](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerBanner) | 164 |  | LoggerBannerDelegate |  |  |
| **LoggerFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles) | 164 |  | LoggerFoodTilesDelegate |  |  |
| **Optimisation** | [Subviews/NutritionSettings/FoodLogSettings/Optimisation](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/Optimisation) | 134 |  | OptimisationDelegate |  |  |
| **TimeSelection** | [Subviews/NutritionSettings/FoodLogSettings/TimeSelection](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimeSelection) | 134 |  | TimeSelectionDelegate |  |  |
| **TimelineFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles) | 154 |  | TimelineFoodTilesDelegate |  |  |
| **StrategySettings** | [Subviews/NutritionSettings/StrategySettings](DialedIn/Core/Profile/Subviews/NutritionSettings/StrategySettings) | 280 |  | StrategySettingsDelegate, `showStrategySettingsView` |  |  |
| **ExerciseAssessment** | [Subviews/TrainingSettings/ExerciseAssessment](DialedIn/Core/Profile/Subviews/TrainingSettings/ExerciseAssessment) | 122 |  | ExerciseAssessmentDelegate, `showExerciseAssessmentView` |  |  |
| **GymProfiles** | [Subviews/TrainingSettings/GymProfiles](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles) | 387 | GymProfile | `showGymProfilesView` | EquipmentColourPicker.swift, GymEquipmentFormat.swift | GymProfilesListPresenterTests.swift |
| **GymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile) | 905 | EditBand, EditBodyWeight, EditCableMachine, EditFixedWeightBar, EditFreeWeight, EditLoadableAccessory, EditLoadableBar, EditPinLoadedMachine, EditPlateLoadedMachine | GymProfileDelegate, `showGymProfileView` |  | GymProfilePresenterTests.swift |
| **CreateGymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile) | 170 | GymProfile | CreateGymProfileDelegate, `showCreateGymProfileView` |  |  |
| **EditBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand) | 248 | AddBand | `showEditBandView` |  |  |
| **AddBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand) | 257 |  | AddBandDelegate, `showAddBandView` |  |  |
| **EditBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight) | 246 | AddBodyWeight | `showEditBodyWeightView` |  |  |
| **AddBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight) | 203 |  | AddBodyWeightDelegate, `showAddBodyWeightView` |  |  |
| **EditCableMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine) | 267 | AddCableMachineRange | `showEditCableMachineView` |  |  |
| **AddCableMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange) | 271 |  | AddCableMachineRangeDelegate, `showAddCableMachineRangeView` |  |  |
| **EditFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar) | 240 | AddFixedWeightBar | `showEditFixedWeightBarView` |  |  |
| **AddFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar) | 202 |  | AddFixedWeightBarDelegate, `showAddFixedWeightBarView` |  |  |
| **EditFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight) | 246 | AddFreeWeight | `showEditFreeWeightView` |  |  |
| **AddFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight) | 240 |  | AddFreeWeightDelegate, `showAddFreeWeightView` |  |  |
| **EditLoadableAccessory** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory) | 166 |  | `showEditLoadableAccessoryView` |  |  |
| **EditLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar) | 239 | AddLoadableBar | `showEditLoadableBarView` |  |  |
| **AddLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar) | 203 |  | AddLoadableBarDelegate, `showAddLoadableBarView` |  |  |
| **EditPinLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine) | 264 | AddPinLoadedMachineRange | `showEditPinLoadedMachineView` |  |  |
| **AddPinLoadedMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange) | 271 |  | AddPinLoadedMachineRangeDelegate, `showAddPinLoadedMachineRangeView` |  |  |
| **EditPlateLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine) | 166 |  | `showEditPlateLoadedMachineView` |  |  |
| **EditWeightRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange) | 240 |  | EditWeightRangeDelegate |  |  |
| **WorkoutSettings** | [Subviews/TrainingSettings/WorkoutSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings) | 353 | ExerciseAssessment, PreviousWorkoutReferenceSettings, RestTimerSettings, SmartProgressionSettings | WorkoutSettingsDelegate, `showWorkoutSettingsView` |  |  |
| **PreviousWorkoutReferenceSettings** | [Subviews/TrainingSettings/WorkoutSettings/PreviousWorkoutReferenceSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/PreviousWorkoutReferenceSettings) | 177 |  | PrevWORefSettingsDelegate, `showPreviousWorkoutReferenceSettingsView` |  |  |
| **RestTimerSettings** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings) | 329 | TimerDuration | RestTimerSettingsDelegate, `showRestTimerSettingsView` |  |  |
| **TimerDuration** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration) | 442 |  | TimerDurationDelegate, `showTimerDurationView` |  | TimerDurationPresenterTests.swift |
| **SmartProgressionSettings** | [Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings) | 201 |  | SmartProgressionSettingsDelegate, `showSmartProgressionSettingsView` |  |  |
| **Tutorials** | [Subviews/Tutorials](DialedIn/Core/Profile/Subviews/Tutorials) | 127 |  | TutorialsDelegate, `showTutorialsView` |  |  |

### `DialedIn/Core/Sharing` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ShareToFollower** | [ShareToFollower](DialedIn/Core/Sharing/ShareToFollower) | 237 |  | ShareToFollowerDelegate, `showShareToFollowerView` |  |  |
| **SharedItem** | [SharedItem](DialedIn/Core/Sharing/SharedItem) | 265 |  | SharedItemDelegate, `showSharedItemView` |  |  |

### `DialedIn/Core/Social` (6 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Social** | [DialedIn/Core/Social](DialedIn/Core/Social) | 1265 | ChallengeDetail, CreateChallenge, EditUsername, Notifications, ProfileViewZoom, SocialProfile, WeeklyGoal, WorkoutSessionDetail, WorkoutSessionThread | SocialDelegate | CircleActivityStripView.swift, InviteFriendCard.swift, PeopleSearch.swift, PeopleSearchResults.swift, UsernameBannerView.swift | SocialPresenterTests.swift |
| **WeeklyGoal** | [CircleGoals/WeeklyGoal](DialedIn/Core/Social/CircleGoals/WeeklyGoal) | 157 |  | `showWeeklyGoalView` |  |  |
| **SocialProfile** | [SocialProfile](DialedIn/Core/Social/SocialProfile) | 678 | FollowersList, WeeklyGoal | SocialProfileDelegate, `showSocialProfileView` |  | SocialProfilePresenterTests.swift |
| **FollowersList** | [SocialProfile/FollowersList](DialedIn/Core/Social/SocialProfile/FollowersList) | 194 | SocialProfile | FollowersListDelegate, `showFollowersList`, `showsFollowButton` |  |  |
| **WorkoutSessionRow** | [WorkoutSessionRow](DialedIn/Core/Social/WorkoutSessionRow) | 778 | Comments, ShareToFollower, SocialProfile, WorkoutSessionDetail, WorkoutTemplateDetail | WorkoutSessionRowDelegate | WorkoutSessionHighlights.swift, WorkoutSessionTemplateBuilder.swift |  |
| **Comments** | [WorkoutSessionRow/Comments](DialedIn/Core/Social/WorkoutSessionRow/Comments) | 689 |  | CommentsDelegate |  |  |

### `DialedIn/Core/TabBar` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **TabBar** | [DialedIn/Core/TabBar](DialedIn/Core/TabBar) | 473 | WorkoutTracker |  | DeepLink.swift |  |

### `DialedIn/Core/Today` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Today** | [DialedIn/Core/Today](DialedIn/Core/Today) | 520 | AddMeal, CheckIn, LogWeight, ProfileViewZoom, TrainingProgramLibrary, WeeklyReview, WorkoutTracker | TodayDelegate |  | TodayPresenterTests.swift |
| **WeeklyReview** | [WeeklyReview](DialedIn/Core/Today/WeeklyReview) | 594 |  | `showWeeklyReviewView` | WeeklyReview.swift, WeeklyReviewCard.swift, WeeklyReviewShareCardView.swift |  |

### `DialedIn/Core/Training` (48 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Training** | [DialedIn/Core/Training](DialedIn/Core/Training) | 630 | CreateExercise, CreateProgram, CreateWorkout, EditTrainingProgram, ExerciseDetail, Exercises, ProfileViewZoom, TrainingProgramLibrary, WorkoutHistory, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker, Workouts | TrainingDelegate |  | TrainingHomePresenterTests.swift, TrainingLibraryPresenterTests.swift, TrainingSettingsPresenterTests.swift |
| **ExerciseListBuilder** | [Components/ExerciseListBuilder](DialedIn/Core/Training/Components/ExerciseListBuilder) | 705 | CreateExercise | ExerciseListBuilderDelegate, `showExerciseListBuilderView` | ExerciseFilters.swift |  |
| **TodaysWorkoutCard** | [Components/TodaysWorkoutCard](DialedIn/Core/Training/Components/TodaysWorkoutCard) | 265 | WorkoutTemplateDetail, WorkoutTracker | TodaysWorkoutCardDelegate | TodaysWorkoutCard.swift, TodaysWorkoutSchedule.swift |  |
| **TrainingAccessory** | [Components/TrainingAccessory](DialedIn/Core/Training/Components/TrainingAccessory) | 270 | WorkoutTracker | TrainingAccessoryDelegate |  |  |
| **WorkoutStreak** | [Components/WorkoutStreakCard](DialedIn/Core/Training/Components/WorkoutStreakCard) | 271 |  | WorkoutStreakDelegate | WorkoutStreakCard.swift |  |
| **ActiveTrainingProgram** | [Subviews/ActiveTrainingProgram](DialedIn/Core/Training/Subviews/ActiveTrainingProgram) | 393 | EditTrainingProgram, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker | ActiveTrainingProgramDelegate, `showActiveTrainingProgramView` |  | ActiveTrainingProgramPresenterTests.swift |
| **CreateExercise** | [Subviews/AddTraining/CreateExercise](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise) | 320 | MuscleGroupPicker | `showCreateExerciseView` |  | CreateExerciseEquipmentPresenterTests.swift, CreateExerciseFlowPresenterTests.swift |
| **EquipmentPicker** | [Subviews/AddTraining/CreateExercise/EquipmentPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/EquipmentPicker) | 243 |  | EquipmentPickerDelegate, `showEquipmentPickerView` |  |  |
| **ExerciseEquipment** | [Subviews/AddTraining/CreateExercise/ExerciseEquipment](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseEquipment) | 319 | EquipmentPicker, FinalExerciseDetails | ExerciseEquipmentDelegate, `showExerciseEquipmentView` |  |  |
| **ExerciseSave** | [Subviews/AddTraining/CreateExercise/ExerciseSave](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseSave) | 368 |  | ExerciseSaveDelegate, `showExerciseSaveView` |  |  |
| **FinalExerciseDetails** | [Subviews/AddTraining/CreateExercise/FinalExerciseDetails](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/FinalExerciseDetails) | 302 | ExerciseSave | FinalExerciseDetailsDelegate, `showFinalExerciseDetailsView` |  |  |
| **MuscleGroupPicker** | [Subviews/AddTraining/CreateExercise/MuscleGroupPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/MuscleGroupPicker) | 297 | ExerciseEquipment | MuscleGroupPickerDelegate, `showMuscleGroupPickerView` |  |  |
| **CreateProgram** | [Subviews/AddTraining/CreateProgram/CreateProgram](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/CreateProgram) | 197 | NameProgram | CreateProgramDelegate, `showCreateProgramView`, `showOnboardingTrainingProgramView` |  | CreateProgramFlowPresenterTests.swift |
| **NameProgram** | [Subviews/AddTraining/CreateProgram/NameProgram](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/NameProgram) | 158 | ProgramIcon | NameProgramDelegate, `showNameProgramView` |  |  |
| **ProgramDesign** | [Subviews/AddTraining/CreateProgram/ProgramDesign](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign) | 714 | ProgramSettings, RenameWorkoutTemplateModel, ShareToFollower | EditTrainingProgramDelegate, ProgramDesignDelegate, `showEditTrainingProgramView`, `showProgramDesignView`, `showRenameWorkoutTemplateModelView` |  | ProgramDesignPresenterTests.swift |
| **ProgramSettings** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings) | 284 | EditDayOrder, EditDeload, EditProgramColourIcon, RenameProgram | `showEditDayOrderView`, `showEditDeloadView`, `showEditProgramColourIconView`, `showProgramSettingsView`, `showRenameProgramView` |  | ProgramSettingsFlowPresenterTests.swift |
| **EditDayOrder** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDayOrder](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDayOrder) | 107 |  |  |  |  |
| **EditDeload** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDeload](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDeload) | 104 |  |  |  |  |
| **EditProgramColourIcon** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditProgramColourIcon](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditProgramColourIcon) | 121 |  |  |  |  |
| **RenameDayPlan** | [Subviews/AddTraining/CreateProgram/ProgramDesign/RenameDayPlan](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/RenameDayPlan) | 119 |  | RenameWorkoutTemplateModelDelegate |  |  |
| **ProgramIcon** | [Subviews/AddTraining/CreateProgram/ProgramIcon](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramIcon) | 215 | ProgramDesign | ProgramIconDelegate, `showProgramIconView` |  |  |
| **CreateWorkout** | [Subviews/AddTraining/CreateWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout) | 154 | NameWorkout | CreateWorkoutDelegate, `showCreateWorkoutView` |  | CreateWorkoutFlowPresenterTests.swift, CreateWorkoutWrapperPresenterTests.swift |
| **ChooseGymProfile** | [Subviews/AddTraining/CreateWorkout/ChooseGymProfile](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/ChooseGymProfile) | 201 | CreateGymProfile, DefineWorkoutWrapper | ChooseGymProfileDelegate, `showChooseGymProfileView` |  |  |
| **DefineWorkout** | [Subviews/AddTraining/CreateWorkout/DefineWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkout) | 273 | ExercisesPicker, SetTarget | DefineWorkoutDelegate, `showDefineWorkoutView` |  |  |
| **DefineWorkoutWrapper** | [Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper) | 214 |  | DefineWorkoutWrapperDelegate, `showDefineWorkoutWrapperView` |  |  |
| **ExercisesPicker** | [Subviews/AddTraining/CreateWorkout/ExercisesPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/ExercisesPicker) | 180 |  | ExercisesPickerDelegate, `showExercisesPickerView` |  |  |
| **NameWorkout** | [Subviews/AddTraining/CreateWorkout/NameWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/NameWorkout) | 180 | ChooseGymProfile, DefineWorkoutWrapper | NameWorkoutDelegate, `showNameWorkoutView` |  |  |
| **SetTarget** | [Subviews/AddTraining/CreateWorkout/SetTarget](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/SetTarget) | 288 |  | SetTargetDelegate, `showSetTargetView` |  |  |
| **ExerciseSettings** | [Subviews/ExerciseSettings](DialedIn/Core/Training/Subviews/ExerciseSettings) | 325 | ExerciseModelDetail, RestModal, RestTimerSettings, WorkoutNotes | ExerciseSettingsDelegate, `showExerciseSettingsView` |  |  |
| **Exercises** | [Subviews/Exercises](DialedIn/Core/Training/Subviews/Exercises) | 110 | CreateExercise, ExerciseModelDetail | `showExercisesView` |  |  |
| **ExerciseTemplateDetail** | [Subviews/Exercises/ExerciseTemplateDetail](DialedIn/Core/Training/Subviews/Exercises/ExerciseTemplateDetail) | 812 |  | ExerciseModelDetailDelegate, `showDeleteConfirmation`, `showExerciseModelDetailView` | ExerciseModelDetailStats.swift, ExerciseTemplateDetailDelegate.swift |  |
| **ProgramManagement** | [Subviews/TrainingProgramLibrary](DialedIn/Core/Training/Subviews/TrainingProgramLibrary) | 333 | CreateProgram, EditTrainingProgram, PrebuiltProgramDetail, ProgramSettings | `showDeleteAlert`, `showTrainingProgramLibraryView` |  |  |
| **InactiveTrainingProgram** | [Subviews/TrainingProgramLibrary/InactiveTrainingProgram](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/InactiveTrainingProgram) | 155 |  | InactiveTrainingProgramDelegate, `showInactiveTrainingProgramView` |  |  |
| **PrebuiltProgramDetail** | [Subviews/TrainingProgramLibrary/PrebuiltProgramDetail](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/PrebuiltProgramDetail) | 209 |  | `showPrebuiltProgramDetailView` |  |  |
| **TrainingProgramDisclosureGroup** | [Subviews/TrainingProgramLibrary/TrainingProgramDisclosureGroup](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/TrainingProgramDisclosureGroup) | 163 | EditTrainingProgram, ShareToFollower | TrainingProgramDisclosureGroupDelegate, `showTrainingProgramDisclosureGroupView` |  |  |
| **WorkoutHistory** | [Subviews/WorkoutHistory](DialedIn/Core/Training/Subviews/WorkoutHistory) | 297 | WorkoutSessionDetail | WorkoutHistoryDelegate, `showWorkoutHistoryView` |  |  |
| **WorkoutSessionDetail** | [Subviews/WorkoutSessionDetailView](DialedIn/Core/Training/Subviews/WorkoutSessionDetailView) | 989 | ExercisesPicker, SessionDuration, SessionStartTime | WorkoutSessionDetailDelegate, `showSessionDurationView`, `showSessionStartTimeView`, `showWorkoutSessionDetailView`, `showWorkoutSessionThread` | WorkoutSessionTimingSheets.swift | WorkoutSessionDetailPresenterTests.swift |
| **WorkoutTemplateDetail** | [Subviews/WorkoutTemplateDetail](DialedIn/Core/Training/Subviews/WorkoutTemplateDetail) | 360 | CreateWorkout, ExerciseModelDetail, ShareToFollower, WorkoutTracker | WorkoutTemplateDetailDelegate, `showDeleteConfirmation`, `showWorkoutTemplateDetailView` |  |  |
| **WorkoutTracker** | [Subviews/WorkoutTracker](DialedIn/Core/Training/Subviews/WorkoutTracker) | 1908 | ExercisesPicker, GymProfile, WorkoutNotes, WorkoutSettings, WorkoutSummary | `showWorkoutSummary`, `showWorkoutTrackerView` | StravaOffer.swift, WorkoutTrackerPresenter+Events.swift, WorkoutTrackerPresenter+Exercises.swift, WorkoutTrackerPresenter+Finish.swift, WorkoutTrackerPresenter+Notes.swift, WorkoutTrackerPresenter+Progression.swift, WorkoutTrackerPresenter+Rest.swift, WorkoutTrackerPresenter+Superset.swift | WorkoutTrackerPresenterProgressionTests.swift, WorkoutTrackerPresenterTests.swift |
| **ExerciseTracker** | [Subviews/WorkoutTracker/ExerciseTracker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker) | 269 | WorkoutNotes | ExerciseTrackerDelegate |  |  |
| **SetTracker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker) | 754 | ExerciseSettings, RestModal, SetTarget, SwapExercisePicker, WarmupSetInfoModal, WarmupSets, WorkoutExerciseEquipmentSheet | SetTrackerDelegate |  | SetTrackerPresenterTests.swift |
| **SetTrackerRow** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow) | 822 | RestModal, WarmupSetInfoModal | SetTrackerRowDelegate, `showSetTrackerRowView` |  |  |
| **SetKeyboard** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard) | 1013 |  |  | PlateCalculator.swift, SetKeyboardTextField.swift, WeightStepper.swift | SetKeyboardPresenterTests.swift |
| **SwapExercisePicker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker) | 121 |  | `showSwapExercisePickerView` |  |  |
| **WarmupSets** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets) | 180 |  | WarmupSetsDelegate, `showWarmupSetsView` |  |  |
| **WorkoutExerciseEquipmentSheet** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet) | 324 |  | WorkoutExerciseEquipmentSheetDelegate, `showWorkoutExerciseEquipmentSheetView` |  |  |
| **WorkoutNotes** | [Subviews/WorkoutTracker/WorkoutNotes](DialedIn/Core/Training/Subviews/WorkoutTracker/WorkoutNotes) | 158 |  | WorkoutNotesDelegate, `showWorkoutNotesView` |  |  |
| **Workouts** | [Subviews/Workouts](DialedIn/Core/Training/Subviews/Workouts) | 124 | WorkoutTemplateDetail, WorkoutTracker | WorkoutsDelegate, `showWorkoutsView` |  |  |

## Managers

| Manager | Folder | Lines | Sync engines | Models (sibling folder) | Services | Extensions | Tests |
|---|---|---:|---|---|---|---|---|
| **ABTestManager** | [DialedIn/Managers/ABTests](DialedIn/Managers/ABTests/ABTestManager.swift) | 110 |  | ActiveABTests, PaywallTestOption | ABTestService, FirebaseABTestService, LocalABTestService, MockABTestService |  | ABTestManagerTests.swift |
| **AIManager** | [DialedIn/Managers/AI](DialedIn/Managers/AI/AIManager.swift) | 63 |  |  | AIService, GoogleAIService, MockAIService |  | AIManagerTests.swift |
| **AnalyticsSettingsManager** | [DialedIn/Managers/Analytics/AnalyticsSettings](DialedIn/Managers/Analytics/AnalyticsSettings/AnalyticsSettingsManager.swift) | 57 | Document<AnalyticsSettings> | AnalyticsSettings |  |  | AnalyticsSettingsManagerTests.swift |
| **BodyMeasurementsManager** | [DialedIn/Managers/BodyMeasurements](DialedIn/Managers/BodyMeasurements/BodyMeasurementsManager.swift) | 363 | Collection<BodyMeasurementEntry> | BodyMeasurementEntry, WeightSource |  |  | BodyMeasurementsManagerTests.swift |
| **GoalManager** | [DialedIn/Managers/Goal](DialedIn/Managers/Goal/GoalManager.swift) | 94 | Document<WeightGoal> | WeightGoal, WeightGoalBuilder |  |  | GoalManagerTests.swift |
| **HKWorkoutManager** | [DialedIn/Managers/HKWorkout](DialedIn/Managers/HKWorkout/HKWorkoutManager.swift) | 654 |  |  |  |  | HKWorkoutManagerPauseTests.swift, HKWorkoutManagerRestAlertTests.swift, HKWorkoutManagerRestTests.swift |
| **HealthKitManager** | [DialedIn/Managers/HealthKitManager](DialedIn/Managers/HealthKitManager/HealthKitManager.swift) | 117 |  |  |  |  | HealthKitManagerTests.swift |
| **ImageUploadManager** | [DialedIn/Managers/ImageUpload](DialedIn/Managers/ImageUpload/ImageUploadManager.swift) | 43 |  |  | FirebaseImageUploadService, ImageUploadService, MockImageUploadService |  | ImageUploadManagerTests.swift |
| **LiveActivityManager** | [DialedIn/Managers/LiveActivities](DialedIn/Managers/LiveActivities/LiveActivityManager.swift) | 513 |  |  |  | LiveActivityManager+Events.swift | LiveActivityManagerTests.swift |
| **ActivityNotificationManager** | [DialedIn/Managers/Notifications](DialedIn/Managers/Notifications/ActivityNotificationManager.swift) | 111 |  |  |  |  | ActivityNotificationManagerTests.swift |
| **FoodManager** | [DialedIn/Managers/Nutrition/Food](DialedIn/Managers/Nutrition/Food/FoodManager.swift) | 63 | Collection<FoodModel> | FoodModel, FoodModel+MealItem, ServingUnit |  |  | FoodManagerTests.swift |
| **FoodLogSettingsManager** | [DialedIn/Managers/Nutrition/FoodLogSettings](DialedIn/Managers/Nutrition/FoodLogSettings/FoodLogSettingsManager.swift) | 88 | Document<FoodLogSettings> | FoodLogSettings |  |  | FoodLogSettingsManagerTests.swift |
| **MealLogManager** | [DialedIn/Managers/Nutrition/MealLog](DialedIn/Managers/Nutrition/MealLog/MealLogManager.swift) | 343 | Collection<MealLogModel> | MealItemModel, MealItemSourceType, MealLogModel, MealLogModel+Mocks |  |  | MealLogManagerTests.swift |
| **NutritionManager** | [DialedIn/Managers/Nutrition/NutritionManager](DialedIn/Managers/Nutrition/NutritionManager/NutritionManager.swift) | 437 | Document<DietPlan> | DailyMacroTarget, DailyNutritionBreakdown, DietPlan |  |  | NutritionManagerDietPlanTests.swift, NutritionManagerTests.swift |
| **NutritionStrategyManager** | [DialedIn/Managers/Nutrition/NutritionStrategy](DialedIn/Managers/Nutrition/NutritionStrategy/NutritionStrategyManager.swift) | 188 | Collection<NutritionDayAnnotation>, Document<CheckInRecord>, Document<LoggingBreak> | CheckInRecord, LoggingBreak, NutritionDayAnnotation |  |  | NutritionStrategyManagerTests.swift |
| **NutritionStrategySettingsManager** | [DialedIn/Managers/Nutrition/NutritionStrategySettings](DialedIn/Managers/Nutrition/NutritionStrategySettings/NutritionStrategySettingsManager.swift) | 57 | Document<NutritionStrategySettings> | NutritionStrategySettings |  |  | NutritionStrategySettingsManagerTests.swift |
| **RecipeTemplateManager** | [DialedIn/Managers/Nutrition/RecipeTemplate](DialedIn/Managers/Nutrition/RecipeTemplate/RecipeTemplateManager.swift) | 63 | Collection<RecipeTemplateModel> | RecipeIngredientModel, RecipeTemplateModel |  |  | RecipeTemplateManagerTests.swift |
| **ProgressPhotoManager** | [DialedIn/Managers/ProgressPhotos](DialedIn/Managers/ProgressPhotos/ProgressPhotoManager.swift) | 97 | Collection<ProgressPhotoModel> |  |  |  |  |
| **PushManager** | [DialedIn/Managers/Push](DialedIn/Managers/Push/PushManager.swift) | 315 |  | PushNotificationDelegate |  |  | PushManagerTests.swift |
| **ReportManager** | [DialedIn/Managers/Reports](DialedIn/Managers/Reports/ReportManager.swift) | 95 |  |  |  |  | ReportManagerTests.swift |
| **NudgeHistoryManager** | [DialedIn/Managers/Search](DialedIn/Managers/Search/NudgeHistoryManager.swift) | 38 |  |  |  |  |  |
| **ShortcutSettingsManager** | [DialedIn/Managers/Shortcuts](DialedIn/Managers/Shortcuts/ShortcutSettingsManager.swift) | 57 | Document<ShortcutSettings> | ShortcutSettings |  |  | ShortcutSettingsManagerTests.swift |
| **CommentsManager** | [DialedIn/Managers/Social](DialedIn/Managers/Social/CommentsManager.swift) | 35 |  |  |  |  | CommentsManagerTests.swift |
| **StepsManager** | [DialedIn/Managers/Steps](DialedIn/Managers/Steps/StepsManager.swift) | 197 | Collection<StepsModel> | StepsModel |  |  | StepsManagerTests.swift |
| **StravaManager** | [DialedIn/Managers/Strava](DialedIn/Managers/Strava/StravaManager.swift) | 179 |  | StravaActivity, StravaTokenResponse | MockStravaService, ProductionStravaService, StravaService |  | StravaManagerTests.swift |
| **ExerciseModelManager** | [DialedIn/Managers/Training/Exercise](DialedIn/Managers/Training/Exercise/ExerciseModelManager.swift) | 195 | Collection<ExerciseModel> | BodyRegion, EquipmentVariation, ExerciseModel, ExerciseType, ExerciseUnitPreference, Laterality, MuscleVolume, Muscles, SetTarget, SetTargetSetType, … +3 more |  |  |  |
| **ExerciseSettingsManager** | [DialedIn/Managers/Training/Exercise/ExerciseSettings](DialedIn/Managers/Training/Exercise/ExerciseSettings/ExerciseSettingsManager.swift) | 76 | Collection<ExerciseSettingsModel> | ExerciseSettingsModel |  |  | ExerciseSettingsManagerTests.swift |
| **ExerciseUnitPreferenceManager** | [DialedIn/Managers/Training/Exercise](DialedIn/Managers/Training/Exercise/ExerciseUnitPreferenceManager.swift) | 155 |  | BodyRegion, EquipmentVariation, ExerciseModel, ExerciseType, ExerciseUnitPreference, Laterality, MuscleVolume, Muscles, SetTarget, SetTargetSetType, … +3 more |  |  | ExerciseUnitPreferenceManagerTests.swift |
| **GymProfileManager** | [DialedIn/Managers/Training/GymProfile](DialedIn/Managers/Training/GymProfile/GymProfileManager.swift) | 110 | Collection<GymProfileModel> | AccessoryEquipment, AnyEquipment, Bands, BodyWeights, BodyWeights+Defaults, CableMachine, EquipmentConformances, EquipmentKind, EquipmentRef, FixedWeightBars, … +22 more |  |  | GymProfileManagerTests.swift |
| **TrainingProgramManager** | [DialedIn/Managers/Training/TrainingProgram](DialedIn/Managers/Training/TrainingProgram/TrainingProgramManager.swift) | 274 | Collection<TrainingProgram> | TrainingProgram |  |  | TrainingProgramManagerTests.swift |
| **WorkoutSessionManager** | [DialedIn/Managers/Training/WorkoutSession](DialedIn/Managers/Training/WorkoutSession/WorkoutSessionManager.swift) | 401 | Collection<WorkoutSessionModel>, CollectionGroup<WorkoutSessionModel> | SetSide, WorkoutExerciseModel, WorkoutSessionComment, WorkoutSessionModel, WorkoutSessionModel+Prefill, WorkoutSessionModel+WarmupSets, WorkoutSetModel, WorkoutSetPairing | FirebaseWorkoutSessionLikeService, MockWorkoutSessionLikeService, WorkoutSessionLikeService |  | WorkoutSessionManagerTests.swift |
| **WorkoutSettingsManager** | [DialedIn/Managers/Training/WorkoutSettings](DialedIn/Managers/Training/WorkoutSettings/WorkoutSettingsManager.swift) | 47 | Document<WorkoutSettings> | WorkoutSettings |  |  | WorkoutSettingsManagerTests.swift |
| **WorkoutTemplateManager** | [DialedIn/Managers/Training/WorkoutTemplate](DialedIn/Managers/Training/WorkoutTemplate/WorkoutTemplateManager.swift) | 210 | Collection<WorkoutTemplateModel> | WorkoutTemplateModel |  |  | WorkoutTemplateManagerTests.swift |
| **UserManager** | [DialedIn/Managers/User](DialedIn/Managers/User/UserManager.swift) | 720 | Collection<UserModel>, Document<PrivateUserSettings>, Document<UserModel> | FollowRequestModel, PrivateUserSettings, UserModel, UserModel+Mocks, Username | FirebaseUserQueryService, MockUserQueryService, UserQueryService | UserManager+RemoveFollower.swift, UserManager+Username.swift | UserManagerAccountDeletionTests.swift, UserManagerTests.swift |

## Sync models (`DataSyncModelProtocol`)

| Model | File |
|---|---|
| `AnalyticsSettings` | [DialedIn/Managers/Analytics/AnalyticsSettings/Models/AnalyticsSettings.swift](DialedIn/Managers/Analytics/AnalyticsSettings/Models/AnalyticsSettings.swift) |
| `BodyMeasurementEntry` | [DialedIn/Managers/BodyMeasurements/Models/BodyMeasurementEntry.swift](DialedIn/Managers/BodyMeasurements/Models/BodyMeasurementEntry.swift) |
| `CheckInRecord` | [DialedIn/Managers/Nutrition/NutritionStrategy/Models/CheckInRecord.swift](DialedIn/Managers/Nutrition/NutritionStrategy/Models/CheckInRecord.swift) |
| `DietPlan` | [DialedIn/Managers/Nutrition/NutritionManager/Models/DietPlan.swift](DialedIn/Managers/Nutrition/NutritionManager/Models/DietPlan.swift) |
| `EquipmentRef` | [DialedIn/Managers/Training/GymProfile/Model/Equipment/EquipmentRef.swift](DialedIn/Managers/Training/GymProfile/Model/Equipment/EquipmentRef.swift) |
| `ExerciseModel` | [DialedIn/Managers/Training/Exercise/Models/ExerciseModel.swift](DialedIn/Managers/Training/Exercise/Models/ExerciseModel.swift) |
| `ExerciseSettingsModel` | [DialedIn/Managers/Training/Exercise/ExerciseSettings/Models/ExerciseSettingsModel.swift](DialedIn/Managers/Training/Exercise/ExerciseSettings/Models/ExerciseSettingsModel.swift) |
| `FoodLogSettings` | [DialedIn/Managers/Nutrition/FoodLogSettings/Models/FoodLogSettings.swift](DialedIn/Managers/Nutrition/FoodLogSettings/Models/FoodLogSettings.swift) |
| `FoodModel` | [DialedIn/Managers/Nutrition/Food/Models/FoodModel.swift](DialedIn/Managers/Nutrition/Food/Models/FoodModel.swift) |
| `GymProfileModel` | [DialedIn/Managers/Training/GymProfile/Model/GymProfile/GymProfileModel.swift](DialedIn/Managers/Training/GymProfile/Model/GymProfile/GymProfileModel.swift) |
| `LoggingBreak` | [DialedIn/Managers/Nutrition/NutritionStrategy/Models/LoggingBreak.swift](DialedIn/Managers/Nutrition/NutritionStrategy/Models/LoggingBreak.swift) |
| `MealItemModel` | [DialedIn/Managers/Nutrition/MealLog/Models/MealItemModel.swift](DialedIn/Managers/Nutrition/MealLog/Models/MealItemModel.swift) |
| `MealLogModel` | [DialedIn/Managers/Nutrition/MealLog/Models/MealLogModel.swift](DialedIn/Managers/Nutrition/MealLog/Models/MealLogModel.swift) |
| `NutritionDayAnnotation` | [DialedIn/Managers/Nutrition/NutritionStrategy/Models/NutritionDayAnnotation.swift](DialedIn/Managers/Nutrition/NutritionStrategy/Models/NutritionDayAnnotation.swift) |
| `NutritionStrategySettings` | [DialedIn/Managers/Nutrition/NutritionStrategySettings/Models/NutritionStrategySettings.swift](DialedIn/Managers/Nutrition/NutritionStrategySettings/Models/NutritionStrategySettings.swift) |
| `PrivateUserSettings` | [DialedIn/Managers/User/Models/PrivateUserSettings.swift](DialedIn/Managers/User/Models/PrivateUserSettings.swift) |
| `ProgressPhotoModel` | [DialedIn/Managers/ProgressPhotos/ProgressPhotoModel.swift](DialedIn/Managers/ProgressPhotos/ProgressPhotoModel.swift) |
| `RecipeIngredientModel` | [DialedIn/Managers/Nutrition/RecipeTemplate/Models/RecipeIngredientModel.swift](DialedIn/Managers/Nutrition/RecipeTemplate/Models/RecipeIngredientModel.swift) |
| `RecipeTemplateModel` | [DialedIn/Managers/Nutrition/RecipeTemplate/Models/RecipeTemplateModel.swift](DialedIn/Managers/Nutrition/RecipeTemplate/Models/RecipeTemplateModel.swift) |
| `SetTarget` | [DialedIn/Managers/Training/Exercise/Models/SetTarget.swift](DialedIn/Managers/Training/Exercise/Models/SetTarget.swift) |
| `ShortcutSettings` | [DialedIn/Managers/Shortcuts/Models/ShortcutSettings.swift](DialedIn/Managers/Shortcuts/Models/ShortcutSettings.swift) |
| `StepsModel` | [DialedIn/Managers/Steps/Models/StepsModel.swift](DialedIn/Managers/Steps/Models/StepsModel.swift) |
| `TrainingProgram` | [DialedIn/Managers/Training/TrainingProgram/Models/TrainingProgram.swift](DialedIn/Managers/Training/TrainingProgram/Models/TrainingProgram.swift) |
| `UserModel` | [DialedIn/Managers/User/Models/UserModel.swift](DialedIn/Managers/User/Models/UserModel.swift) |
| `WeightGoal` | [DialedIn/Managers/Goal/Models/WeightGoal.swift](DialedIn/Managers/Goal/Models/WeightGoal.swift) |
| `WorkoutExerciseModel` | [DialedIn/Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift](DialedIn/Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift) |
| `WorkoutSessionModel` | [DialedIn/Managers/Training/WorkoutSession/Models/WorkoutSessionModel.swift](DialedIn/Managers/Training/WorkoutSession/Models/WorkoutSessionModel.swift) |
| `WorkoutSettings` | [DialedIn/Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift](DialedIn/Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift) |
| `WorkoutTemplateExercise` | [DialedIn/Managers/Training/Exercise/Models/WorkoutTemplateExercise.swift](DialedIn/Managers/Training/Exercise/Models/WorkoutTemplateExercise.swift) |
| `WorkoutTemplateModel` | [DialedIn/Managers/Training/WorkoutTemplate/Models/WorkoutTemplateModel.swift](DialedIn/Managers/Training/WorkoutTemplate/Models/WorkoutTemplateModel.swift) |

## CoreInteractor and its extensions

| File | Lines |
|---|---:|
| [CoreBuilder.swift](DialedIn/Root/RIBs/Core/CoreBuilder.swift) | 18 |
| [CoreInteractor+AccountDeletion.swift](DialedIn/Root/RIBs/Core/CoreInteractor+AccountDeletion.swift) | 39 |
| [CoreInteractor+CircleGoals.swift](DialedIn/Root/RIBs/Core/CoreInteractor+CircleGoals.swift) | 15 |
| [CoreInteractor+PreviousWorkoutReference.swift](DialedIn/Root/RIBs/Core/CoreInteractor+PreviousWorkoutReference.swift) | 114 |
| [CoreInteractor+Progression.swift](DialedIn/Root/RIBs/Core/CoreInteractor+Progression.swift) | 105 |
| [CoreInteractor+ScheduledPush.swift](DialedIn/Root/RIBs/Core/CoreInteractor+ScheduledPush.swift) | 10 |
| [CoreInteractor+Username.swift](DialedIn/Root/RIBs/Core/CoreInteractor+Username.swift) | 17 |
| [CoreInteractor.swift](DialedIn/Root/RIBs/Core/CoreInteractor.swift) | 302 |
| [CoreRouter.swift](DialedIn/Root/RIBs/Core/CoreRouter.swift) | 32 |

## Cloud Functions (`functions/index.js`)

| Export | Kind | Line |
|---|---|---|
| `foodAnalyze` | onCall | [index.js:112](functions/index.js#L112) |
| `mealDescribe` | onCall | [index.js:158](functions/index.js#L158) |
| `nutritionLabelAnalyze` | onCall | [index.js:199](functions/index.js#L199) |
| `chatGenerate` | onCall | [index.js:230](functions/index.js#L230) |
| `imageGenerate` | onCall | [index.js:258](functions/index.js#L258) |
| `foodSearch` | onCall | [index.js:287](functions/index.js#L287) |
| `onActivityNotificationCreated` | onDocumentCreated | [index.js:421](functions/index.js#L421) |
| `onUserBlockListChanged` | onDocumentUpdated | [index.js:462](functions/index.js#L462) |
| `onFollowRequestUpdated` | onDocumentUpdated | [index.js:493](functions/index.js#L493) |
| `onFollowRequestCreated` | onDocumentCreated | [index.js:520](functions/index.js#L520) |
| `removeFollower` | onCall | [index.js:546](functions/index.js#L546) |
| `onUserFollowingChanged` | onDocumentUpdated | [index.js:566](functions/index.js#L566) |
| `onUserPrivacyChanged` | onDocumentUpdated | [index.js:588](functions/index.js#L588) |
| `onUsernameChanged` | onDocumentWritten | [index.js:620](functions/index.js#L620) |
| `streakReminder` | onSchedule | [index.js:673](functions/index.js#L673) |
| `weeklyDigest` | onSchedule | [index.js:689](functions/index.js#L689) |
| `onUserDeleted` | onDocumentDeleted | [index.js:724](functions/index.js#L724) |
| `onReportCreated` | onDocumentCreated | [index.js:797](functions/index.js#L797) |
| `onWorkoutSessionEndedForChallenges` | onDocumentWritten | [index.js:831](functions/index.js#L831) |
| `acceptInvite` | onCall | [index.js:875](functions/index.js#L875) |
| `sessionPage` | onRequest | [index.js:934](functions/index.js#L934) |

## Firestore paths (`firestore.rules`)

| Path | Rules |
|---|---|
| `/users/{user_id}` | [rules:47](firestore.rules#L47) |
| `/users/{user_id}/private/{private_id}` | [rules:55](firestore.rules#L55) |
| `/users/{user_id}/body_measurements/{entry_id}` | [rules:60](firestore.rules#L60) |
| `/users/{user_id}/steps/{entry_id}` | [rules:71](firestore.rules#L71) |
| `/users/{user_id}/goals/{goal_id}` | [rules:82](firestore.rules#L82) |
| `/users/{user_id}/gym_profiles/{gym_profile_id}` | [rules:94](firestore.rules#L94) |
| `/users/{user_id}/training_programs/{training_program_id}` | [rules:101](firestore.rules#L101) |
| `/users/{user_id}/workout_sessions/{workout_session_id}` | [rules:110](firestore.rules#L110) |
| `/users/{user_id}/workout_templates/{workout_templates_id}` | [rules:127](firestore.rules#L127) |
| `/users/{user_id}/workout_settings/{workout_settings_id}` | [rules:134](firestore.rules#L134) |
| `/users/{user_id}/exercise_settings/{exercise_settings_id}` | [rules:139](firestore.rules#L139) |
| `/users/{user_id}/food_log_settings/{food_log_settings_id}` | [rules:144](firestore.rules#L144) |
| `/users/{user_id}/analytics_settings/{analytics_settings_id}` | [rules:149](firestore.rules#L149) |
| `/users/{user_id}/shortcut_settings/{shortcut_settings_id}` | [rules:154](firestore.rules#L154) |
| `/users/{user_id}/nutrition_strategy_settings/{nutrition_strategy_settings_id}` | [rules:159](firestore.rules#L159) |
| `/users/{user_id}/nutrition_day_annotations/{day_key}` | [rules:165](firestore.rules#L165) |
| `/users/{user_id}/logging_break/{logging_break_id}` | [rules:176](firestore.rules#L176) |
| `/users/{user_id}/check_in_record/{check_in_record_id}` | [rules:186](firestore.rules#L186) |
| `/users/{user_id}/meal_logs/{document=**}` | [rules:197](firestore.rules#L197) |
| `/users/{user_id}/recipe_templates/{workout_templates_id}` | [rules:202](firestore.rules#L202) |
| `/users/{user_id}/foods/{food_id}` | [rules:209](firestore.rules#L209) |
| `/users/{user_id}/follow_requests/{requester_id}` | [rules:221](firestore.rules#L221) |
| `/users/{user_id}/notifications/{notification_id}` | [rules:243](firestore.rules#L243) |
| `/user_streaks/{user_id}` | [rules:259](firestore.rules#L259) |
| `/user_streaks/{user_id}/workout/{document_id}` | [rules:264](firestore.rules#L264) |
| `/user_streaks/{user_id}/workout/{document_id}/data/{data_id}` | [rules:267](firestore.rules#L267) |
| `/food_search_cache/{doc}` | [rules:275](firestore.rules#L275) |
| `/{path=**}/workout_sessions/{workout_session_id}` | [rules:284](firestore.rules#L284) |
| `/{path=**}/follow_requests/{requester_id}` | [rules:292](firestore.rules#L292) |
| `/ingredient_templates/{ingredient_id}` | [rules:297](firestore.rules#L297) |
| `/recipe_templates/{recipe_id}` | [rules:304](firestore.rules#L304) |
| `/diet_plans/{user_id}` | [rules:311](firestore.rules#L311) |
| `/gym_profiles/{gym_profile_id}` | [rules:318](firestore.rules#L318) |
| `/exercise_templates/{exercise_id}` | [rules:325](firestore.rules#L325) |
| `/exercise_history/{exercise_history_id}` | [rules:332](firestore.rules#L332) |
| `/workout_templates/{workout_template_id}` | [rules:338](firestore.rules#L338) |
| `/workout_exercises/{exercise_id}` | [rules:349](firestore.rules#L349) |
| `/workout_sets/{set_id}` | [rules:356](firestore.rules#L356) |
| `/program_templates/{program_template_id}` | [rules:363](firestore.rules#L363) |
| `/training_plans/{training_plan_id}` | [rules:370](firestore.rules#L370) |
| `/training_programs/{training_program_id}` | [rules:378](firestore.rules#L378) |
| `/reports/{report_id}` | [rules:388](firestore.rules#L388) |
| `/moderation_queue/{target_id}` | [rules:408](firestore.rules#L408) |
| `/workout_session_comments/{comment_id}` | [rules:414](firestore.rules#L414) |
| `/usernames/{handle}` | [rules:454](firestore.rules#L454) |
| `/shares/{share_id}` | [rules:466](firestore.rules#L466) |
| `/challenges/{challenge_id}` | [rules:492](firestore.rules#L492) |
| `/progress/{member_id}` | [rules:523](firestore.rules#L523) |
| `/invites/{code}` | [rules:534](firestore.rules#L534) |
| `/users/{user_id}/progress_photos/{photo_id}` | [rules:551](firestore.rules#L551) |

## Unit test suites

**`DialedInUnitTests`** (1): `DialedInTests`

**`DialedInUnitTests/Components`** (9): `AutoSelectNumberFieldTextTests`, `CalendarDayMarkerAccessibilityTests`, `CalendarDayMarkerRingStyleTests`, `CalendarHeaderPresenterTests`, `CustomPaywallViewTests`, `ExerciseImageViewTests`, `ListBuilderSelectionTests`, `MetricChartReadingsTests`, `SetDetailRowTests`

**`DialedInUnitTests/Core`** (142): `AIFoodInputPresenterTests`, `ActiveTrainingProgramPresenterTests`, `AddMealPresenterTests`, `AmountPresenterTests`, `AnalyticsBodyMetricsPresenterTests`, `AnalyticsConsistencyPresenterTests`, `AnalyticsExercisePresenterTests`, `AnalyticsInsightsPresenterTests`, `AnalyticsNutritionPresenterTests`, `AnalyticsPresenterTests`, `AppShellPresenterTests`, `BarcodeScannerHandoffTests`, `BarcodeScannerPresenterTests`, `BodyMeasurementTests`, `ChallengesPresenterTests`, `CheckInPresenterTests`, `CircleGoalsPresenterTests`, `CircleWeekTests`, `CommentLikesTests`, `CommentMentionsTests`, `ContentDeletionPresenterTests`, `CreateExerciseEquipmentPresenterTests`, `CreateExerciseFlowPresenterTests`, `CreateFoodFlowPresenterTests`, `CreateProgramFlowPresenterTests`, `CreateWorkoutFlowPresenterTests`, `CreateWorkoutWrapperPresenterTests`, `DecimalWheelValueTests`, `DeleteAccountPresenterTests`, `DevToolsPresenterTests`, `EnergyBalancePresenterTests`, `ErrorAlertMessageTests`, `ExerciseModelDetailPresenterTests`, `FeedLoadingTests`, `FollowersListRemoveTests`, `FoodDefinitionPresenterTests`, `FoodItemQuickAddPresenterTests`, `FoodLibraryPresenterTests`, `FoodLogSettingsStaleSnapshotTests`, `GeneralSettingsPresenterTests`, `GymEquipmentAdderPresenterTests`, `GymEquipmentEditorPresenterTests`, `GymMachineEditorPresenterTests`, `GymProfilePresenterTests`, `GymProfilesListPresenterTests`, `HabitsPresenterTests`, `InviteTests`, `MacroHeaderRemainingTests`, `MealHourHeaderPresenterTests`, `MetricDetailPresenterTests`, `MuscleBalanceTests`, `MuscleGroupDetailPresenterTests`, `NotificationGroupingTests`, `NotificationSettingsPresenterTests`, `NotificationTapThroughTests`, `NotificationsFollowRequestTests`, `NutritionOverviewPresenterTests`, `NutritionPresenterTests`, `NutritionSettingsPresenterTests`, `NutritionSettingsTilePresenterTests`, `NutritionTargetChartColourTests`, `OfflineDetectionTests`, `OnboardingAccountSetupPresenterTests`, `OnboardingAppleHealthFillTests`, `OnboardingAuthPresenterTests`, `OnboardingCompletedRetryTests`, `OnboardingDietChoicesPresenterTests`, `OnboardingDietPlanPresenterTests`, `OnboardingEntryPresenterTests`, `OnboardingExpenditurePresenterTests`, `OnboardingFinishPresenterTests`, `OnboardingGoalSettingPresenterTests`, `OnboardingGoalSummaryEstimateTests`, `OnboardingGoalSummaryPresenterTests`, `OnboardingHealthConsentPresenterTests`, `OnboardingHeightConversionTests`, `OnboardingLifestylePresenterTests`, `OnboardingSelectionHapticsTests`, `OnboardingStepRouterTests`, `OnboardingWeightRatePresenterTests`, `PaywallPresenterTests`, `PrevWORefSettingsPresenterTests`, `PreviousWorkoutReferenceResolverTests`, `ProfileAccountPresenterTests`, `ProfileAppInfoPresenterTests`, `ProfilePresenterTests`, `ProgramDesignPresenterTests`, `ProgramSettingsFlowPresenterTests`, `ProgramSharingTests`, `ProgressPhotosPresenterTests`, `RecipeFlowPresenterTests`, `RecipePreparationPresenterTests`, `RecipeScalingPresenterTests`, `ReminderOfferFlowTests`, `ReportReasonsTests`, `ReviewMomentTests`, `ReviewPromptPolicyTests`, `SaveFailureAlertTests`, `SessionVolumeUnitTests`, `SessionWebLinkTests`, `SetKeyboardPresenterTests`, `SetSideTrackingTests`, `SetTrackerPresenterTests`, `SettingsSnapshotRefreshTests`, `ShareCardTests`, `SignOutListenersTests`, `SocialCirclePresenterTests`, `SocialPresenterTests`, `SocialProfilePresenterTests`, `SocialSafetyTests`, `SocialWorkoutSessionRowTests`, `StravaOfferTests`, `StreakVisibilityTests`, `TimelineActionsPresenterTests`, `TimerDurationPresenterTests`, `TodayPresenterTests`, `TrainingHomePresenterTests`, `TrainingLibraryPresenterTests`, `TrainingSearchTests`, `TrainingSettingsPresenterTests`, `WeeklyReviewTests`, `WeightStepperTests`, `WeightTrendPresenterTests`, `WorkoutBuildUnsavedChangesTests`, `WorkoutNotesTests`, `WorkoutPausedTimeTests`, `WorkoutPresenterTests`, `WorkoutSessionAuthorTests`, `WorkoutSessionDeleteFailureTests`, `WorkoutSessionDetailPresenterTests`, `WorkoutSessionHighlightsTests`, `WorkoutSessionRowStatsTests`, `WorkoutSessionSaveAsTemplateTests`, `WorkoutSessionTemplateBuilderTests`, `WorkoutTrackerFinishTests`, `WorkoutTrackerPresenterProgressionTests`, `WorkoutTrackerPresenterTests`, `WorkoutTrackerQuickFinishTests`, `WorkoutTrackerRestFeedbackTests`, `WorkoutTrackerSupersetTests`, `WorkoutTrackingRowPresenterTests`, `WorkoutTrackingSheetPresenterTests`

**`DialedInUnitTests/DesignSystem`** (2): `FormatTests`, `OnboardingStepProgressTests`

**`DialedInUnitTests/Extensions`** (2): `CollectionAndStringExtensionTests`, `DateExtensionTests`

**`DialedInUnitTests/Managers`** (27): `ABTestManagerTests`, `AIManagerTests`, `ActivityNotificationManagerTests`, `AdjustLastSetRepsIntentTests`, `AppIntentsTests`, `AppStateTests`, `HKWorkoutManagerPauseTests`, `HKWorkoutManagerRestAlertTests`, `HKWorkoutManagerRestTests`, `HealthKitManagerTests`, `ImageUploadManagerTests`, `LiveActivityEventNameTests`, `LiveActivityIntentHandlerTests`, `LiveActivityPhaseTests`, `LiveActivityScenarioTests`, `LiveActivitySetTargetLabelTests`, `PremiumAccessTests`, `PushManagerTests`, `PushPendingDeepLinkTests`, `ReportManagerTests`, `RestDurationRulesTests`, `RestOverAlertTests`, `RestOverMessageTests`, `StepsManagerTests`, `StravaManagerTests`, `WorkoutLocationTypeDescriptionTests`, `WorkoutSettingsLockScreenTests`

**`DialedInUnitTests/Managers/FirestoreCost`** (2): `DataAccessLogTests`, `FollowingQueriesTests`

**`DialedInUnitTests/Managers/Nutrition`** (5): `CheckInScheduleTests`, `ExpenditureEngineTests`, `ExpenditureSampleBuilderTests`, `NutritionScalingTests`, `TargetProposalTests`

**`DialedInUnitTests/Managers/Training`** (2): `ProgressionEngineTests`, `ProgressionSuggestionDisplayTests`

**`DialedInUnitTests/Services/AI`** (1): `ImageDescriptionBuilderTests`

**`DialedInUnitTests/Services/Analytics`** (1): `AnalyticsSettingsManagerTests`

**`DialedInUnitTests/Services/BodyMeasurements`** (2): `BodyMeasurementEntryTests`, `BodyMeasurementsManagerTests`

**`DialedInUnitTests/Services/Goal`** (1): `GoalManagerTests`

**`DialedInUnitTests/Services/Goal/Models`** (4): `WeightGoalComputedPropertiesAndCalculationsTests`, `WeightGoalEqualityAndCodableTests`, `WeightGoalInitializationTests`, `WeightGoalMocksAndEdgeCasesTests`

**`DialedInUnitTests/Services/Nutrition`** (12): `ExpenditureEstimationMethodTests`, `FoodLogSettingsManagerTests`, `FoodManagerTests`, `MealLogManagerTests`, `MealLogModelTests`, `NutrientMapTests`, `NutritionManagerDietPlanTests`, `NutritionManagerTests`, `NutritionStrategyManagerTests`, `NutritionStrategySettingsManagerTests`, `RecipeTemplateManagerTests`, `RecipeTemplateModelTests`

**`DialedInUnitTests/Services/Nutrition/IngredientTemplate/Models`** (3): `IngredientTemplateModelCodableAndProtocolTests`, `IngredientTemplateModelInitializationTests`, `IngredientTemplateModelMockAndEdgeCasesTests`

**`DialedInUnitTests/Services/Shortcuts`** (1): `ShortcutSettingsManagerTests`

**`DialedInUnitTests/Services/Social`** (1): `CommentsManagerTests`

**`DialedInUnitTests/Services/Training`** (3): `GymProfileSyncTests`, `LiveActivityManagerTests`, `WorkoutTemplateModelTests`

**`DialedInUnitTests/Services/Training/ExerciseTemplate`** (3): `ExerciseTemplateManagerErrorHandlingTests`, `ExerciseTemplateManagerTests`, `ExerciseUnitPreferenceManagerTests`

**`DialedInUnitTests/Services/Training/ExerciseTemplate/Models`** (4): `ExerciseTemplateEnumTests`, `ExerciseTemplateModelCodableAndProtocolTests`, `ExerciseTemplateModelInitializationTests`, `ExerciseTemplateModelMockAndEdgeCasesTests`

**`DialedInUnitTests/Services/Training/GymProfile`** (1): `GymProfileManagerTests`

**`DialedInUnitTests/Services/Training/Settings`** (2): `ExerciseSettingsManagerTests`, `WorkoutSettingsManagerTests`

**`DialedInUnitTests/Services/Training/TrainingProgram`** (2): `PrebuiltProgramTests`, `TrainingProgramManagerTests`

**`DialedInUnitTests/Services/Training/WorkoutSession`** (6): `WarmupSetGenerationTests`, `WorkoutExerciseAndSetTests`, `WorkoutSessionManagerTests`, `WorkoutSessionModelTests`, `WorkoutSessionPrefillTests`, `WorkoutSetSideTests`

**`DialedInUnitTests/Services/Training/WorkoutTemplate`** (2): `WorkoutTemplateManagerTests`, `WorkoutTemplateSeedingTests`

**`DialedInUnitTests/Services/User`** (3): `UserManagerAccountDeletionTests`, `UserManagerTests`, `UsernameTests`

**`DialedInUnitTests/Services/User/Models`** (2): `OnboardingStepInferenceTests`, `UserModelTests`

**`DialedInUnitTests/Support`** (1): `WorkoutRestSharedStateTests`

**`DialedInUnitTests/Utilities`** (4): `PrivacyManifestTests`, `RetryPolicyTests`, `UnitConversionTests`, `WeightTrendCalculatorTests`

**`DialedInUnitTests/Widgets`** (1): `WidgetSnapshotTests`

**`DialedInUITests`**: `CreateExerciseUITests`, `CreateProgramUITests`, `CreateWorkoutUITests`, `OnboardingUITests`, `ScreenDeckSmokeTests+Screens`, `ScreenDeckSmokeTests`, `UITestApp`


## Scripts, docs, CI, backend files

| File | Lines |
|---|---:|
| [scripts/clean-simulators.sh](scripts/clean-simulators.sh) | 38 |
| [scripts/codebase-map.py](scripts/codebase-map.py) | 378 |
| [scripts/contact-sheet.py](scripts/contact-sheet.py) | 42 |
| [scripts/gen-smoke-tests.sh](scripts/gen-smoke-tests.sh) | 29 |
| [scripts/screenshots-diff.py](scripts/screenshots-diff.py) | 119 |
| [scripts/screenshots.sh](scripts/screenshots.sh) | 94 |
| [docs/AppPrivacy.md](docs/AppPrivacy.md) | 101 |
| [docs/dead-settings-audit.md](docs/dead-settings-audit.md) | 279 |
| [docs/release-checklist.md](docs/release-checklist.md) | 60 |
| [docs/reviews/hig-active-workout.md](docs/reviews/hig-active-workout.md) | 527 |
| [docs/reviews/hig-analytics-charts.md](docs/reviews/hig-analytics-charts.md) | 474 |
| [docs/reviews/hig-dashboard-social.md](docs/reviews/hig-dashboard-social.md) | 552 |
| [docs/reviews/hig-decisions.md](docs/reviews/hig-decisions.md) | 209 |
| [docs/reviews/hig-foundations.md](docs/reviews/hig-foundations.md) | 502 |
| [docs/reviews/hig-handoffs.md](docs/reviews/hig-handoffs.md) | 252 |
| [docs/reviews/hig-index.md](docs/reviews/hig-index.md) | 182 |
| [docs/reviews/hig-nutrition.md](docs/reviews/hig-nutrition.md) | 531 |
| [docs/reviews/hig-onboarding-data-steps.md](docs/reviews/hig-onboarding-data-steps.md) | 525 |
| [docs/reviews/hig-profile-settings-paywalls.md](docs/reviews/hig-profile-settings-paywalls.md) | 520 |
| [docs/reviews/hig-screenshot-review.md](docs/reviews/hig-screenshot-review.md) | 256 |
| [docs/reviews/hig-shell-navigation.md](docs/reviews/hig-shell-navigation.md) | 538 |
| [docs/reviews/hig-training-library.md](docs/reviews/hig-training-library.md) | 554 |
| [docs/reviews/live-activity-review.md](docs/reviews/live-activity-review.md) | 260 |
| [docs/reviews/onboarding-hig-review.md](docs/reviews/onboarding-hig-review.md) | 169 |
| [docs/reviews/tab-layout-ux-audit.md](docs/reviews/tab-layout-ux-audit.md) | 184 |
| [docs/specs/adaptive-expenditure.md](docs/specs/adaptive-expenditure.md) | 281 |
| [docs/specs/live-activity-work-packages.md](docs/specs/live-activity-work-packages.md) | 372 |
| [docs/specs/live-activity.md](docs/specs/live-activity.md) | 316 |
| [docs/specs/smart-progression.md](docs/specs/smart-progression.md) | 231 |
| [docs/specs/ui-framework/CONTRACT.md](docs/specs/ui-framework/CONTRACT.md) | 261 |
| [docs/specs/ui-framework/README.md](docs/specs/ui-framework/README.md) | 133 |
| [docs/specs/ui-framework/accent-swap-findings.md](docs/specs/ui-framework/accent-swap-findings.md) | 51 |
| [docs/specs/ui-framework/wave-3-checklist.md](docs/specs/ui-framework/wave-3-checklist.md) | 77 |
| [docs/specs/ui-framework/wp-01-tokens.md](docs/specs/ui-framework/wp-01-tokens.md) | 67 |
| [docs/specs/ui-framework/wp-02-dead-code.md](docs/specs/ui-framework/wp-02-dead-code.md) | 37 |
| [docs/specs/ui-framework/wp-03-bug-fixes.md](docs/specs/ui-framework/wp-03-bug-fixes.md) | 38 |
| [docs/specs/ui-framework/wp-04-shell.md](docs/specs/ui-framework/wp-04-shell.md) | 52 |
| [docs/specs/ui-framework/wp-05-surfaces.md](docs/specs/ui-framework/wp-05-surfaces.md) | 55 |
| [docs/specs/ui-framework/wp-06-rows-inputs.md](docs/specs/ui-framework/wp-06-rows-inputs.md) | 61 |
| [docs/specs/ui-framework/wp-07-actions-scaffolds.md](docs/specs/ui-framework/wp-07-actions-scaffolds.md) | 55 |
| [docs/specs/ui-framework/wp-08-nutrition.md](docs/specs/ui-framework/wp-08-nutrition.md) | 36 |
| [docs/specs/ui-framework/wp-09-active-workout.md](docs/specs/ui-framework/wp-09-active-workout.md) | 56 |
| [docs/specs/ui-framework/wp-10-training-library.md](docs/specs/ui-framework/wp-10-training-library.md) | 39 |
| [docs/specs/ui-framework/wp-11-dashboard-social.md](docs/specs/ui-framework/wp-11-dashboard-social.md) | 43 |
| [docs/specs/ui-framework/wp-12-profile-paywalls.md](docs/specs/ui-framework/wp-12-profile-paywalls.md) | 49 |
| [docs/specs/ui-framework/wp-13-onboarding.md](docs/specs/ui-framework/wp-13-onboarding.md) | 55 |
| [docs/specs/ui-framework/wp-14-analytics.md](docs/specs/ui-framework/wp-14-analytics.md) | 39 |
| [docs/specs/ui-framework/wp-15-lock-in.md](docs/specs/ui-framework/wp-15-lock-in.md) | 52 |
| [docs/specs/weekly-check-in.md](docs/specs/weekly-check-in.md) | 128 |
| [docs/ui-audit.md](docs/ui-audit.md) | 120 |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | 219 |
| [functions/functions.test.js](functions/functions.test.js) | 504 |
| [functions/index.js](functions/index.js) | 956 |
| [functions/index.test.js](functions/index.test.js) | 737 |
| [functions/lib.js](functions/lib.js) | 750 |
| [functions/rules.test.js](functions/rules.test.js) | 397 |
| [functions/scripts/migrateEquipmentVariations.js](functions/scripts/migrateEquipmentVariations.js) | 177 |
