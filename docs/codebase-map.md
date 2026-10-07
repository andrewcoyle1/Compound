# Compound codebase map

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

**A test for `Foo`** is `CompoundUnitTests/**/FooTests.swift` or `FooPresenterTests.swift`, run with
`-only-testing:CompoundUnitTests/FooPresenterTests`. Shared doubles are in `CompoundUnitTests/Support`
(`TestManagers.swift` builds real managers on mock engines; `TestDoubles.swift` has `SpyGlobalInteractor` and
`SpyOnboardingRouter`).

**A Firestore collection** is named in `firestore.rules` (table below), wired in `Dependencies.swift`
through a `FirebaseRemoteCollectionService(collectionPath:)` closure that usually reads the signed-in
uid, and indexed in `firestore.indexes.json`. Adding one means all three plus a deploy.

## Cross-cutting flows

- **Launch**: `CompoundApp` → `AppDelegate.application(_:didFinishLaunchingWithOptions:)` picks
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
| `Compound/Core/Analytics` | 123 | 11,747 | Progress tab: body metrics, exercise/nutrition analytics, insights, consistency |
| `Compound/Core/AppView` | 7 | 737 | Root view: onboarding-or-tabbar switch, toasts, notification banner |
| `Compound/Core/Challenges` | 11 | 837 | Group challenges (create, detail) |
| `Compound/Core/Social` | 39 | 5,088 | Social tab: workout feed, circle goals, challenges, people search, invites, share card, profiles |
| `Compound/Core/Today` | 13 | 1,904 | Today tab: today's workout, nutrition, weigh-in, streak, weekly check-in and weekly review |
| `Compound/Core/DevSettings` | 4 | 809 | DEV/MOCK-only developer tools screen |
| `Compound/Core/Notifications` | 10 | 1,391 | Activity notifications inbox |
| `Compound/Core/Nutrition` | 142 | 13,398 | Nutrition tab: meal log, foods, recipes, check-in, library picker, AI scanners |
| `Compound/Core/Onboarding` | 98 | 7,186 | Numbered onboarding steps 0–9 (see OnboardingStepRouter) |
| `Compound/Core/Paywalls` | 9 | 888 | Paywall screens |
| `Compound/Core/Profile` | 185 | 12,267 | Settings (behind the profile's gear) and every settings screen (training, nutrition, general, edit profile, legal) |
| `Compound/Core/Sharing` | 8 | 526 | Share-to-follower and shared-item viewer |
| `Compound/Core/TabBar` | 5 | 518 | Tab bar, DeepLink parsing, tab selection |
| `Compound/Core/Training` | 245 | 23,707 | Training tab: workouts, tracker, programs, history, create flows |
| `Compound/Components` | 70 | 6,601 | Reusable views, buttons, modals, charts (QuickCharts alias), view modifiers |
| `Compound/Managers` | 261 | 32,989 | App-owned managers, models and services (see Managers table) |
| `Compound/Root` | 22 | 3,579 | AppDelegate, CompoundApp, Dependencies DI root, CoreInteractor/Builder/Router, Global protocols |
| `Compound/Utilities` | 14 | 957 | Constants, Keys, NetworkMonitor, App Check factory, unit conversion, helpers |
| `Compound/Extensions` | 13 | 622 | Foundation/SwiftUI type extensions (`X+EXT.swift`) |
| `Compound/SupportingFiles` | 318 | 6,025 | Assets, entitlements, GoogleService plists, privacy manifest, seed JSON |
| `Shared` | 5 | 680 | Code compiled into both the app and the Live Activity extension |
| `WorkoutSessionActivity` | 263 | 2,525 | Live Activity / Dynamic Island / home widget extension |
| `CompoundUnitTests` | 310 | 86,883 | Swift Testing unit suites (BlueprintName CompoundUnitTests) |
| `CompoundUITests` | 9 | 882 | XCUITest smoke and create-flow tests (launch via STARTSCREEN) |
| `functions` | 18 | 23,292 | Firebase Cloud Functions v2 (Node ESM, Genkit/Vertex) |
| `hosting` | 1 | 7 | Firebase Hosting landing page |
| `scripts` | 6 | 701 | Screenshot, contact-sheet, smoke-test generation, this map |
| `docs` | 61 | 15,830 | Specs, reviews, audits, this map |

## Screens and VIPER components

Each row is one folder holding `<Module>{Interactor,Presenter,Router,View}.swift`. *Routes to* is what the module's router protocol can open; *Delegate / entry* is the input struct and the `showXView` defined at the bottom of its View file; *Extra files* are presenter splits and helper views.
197 presenter-backed modules.

### `Compound/Components` (3 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **CalendarHeader** | [Views/CalendarHeader](Compound/Components/Views/CalendarHeader) | 910 | CalendarViewZoom | CalendarHeaderDelegate | CalendarDayCell.swift, CalendarDayMarker.swift | CalendarHeaderPresenterTests.swift |
| **Calendar** | [Views/CalendarHeader/Calendar](Compound/Components/Views/CalendarHeader/Calendar) | 406 |  | CalendarDelegate, `showCalendarView` |  | CalendarHeaderPresenterTests.swift |
| **AuthorHeader** | [Views/User](Compound/Components/Views/User) | 276 | SocialProfile | AuthorHeaderDelegate | UserRowView.swift, UsernameLabel.swift |  |

### `Compound/Core/Analytics` (26 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Analytics** | [Compound/Core/Analytics](Compound/Core/Analytics) | 1405 | BodyMetrics, CustomiseAnalytics, EnergyBalance, ExerciseAnalytics, ExerciseDetail, ExpenditureDetail, GoalProgress, Habits, InsightsAndAnalytics, LogMeasurement, LogWeight, MuscleGroupDetail, MuscleGroups, NutritionAnalytics, NutritionMetricDetail, Paywall, ProfileViewZoom, ScaleWeight, Steps, VisualBodyFat, WeeklyReview, WeighInConsistency, WeightTrend, Workout, WorkoutConsistency | AnalyticsDelegate | AnalyticsPresenter+DataLoading.swift, MuscleGroupCardItem.swift | AnalyticsPresenterTests.swift |
| **BodyMetrics** | [Subviews/BodyMetrics](Compound/Core/Analytics/Subviews/BodyMetrics) | 550 | BodyMeasurementDetail, BodyRatio, LogMeasurement, ProgressPhotos, ScaleWeight, VisualBodyFat | BodyMetricsDelegate, `showBodyMetricsView` | BodyMetricCardView.swift, BodyMetricsModels.swift |  |
| **LogMeasurement** | [Subviews/BodyMetrics/LogMeasurement](Compound/Core/Analytics/Subviews/BodyMetrics/LogMeasurement) | 469 |  | `showLogMeasurementView` | BodyMeasurementKind.swift, DecimalWheelValue.swift |  |
| **LogWeight** | [Subviews/BodyMetrics/LogMeasurement/LogWeightView](Compound/Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView) | 387 |  | `showLogWeightView` | WeightPickerInput.swift |  |
| **ProgressPhotos** | [Subviews/BodyMetrics/ProgressPhotos](Compound/Core/Analytics/Subviews/BodyMetrics/ProgressPhotos) | 669 | ProgressPhotoCompare | ProgressPhotoCompareDelegate, `showProgressPhotoCompareView`, `showProgressPhotosView` | ProgressPhotoCameraPicker.swift, ProgressPhotoCompareView.swift | ProgressPhotosPresenterTests.swift |
| **ScaleWeight** | [Subviews/BodyMetrics/ScaleWeight](Compound/Core/Analytics/Subviews/BodyMetrics/ScaleWeight) | 227 | LogWeight | ScaleWeightDelegate, `showScaleWeightView` |  |  |
| **ExerciseAnalytics** | [Subviews/ExerciseAnalytics](Compound/Core/Analytics/Subviews/ExerciseAnalytics) | 311 | ExerciseDetail | ExerciseAnalyticsDelegate, `showExerciseAnalyticsView` | ExerciseCardItem.swift, ExerciseOneRMAggregator.swift |  |
| **ExerciseDetail** | [Subviews/ExerciseAnalytics/ExerciseDetail](Compound/Core/Analytics/Subviews/ExerciseAnalytics/ExerciseDetail) | 296 | Workouts | ExerciseDetailDelegate, `showExerciseDetailView` | ExerciseDetailEntry.swift |  |
| **FoodLoggingConsistency** | [Subviews/FoodLoggingConsistency](Compound/Core/Analytics/Subviews/FoodLoggingConsistency) | 192 |  | FoodLoggingConsistencyDelegate, `showFoodLoggingConsistencyView` |  |  |
| **Habits** | [Subviews/Habits](Compound/Core/Analytics/Subviews/Habits) | 420 | FoodLoggingConsistency, NutritionMetricDetail, ScaleWeight, WeighInConsistency, Workout, WorkoutConsistency | HabitsDelegate, `showHabitsView` |  | HabitsPresenterTests.swift |
| **InsightsAndAnalytics** | [Subviews/InsightsAndAnalytics](Compound/Core/Analytics/Subviews/InsightsAndAnalytics) | 505 | EnergyBalance, ExpenditureDetail, GoalProgress, WeightTrend, Workout | InsightsAndAnalyticsDelegate, `showInsightsAndAnalyticsView` |  |  |
| **EnergyBalance** | [Subviews/InsightsAndAnalytics/EnergyBalance](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/EnergyBalance) | 358 | AddMeal | EnergyBalanceDelegate, `showEnergyBalanceView` | EnergyBalanceEntry.swift | EnergyBalancePresenterTests.swift |
| **ExpenditureDetail** | [Subviews/InsightsAndAnalytics/ExpenditureDetail](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/ExpenditureDetail) | 275 | EditProfile | ExpenditureDetailDelegate, `showExpenditureDetailView` | ExpenditureDetailEntry.swift |  |
| **GoalProgress** | [Subviews/InsightsAndAnalytics/GoalProgress](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/GoalProgress) | 326 |  | GoalProgressDelegate, `showGoalProgressView` | GoalProgressEntry.swift |  |
| **MuscleGroupDetail** | [Subviews/InsightsAndAnalytics/MuscleGroupDetail](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/MuscleGroupDetail) | 291 | Workouts | MuscleGroupDetailDelegate, `showMuscleGroupDetailView` | MuscleGroupDetailEntry.swift | MuscleGroupDetailPresenterTests.swift |
| **Steps** | [Subviews/InsightsAndAnalytics/Steps](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/Steps) | 283 |  | StepsDelegate, `showStepsView` | StepsEntry.swift |  |
| **WeightTrend** | [Subviews/InsightsAndAnalytics/WeightTrend](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/WeightTrend) | 315 |  | WeightTrendDelegate, `showWeightTrendView` | WeightTrendEntry.swift | WeightTrendPresenterTests.swift |
| **Workout** | [Subviews/InsightsAndAnalytics/Workouts](Compound/Core/Analytics/Subviews/InsightsAndAnalytics/Workouts) | 262 | Workouts | WorkoutDelegate, `showWorkoutView` | WorkoutEntry.swift | WorkoutPresenterTests.swift |
| **MuscleBalance** | [Subviews/MuscleBalance](Compound/Core/Analytics/Subviews/MuscleBalance) | 278 |  | `showMuscleBalanceView`, `showsFooter` |  |  |
| **MuscleGroups** | [Subviews/MuscleGroups](Compound/Core/Analytics/Subviews/MuscleGroups) | 315 | MuscleBalance, MuscleGroupDetail | MuscleGroupsDelegate, `showMuscleGroupsView` | MuscleGroupSetsAggregator.swift |  |
| **NutritionAnalytics** | [Subviews/NutritionAnalytics](Compound/Core/Analytics/Subviews/NutritionAnalytics) | 528 | AddMeal, NutritionMetricDetail | NutritionAnalyticsDelegate, `showNutritionAnalyticsView` |  |  |
| **NutritionMetricDetail** | [Subviews/NutritionAnalytics/NutritionMetricDetail](Compound/Core/Analytics/Subviews/NutritionAnalytics/NutritionMetricDetail) | 626 |  | NutritionMetricDetailDelegate, `showNutritionMetricDetailView` | NutritionMetric.swift, NutritionMetricEntry.swift |  |
| **NutritionTargetChart** | [Subviews/NutritionTargetChart](Compound/Core/Analytics/Subviews/NutritionTargetChart) | 430 | PreferredDiet |  |  |  |
| **ProgressCarousel** | [Subviews/ProgressCarousel](Compound/Core/Analytics/Subviews/ProgressCarousel) | 897 |  |  | ProgressCarouselCards.swift, ProgressCarouselMetrics.swift |  |
| **WeighInConsistency** | [Subviews/WeighInConsistency](Compound/Core/Analytics/Subviews/WeighInConsistency) | 209 |  | WeighInConsistencyDelegate, `showWeighInConsistencyView` |  |  |
| **WorkoutConsistency** | [Subviews/WorkoutConsistency](Compound/Core/Analytics/Subviews/WorkoutConsistency) | 186 |  | WorkoutConsistencyDelegate, `showWorkoutConsistencyView` |  |  |

### `Compound/Core/AppView` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **App** | [Compound/Core/AppView](Compound/Core/AppView) | 737 |  | `showAppToast` | ActivityNotificationBannerView.swift, AppToast.swift, AppToastView.swift, AppViewBuilder.swift | AppShellPresenterTests.swift |

### `Compound/Core/Challenges` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ChallengeDetail** | [ChallengeDetail](Compound/Core/Challenges/ChallengeDetail) | 324 | SocialProfile | ChallengeDetailDelegate, `showChallengeDetailView` |  |  |
| **CreateChallenge** | [CreateChallenge](Compound/Core/Challenges/CreateChallenge) | 317 |  | `showCreateChallengeView` |  |  |

### `Compound/Core/Coach` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Coach** | [Compound/Core/Coach](Compound/Core/Coach) | 805 | Coach, CoachChat, CoachChats, Paywall | CoachChatsDelegate, CoachDelegate, `showCoach`, `showCoachChatView`, `showCoachChatsView` | AskCoachToolbarItem.swift, CoachChatsView.swift |  |

### `Compound/Core/DevSettings` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **DevSettings** | [Compound/Core/DevSettings](Compound/Core/DevSettings) | 809 |  | `showDevSettingsView` |  |  |

### `Compound/Core/Notifications` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Notifications** | [Compound/Core/Notifications](Compound/Core/Notifications) | 970 | ChallengeDetail, NotificationSettings, SharedItem, SocialProfile, WorkoutSessionDetail, WorkoutSessionThreadPushed | `showNotificationsView`, `showWorkoutSessionThreadPushed`, `showsFollowBack` | NotificationGrouping.swift, ReminderOfferFlow.swift |  |
| **NotificationSettings** | [NotificationSettings](Compound/Core/Notifications/NotificationSettings) | 421 |  | NotificationSettingsDelegate, `showNotificationSettingsView` |  | NotificationSettingsPresenterTests.swift |

### `Compound/Core/Nutrition` (32 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Nutrition** | [Compound/Core/Nutrition](Compound/Core/Nutrition) | 871 | AddMeal, FoodDetail, FoodLogSettings, Foods, MealDetail, MealItemAmountView, NutritionOverview, ProfileViewZoom, RecipeDetail, Recipes, TimelineActions | NutritionDelegate, `showNutritionView` |  | NutritionPresenterTests.swift |
| **CheckIn** | [CheckIn](Compound/Core/Nutrition/CheckIn) | 851 |  | CheckInDelegate, `showCheckInView` | CheckInPresenter+Events.swift, CheckInStep.swift | CheckInPresenterTests.swift |
| **IngredientListBuilder** | [Components/IngredientListBuilder](Compound/Core/Nutrition/Components/IngredientListBuilder) | 385 | CreateFood, IngredientAmount, RecipeIngredientAmount | IngredientListBuilderDelegate, `showIngredientListBuilderView` |  |  |
| **MealAccessory** | [Components/MealAccessory](Compound/Core/Nutrition/Components/MealAccessory) | 186 | AddMeal | MealAccessoryDelegate |  | MealAccessoryPresenterTests.swift |
| **MealHourHeader** | [Components/MealHourHeader](Compound/Core/Nutrition/Components/MealHourHeader) | 282 | AddMeal | MealHourHeaderDelegate |  | MealHourHeaderPresenterTests.swift |
| **RecipeListBuilder** | [Components/RecipeListBuilder](Compound/Core/Nutrition/Components/RecipeListBuilder) | 269 | CreateRecipe, RecipeAmount, RecipeDetail | RecipeListBuilderDelegate, `showRecipeListBuilderView` |  |  |
| **Foods** | [Foods](Compound/Core/Nutrition/Foods) | 138 | FoodDetail, SimpleAlert | `showFoodsView` |  |  |
| **CreateFood** | [Foods/CreateFood](Compound/Core/Nutrition/Foods/CreateFood) | 441 | BarcodeScanner, FoodPackaging, PortionDefinition | CreateFoodDelegate, `showCreateFoodView` |  | CreateFoodFlowPresenterTests.swift |
| **FoodDefinition** | [Foods/CreateFood/FoodDefinition](Compound/Core/Nutrition/Foods/CreateFood/FoodDefinition) | 625 |  | FoodDefinitionDelegate, `showFoodDefinitionView` |  | FoodDefinitionPresenterTests.swift |
| **FoodPackaging** | [Foods/CreateFood/FoodPackaging](Compound/Core/Nutrition/Foods/CreateFood/FoodPackaging) | 261 | PortionDefinition | FoodPackagingDelegate, `showFoodPackagingView` |  |  |
| **PortionDefinition** | [Foods/CreateFood/PortionDefinition](Compound/Core/Nutrition/Foods/CreateFood/PortionDefinition) | 357 | FoodDefinition | PortionDefinitionDelegate, `showPortionDefinitionView` |  |  |
| **FoodDetail** | [Foods/FoodDetail](Compound/Core/Nutrition/Foods/FoodDetail) | 390 |  | FoodDetailDelegate, `showDeleteConfirmation`, `showFoodDetailView` |  |  |
| **AddMeal** | [MealLog/AddMeal](Compound/Core/Nutrition/MealLog/AddMeal) | 733 | MealItemAmountView, NutritionLibraryPicker | AddMealDelegate, `showAddMealView` |  | AddMealPresenterTests.swift |
| **IngredientAmount** | [MealLog/IngredientAmount](Compound/Core/Nutrition/MealLog/IngredientAmount) | 283 |  | IngredientAmountDelegate, `showIngredientAmountView` |  |  |
| **MealDetail** | [MealLog/MealDetail](Compound/Core/Nutrition/MealLog/MealDetail) | 274 |  | MealDetailDelegate, `showMealDetailView` |  |  |
| **MealItemAmountView** | [MealLog/MealItemAmountView](Compound/Core/Nutrition/MealLog/MealItemAmountView) | 235 |  | MealItemAmountViewDelegate, `showMealItemAmountViewView` |  |  |
| **NutritionLibraryPicker** | [MealLog/NutritionLibraryPicker](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker) | 425 | IngredientAmount, RecipeAmount | NutritionLibraryPickerDelegate, `showNutritionLibraryPickerView` |  |  |
| **BarcodeScanner** | [MealLog/NutritionLibraryPicker/BarcodeScanner](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/BarcodeScanner) | 961 |  | BarcodeScannerDelegate, `showBarcodeScannerView` |  | BarcodeScannerPresenterTests.swift |
| **FoodItemQuickAdd** | [MealLog/NutritionLibraryPicker/FoodItemQuickAdd](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemQuickAdd) | 299 |  | FoodItemQuickAddDelegate |  | FoodItemQuickAddPresenterTests.swift |
| **FoodItemSearch** | [MealLog/NutritionLibraryPicker/FoodItemSearch](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemSearch) | 381 |  | FoodItemSearchDelegate, `showFoodItemSearchView` |  | FoodItemSearchPresenterTests.swift |
| **FoodLibrary** | [MealLog/NutritionLibraryPicker/FoodLibrary](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodLibrary) | 288 | IngredientAmount, RecipeAmount, RecipeDetail | FoodLibraryDelegate, `showFoodLibraryView` |  | FoodLibraryPresenterTests.swift |
| **FoodPhotoScanner** | [MealLog/NutritionLibraryPicker/FoodPhotoScanner](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodPhotoScanner) | 470 | IngredientAmount | FoodPhotoScannerDelegate |  |  |
| **MealDescribe** | [MealLog/NutritionLibraryPicker/MealDescribe](Compound/Core/Nutrition/MealLog/NutritionLibraryPicker/MealDescribe) | 252 | IngredientAmount | MealDescribeDelegate, `showMealDescribeView` |  |  |
| **RecipeAmount** | [MealLog/RecipeAmount](Compound/Core/Nutrition/MealLog/RecipeAmount) | 238 |  | RecipeAmountDelegate, `showRecipeAmountView` |  |  |
| **NutritionOverview** | [NutritionOverview](Compound/Core/Nutrition/NutritionOverview) | 590 | CheckIn | NutritionOverviewDelegate, `showNutritionOverviewView` |  | NutritionOverviewPresenterTests.swift |
| **Recipes** | [Recipes](Compound/Core/Nutrition/Recipes) | 150 | CreateRecipe, RecipeDetail, SimpleAlert | `showRecipesView` |  |  |
| **CreateRecipe** | [Recipes/CreateRecipe](Compound/Core/Nutrition/Recipes/CreateRecipe) | 348 | IngredientListBuilder, RecipePreparation | `showCreateRecipeView` |  |  |
| **RecipeIngredientAmount** | [Recipes/CreateRecipe/RecipeIngredientAmount](Compound/Core/Nutrition/Recipes/CreateRecipe/RecipeIngredientAmount) | 156 |  | RecipeIngredientAmountDelegate, `showRecipeIngredientAmountView` |  |  |
| **RecipePreparation** | [Recipes/CreateRecipe/RecipePreparation](Compound/Core/Nutrition/Recipes/CreateRecipe/RecipePreparation) | 395 |  | RecipePreparationDelegate, `showRecipePreparationView` |  | RecipePreparationPresenterTests.swift |
| **RecipeDetail** | [Recipes/RecipeDetail](Compound/Core/Nutrition/Recipes/RecipeDetail) | 366 | StartRecipe | RecipeDetailDelegate, `showDeleteConfirmation`, `showRecipeDetailView` | RecipeDetailDelegate.swift |  |
| **RecipeStart** | [Recipes/RecipeStart](Compound/Core/Nutrition/Recipes/RecipeStart) | 150 |  | RecipeStartDelegate, `showStartRecipeView` | RecipeStartDelegate.swift |  |
| **TimelineActions** | [TimelineActions](Compound/Core/Nutrition/TimelineActions) | 394 |  | TimelineActionsDelegate, `showTimelineActionsView` |  | TimelineActionsPresenterTests.swift |

### `Compound/Core/Onboarding` (23 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Welcome** | [0 - WelcomeView](Compound/Core/Onboarding/0%20-%20WelcomeView) | 258 | Auth, Paywall, Subscription | WelcomeDelegate |  |  |
| **Auth** | [2 - AuthView](Compound/Core/Onboarding/2%20-%20AuthView) | 449 | Paywall, Subscription | `showAuthView` |  |  |
| **Subscription** | [3 - Subscription](Compound/Core/Onboarding/3%20-%20Subscription) | 188 | Paywall | `showSubscriptionView` |  |  |
| **NamePhoto** | [4 - CompleteAccountSetup/1 - NamePhoto](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/1%20-%20NamePhoto) | 364 | Gender | `showNamePhotoView` |  |  |
| **Gender** | [4 - CompleteAccountSetup/2 - Gender](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/2%20-%20Gender) | 197 | DateOfBirth | `showGenderView` |  |  |
| **DateOfBirth** | [4 - CompleteAccountSetup/3 - DateOfBirth](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/3%20-%20DateOfBirth) | 206 | Height | DateOfBirthDelegate, `showDateOfBirthView` |  |  |
| **Height** | [4 - CompleteAccountSetup/4 - Height](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/4%20-%20Height) | 325 | Weight | HeightDelegate, `showHeightView` |  |  |
| **Weight** | [4 - CompleteAccountSetup/5 - Weight](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/5%20-%20Weight) | 329 | ExerciseFrequency | WeightDelegate, `showWeightView` |  | WeightTrendPresenterTests.swift |
| **ExerciseFrequency** | [4 - CompleteAccountSetup/6 - ExerciseFrequency](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/6%20-%20ExerciseFrequency) | 219 | Activity | ExerciseFrequencyDelegate, `showExerciseFrequencyView` |  |  |
| **Activity** | [4 - CompleteAccountSetup/7 - Activity](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/7%20-%20Activity) | 236 | Expenditure | ActivityDelegate, `showActivityView` |  |  |
| **Expenditure** | [4 - CompleteAccountSetup/9 - Expenditure](Compound/Core/Onboarding/4%20-%20CompleteAccountSetup/9%20-%20Expenditure) | 577 | HealthDisclaimer | ExpenditureDelegate, `showExpenditureView` |  |  |
| **HealthDisclaimer** | [5 - HealthDisclaimer](Compound/Core/Onboarding/5%20-%20HealthDisclaimer) | 256 | OverarchingObjective | `showHealthDisclaimerView` |  |  |
| **OverarchingObjective** | [6 - GoalSetting/1 - OverarchingObjective](Compound/Core/Onboarding/6%20-%20GoalSetting/1%20-%20OverarchingObjective) | 252 | GoalSummary, TargetWeight | `showOverarchingObjectiveView`, `showWeightGoalFlow` |  |  |
| **TargetWeight** | [6 - GoalSetting/2 - TargetWeight](Compound/Core/Onboarding/6%20-%20GoalSetting/2%20-%20TargetWeight) | 409 | WeightRate | TargetWeightDelegate, `showTargetWeightView` |  |  |
| **WeightRate** | [6 - GoalSetting/3 - WeightRate](Compound/Core/Onboarding/6%20-%20GoalSetting/3%20-%20WeightRate) | 427 | GoalSummary | WeightRateDelegate, `showWeightRateView` |  |  |
| **GoalSummary** | [6 - GoalSetting/4 - GoalSummary](Compound/Core/Onboarding/6%20-%20GoalSetting/4%20-%20GoalSummary) | 506 |  | GoalSummaryDelegate, `showGoalSummaryView` |  |  |
| **CustomisingDietProgram** | [8 - OnboardingDiet](Compound/Core/Onboarding/8%20-%20OnboardingDiet) | 170 | DietPlan, PreferredDiet | `showCustomisingDietProgramView` |  |  |
| **PreferredDiet** | [8 - OnboardingDiet/1 - PreferredDiet](Compound/Core/Onboarding/8%20-%20OnboardingDiet/1%20-%20PreferredDiet) | 222 | CalorieDistribution, CalorieFloor | `showPreferredDietView` |  |  |
| **CalorieFloor** | [8 - OnboardingDiet/2 - CalorieFloor](Compound/Core/Onboarding/8%20-%20OnboardingDiet/2%20-%20CalorieFloor) | 230 | CalorieDistribution | CalorieFloorDelegate, `showCalorieFloorView` |  |  |
| **CalorieDistribution** | [8 - OnboardingDiet/4 - CalorieDistribution](Compound/Core/Onboarding/8%20-%20OnboardingDiet/4%20-%20CalorieDistribution) | 262 | ProteinIntake | CalorieDistributionDelegate, `showCalorieDistributionView` |  |  |
| **ProteinIntake** | [8 - OnboardingDiet/5 - ProteinIntake](Compound/Core/Onboarding/8%20-%20OnboardingDiet/5%20-%20ProteinIntake) | 227 | DietPlan | ProteinIntakeDelegate, `showProteinIntakeView` |  |  |
| **DietPlan** | [8 - OnboardingDiet/6 - DietPlan](Compound/Core/Onboarding/8%20-%20OnboardingDiet/6%20-%20DietPlan) | 310 |  | DietPlanDelegate, `showDietPlanView` |  |  |
| **OnboardingCompleted** | [9 - OnboardingCompleted](Compound/Core/Onboarding/9%20-%20OnboardingCompleted) | 193 |  | `showOnboardingCompletedView` |  |  |

### `Compound/Core/Paywalls` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Paywall** | [Paywall](Compound/Core/Paywalls/Paywall) | 561 |  | `showPaywall` |  | PaywallPresenterTests.swift |

### `Compound/Core/Profile` (45 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Settings** | [Compound/Core/Profile](Compound/Core/Profile) | 640 | About, AppIcon, Auth, CoachChats, CustomiseAnalytics, DeleteAccount, ExpenditureSettings, FoodLogSettings, GymProfiles, Integrations, Legal, NotificationSettings, Notifications, Paywall, PreferredDiet, Siri, StrategySettings, Tutorials, Units, WorkoutSettings | `showSettingsView` | ReviewMoment.swift, SignInCancellation.swift | SettingsPresenterTests.swift |
| **About** | [Subviews/About](Compound/Core/Profile/Subviews/About) | 149 | Licences | AboutDelegate, `showAboutView` |  |  |
| **Licences** | [Subviews/About/Licences](Compound/Core/Profile/Subviews/About/Licences) | 246 |  | LicencesDelegate, `showLicencesView` | Licence.swift |  |
| **AppIcon** | [Subviews/AppIcon](Compound/Core/Profile/Subviews/AppIcon) | 126 |  | AppIconDelegate, `showAppIconView` |  |  |
| **EditProfile** | [Subviews/EditProfile](Compound/Core/Profile/Subviews/EditProfile) | 544 | EditUsername | EditProfileDelegate, `showEditProfileView` |  | EditProfilePresenterTests.swift |
| **DeleteAccount** | [Subviews/EditProfile/DeleteAccount](Compound/Core/Profile/Subviews/EditProfile/DeleteAccount) | 264 |  | `showDeleteAccountView` |  | DeleteAccountPresenterTests.swift |
| **EditUsername** | [Subviews/EditProfile/EditUsername](Compound/Core/Profile/Subviews/EditProfile/EditUsername) | 290 |  | `showEditUsernameView` |  |  |
| **CustomiseAnalytics** | [Subviews/GeneralSettings/CustomiseAnalytics](Compound/Core/Profile/Subviews/GeneralSettings/CustomiseAnalytics) | 228 |  | CustomiseAnalyticsDelegate, `showCustomiseAnalyticsView` |  |  |
| **Integrations** | [Subviews/GeneralSettings/Integrations](Compound/Core/Profile/Subviews/GeneralSettings/Integrations) | 369 | SimpleAlert | IntegrationsDelegate, `showIntegrationsView` |  |  |
| **Siri** | [Subviews/GeneralSettings/Siri](Compound/Core/Profile/Subviews/GeneralSettings/Siri) | 155 |  | SiriDelegate, `showSiriView` |  |  |
| **Units** | [Subviews/GeneralSettings/Units](Compound/Core/Profile/Subviews/GeneralSettings/Units) | 242 |  | UnitsDelegate, `showUnitsView` |  |  |
| **Legal** | [Subviews/Legal](Compound/Core/Profile/Subviews/Legal) | 162 |  | LegalDelegate, `showLegalView` |  |  |
| **ExpenditureSettings** | [Subviews/NutritionSettings/ExpenditureSettings](Compound/Core/Profile/Subviews/NutritionSettings/ExpenditureSettings) | 393 |  | ExpenditureSettingsDelegate, `showExpenditureSettingsView` |  |  |
| **FoodLogSettings** | [Subviews/NutritionSettings/FoodLogSettings](Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings) | 401 | FavouriteMeasurements, LoggerBanner, LoggerFoodTiles, TimelineFoodTiles | FoodLogSettingsDelegate, `showFavouriteMeasurementsView`, `showFoodLogSettingsView`, `showLoggerBannerView`, `showLoggerFoodTilesView`, `showTimelineFoodTilesView` |  |  |
| **FavouriteMeasurements** | [Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements](Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements) | 165 |  | FavouriteMeasurementsDelegate |  |  |
| **LoggerBanner** | [Subviews/NutritionSettings/FoodLogSettings/LoggerBanner](Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerBanner) | 179 |  | LoggerBannerDelegate |  |  |
| **LoggerFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles](Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles) | 179 |  | LoggerFoodTilesDelegate |  |  |
| **TimelineFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles](Compound/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles) | 169 |  | TimelineFoodTilesDelegate |  |  |
| **StrategySettings** | [Subviews/NutritionSettings/StrategySettings](Compound/Core/Profile/Subviews/NutritionSettings/StrategySettings) | 286 |  | StrategySettingsDelegate, `showStrategySettingsView` |  |  |
| **ExerciseAssessment** | [Subviews/TrainingSettings/ExerciseAssessment](Compound/Core/Profile/Subviews/TrainingSettings/ExerciseAssessment) | 122 |  | ExerciseAssessmentDelegate, `showExerciseAssessmentView` |  |  |
| **GymProfiles** | [Subviews/TrainingSettings/GymProfiles](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles) | 387 | GymProfile | `showGymProfilesView` | EquipmentColourPicker.swift, GymEquipmentFormat.swift | GymProfilesListPresenterTests.swift |
| **GymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile) | 905 | EditBand, EditBodyWeight, EditCableMachine, EditFixedWeightBar, EditFreeWeight, EditLoadableAccessory, EditLoadableBar, EditPinLoadedMachine, EditPlateLoadedMachine | GymProfileDelegate, `showGymProfileView` |  | GymProfilePresenterTests.swift |
| **CreateGymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile) | 178 | GymProfile | CreateGymProfileDelegate, `showCreateGymProfileView` |  |  |
| **EditBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand) | 248 | AddBand | `showEditBandView` |  |  |
| **AddBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand) | 257 |  | AddBandDelegate, `showAddBandView` |  |  |
| **EditBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight) | 246 | AddBodyWeight | `showEditBodyWeightView` |  |  |
| **AddBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight) | 203 |  | AddBodyWeightDelegate, `showAddBodyWeightView` |  |  |
| **EditCableMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine) | 267 | AddCableMachineRange | `showEditCableMachineView` |  |  |
| **AddCableMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange) | 271 |  | AddCableMachineRangeDelegate, `showAddCableMachineRangeView` |  |  |
| **EditFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar) | 240 | AddFixedWeightBar | `showEditFixedWeightBarView` |  |  |
| **AddFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar) | 202 |  | AddFixedWeightBarDelegate, `showAddFixedWeightBarView` |  |  |
| **EditFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight) | 246 | AddFreeWeight | `showEditFreeWeightView` |  |  |
| **AddFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight) | 240 |  | AddFreeWeightDelegate, `showAddFreeWeightView` |  |  |
| **EditLoadableAccessory** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory) | 166 |  | `showEditLoadableAccessoryView` |  |  |
| **EditLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar) | 239 | AddLoadableBar | `showEditLoadableBarView` |  |  |
| **AddLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar) | 203 |  | AddLoadableBarDelegate, `showAddLoadableBarView` |  |  |
| **EditPinLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine) | 264 | AddPinLoadedMachineRange | `showEditPinLoadedMachineView` |  |  |
| **AddPinLoadedMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange) | 271 |  | AddPinLoadedMachineRangeDelegate, `showAddPinLoadedMachineRangeView` |  |  |
| **EditPlateLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine) | 166 |  | `showEditPlateLoadedMachineView` |  |  |
| **EditWeightRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange](Compound/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange) | 240 |  | EditWeightRangeDelegate |  |  |
| **WorkoutSettings** | [Subviews/TrainingSettings/WorkoutSettings](Compound/Core/Profile/Subviews/TrainingSettings/WorkoutSettings) | 394 | ExerciseAssessment, RestTimerSettings, SmartProgressionSettings | WorkoutSettingsDelegate, `showWorkoutSettingsView` |  |  |
| **RestTimerSettings** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings](Compound/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings) | 336 | TimerDuration | RestTimerSettingsDelegate, `showRestTimerSettingsView` |  |  |
| **TimerDuration** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration](Compound/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration) | 455 |  | TimerDurationDelegate, `showTimerDurationView` |  | TimerDurationPresenterTests.swift |
| **SmartProgressionSettings** | [Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings](Compound/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings) | 207 |  | SmartProgressionSettingsDelegate, `showSmartProgressionSettingsView` |  |  |
| **Tutorials** | [Subviews/Tutorials](Compound/Core/Profile/Subviews/Tutorials) | 127 |  | TutorialsDelegate, `showTutorialsView` |  |  |

### `Compound/Core/Sharing` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ShareToFollower** | [ShareToFollower](Compound/Core/Sharing/ShareToFollower) | 246 |  | ShareToFollowerDelegate, `showShareToFollowerView` |  |  |
| **SharedItem** | [SharedItem](Compound/Core/Sharing/SharedItem) | 280 |  | SharedItemDelegate, `showSharedItemView` |  |  |

### `Compound/Core/Social` (6 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Social** | [Compound/Core/Social](Compound/Core/Social) | 1289 | ChallengeDetail, CreateChallenge, EditUsername, Notifications, ProfileViewZoom, SocialProfile, WeeklyGoal, WorkoutSessionDetail, WorkoutSessionThread | SocialDelegate | CircleActivityStripView.swift, InviteFriendCard.swift, PeopleSearch.swift, PeopleSearchResults.swift, UsernameBannerView.swift | SocialPresenterTests.swift |
| **WeeklyGoal** | [CircleGoals/WeeklyGoal](Compound/Core/Social/CircleGoals/WeeklyGoal) | 216 |  | `showWeeklyGoalView` |  |  |
| **SocialProfile** | [SocialProfile](Compound/Core/Social/SocialProfile) | 962 | EditProfile, FollowersList, Settings, WeeklyGoal | SocialProfileDelegate, `showProfileViewZoom`, `showSocialProfileView` |  | SocialProfilePresenterTests.swift |
| **FollowersList** | [SocialProfile/FollowersList](Compound/Core/Social/SocialProfile/FollowersList) | 241 | SocialProfile | FollowersListDelegate, `showFollowersList`, `showsFollowButton` |  |  |
| **WorkoutSessionRow** | [WorkoutSessionRow](Compound/Core/Social/WorkoutSessionRow) | 802 | Comments, ShareToFollower, SocialProfile, WorkoutSessionDetail, WorkoutTemplateDetail | WorkoutSessionRowDelegate | WorkoutSessionHighlights.swift, WorkoutSessionTemplateBuilder.swift |  |
| **Comments** | [WorkoutSessionRow/Comments](Compound/Core/Social/WorkoutSessionRow/Comments) | 781 |  | CommentsDelegate |  |  |

### `Compound/Core/TabBar` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **TabBar** | [Compound/Core/TabBar](Compound/Core/TabBar) | 518 | WorkoutTracker |  | DeepLink.swift |  |

### `Compound/Core/Today` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Today** | [Compound/Core/Today](Compound/Core/Today) | 1186 | AddMeal, CheckIn, Integrations, LogWeight, MesocycleLibrary, ProfileViewZoom, ScaleWeight, Steps, WeeklyReview, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker | TodayDelegate | TodayChecklist.swift, TodayPresenter+Checklist.swift | TodayPresenterTests.swift |
| **WeeklyReview** | [WeeklyReview](Compound/Core/Today/WeeklyReview) | 594 |  | `showWeeklyReviewView` | WeeklyReview.swift, WeeklyReviewShareCardView.swift |  |

### `Compound/Core/Training` (49 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Training** | [Compound/Core/Training](Compound/Core/Training) | 647 | CreateExercise, CreateMesocycle, CreateWorkout, EditMesocycle, ExerciseDetail, Exercises, MacrocycleDetail, Macrocycles, MesocycleLibrary, ProfileViewZoom, WorkoutHistory, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker, Workouts | TrainingDelegate |  | TrainingHomePresenterTests.swift, TrainingLibraryPresenterTests.swift, TrainingSettingsPresenterTests.swift |
| **ExerciseListBuilder** | [Components/ExerciseListBuilder](Compound/Core/Training/Components/ExerciseListBuilder) | 673 | CreateExercise | ExerciseListBuilderDelegate, `showExerciseListBuilderView` | ExerciseFilters.swift |  |
| **TodaysWorkoutCard** | [Components/TodaysWorkoutCard](Compound/Core/Training/Components/TodaysWorkoutCard) | 776 | WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker | TodaysWorkoutCardDelegate | MesocycleSchedule.swift, TodaysWorkoutCard.swift | TodaysWorkoutCardPresenterTests.swift |
| **TrainingAccessory** | [Components/TrainingAccessory](Compound/Core/Training/Components/TrainingAccessory) | 288 | WorkoutTracker | TrainingAccessoryDelegate |  |  |
| **WorkoutStreak** | [Components/WorkoutStreakCard](Compound/Core/Training/Components/WorkoutStreakCard) | 232 |  | WorkoutStreakDelegate | WorkoutStreakCard.swift |  |
| **ActiveMesocycle** | [Subviews/ActiveMesocycle](Compound/Core/Training/Subviews/ActiveMesocycle) | 579 | EditMesocycle, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker | ActiveMesocycleDelegate, `showActiveMesocycleView` |  | ActiveMesocyclePresenterTests.swift |
| **CreateExercise** | [Subviews/AddTraining/CreateExercise](Compound/Core/Training/Subviews/AddTraining/CreateExercise) | 302 | MuscleGroupPicker | `showCreateExerciseView` |  | CreateExerciseEquipmentPresenterTests.swift, CreateExerciseFlowPresenterTests.swift |
| **EquipmentPicker** | [Subviews/AddTraining/CreateExercise/EquipmentPicker](Compound/Core/Training/Subviews/AddTraining/CreateExercise/EquipmentPicker) | 243 |  | EquipmentPickerDelegate, `showEquipmentPickerView` |  |  |
| **ExerciseEquipment** | [Subviews/AddTraining/CreateExercise/ExerciseEquipment](Compound/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseEquipment) | 319 | EquipmentPicker, FinalExerciseDetails | ExerciseEquipmentDelegate, `showExerciseEquipmentView` |  |  |
| **ExerciseSave** | [Subviews/AddTraining/CreateExercise/ExerciseSave](Compound/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseSave) | 368 |  | ExerciseSaveDelegate, `showExerciseSaveView` |  |  |
| **FinalExerciseDetails** | [Subviews/AddTraining/CreateExercise/FinalExerciseDetails](Compound/Core/Training/Subviews/AddTraining/CreateExercise/FinalExerciseDetails) | 310 | ExerciseSave | FinalExerciseDetailsDelegate, `showFinalExerciseDetailsView` |  |  |
| **MuscleGroupPicker** | [Subviews/AddTraining/CreateExercise/MuscleGroupPicker](Compound/Core/Training/Subviews/AddTraining/CreateExercise/MuscleGroupPicker) | 300 | ExerciseEquipment | MuscleGroupPickerDelegate, `showMuscleGroupPickerView` |  |  |
| **CreateMesocycle** | [Subviews/AddTraining/CreateMesocycle/CreateMesocycle](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/CreateMesocycle) | 273 | NameMesocycle, PrebuiltMesocycleDetail | CreateMesocycleDelegate, `showCreateMesocycleView`, `showOnboardingMesocycleView` |  | CreateMesocycleFlowPresenterTests.swift |
| **MesocycleDesign** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign) | 709 | MesocycleSettings, RenameWorkoutTemplateModel, ShareToFollower | EditMesocycleDelegate, MesocycleDesignDelegate, `showEditMesocycleView`, `showMesocycleDesignView`, `showRenameWorkoutTemplateModelView` |  | MesocycleDesignPresenterTests.swift |
| **MesocycleSettings** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings) | 297 | EditDayOrder, EditDeload, EditMesocycleColourIcon, RenameMesocycle | `showEditDayOrderView`, `showEditDeloadView`, `showEditMesocycleColourIconView`, `showMesocycleSettingsView`, `showRenameMesocycleView` |  | MesocycleSettingsFlowPresenterTests.swift |
| **EditDayOrder** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDayOrder](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDayOrder) | 136 |  |  |  |  |
| **EditDeload** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDeload](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditDeload) | 133 |  |  |  |  |
| **EditMesocycleColourIcon** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditMesocycleColourIcon](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/MesocycleSettings/EditMesocycleColourIcon) | 150 |  |  |  |  |
| **RenameDayPlan** | [Subviews/AddTraining/CreateMesocycle/MesocycleDesign/RenameDayPlan](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleDesign/RenameDayPlan) | 144 |  | RenameWorkoutTemplateModelDelegate |  |  |
| **MesocycleIcon** | [Subviews/AddTraining/CreateMesocycle/MesocycleIcon](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/MesocycleIcon) | 215 | MesocycleDesign | MesocycleIconDelegate, `showMesocycleIconView` |  |  |
| **NameMesocycle** | [Subviews/AddTraining/CreateMesocycle/NameMesocycle](Compound/Core/Training/Subviews/AddTraining/CreateMesocycle/NameMesocycle) | 185 | MesocycleIcon | NameMesocycleDelegate, `showNameMesocycleView` |  |  |
| **ChooseGymProfile** | [Subviews/AddTraining/CreateWorkout/ChooseGymProfile](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/ChooseGymProfile) | 201 | CreateGymProfile, DefineWorkoutWrapper | ChooseGymProfileDelegate, `showChooseGymProfileView` |  |  |
| **DefineWorkout** | [Subviews/AddTraining/CreateWorkout/DefineWorkout](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkout) | 246 | ExercisesPicker, SetTarget | DefineWorkoutDelegate, `showDefineWorkoutView` |  |  |
| **DefineWorkoutWrapper** | [Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper) | 229 |  | DefineWorkoutWrapperDelegate, `showDefineWorkoutWrapperView` |  |  |
| **ExercisesPicker** | [Subviews/AddTraining/CreateWorkout/ExercisesPicker](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/ExercisesPicker) | 206 |  | ExercisesPickerDelegate, `showExercisesPickerView` |  |  |
| **NameWorkout** | [Subviews/AddTraining/CreateWorkout/NameWorkout](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/NameWorkout) | 219 | ChooseGymProfile, DefineWorkoutWrapper | NameWorkoutDelegate |  |  |
| **SetTarget** | [Subviews/AddTraining/CreateWorkout/SetTarget](Compound/Core/Training/Subviews/AddTraining/CreateWorkout/SetTarget) | 288 |  | SetTargetDelegate, `showSetTargetView` |  |  |
| **ExerciseSettings** | [Subviews/ExerciseSettings](Compound/Core/Training/Subviews/ExerciseSettings) | 341 | ExerciseModelDetail, RestModal, RestTimerSettings, WorkoutNotes | ExerciseSettingsDelegate, `showExerciseSettingsView` |  |  |
| **Exercises** | [Subviews/Exercises](Compound/Core/Training/Subviews/Exercises) | 135 | CreateExercise, ExerciseModelDetail | `showExercisesView` |  |  |
| **ExerciseTemplateDetail** | [Subviews/Exercises/ExerciseTemplateDetail](Compound/Core/Training/Subviews/Exercises/ExerciseTemplateDetail) | 855 |  | ExerciseModelDetailDelegate, `showDeleteConfirmation`, `showExerciseModelDetailView` | ExerciseModelDetailStats.swift, ExerciseTemplateDetailDelegate.swift |  |
| **Macrocycles** | [Subviews/Macrocycles](Compound/Core/Training/Subviews/Macrocycles) | 200 | MacrocycleDetail | `showMacrocyclesView` |  |  |
| **MacrocycleDetail** | [Subviews/Macrocycles/MacrocycleDetail](Compound/Core/Training/Subviews/Macrocycles/MacrocycleDetail) | 426 |  | MacrocycleDetailDelegate, `showMacrocycleDetailView` |  | MacrocycleDetailPresenterTests.swift |
| **MesocycleManagement** | [Subviews/MesocycleLibrary](Compound/Core/Training/Subviews/MesocycleLibrary) | 328 | CreateMesocycle, EditMesocycle, MesocycleSettings, PrebuiltMesocycleDetail | `showDeleteAlert`, `showMesocycleLibraryView` |  |  |
| **InactiveMesocycle** | [Subviews/MesocycleLibrary/InactiveMesocycle](Compound/Core/Training/Subviews/MesocycleLibrary/InactiveMesocycle) | 110 |  | InactiveMesocycleDelegate, `showInactiveMesocycleView` |  |  |
| **MesocycleDisclosureGroup** | [Subviews/MesocycleLibrary/MesocycleDisclosureGroup](Compound/Core/Training/Subviews/MesocycleLibrary/MesocycleDisclosureGroup) | 117 | EditMesocycle, ShareToFollower | MesocycleDisclosureGroupDelegate, `showMesocycleDisclosureGroupView` |  |  |
| **PrebuiltMesocycleDetail** | [Subviews/MesocycleLibrary/PrebuiltMesocycleDetail](Compound/Core/Training/Subviews/MesocycleLibrary/PrebuiltMesocycleDetail) | 236 |  | `showPrebuiltMesocycleDetailView` |  |  |
| **WorkoutHistory** | [Subviews/WorkoutHistory](Compound/Core/Training/Subviews/WorkoutHistory) | 293 | WorkoutSessionDetail | WorkoutHistoryDelegate, `showWorkoutHistoryView` |  |  |
| **WorkoutSessionDetail** | [Subviews/WorkoutSessionDetailView](Compound/Core/Training/Subviews/WorkoutSessionDetailView) | 1168 | ExercisesPicker, SessionDuration, SessionStartTime | WorkoutSessionDetailDelegate, `showSessionDurationView`, `showSessionStartTimeView`, `showWorkoutSessionDetailView`, `showWorkoutSessionThread` | WorkoutSessionTimingSheets.swift | WorkoutSessionDetailPresenterTests.swift |
| **WorkoutTemplateDetail** | [Subviews/WorkoutTemplateDetail](Compound/Core/Training/Subviews/WorkoutTemplateDetail) | 510 | CreateWorkout, EditMesocycle, ExerciseModelDetail, ShareToFollower, WorkoutTracker | WorkoutTemplateDetailDelegate, `showDeleteConfirmation`, `showWorkoutTemplateDetailView` |  |  |
| **WorkoutTracker** | [Subviews/WorkoutTracker](Compound/Core/Training/Subviews/WorkoutTracker) | 4714 | ExercisesPicker, GymProfile, WorkoutNotes, WorkoutSettings, WorkoutSummary | `showWorkoutSummary`, `showWorkoutTrackerView` | ActiveWorkout+Correction.swift, ActiveWorkout+Focus.swift, ActiveWorkout+Log.swift, ActiveWorkout+PrimarySlot.swift, ActiveWorkout+Propagation.swift, ActiveWorkout+Resume.swift, ActiveWorkout+SupersetBlock.swift, ActiveWorkoutScreenState.swift, ActiveWorkoutState.swift, InlineRestTimerRow.swift, ProgressionNote.swift, StravaOffer.swift, SupersetBlockView.swift, WorkoutPrimaryCTA.swift, WorkoutProgressHeader.swift, WorkoutTrackerPresenter+ActiveExercise.swift, WorkoutTrackerPresenter+Correction.swift, WorkoutTrackerPresenter+Events.swift, WorkoutTrackerPresenter+Exercises.swift, WorkoutTrackerPresenter+Finish.swift, WorkoutTrackerPresenter+Focus.swift, WorkoutTrackerPresenter+Notes.swift, WorkoutTrackerPresenter+Persistence.swift, WorkoutTrackerPresenter+PrimarySlot.swift, WorkoutTrackerPresenter+Progression.swift, WorkoutTrackerPresenter+Rest.swift, WorkoutTrackerPresenter+SessionChanges.swift, WorkoutTrackerPresenter+Swap.swift, WorkoutTrackerView+Exercises.swift, WorkoutTrackerView+Toolbar.swift | WorkoutTrackerPresenterProgressionTests.swift, WorkoutTrackerPresenterTests.swift |
| **ExerciseTracker** | [Subviews/WorkoutTracker/ExerciseTracker](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker) | 422 | WorkoutNotes | ExerciseTrackerDelegate |  |  |
| **SetTracker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker) | 1035 | ExerciseSettings, RestModal, SetTarget, SwapExercisePicker, WarmupSetInfoModal, WarmupSets, WorkoutExerciseEquipmentSheet | SetTrackerDelegate |  | SetTrackerPresenterTests.swift |
| **SetTrackerRow** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow) | 916 | RestModal, WarmupSetInfoModal | SetTrackerRowDelegate, `showSetTrackerRowView` |  |  |
| **SetKeyboard** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard) | 1110 |  |  | PlateCalculator.swift, SetKeyboardTextField.swift, WeightStepper.swift | SetKeyboardPresenterTests.swift |
| **SwapExercisePicker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker) | 121 |  | `showSwapExercisePickerView` |  |  |
| **WarmupSets** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets) | 180 |  | WarmupSetsDelegate, `showWarmupSetsView` |  |  |
| **WorkoutExerciseEquipmentSheet** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet](Compound/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet) | 320 |  | WorkoutExerciseEquipmentSheetDelegate, `showWorkoutExerciseEquipmentSheetView` |  |  |
| **WorkoutNotes** | [Subviews/WorkoutTracker/WorkoutNotes](Compound/Core/Training/Subviews/WorkoutTracker/WorkoutNotes) | 183 |  | WorkoutNotesDelegate, `showWorkoutNotesView` |  |  |
| **Workouts** | [Subviews/Workouts](Compound/Core/Training/Subviews/Workouts) | 151 | WorkoutTemplateDetail, WorkoutTracker | WorkoutsDelegate, `showWorkoutsView` |  |  |

## Managers

| Manager | Folder | Lines | Sync engines | Models (sibling folder) | Services | Extensions | Tests |
|---|---|---:|---|---|---|---|---|
| **ABTestManager** | [Compound/Managers/ABTests](Compound/Managers/ABTests/ABTestManager.swift) | 110 |  | ActiveABTests, PaywallTestOption | ABTestService, FirebaseABTestService, LocalABTestService, MockABTestService |  | ABTestManagerTests.swift |
| **AIManager** | [Compound/Managers/AI](Compound/Managers/AI/AIManager.swift) | 55 |  |  | AIService, GoogleAIService, MockAIService |  | AIManagerTests.swift |
| **AnalyticsSettingsManager** | [Compound/Managers/Analytics/AnalyticsSettings](Compound/Managers/Analytics/AnalyticsSettings/AnalyticsSettingsManager.swift) | 57 | Document<AnalyticsSettings> | AnalyticsSettings |  |  | AnalyticsSettingsManagerTests.swift |
| **BodyMeasurementsManager** | [Compound/Managers/BodyMeasurements](Compound/Managers/BodyMeasurements/BodyMeasurementsManager.swift) | 275 | Collection<BodyMeasurementEntry> | BodyMeasurementEntry, WeightSource |  |  | BodyMeasurementsManagerTests.swift |
| **CoachManager** | [Compound/Managers/Coach](Compound/Managers/Coach/CoachManager.swift) | 105 | Collection<CoachChat> | CoachModels | CoachService |  |  |
| **GoalManager** | [Compound/Managers/Goal](Compound/Managers/Goal/GoalManager.swift) | 152 | Document<WeightGoal> | WeightGoal, WeightGoalBuilder |  |  | GoalManagerTests.swift |
| **HKWorkoutManager** | [Compound/Managers/HKWorkout](Compound/Managers/HKWorkout/HKWorkoutManager.swift) | 524 |  |  |  | HKWorkoutManager+Rest.swift | HKWorkoutManagerPauseTests.swift, HKWorkoutManagerRestAlertTests.swift, HKWorkoutManagerRestTests.swift |
| **HealthKitManager** | [Compound/Managers/HealthKitManager](Compound/Managers/HealthKitManager/HealthKitManager.swift) | 117 |  |  |  |  | HealthKitManagerTests.swift |
| **ImageUploadManager** | [Compound/Managers/ImageUpload](Compound/Managers/ImageUpload/ImageUploadManager.swift) | 43 |  |  | FirebaseImageUploadService, ImageUploadService, MockImageUploadService |  | ImageUploadManagerTests.swift |
| **LiveActivityManager** | [Compound/Managers/LiveActivities](Compound/Managers/LiveActivities/LiveActivityManager.swift) | 525 |  |  |  | LiveActivityManager+Events.swift | LiveActivityManagerTests.swift |
| **ActivityNotificationManager** | [Compound/Managers/Notifications](Compound/Managers/Notifications/ActivityNotificationManager.swift) | 111 |  |  |  |  | ActivityNotificationManagerTests.swift |
| **FoodManager** | [Compound/Managers/Nutrition/Food](Compound/Managers/Nutrition/Food/FoodManager.swift) | 63 | Collection<FoodModel> | FoodModel, FoodModel+MealItem, ServingUnit |  |  | FoodManagerTests.swift |
| **FoodLogSettingsManager** | [Compound/Managers/Nutrition/FoodLogSettings](Compound/Managers/Nutrition/FoodLogSettings/FoodLogSettingsManager.swift) | 88 | Document<FoodLogSettings> | FoodLogSettings |  |  | FoodLogSettingsManagerTests.swift |
| **MealLogManager** | [Compound/Managers/Nutrition/MealLog](Compound/Managers/Nutrition/MealLog/MealLogManager.swift) | 486 | Collection<MealLogModel> | MealItemModel, MealItemSourceType, MealLogModel, MealLogModel+Mocks |  |  | MealLogManagerTests.swift |
| **NutritionManager** | [Compound/Managers/Nutrition/NutritionManager](Compound/Managers/Nutrition/NutritionManager/NutritionManager.swift) | 447 | Document<DietPlan> | DailyMacroTarget, DailyNutritionBreakdown, DietPlan |  |  | NutritionManagerDietPlanTests.swift, NutritionManagerTests.swift |
| **NutritionStrategyManager** | [Compound/Managers/Nutrition/NutritionStrategy](Compound/Managers/Nutrition/NutritionStrategy/NutritionStrategyManager.swift) | 188 | Collection<NutritionDayAnnotation>, Document<CheckInRecord>, Document<LoggingBreak> | CheckInRecord, LoggingBreak, NutritionDayAnnotation |  |  | NutritionStrategyManagerTests.swift |
| **NutritionStrategySettingsManager** | [Compound/Managers/Nutrition/NutritionStrategySettings](Compound/Managers/Nutrition/NutritionStrategySettings/NutritionStrategySettingsManager.swift) | 57 | Document<NutritionStrategySettings> | NutritionStrategySettings |  |  | NutritionStrategySettingsManagerTests.swift |
| **RecipeTemplateManager** | [Compound/Managers/Nutrition/RecipeTemplate](Compound/Managers/Nutrition/RecipeTemplate/RecipeTemplateManager.swift) | 63 | Collection<RecipeTemplateModel> | RecipeIngredientModel, RecipeTemplateModel |  |  | RecipeTemplateManagerTests.swift |
| **ProgressPhotoManager** | [Compound/Managers/ProgressPhotos](Compound/Managers/ProgressPhotos/ProgressPhotoManager.swift) | 97 | Collection<ProgressPhotoModel> |  |  |  |  |
| **PushManager** | [Compound/Managers/Push](Compound/Managers/Push/PushManager.swift) | 319 |  | PushNotificationDelegate |  |  | PushManagerTests.swift |
| **ReportManager** | [Compound/Managers/Reports](Compound/Managers/Reports/ReportManager.swift) | 95 |  |  |  |  | ReportManagerTests.swift |
| **NudgeHistoryManager** | [Compound/Managers/Search](Compound/Managers/Search/NudgeHistoryManager.swift) | 38 |  |  |  |  |  |
| **ShortcutSettingsManager** | [Compound/Managers/Shortcuts](Compound/Managers/Shortcuts/ShortcutSettingsManager.swift) | 57 | Document<ShortcutSettings> | ShortcutSettings |  |  | ShortcutSettingsManagerTests.swift |
| **CommentsManager** | [Compound/Managers/Social](Compound/Managers/Social/CommentsManager.swift) | 35 |  |  |  |  | CommentsManagerTests.swift |
| **StepsManager** | [Compound/Managers/Steps](Compound/Managers/Steps/StepsManager.swift) | 188 | Collection<StepsModel> | StepsModel |  |  | StepsManagerTests.swift |
| **StravaManager** | [Compound/Managers/Strava](Compound/Managers/Strava/StravaManager.swift) | 288 | Collection<StravaImportedActivity> | StravaAthlete, StravaExerciseType, StravaImportedActivity, StravaStrengthFile, StravaUploadStatus | MockStravaService, ProductionStravaService, StravaService | StravaManager+Uploads.swift | StravaManagerTests.swift |
| **ExerciseModelManager** | [Compound/Managers/Training/Exercise](Compound/Managers/Training/Exercise/ExerciseModelManager.swift) | 195 | Collection<ExerciseModel> | BodyRegion, EquipmentVariation, ExerciseDefinitionRules, ExerciseModel, ExerciseType, ExerciseUnitPreference, Laterality, MuscleVolume, Muscles, PickableItem, … +5 more |  |  |  |
| **ExerciseSettingsManager** | [Compound/Managers/Training/Exercise/ExerciseSettings](Compound/Managers/Training/Exercise/ExerciseSettings/ExerciseSettingsManager.swift) | 76 | Collection<ExerciseSettingsModel> | ExerciseSettingsModel |  |  | ExerciseSettingsManagerTests.swift |
| **ExerciseUnitPreferenceManager** | [Compound/Managers/Training/Exercise](Compound/Managers/Training/Exercise/ExerciseUnitPreferenceManager.swift) | 161 |  | BodyRegion, EquipmentVariation, ExerciseDefinitionRules, ExerciseModel, ExerciseType, ExerciseUnitPreference, Laterality, MuscleVolume, Muscles, PickableItem, … +5 more |  |  | ExerciseUnitPreferenceManagerTests.swift |
| **GymProfileManager** | [Compound/Managers/Training/GymProfile](Compound/Managers/Training/GymProfile/GymProfileManager.swift) | 110 | Collection<GymProfileModel> | AccessoryEquipment, AnyEquipment, Bands, BodyWeights, BodyWeights+Defaults, CableMachine, EquipmentConformances, EquipmentKind, EquipmentRef, FixedWeightBars, … +22 more |  |  | GymProfileManagerTests.swift |
| **MacrocycleManager** | [Compound/Managers/Training/Macrocycle](Compound/Managers/Training/Macrocycle/MacrocycleManager.swift) | 311 | Collection<Macrocycle> | Macrocycle |  |  | MacrocycleManagerTests.swift |
| **MesocycleManager** | [Compound/Managers/Training/Mesocycle](Compound/Managers/Training/Mesocycle/MesocycleManager.swift) | 274 | Collection<Mesocycle> | Mesocycle |  |  | MesocycleManagerTests.swift |
| **WorkoutSessionManager** | [Compound/Managers/Training/WorkoutSession](Compound/Managers/Training/WorkoutSession/WorkoutSessionManager.swift) | 452 | Collection<WorkoutSessionModel>, CollectionGroup<WorkoutSessionModel> | SetSide, WorkoutExerciseModel, WorkoutSessionComment, WorkoutSessionModel, WorkoutSessionModel+Prefill, WorkoutSessionModel+WarmupSets, WorkoutSetModel, WorkoutSetPairing | FirebaseWorkoutSessionLikeService, MockWorkoutSessionLikeService, WorkoutSessionLikeService |  | WorkoutSessionManagerTests.swift |
| **WorkoutSettingsManager** | [Compound/Managers/Training/WorkoutSettings](Compound/Managers/Training/WorkoutSettings/WorkoutSettingsManager.swift) | 47 | Document<WorkoutSettings> | WorkoutSettings |  |  | WorkoutSettingsManagerTests.swift |
| **WorkoutTemplateManager** | [Compound/Managers/Training/WorkoutTemplate](Compound/Managers/Training/WorkoutTemplate/WorkoutTemplateManager.swift) | 210 | Collection<WorkoutTemplateModel> | WorkoutTemplateModel |  |  | WorkoutTemplateManagerTests.swift |
| **UserManager** | [Compound/Managers/User](Compound/Managers/User/UserManager.swift) | 716 | Collection<UserModel>, Document<PrivateUserSettings>, Document<UserModel> | FollowRequestModel, PrivateUserSettings, UserModel, UserModel+Mocks, Username | FirebaseUserQueryService, MockUserQueryService, UserQueryService | UserManager+RemoveFollower.swift, UserManager+Username.swift | UserManagerAccountDeletionTests.swift, UserManagerTests.swift |

## Sync models (`DataSyncModelProtocol`)

| Model | File |
|---|---|
| `AnalyticsSettings` | [Compound/Managers/Analytics/AnalyticsSettings/Models/AnalyticsSettings.swift](Compound/Managers/Analytics/AnalyticsSettings/Models/AnalyticsSettings.swift) |
| `BodyMeasurementEntry` | [Compound/Managers/BodyMeasurements/Models/BodyMeasurementEntry.swift](Compound/Managers/BodyMeasurements/Models/BodyMeasurementEntry.swift) |
| `CheckInRecord` | [Compound/Managers/Nutrition/NutritionStrategy/Models/CheckInRecord.swift](Compound/Managers/Nutrition/NutritionStrategy/Models/CheckInRecord.swift) |
| `CoachChat` | [Compound/Managers/Coach/Models/CoachModels.swift](Compound/Managers/Coach/Models/CoachModels.swift) |
| `DietPlan` | [Compound/Managers/Nutrition/NutritionManager/Models/DietPlan.swift](Compound/Managers/Nutrition/NutritionManager/Models/DietPlan.swift) |
| `EquipmentRef` | [Compound/Managers/Training/GymProfile/Model/Equipment/EquipmentRef.swift](Compound/Managers/Training/GymProfile/Model/Equipment/EquipmentRef.swift) |
| `ExerciseModel` | [Compound/Managers/Training/Exercise/Models/ExerciseModel.swift](Compound/Managers/Training/Exercise/Models/ExerciseModel.swift) |
| `ExerciseSettingsModel` | [Compound/Managers/Training/Exercise/ExerciseSettings/Models/ExerciseSettingsModel.swift](Compound/Managers/Training/Exercise/ExerciseSettings/Models/ExerciseSettingsModel.swift) |
| `FoodLogSettings` | [Compound/Managers/Nutrition/FoodLogSettings/Models/FoodLogSettings.swift](Compound/Managers/Nutrition/FoodLogSettings/Models/FoodLogSettings.swift) |
| `FoodModel` | [Compound/Managers/Nutrition/Food/Models/FoodModel.swift](Compound/Managers/Nutrition/Food/Models/FoodModel.swift) |
| `GymProfileModel` | [Compound/Managers/Training/GymProfile/Model/GymProfile/GymProfileModel.swift](Compound/Managers/Training/GymProfile/Model/GymProfile/GymProfileModel.swift) |
| `LoggingBreak` | [Compound/Managers/Nutrition/NutritionStrategy/Models/LoggingBreak.swift](Compound/Managers/Nutrition/NutritionStrategy/Models/LoggingBreak.swift) |
| `Macrocycle` | [Compound/Managers/Training/Macrocycle/Models/Macrocycle.swift](Compound/Managers/Training/Macrocycle/Models/Macrocycle.swift) |
| `MealItemModel` | [Compound/Managers/Nutrition/MealLog/Models/MealItemModel.swift](Compound/Managers/Nutrition/MealLog/Models/MealItemModel.swift) |
| `MealLogModel` | [Compound/Managers/Nutrition/MealLog/Models/MealLogModel.swift](Compound/Managers/Nutrition/MealLog/Models/MealLogModel.swift) |
| `Mesocycle` | [Compound/Managers/Training/Mesocycle/Models/Mesocycle.swift](Compound/Managers/Training/Mesocycle/Models/Mesocycle.swift) |
| `NutritionDayAnnotation` | [Compound/Managers/Nutrition/NutritionStrategy/Models/NutritionDayAnnotation.swift](Compound/Managers/Nutrition/NutritionStrategy/Models/NutritionDayAnnotation.swift) |
| `NutritionStrategySettings` | [Compound/Managers/Nutrition/NutritionStrategySettings/Models/NutritionStrategySettings.swift](Compound/Managers/Nutrition/NutritionStrategySettings/Models/NutritionStrategySettings.swift) |
| `PrivateUserSettings` | [Compound/Managers/User/Models/PrivateUserSettings.swift](Compound/Managers/User/Models/PrivateUserSettings.swift) |
| `ProgressPhotoModel` | [Compound/Managers/ProgressPhotos/ProgressPhotoModel.swift](Compound/Managers/ProgressPhotos/ProgressPhotoModel.swift) |
| `RecipeIngredientModel` | [Compound/Managers/Nutrition/RecipeTemplate/Models/RecipeIngredientModel.swift](Compound/Managers/Nutrition/RecipeTemplate/Models/RecipeIngredientModel.swift) |
| `RecipeTemplateModel` | [Compound/Managers/Nutrition/RecipeTemplate/Models/RecipeTemplateModel.swift](Compound/Managers/Nutrition/RecipeTemplate/Models/RecipeTemplateModel.swift) |
| `SetTarget` | [Compound/Managers/Training/Exercise/Models/SetTarget.swift](Compound/Managers/Training/Exercise/Models/SetTarget.swift) |
| `ShortcutSettings` | [Compound/Managers/Shortcuts/Models/ShortcutSettings.swift](Compound/Managers/Shortcuts/Models/ShortcutSettings.swift) |
| `StepsModel` | [Compound/Managers/Steps/Models/StepsModel.swift](Compound/Managers/Steps/Models/StepsModel.swift) |
| `StravaImportedActivity` | [Compound/Managers/Strava/Models/StravaImportedActivity.swift](Compound/Managers/Strava/Models/StravaImportedActivity.swift) |
| `UserModel` | [Compound/Managers/User/Models/UserModel.swift](Compound/Managers/User/Models/UserModel.swift) |
| `WeightGoal` | [Compound/Managers/Goal/Models/WeightGoal.swift](Compound/Managers/Goal/Models/WeightGoal.swift) |
| `WorkoutExerciseModel` | [Compound/Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift](Compound/Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift) |
| `WorkoutSessionModel` | [Compound/Managers/Training/WorkoutSession/Models/WorkoutSessionModel.swift](Compound/Managers/Training/WorkoutSession/Models/WorkoutSessionModel.swift) |
| `WorkoutSettings` | [Compound/Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift](Compound/Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift) |
| `WorkoutTemplateExercise` | [Compound/Managers/Training/Exercise/Models/WorkoutTemplateExercise.swift](Compound/Managers/Training/Exercise/Models/WorkoutTemplateExercise.swift) |
| `WorkoutTemplateModel` | [Compound/Managers/Training/WorkoutTemplate/Models/WorkoutTemplateModel.swift](Compound/Managers/Training/WorkoutTemplate/Models/WorkoutTemplateModel.swift) |

## CoreInteractor and its extensions

| File | Lines |
|---|---:|
| [CoreBuilder.swift](Compound/Root/RIBs/Core/CoreBuilder.swift) | 18 |
| [CoreInteractor+AccountDeletion.swift](Compound/Root/RIBs/Core/CoreInteractor+AccountDeletion.swift) | 39 |
| [CoreInteractor+CircleGoals.swift](Compound/Root/RIBs/Core/CoreInteractor+CircleGoals.swift) | 15 |
| [CoreInteractor+PreviousWorkoutReference.swift](Compound/Root/RIBs/Core/CoreInteractor+PreviousWorkoutReference.swift) | 114 |
| [CoreInteractor+Progression.swift](Compound/Root/RIBs/Core/CoreInteractor+Progression.swift) | 105 |
| [CoreInteractor+ScheduledPush.swift](Compound/Root/RIBs/Core/CoreInteractor+ScheduledPush.swift) | 10 |
| [CoreInteractor+Username.swift](Compound/Root/RIBs/Core/CoreInteractor+Username.swift) | 17 |
| [CoreInteractor.swift](Compound/Root/RIBs/Core/CoreInteractor.swift) | 333 |
| [CoreRouter.swift](Compound/Root/RIBs/Core/CoreRouter.swift) | 32 |

## Cloud Functions (`functions/index.js`)

| Export | Kind | Line |
|---|---|---|
| `foodAnalyze` | onCall | [index.js:138](functions/index.js#L138) |
| `mealDescribe` | onCall | [index.js:184](functions/index.js#L184) |
| `nutritionLabelAnalyze` | onCall | [index.js:225](functions/index.js#L225) |
| `imageGenerate` | onCall | [index.js:256](functions/index.js#L256) |
| `foodSearch` | onCall | [index.js:285](functions/index.js#L285) |
| `onActivityNotificationCreated` | onDocumentCreated | [index.js:378](functions/index.js#L378) |
| `onUserBlockListChanged` | onDocumentUpdated | [index.js:419](functions/index.js#L419) |
| `onFollowRequestUpdated` | onDocumentUpdated | [index.js:450](functions/index.js#L450) |
| `onFollowRequestCreated` | onDocumentCreated | [index.js:477](functions/index.js#L477) |
| `removeFollower` | onCall | [index.js:503](functions/index.js#L503) |
| `onUserFollowingChanged` | onDocumentUpdated | [index.js:523](functions/index.js#L523) |
| `onUserPrivacyChanged` | onDocumentUpdated | [index.js:545](functions/index.js#L545) |
| `onUsernameChanged` | onDocumentWritten | [index.js:577](functions/index.js#L577) |
| `streakReminder` | onSchedule | [index.js:630](functions/index.js#L630) |
| `weeklyDigest` | onSchedule | [index.js:641](functions/index.js#L641) |
| `onUserDeleted` | onDocumentDeleted | [index.js:676](functions/index.js#L676) |
| `onReportCreated` | onDocumentCreated | [index.js:753](functions/index.js#L753) |
| `onWorkoutSessionEndedForChallenges` | onDocumentWritten | [index.js:787](functions/index.js#L787) |
| `acceptInvite` | onCall | [index.js:831](functions/index.js#L831) |
| `sessionPage` | onRequest | [index.js:890](functions/index.js#L890) |
| `stravaToken` | onCall | [index.js:922](functions/index.js#L922) |
| `stravaConnect` | onCall | [index.js:1002](functions/index.js#L1002) |
| `stravaAccessToken` | onCall | [index.js:1039](functions/index.js#L1039) |
| `stravaConnection` | onCall | [index.js:1044](functions/index.js#L1044) |
| `stravaDisconnect` | onCall | [index.js:1050](functions/index.js#L1050) |
| `stravaWebhook` | onRequest | [index.js:1058](functions/index.js#L1058) |
| `onStravaEventCreated` | onDocumentCreated | [index.js:1118](functions/index.js#L1118) |
| `coachChat` | onCall | [index.js:1155](functions/index.js#L1155) |

## Firestore paths (`firestore.rules`)

| Path | Rules |
|---|---|
| `/users/{user_id}` | [rules:47](firestore.rules#L47) |
| `/users/{user_id}/private/{private_id}` | [rules:55](firestore.rules#L55) |
| `/users/{user_id}/body_measurements/{entry_id}` | [rules:60](firestore.rules#L60) |
| `/users/{user_id}/steps/{entry_id}` | [rules:71](firestore.rules#L71) |
| `/users/{user_id}/goals/{goal_id}` | [rules:82](firestore.rules#L82) |
| `/users/{user_id}/gym_profiles/{gym_profile_id}` | [rules:95](firestore.rules#L95) |
| `/users/{user_id}/mesocycles/{mesocycle_id}` | [rules:102](firestore.rules#L102) |
| `/users/{user_id}/macrocycles/{macrocycle_id}` | [rules:109](firestore.rules#L109) |
| `/users/{user_id}/training_programs/{training_program_id}` | [rules:117](firestore.rules#L117) |
| `/users/{user_id}/training_plans/{training_plan_id}` | [rules:123](firestore.rules#L123) |
| `/users/{user_id}/workout_sessions/{workout_session_id}` | [rules:132](firestore.rules#L132) |
| `/users/{user_id}/workout_templates/{workout_templates_id}` | [rules:149](firestore.rules#L149) |
| `/users/{user_id}/workout_settings/{workout_settings_id}` | [rules:156](firestore.rules#L156) |
| `/users/{user_id}/exercise_settings/{exercise_settings_id}` | [rules:161](firestore.rules#L161) |
| `/users/{user_id}/food_log_settings/{food_log_settings_id}` | [rules:166](firestore.rules#L166) |
| `/users/{user_id}/analytics_settings/{analytics_settings_id}` | [rules:171](firestore.rules#L171) |
| `/users/{user_id}/shortcut_settings/{shortcut_settings_id}` | [rules:176](firestore.rules#L176) |
| `/users/{user_id}/nutrition_strategy_settings/{nutrition_strategy_settings_id}` | [rules:181](firestore.rules#L181) |
| `/users/{user_id}/nutrition_day_annotations/{day_key}` | [rules:187](firestore.rules#L187) |
| `/users/{user_id}/logging_break/{logging_break_id}` | [rules:198](firestore.rules#L198) |
| `/users/{user_id}/check_in_record/{check_in_record_id}` | [rules:208](firestore.rules#L208) |
| `/users/{user_id}/meal_logs/{document=**}` | [rules:219](firestore.rules#L219) |
| `/users/{user_id}/recipe_templates/{workout_templates_id}` | [rules:224](firestore.rules#L224) |
| `/users/{user_id}/foods/{food_id}` | [rules:231](firestore.rules#L231) |
| `/users/{user_id}/follow_requests/{requester_id}` | [rules:243](firestore.rules#L243) |
| `/users/{user_id}/notifications/{notification_id}` | [rules:265](firestore.rules#L265) |
| `/users/{user_id}/strava_activities/{activity_id}` | [rules:280](firestore.rules#L280) |
| `/users/{user_id}/coach_chats/{chat_id}` | [rules:286](firestore.rules#L286) |
| `/user_streaks/{user_id}` | [rules:293](firestore.rules#L293) |
| `/user_streaks/{user_id}/workout/{document_id}` | [rules:298](firestore.rules#L298) |
| `/user_streaks/{user_id}/workout/{document_id}/data/{data_id}` | [rules:301](firestore.rules#L301) |
| `/food_search_cache/{doc}` | [rules:309](firestore.rules#L309) |
| `/strava_connections/{user_id}` | [rules:316](firestore.rules#L316) |
| `/strava_events/{event_id}` | [rules:319](firestore.rules#L319) |
| `/coach_usage/{user_id}` | [rules:325](firestore.rules#L325) |
| `/{path=**}/workout_sessions/{workout_session_id}` | [rules:333](firestore.rules#L333) |
| `/{path=**}/follow_requests/{requester_id}` | [rules:341](firestore.rules#L341) |
| `/ingredient_templates/{ingredient_id}` | [rules:346](firestore.rules#L346) |
| `/recipe_templates/{recipe_id}` | [rules:353](firestore.rules#L353) |
| `/diet_plans/{user_id}` | [rules:360](firestore.rules#L360) |
| `/gym_profiles/{gym_profile_id}` | [rules:367](firestore.rules#L367) |
| `/exercise_templates/{exercise_id}` | [rules:374](firestore.rules#L374) |
| `/exercise_history/{exercise_history_id}` | [rules:381](firestore.rules#L381) |
| `/workout_templates/{workout_template_id}` | [rules:387](firestore.rules#L387) |
| `/workout_exercises/{exercise_id}` | [rules:398](firestore.rules#L398) |
| `/workout_sets/{set_id}` | [rules:405](firestore.rules#L405) |
| `/program_templates/{program_template_id}` | [rules:412](firestore.rules#L412) |
| `/training_plans/{training_plan_id}` | [rules:419](firestore.rules#L419) |
| `/training_programs/{training_program_id}` | [rules:427](firestore.rules#L427) |
| `/reports/{report_id}` | [rules:437](firestore.rules#L437) |
| `/moderation_queue/{target_id}` | [rules:457](firestore.rules#L457) |
| `/workout_session_comments/{comment_id}` | [rules:463](firestore.rules#L463) |
| `/usernames/{handle}` | [rules:503](firestore.rules#L503) |
| `/shares/{share_id}` | [rules:515](firestore.rules#L515) |
| `/challenges/{challenge_id}` | [rules:541](firestore.rules#L541) |
| `/progress/{member_id}` | [rules:572](firestore.rules#L572) |
| `/invites/{code}` | [rules:583](firestore.rules#L583) |
| `/users/{user_id}/progress_photos/{photo_id}` | [rules:600](firestore.rules#L600) |

## Unit test suites

**`CompoundUnitTests`** (1): `DialedInTests`

**`CompoundUnitTests/Components`** (9): `AutoSelectNumberFieldTextTests`, `CalendarDayMarkerAccessibilityTests`, `CalendarDayMarkerRingStyleTests`, `CalendarHeaderPresenterTests`, `CustomPaywallViewTests`, `ExerciseImageViewTests`, `ListBuilderSelectionTests`, `MetricChartReadingsTests`, `SetDetailRowTests`

**`CompoundUnitTests/Core`** (174): `AIFoodInputPresenterTests`, `ActiveMesocyclePresenterTests`, `ActiveWorkoutFocusTests`, `ActiveWorkoutLogRuleTests`, `ActiveWorkoutScreenStateTests`, `ActiveWorkoutStateTests`, `AddMealPresenterTests`, `AmountPresenterTests`, `AnalyticsBodyMetricsPresenterTests`, `AnalyticsConsistencyPresenterTests`, `AnalyticsExercisePresenterTests`, `AnalyticsInsightsPresenterTests`, `AnalyticsNutritionPresenterTests`, `AnalyticsPresenterTests`, `AppShellPresenterTests`, `BarcodeScannerHandoffTests`, `BarcodeScannerPresenterTests`, `BodyMeasurementTests`, `ChallengesPresenterTests`, `CheckInPresenterTests`, `CircleGoalsPresenterTests`, `CircleWeekTests`, `CoachTests`, `CommentLikesTests`, `CommentMentionsTests`, `ContentDeletionPresenterTests`, `CorrectionRuleTests`, `CreateExerciseEquipmentPresenterTests`, `CreateExerciseFlowPresenterTests`, `CreateFoodFlowPresenterTests`, `CreateMesocycleFlowPresenterTests`, `CreateWorkoutFlowPresenterTests`, `CreateWorkoutWrapperPresenterTests`, `DecimalWheelValueTests`, `DeleteAccountPresenterTests`, `DevToolsPresenterTests`, `EditProfilePresenterTests`, `EnergyBalancePresenterTests`, `ErrorAlertMessageTests`, `ExerciseDefinitionRulesTests`, `ExerciseModelDetailPresenterTests`, `FeedLoadingTests`, `FollowersListRemoveTests`, `FoodDefinitionPresenterTests`, `FoodItemQuickAddPresenterTests`, `FoodItemSearchPresenterTests`, `FoodLibraryPresenterTests`, `FoodLogSettingsStaleSnapshotTests`, `GeneralSettingsPresenterTests`, `GymEquipmentAdderPresenterTests`, `GymEquipmentEditorPresenterTests`, `GymMachineEditorPresenterTests`, `GymProfilePresenterTests`, `GymProfilesListPresenterTests`, `HabitsPresenterTests`, `IdleWorkoutReminderTests`, `InviteTests`, `MacroHeaderRemainingTests`, `MacrocycleDetailPresenterTests`, `MealAccessoryPresenterTests`, `MealHourHeaderPresenterTests`, `MesocycleDayDetailTests`, `MesocycleDesignPresenterTests`, `MesocycleSettingsFlowPresenterTests`, `MesocycleSharingTests`, `MetricDetailPresenterTests`, `MuscleBalanceTests`, `MuscleGroupDetailPresenterTests`, `NotificationGroupingTests`, `NotificationSettingsPresenterTests`, `NotificationTapThroughTests`, `NotificationsFollowRequestTests`, `NutritionOverviewPresenterTests`, `NutritionPresenterTests`, `NutritionSettingsPresenterTests`, `NutritionSettingsTilePresenterTests`, `NutritionTargetChartColourTests`, `OfflineDetectionTests`, `OnboardingAccountSetupPresenterTests`, `OnboardingAppleHealthFillTests`, `OnboardingAuthPresenterTests`, `OnboardingCompletedRetryTests`, `OnboardingDietChoicesPresenterTests`, `OnboardingDietPlanPresenterTests`, `OnboardingEntryPresenterTests`, `OnboardingExpenditurePresenterTests`, `OnboardingFinishPresenterTests`, `OnboardingGoalSettingPresenterTests`, `OnboardingGoalSummaryEstimateTests`, `OnboardingGoalSummaryPresenterTests`, `OnboardingHealthConsentPresenterTests`, `OnboardingHeightConversionTests`, `OnboardingLifestylePresenterTests`, `OnboardingSelectionHapticsTests`, `OnboardingStepRouterTests`, `OnboardingWeightRatePresenterTests`, `PaywallPresenterTests`, `PreviousWorkoutReferenceResolverTests`, `PreviousWorkoutReferenceSettingTests`, `PrimarySlotTests`, `ProfileAppInfoPresenterTests`, `ProgressCarouselMetricsTests`, `ProgressPhotosPresenterTests`, `PropagationRuleTests`, `RecipeFlowPresenterTests`, `RecipePreparationPresenterTests`, `RecipeScalingPresenterTests`, `ReminderOfferFlowTests`, `ReportReasonsTests`, `ReviewMomentTests`, `ReviewPromptPolicyTests`, `SaveFailureAlertTests`, `SessionVolumeUnitTests`, `SessionWebLinkTests`, `SetKeyboardPresenterTests`, `SetSideTrackingTests`, `SetTrackerPresenterTests`, `SettingsPresenterTests`, `SettingsSnapshotRefreshTests`, `ShareCardTests`, `SignOutListenersTests`, `SocialCirclePresenterTests`, `SocialFollowersListTests`, `SocialPresenterTests`, `SocialProfilePresenterTests`, `SocialSafetyTests`, `SocialWorkoutSessionRowTests`, `StravaOfferTests`, `StreakVisibilityTests`, `SupersetBlockLayoutTests`, `TimelineActionsPresenterTests`, `TimerDurationPresenterTests`, `TodayChecklistTests`, `TodayPresenterTests`, `TodaysWorkoutCardPresenterTests`, `TrainingHomePresenterTests`, `TrainingLibraryPresenterTests`, `TrainingSearchTests`, `TrainingSettingsPresenterTests`, `WeeklyReviewTests`, `WeeklyStreakTests`, `WeightStepperTests`, `WeightTrendPresenterTests`, `WorkoutBuildUnsavedChangesTests`, `WorkoutNotesTests`, `WorkoutPausedTimeTests`, `WorkoutPresenterTests`, `WorkoutResumeRuleTests`, `WorkoutSessionAuthorTests`, `WorkoutSessionDeleteFailureTests`, `WorkoutSessionDetailPresenterTests`, `WorkoutSessionHighlightsTests`, `WorkoutSessionRowStatsTests`, `WorkoutSessionSaveAsTemplateTests`, `WorkoutSessionStravaLinkTests`, `WorkoutSessionTemplateBuilderTests`, `WorkoutTrackerAddExerciseTests`, `WorkoutTrackerCorrectionTests`, `WorkoutTrackerDeleteExerciseTests`, `WorkoutTrackerFinishTests`, `WorkoutTrackerGymProfileTests`, `WorkoutTrackerPresenterProgressionTests`, `WorkoutTrackerPresenterTests`, `WorkoutTrackerPrimarySlotTests`, `WorkoutTrackerPropagationTests`, `WorkoutTrackerQuickFinishTests`, `WorkoutTrackerRestFeedbackTests`, `WorkoutTrackerResumeTests`, `WorkoutTrackerSaveCoalescingTests`, `WorkoutTrackerSharedLogTests`, `WorkoutTrackerSupersetTests`, `WorkoutTrackerSwapTests`, `WorkoutTrackingRowPresenterTests`, `WorkoutTrackingSheetPresenterTests`

**`CompoundUnitTests/DesignSystem`** (2): `FormatTests`, `OnboardingStepProgressTests`

**`CompoundUnitTests/Extensions`** (2): `CollectionAndStringExtensionTests`, `DateExtensionTests`

**`CompoundUnitTests/Managers`** (31): `ABTestManagerTests`, `AIManagerTests`, `ActivityNotificationManagerTests`, `AdjustLastSetRepsIntentTests`, `AppIntentsTests`, `AppStateTests`, `CoachParityTests`, `HKWorkoutManagerPauseTests`, `HKWorkoutManagerRestAlertTests`, `HKWorkoutManagerRestTests`, `HealthKitManagerTests`, `ImageUploadManagerTests`, `LiveActivityEventNameTests`, `LiveActivityIntentHandlerTests`, `LiveActivityPhaseTests`, `LiveActivityScenarioTests`, `LiveActivitySetTargetLabelTests`, `PremiumAccessTests`, `PushManagerTests`, `PushPendingDeepLinkTests`, `ReportManagerTests`, `RestDurationRulesTests`, `RestOverAlertTests`, `RestOverMessageTests`, `StepsManagerTests`, `StravaManagerTests`, `StravaStrengthFileTests`, `WorkoutLocationTypeDescriptionTests`, `WorkoutRelaunchRecoveryTests`, `WorkoutSettingsDecodingTests`, `WorkoutSettingsLockScreenTests`

**`CompoundUnitTests/Managers/FirestoreCost`** (2): `DataAccessLogTests`, `FollowingQueriesTests`

**`CompoundUnitTests/Managers/Nutrition`** (6): `CheckInScheduleTests`, `ExpenditureEngineTests`, `ExpenditureSampleBuilderTests`, `NutritionScalingTests`, `OpenFoodFactsDecodingTests`, `TargetProposalTests`

**`CompoundUnitTests/Managers/Training`** (4): `MacrocycleManagerTests`, `MesocycleScheduleTests`, `ProgressionEngineTests`, `ProgressionSuggestionDisplayTests`

**`CompoundUnitTests/Services/AI`** (1): `ImageDescriptionBuilderTests`

**`CompoundUnitTests/Services/Analytics`** (1): `AnalyticsSettingsManagerTests`

**`CompoundUnitTests/Services/BodyMeasurements`** (2): `BodyMeasurementEntryTests`, `BodyMeasurementsManagerTests`

**`CompoundUnitTests/Services/Goal`** (1): `GoalManagerTests`

**`CompoundUnitTests/Services/Goal/Models`** (4): `WeightGoalComputedPropertiesAndCalculationsTests`, `WeightGoalEqualityAndCodableTests`, `WeightGoalInitializationTests`, `WeightGoalMocksAndEdgeCasesTests`

**`CompoundUnitTests/Services/Nutrition`** (14): `ExpenditureEstimationMethodTests`, `FoodLogSettingsManagerTests`, `FoodManagerTests`, `MealLogHealthKitImportTests`, `MealLogManagerTests`, `MealLogModelTests`, `NutrientMapTests`, `NutritionGoalTargetTests`, `NutritionManagerDietPlanTests`, `NutritionManagerTests`, `NutritionStrategyManagerTests`, `NutritionStrategySettingsManagerTests`, `RecipeTemplateManagerTests`, `RecipeTemplateModelTests`

**`CompoundUnitTests/Services/Nutrition/IngredientTemplate/Models`** (3): `IngredientTemplateModelCodableAndProtocolTests`, `IngredientTemplateModelInitializationTests`, `IngredientTemplateModelMockAndEdgeCasesTests`

**`CompoundUnitTests/Services/Shortcuts`** (1): `ShortcutSettingsManagerTests`

**`CompoundUnitTests/Services/Social`** (1): `CommentsManagerTests`

**`CompoundUnitTests/Services/Training`** (3): `GymProfileSyncTests`, `LiveActivityManagerTests`, `WorkoutTemplateModelTests`

**`CompoundUnitTests/Services/Training/ExerciseTemplate`** (3): `ExerciseTemplateManagerErrorHandlingTests`, `ExerciseTemplateManagerTests`, `ExerciseUnitPreferenceManagerTests`

**`CompoundUnitTests/Services/Training/ExerciseTemplate/Models`** (4): `ExerciseTemplateEnumTests`, `ExerciseTemplateModelCodableAndProtocolTests`, `ExerciseTemplateModelInitializationTests`, `ExerciseTemplateModelMockAndEdgeCasesTests`

**`CompoundUnitTests/Services/Training/GymProfile`** (1): `GymProfileManagerTests`

**`CompoundUnitTests/Services/Training/Mesocycle`** (2): `MesocycleManagerTests`, `PrebuiltMesocycleTests`

**`CompoundUnitTests/Services/Training/Settings`** (2): `ExerciseSettingsManagerTests`, `WorkoutSettingsManagerTests`

**`CompoundUnitTests/Services/Training/WorkoutSession`** (6): `WarmupSetGenerationTests`, `WorkoutExerciseAndSetTests`, `WorkoutSessionManagerTests`, `WorkoutSessionModelTests`, `WorkoutSessionPrefillTests`, `WorkoutSetSideTests`

**`CompoundUnitTests/Services/Training/WorkoutTemplate`** (2): `WorkoutTemplateManagerTests`, `WorkoutTemplateSeedingTests`

**`CompoundUnitTests/Services/User`** (3): `UserManagerAccountDeletionTests`, `UserManagerTests`, `UsernameTests`

**`CompoundUnitTests/Services/User/Models`** (2): `OnboardingStepInferenceTests`, `UserModelTests`

**`CompoundUnitTests/Support`** (1): `WorkoutRestSharedStateTests`

**`CompoundUnitTests/Utilities`** (4): `PrivacyManifestTests`, `RetryPolicyTests`, `UnitConversionTests`, `WeightTrendCalculatorTests`

**`CompoundUnitTests/Widgets`** (2): `SharedWorkoutStorageMigrationTests`, `WidgetSnapshotTests`

**`CompoundUITests`**: `CreateExerciseUITests`, `CreateMesocycleUITests`, `CreateWorkoutUITests`, `EditWorkoutSessionUITests`, `OnboardingUITests`, `ScreenDeckSmokeTests+Screens`, `ScreenDeckSmokeTests`, `UITestApp`, `WorkoutTrackerUITests`


## Scripts, docs, CI, backend files

| File | Lines |
|---|---:|
| [scripts/clean-simulators.sh](scripts/clean-simulators.sh) | 38 |
| [scripts/codebase-map.py](scripts/codebase-map.py) | 378 |
| [scripts/contact-sheet.py](scripts/contact-sheet.py) | 42 |
| [scripts/gen-smoke-tests.sh](scripts/gen-smoke-tests.sh) | 29 |
| [scripts/screenshots-diff.py](scripts/screenshots-diff.py) | 119 |
| [scripts/screenshots.sh](scripts/screenshots.sh) | 95 |
| [docs/AppPrivacy.md](docs/AppPrivacy.md) | 101 |
| [docs/analytics/mixpanel-business-context.md](docs/analytics/mixpanel-business-context.md) | 113 |
| [docs/dead-settings-audit.md](docs/dead-settings-audit.md) | 279 |
| [docs/release-checklist.md](docs/release-checklist.md) | 64 |
| [docs/reviews/2026-10-01-list-form-and-wide-layouts.md](docs/reviews/2026-10-01-list-form-and-wide-layouts.md) | 73 |
| [docs/reviews/analytics-coverage.md](docs/reviews/analytics-coverage.md) | 494 |
| [docs/reviews/hig-active-workout.md](docs/reviews/hig-active-workout.md) | 527 |
| [docs/reviews/hig-analytics-charts.md](docs/reviews/hig-analytics-charts.md) | 474 |
| [docs/reviews/hig-dashboard-social.md](docs/reviews/hig-dashboard-social.md) | 552 |
| [docs/reviews/hig-decisions.md](docs/reviews/hig-decisions.md) | 226 |
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
| [docs/specs/ai-coach.md](docs/specs/ai-coach.md) | 70 |
| [docs/specs/live-activity-work-packages.md](docs/specs/live-activity-work-packages.md) | 372 |
| [docs/specs/live-activity.md](docs/specs/live-activity.md) | 316 |
| [docs/specs/smart-progression.md](docs/specs/smart-progression.md) | 231 |
| [docs/specs/ui-framework/CONTRACT.md](docs/specs/ui-framework/CONTRACT.md) | 261 |
| [docs/specs/ui-framework/README.md](docs/specs/ui-framework/README.md) | 136 |
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
| [docs/specs/workout-tracker/a11y.md](docs/specs/workout-tracker/a11y.md) | 240 |
| [docs/specs/workout-tracker/containers.md](docs/specs/workout-tracker/containers.md) | 654 |
| [docs/specs/workout-tracker/edges.md](docs/specs/workout-tracker/edges.md) | 174 |
| [docs/specs/workout-tracker/hig.md](docs/specs/workout-tracker/hig.md) | 551 |
| [docs/specs/workout-tracker/input.md](docs/specs/workout-tracker/input.md) | 401 |
| [docs/specs/workout-tracker/learn-decide.md](docs/specs/workout-tracker/learn-decide.md) | 500 |
| [docs/specs/workout-tracker/perf.md](docs/specs/workout-tracker/perf.md) | 336 |
| [docs/specs/workout-tracker/plan.md](docs/specs/workout-tracker/plan.md) | 274 |
| [docs/specs/workout-tracker/product.md](docs/specs/workout-tracker/product.md) | 347 |
| [docs/specs/workout-tracker/system.md](docs/specs/workout-tracker/system.md) | 340 |
| [docs/specs/workout-tracker/uikit-motion.md](docs/specs/workout-tracker/uikit-motion.md) | 707 |
| [docs/specs/workout-tracker/ux.md](docs/specs/workout-tracker/ux.md) | 413 |
| [docs/ui-audit.md](docs/ui-audit.md) | 120 |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | 253 |
| [.github/workflows/release.yml](.github/workflows/release.yml) | 180 |
| [functions/coach-fixtures.js](functions/coach-fixtures.js) | 164 |
| [functions/coach-maths.js](functions/coach-maths.js) | 341 |
| [functions/coach-maths.test.js](functions/coach-maths.test.js) | 53 |
| [functions/coach.js](functions/coach.js) | 802 |
| [functions/coach.test.js](functions/coach.test.js) | 297 |
| [functions/functions.test.js](functions/functions.test.js) | 730 |
| [functions/index.js](functions/index.js) | 1203 |
| [functions/index.test.js](functions/index.test.js) | 933 |
| [functions/lib.js](functions/lib.js) | 979 |
| [functions/rules.test.js](functions/rules.test.js) | 434 |
| [functions/scripts/coach-eval.js](functions/scripts/coach-eval.js) | 92 |
| [functions/scripts/migrateEquipmentVariations.js](functions/scripts/migrateEquipmentVariations.js) | 177 |
| [functions/scripts/migrateMesocycleNames.js](functions/scripts/migrateMesocycleNames.js) | 160 |
