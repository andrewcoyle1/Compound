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
| `DialedIn/Core/AdaptiveMain` | 4 | 98 | iPad/Mac split-vs-tab root chooser |
| `DialedIn/Core/Analytics` | 115 | 9,644 | Analytics tab: body metrics, exercise/nutrition analytics, insights, consistency |
| `DialedIn/Core/AppView` | 7 | 646 | Root view: onboarding-or-tabbar switch, toasts, notification banner |
| `DialedIn/Core/Challenges` | 11 | 773 | Group challenges (create, detail) |
| `DialedIn/Core/Dashboard` | 43 | 5,020 | Home tab: social feed, circle goals, weekly review, share card, profile |
| `DialedIn/Core/DevSettings` | 4 | 815 | DEV/MOCK-only developer tools screen |
| `DialedIn/Core/Notifications` | 5 | 894 | Activity notifications inbox |
| `DialedIn/Core/Nutrition` | 121 | 11,109 | Nutrition tab: meal log, foods, recipes, check-in, library picker, AI scanners |
| `DialedIn/Core/Onboarding` | 121 | 8,785 | Numbered onboarding steps 0–9 (see OnboardingStepRouter) |
| `DialedIn/Core/Paywalls` | 7 | 599 | Paywall screens |
| `DialedIn/Core/Profile` | 203 | 13,927 | Profile tab and every settings screen (training, nutrition, general, account, legal) |
| `DialedIn/Core/Search` | 4 | 801 | User search |
| `DialedIn/Core/Sharing` | 8 | 502 | Share-to-follower and shared-item viewer |
| `DialedIn/Core/SplitViewContainer` | 4 | 165 | iPad sidebar container |
| `DialedIn/Core/TabBar` | 5 | 514 | Tab bar, DeepLink parsing, tab selection |
| `DialedIn/Core/Training` | 182 | 15,395 | Training tab: workouts, tracker, programs, history, create flows |
| `DialedIn/Components` | 134 | 10,749 | Reusable views, buttons, modals, charts (QuickCharts alias), view modifiers |
| `DialedIn/Managers` | 242 | 29,888 | App-owned managers, models and services (see Managers table) |
| `DialedIn/Root` | 22 | 3,147 | AppDelegate, DialedInApp, Dependencies DI root, CoreInteractor/Builder/Router, Global protocols |
| `DialedIn/Utilities` | 14 | 940 | Constants, Keys, NetworkMonitor, App Check factory, unit conversion, helpers |
| `DialedIn/Extensions` | 13 | 638 | Foundation/SwiftUI type extensions (`X+EXT.swift`) |
| `DialedIn/SupportingFiles` | 188 | 3,215 | Assets, entitlements, GoogleService plists, privacy manifest, seed JSON |
| `Shared` | 5 | 588 | Code compiled into both the app and the Live Activity extension |
| `WorkoutSessionActivity` | 135 | 1,724 | Live Activity / Dynamic Island / home widget extension |
| `DialedInUnitTests` | 238 | 69,033 | Swift Testing unit suites (BlueprintName DialedInUnitTests) |
| `DialedInUITests` | 6 | 401 | XCUITest smoke and create-flow tests (launch via STARTSCREEN) |
| `functions` | 8 | 16,741 | Firebase Cloud Functions v2 (Node ESM, Genkit/Vertex) |
| `hosting` | 1 | 7 | Firebase Hosting landing page |
| `scripts` | 5 | 660 | Screenshot, contact-sheet, smoke-test generation, this map |
| `docs` | 9 | 2,647 | Specs, reviews, audits, this map |

## Screens and VIPER components

Each row is one folder holding `<Module>{Interactor,Presenter,Router,View}.swift`. *Routes to* is what the module's router protocol can open; *Delegate / entry* is the input struct and the `showXView` defined at the bottom of its View file; *Extra files* are presenter splits and helper views.
208 presenter-backed modules.

### `DialedIn/Components` (12 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **CalendarHeader** | [Views/CalendarHeader](DialedIn/Components/Views/CalendarHeader) | 787 | CalendarViewZoom | CalendarHeaderDelegate | CalendarDayCell.swift, CalendarDayMarker.swift | CalendarHeaderPresenterTests.swift |
| **Calendar** | [Views/CalendarHeader/Calendar](DialedIn/Components/Views/CalendarHeader/Calendar) | 396 |  | CalendarDelegate, `showCalendarView` |  | CalendarHeaderPresenterTests.swift |
| **EnumPicker** | [Views/EnumPicker](DialedIn/Components/Views/EnumPicker) | 214 |  | EnumPickerDelegate |  |  |
| **IngredientListBuilder** | [Views/Nutrition/IngredientListBuilder](DialedIn/Components/Views/Nutrition/IngredientListBuilder) | 345 | CreateFood, MealItemAmountView, RecipeIngredientAmount | IngredientListBuilderDelegate, `showIngredientListBuilderView` |  |  |
| **MealAccessory** | [Views/Nutrition/MealAccessory](DialedIn/Components/Views/Nutrition/MealAccessory) | 185 | AddMeal | MealAccessoryDelegate |  |  |
| **MealHourHeader** | [Views/Nutrition/MealHourHeader](DialedIn/Components/Views/Nutrition/MealHourHeader) | 249 | AddMeal | MealHourHeaderDelegate |  | MealHourHeaderPresenterTests.swift |
| **RecipeListBuilder** | [Views/Nutrition/RecipeListBuilder](DialedIn/Components/Views/Nutrition/RecipeListBuilder) | 305 | CreateRecipe, RecipeAmount, RecipeDetail | RecipeListBuilderDelegate, `showRecipeListBuilderView` |  |  |
| **ExerciseListBuilder** | [Views/Training/ExerciseListBuilder](DialedIn/Components/Views/Training/ExerciseListBuilder) | 729 | CreateExercise | ExerciseListBuilderDelegate, `showExerciseListBuilderView` | ExerciseFilters.swift |  |
| **TodaysWorkoutCard** | [Views/Training/TodaysWorkoutCard](DialedIn/Components/Views/Training/TodaysWorkoutCard) | 265 | WorkoutTemplateDetail, WorkoutTracker | TodaysWorkoutCardDelegate | TodaysWorkoutCard.swift, TodaysWorkoutSchedule.swift |  |
| **TrainingAccessory** | [Views/Training/TrainingAccessory](DialedIn/Components/Views/Training/TrainingAccessory) | 242 | WorkoutTracker | TrainingAccessoryDelegate |  |  |
| **WorkoutStreak** | [Views/Training/WorkoutStreakCard](DialedIn/Components/Views/Training/WorkoutStreakCard) | 275 |  | WorkoutStreakDelegate | WorkoutStreakCard.swift |  |
| **AuthorHeader** | [Views/User](DialedIn/Components/Views/User) | 272 | SocialProfile | AuthorHeaderDelegate | UserRowView.swift, UsernameLabel.swift |  |

### `DialedIn/Core/AdaptiveMain` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **AdaptiveMain** | [DialedIn/Core/AdaptiveMain](DialedIn/Core/AdaptiveMain) | 98 |  |  |  |  |

### `DialedIn/Core/Analytics` (25 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Analytics** | [DialedIn/Core/Analytics](DialedIn/Core/Analytics) | 1395 | BodyMetrics, CustomiseAnalytics, EnergyBalance, ExerciseAnalytics, ExerciseDetail, ExpenditureDetail, GoalProgress, Habits, InsightsAndAnalytics, MuscleGroupDetail, MuscleGroups, NutritionAnalytics, NutritionMetricDetail, Paywall, ProfileViewZoom, ScaleWeight, Steps, VisualBodyFat, WeeklyReview, WeighInConsistency, WeightTrend, Workout, WorkoutConsistency | AnalyticsDelegate | AnalyticsPresenter+DataLoading.swift, MuscleGroupCardItem.swift | AnalyticsPresenterTests.swift |
| **BodyMetrics** | [Subviews/BodyMetrics](DialedIn/Core/Analytics/Subviews/BodyMetrics) | 550 | BodyMeasurementDetail, BodyRatio, LogMeasurement, ProgressPhotos, ScaleWeight, VisualBodyFat | BodyMetricsDelegate, `showBodyMetricsView` | BodyMetricCardView.swift, BodyMetricsModels.swift |  |
| **LogMeasurement** | [Subviews/BodyMetrics/LogMeasurement](DialedIn/Core/Analytics/Subviews/BodyMetrics/LogMeasurement) | 364 | Alert | `showLogMeasurementView` | BodyMeasurementKind.swift |  |
| **LogWeight** | [Subviews/BodyMetrics/LogMeasurement/LogWeightView](DialedIn/Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView) | 303 |  | `showLogWeightView` | WeightPickerInput.swift |  |
| **ProgressPhotos** | [Subviews/BodyMetrics/ProgressPhotos](DialedIn/Core/Analytics/Subviews/BodyMetrics/ProgressPhotos) | 586 | ProgressPhotoCompare | ProgressPhotoCompareDelegate, `showProgressPhotoCompareView`, `showProgressPhotosView` | ProgressPhotoCameraPicker.swift, ProgressPhotoCompareView.swift | ProgressPhotosPresenterTests.swift |
| **ScaleWeight** | [Subviews/BodyMetrics/ScaleWeight](DialedIn/Core/Analytics/Subviews/BodyMetrics/ScaleWeight) | 209 | LogWeight | ScaleWeightDelegate, `showScaleWeightView` |  |  |
| **ExerciseAnalytics** | [Subviews/ExerciseAnalytics](DialedIn/Core/Analytics/Subviews/ExerciseAnalytics) | 318 | ExerciseDetail | ExerciseAnalyticsDelegate, `showExerciseAnalyticsView` | ExerciseCardItem.swift, ExerciseOneRMAggregator.swift |  |
| **ExerciseDetail** | [Subviews/ExerciseAnalytics/ExerciseDetail](DialedIn/Core/Analytics/Subviews/ExerciseAnalytics/ExerciseDetail) | 266 | Workouts | ExerciseDetailDelegate, `showExerciseDetailView` | ExerciseDetailEntry.swift |  |
| **FoodLoggingConsistency** | [Subviews/FoodLoggingConsistency](DialedIn/Core/Analytics/Subviews/FoodLoggingConsistency) | 146 |  | FoodLoggingConsistencyDelegate, `showFoodLoggingConsistencyView` |  |  |
| **Habits** | [Subviews/Habits](DialedIn/Core/Analytics/Subviews/Habits) | 421 | FoodLoggingConsistency, NutritionMetricDetail, ScaleWeight, WeighInConsistency, Workout, WorkoutConsistency | HabitsDelegate, `showHabitsView` |  | HabitsPresenterTests.swift |
| **InsightsAndAnalytics** | [Subviews/InsightsAndAnalytics](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics) | 502 | EnergyBalance, ExpenditureDetail, GoalProgress, WeightTrend, Workout | InsightsAndAnalyticsDelegate, `showInsightsAndAnalyticsView` |  |  |
| **EnergyBalance** | [Subviews/InsightsAndAnalytics/EnergyBalance](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/EnergyBalance) | 308 | AddMeal | EnergyBalanceDelegate, `showEnergyBalanceView` | EnergyBalanceEntry.swift | EnergyBalancePresenterTests.swift |
| **ExpenditureDetail** | [Subviews/InsightsAndAnalytics/ExpenditureDetail](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/ExpenditureDetail) | 238 | Account | ExpenditureDetailDelegate, `showExpenditureDetailView` | ExpenditureDetailEntry.swift |  |
| **GoalProgress** | [Subviews/InsightsAndAnalytics/GoalProgress](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/GoalProgress) | 291 |  | GoalProgressDelegate, `showGoalProgressView` | GoalProgressEntry.swift |  |
| **MuscleGroupDetail** | [Subviews/InsightsAndAnalytics/MuscleGroupDetail](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/MuscleGroupDetail) | 249 | Workouts | MuscleGroupDetailDelegate, `showMuscleGroupDetailView` | MuscleGroupDetailEntry.swift | MuscleGroupDetailPresenterTests.swift |
| **Steps** | [Subviews/InsightsAndAnalytics/Steps](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/Steps) | 247 |  | StepsDelegate, `showStepsView` | StepsEntry.swift |  |
| **WeightTrend** | [Subviews/InsightsAndAnalytics/WeightTrend](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/WeightTrend) | 251 |  | WeightTrendDelegate, `showWeightTrendView` | WeightTrendEntry.swift | WeightTrendPresenterTests.swift |
| **Workout** | [Subviews/InsightsAndAnalytics/Workouts](DialedIn/Core/Analytics/Subviews/InsightsAndAnalytics/Workouts) | 239 | Workouts | WorkoutDelegate, `showWorkoutView` | WorkoutEntry.swift | WorkoutPresenterTests.swift |
| **MuscleBalance** | [Subviews/MuscleBalance](DialedIn/Core/Analytics/Subviews/MuscleBalance) | 271 |  | `showMuscleBalanceView` |  |  |
| **MuscleGroups** | [Subviews/MuscleGroups](DialedIn/Core/Analytics/Subviews/MuscleGroups) | 300 | MuscleBalance, MuscleGroupDetail | MuscleGroupsDelegate, `showMuscleGroupsView` | MuscleGroupSetsAggregator.swift |  |
| **NutritionAnalytics** | [Subviews/NutritionAnalytics](DialedIn/Core/Analytics/Subviews/NutritionAnalytics) | 523 | AddMeal, NutritionMetricDetail | NutritionAnalyticsDelegate, `showNutritionAnalyticsView` |  |  |
| **NutritionMetricDetail** | [Subviews/NutritionAnalytics/NutritionMetricDetail](DialedIn/Core/Analytics/Subviews/NutritionAnalytics/NutritionMetricDetail) | 570 |  | NutritionMetricDetailDelegate, `showNutritionMetricDetailView` | NutritionMetric.swift, NutritionMetricEntry.swift |  |
| **NutritionTargetChart** | [Subviews/NutritionTargetChart](DialedIn/Core/Analytics/Subviews/NutritionTargetChart) | 293 | PreferredDiet |  |  |  |
| **WeighInConsistency** | [Subviews/WeighInConsistency](DialedIn/Core/Analytics/Subviews/WeighInConsistency) | 162 |  | WeighInConsistencyDelegate, `showWeighInConsistencyView` |  |  |
| **WorkoutConsistency** | [Subviews/WorkoutConsistency](DialedIn/Core/Analytics/Subviews/WorkoutConsistency) | 163 |  | WorkoutConsistencyDelegate, `showWorkoutConsistencyView` |  |  |

### `DialedIn/Core/AppView` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **App** | [DialedIn/Core/AppView](DialedIn/Core/AppView) | 646 |  | `showAppToast` | ActivityNotificationBannerView.swift, AppToast.swift, AppToastView.swift, AppViewBuilder.swift | AppShellPresenterTests.swift |

### `DialedIn/Core/Challenges` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ChallengeDetail** | [ChallengeDetail](DialedIn/Core/Challenges/ChallengeDetail) | 304 | SocialProfile | ChallengeDetailDelegate, `showChallengeDetailView` |  |  |
| **CreateChallenge** | [CreateChallenge](DialedIn/Core/Challenges/CreateChallenge) | 275 |  | `showCreateChallengeView` |  |  |

### `DialedIn/Core/Dashboard` (7 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Dashboard** | [DialedIn/Core/Dashboard](DialedIn/Core/Dashboard) | 1333 | AddMeal, ChallengeDetail, CreateChallenge, EditUsername, Notifications, Nutrition, ProfileViewZoom, SocialProfile, WeeklyGoal, WeeklyReview, WorkoutSessionDetail, WorkoutSessionThread | DashboardDelegate, `showDashboardView` | CircleActivityStripView.swift, InviteFriendCard.swift, UsernameBannerView.swift | DashboardPresenterTests.swift |
| **WeeklyGoal** | [CircleGoals/WeeklyGoal](DialedIn/Core/Dashboard/CircleGoals/WeeklyGoal) | 152 |  | `showWeeklyGoalView` |  |  |
| **SocialProfile** | [SocialProfile](DialedIn/Core/Dashboard/SocialProfile) | 651 | FollowersList, WeeklyGoal | SocialProfileDelegate, `showSocialProfileView` |  | SocialProfilePresenterTests.swift |
| **FollowersList** | [SocialProfile/FollowersList](DialedIn/Core/Dashboard/SocialProfile/FollowersList) | 192 | SocialProfile | FollowersListDelegate, `showFollowersList`, `showsFollowButton` |  |  |
| **WeeklyReview** | [WeeklyReview](DialedIn/Core/Dashboard/WeeklyReview) | 591 |  | `showWeeklyReviewView` | WeeklyReview.swift, WeeklyReviewCard.swift, WeeklyReviewShareCardView.swift |  |
| **WorkoutSessionRow** | [WorkoutSessionRow](DialedIn/Core/Dashboard/WorkoutSessionRow) | 802 | Comments, ShareToFollower, SocialProfile, WorkoutSessionDetail, WorkoutTemplateDetail | WorkoutSessionRowDelegate | WorkoutSessionHighlights.swift, WorkoutSessionTemplateBuilder.swift |  |
| **Comments** | [WorkoutSessionRow/Comments](DialedIn/Core/Dashboard/WorkoutSessionRow/Comments) | 649 |  | CommentsDelegate |  |  |

### `DialedIn/Core/DevSettings` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **DevSettings** | [DialedIn/Core/DevSettings](DialedIn/Core/DevSettings) | 815 |  | `showDevSettingsView` |  |  |

### `DialedIn/Core/Notifications` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Notifications** | [DialedIn/Core/Notifications](DialedIn/Core/Notifications) | 894 | ChallengeDetail, SharedItem, SocialProfile, WorkoutSessionDetail, WorkoutSessionThread | `showNotificationsView`, `showsFollowBack` | NotificationGrouping.swift |  |

### `DialedIn/Core/Nutrition` (29 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Nutrition** | [DialedIn/Core/Nutrition](DialedIn/Core/Nutrition) | 672 | AddMeal, FoodLogSettings, MealDetail, MealItemAmountView, NutritionOverview, ProfileViewZoom, TimelineActions | NutritionDelegate, `showNutritionView` |  | NutritionPresenterTests.swift |
| **CheckIn** | [CheckIn](DialedIn/Core/Nutrition/CheckIn) | 806 |  | CheckInDelegate, `showCheckInView` | CheckInPresenter+Events.swift, CheckInStep.swift | CheckInPresenterTests.swift |
| **Foods** | [Foods](DialedIn/Core/Nutrition/Foods) | 104 | FoodDetail, SimpleAlert | `showFoodsView` |  |  |
| **CreateFood** | [Foods/CreateFood](DialedIn/Core/Nutrition/Foods/CreateFood) | 465 | BarcodeScanner, FoodPackaging, PortionDefinition | CreateFoodDelegate, `showCreateFoodView` |  | CreateFoodFlowPresenterTests.swift |
| **FoodDefinition** | [Foods/CreateFood/FoodDefinition](DialedIn/Core/Nutrition/Foods/CreateFood/FoodDefinition) | 825 |  | FoodDefinitionDelegate, `showFoodDefinitionView` |  | FoodDefinitionPresenterTests.swift |
| **FoodPackaging** | [Foods/CreateFood/FoodPackaging](DialedIn/Core/Nutrition/Foods/CreateFood/FoodPackaging) | 255 | PortionDefinition | FoodPackagingDelegate, `showFoodPackagingView` |  |  |
| **PortionDefinition** | [Foods/CreateFood/PortionDefinition](DialedIn/Core/Nutrition/Foods/CreateFood/PortionDefinition) | 394 | FoodDefinition | PortionDefinitionDelegate, `showPortionDefinitionView` |  |  |
| **FoodDetail** | [Foods/FoodDetail](DialedIn/Core/Nutrition/Foods/FoodDetail) | 419 |  | FoodDetailDelegate, `showDeleteConfirmation`, `showFoodDetailView` |  |  |
| **AddMeal** | [MealLog/AddMeal](DialedIn/Core/Nutrition/MealLog/AddMeal) | 659 | MealItemAmountView, NutritionLibraryPicker | AddMealDelegate, `showAddMealView` |  | AddMealPresenterTests.swift |
| **IngredientAmount** | [MealLog/IngredientAmount](DialedIn/Core/Nutrition/MealLog/IngredientAmount) | 207 |  | IngredientAmountDelegate, `showIngredientAmountView` |  |  |
| **MealDetail** | [MealLog/MealDetail](DialedIn/Core/Nutrition/MealLog/MealDetail) | 294 |  | MealDetailDelegate, `showMealDetailView` |  |  |
| **MealItemAmountView** | [MealLog/MealItemAmountView](DialedIn/Core/Nutrition/MealLog/MealItemAmountView) | 321 |  | MealItemAmountViewDelegate, `showMealItemAmountViewView` |  |  |
| **NutritionLibraryPicker** | [MealLog/NutritionLibraryPicker](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker) | 276 | IngredientAmount, RecipeAmount | NutritionLibraryPickerDelegate, `showNutritionLibraryPickerView` |  |  |
| **BarcodeScanner** | [MealLog/NutritionLibraryPicker/BarcodeScanner](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/BarcodeScanner) | 805 |  | BarcodeScannerDelegate, `showBarcodeScannerView` |  | BarcodeScannerPresenterTests.swift |
| **FoodItemQuickAdd** | [MealLog/NutritionLibraryPicker/FoodItemQuickAdd](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemQuickAdd) | 418 |  | FoodItemQuickAddDelegate |  | FoodItemQuickAddPresenterTests.swift |
| **FoodItemSearch** | [MealLog/NutritionLibraryPicker/FoodItemSearch](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodItemSearch) | 279 |  | FoodItemSearchDelegate, `showFoodItemSearchView` |  |  |
| **FoodLibrary** | [MealLog/NutritionLibraryPicker/FoodLibrary](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodLibrary) | 344 | IngredientAmount, RecipeDetail | FoodLibraryDelegate, `showFoodLibraryView` |  | FoodLibraryPresenterTests.swift |
| **FoodPhotoScanner** | [MealLog/NutritionLibraryPicker/FoodPhotoScanner](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/FoodPhotoScanner) | 389 |  | FoodPhotoScannerDelegate |  |  |
| **MealDescribe** | [MealLog/NutritionLibraryPicker/MealDescribe](DialedIn/Core/Nutrition/MealLog/NutritionLibraryPicker/MealDescribe) | 290 |  | MealDescribeDelegate, `showMealDescribeView` |  |  |
| **RecipeAmount** | [MealLog/RecipeAmount](DialedIn/Core/Nutrition/MealLog/RecipeAmount) | 208 |  | RecipeAmountDelegate, `showRecipeAmountView` |  |  |
| **NutritionOverview** | [NutritionOverview](DialedIn/Core/Nutrition/NutritionOverview) | 640 | CheckIn | NutritionOverviewDelegate, `showNutritionOverviewView` |  | NutritionOverviewPresenterTests.swift |
| **Recipes** | [Recipes](DialedIn/Core/Nutrition/Recipes) | 148 | CreateRecipe, RecipeDetail, SimpleAlert | `showRecipesView` |  |  |
| **AddFood** | [Recipes/AddFood](DialedIn/Core/Nutrition/Recipes/AddFood) | 169 |  | AddFoodDelegate, `showAddIngredientView` | AddFoodDelegate.swift |  |
| **CreateRecipe** | [Recipes/CreateRecipe](DialedIn/Core/Nutrition/Recipes/CreateRecipe) | 302 | IngredientListBuilder, RecipePreparation | `showCreateRecipeView` |  |  |
| **RecipeIngredientAmount** | [Recipes/CreateRecipe/RecipeIngredientAmount](DialedIn/Core/Nutrition/Recipes/CreateRecipe/RecipeIngredientAmount) | 140 |  | RecipeIngredientAmountDelegate, `showRecipeIngredientAmountView` |  |  |
| **RecipePreparation** | [Recipes/CreateRecipe/RecipePreparation](DialedIn/Core/Nutrition/Recipes/CreateRecipe/RecipePreparation) | 378 |  | RecipePreparationDelegate, `showRecipePreparationView` |  | RecipePreparationPresenterTests.swift |
| **RecipeDetail** | [Recipes/RecipeDetail](DialedIn/Core/Nutrition/Recipes/RecipeDetail) | 340 | StartRecipe | RecipeDetailDelegate, `showDeleteConfirmation`, `showRecipeDetailView` | RecipeDetailDelegate.swift |  |
| **RecipeStart** | [Recipes/RecipeStart](DialedIn/Core/Nutrition/Recipes/RecipeStart) | 122 |  | RecipeStartDelegate, `showStartRecipeView` | RecipeStartDelegate.swift |  |
| **TimelineActions** | [TimelineActions](DialedIn/Core/Nutrition/TimelineActions) | 343 |  | TimelineActionsDelegate, `showTimelineActionsView` |  | TimelineActionsPresenterTests.swift |

### `DialedIn/Core/Onboarding` (30 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Welcome** | [0 - WelcomeView](DialedIn/Core/Onboarding/0%20-%20WelcomeView) | 287 | Auth, Intro, Paywall, Subscription | WelcomeDelegate |  |  |
| **Intro** | [1 - IntroView](DialedIn/Core/Onboarding/1%20-%20IntroView) | 252 | Auth | `showIntroView` |  |  |
| **Auth** | [2 - AuthView](DialedIn/Core/Onboarding/2%20-%20AuthView) | 451 | Paywall, Subscription | `showAuthView` |  |  |
| **Subscription** | [3 - Subscription](DialedIn/Core/Onboarding/3%20-%20Subscription) | 212 | CompleteAccountSetup, Paywall | `showSubscriptionView` |  |  |
| **CompleteAccountSetup** | [4 - CompleteAccountSetup](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup) | 164 | NamePhoto | `showCompleteAccountSetupView` |  |  |
| **NamePhoto** | [4 - CompleteAccountSetup/1 - NamePhoto](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/1%20-%20NamePhoto) | 351 | Gender | `showNamePhotoView` |  |  |
| **NotificationsPermissions** | [4 - CompleteAccountSetup/10 - NotificationsPermissions](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/10%20-%20NotificationsPermissions) | 339 | HealthDisclaimer, NotificationsPermissionsModal, OnboardingHealthData | `showNotificationsPermissionsModal`, `showNotificationsPermissionsView` |  |  |
| **HealthData** | [4 - CompleteAccountSetup/11 - HealthData](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/11%20-%20HealthData) | 275 | HealthDisclaimer | `showOnboardingHealthDataView` |  |  |
| **Gender** | [4 - CompleteAccountSetup/2 - Gender](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/2%20-%20Gender) | 216 | DateOfBirth | `showGenderView` |  |  |
| **DateOfBirth** | [4 - CompleteAccountSetup/3 - DateOfBirth](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/3%20-%20DateOfBirth) | 190 | Height | DateOfBirthDelegate, `showDateOfBirthView` |  |  |
| **Height** | [4 - CompleteAccountSetup/4 - Height](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/4%20-%20Height) | 322 | Weight | HeightDelegate, `showHeightView` |  |  |
| **Weight** | [4 - CompleteAccountSetup/5 - Weight](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/5%20-%20Weight) | 299 | ExerciseFrequency | WeightDelegate, `showWeightView` |  | WeightTrendPresenterTests.swift |
| **ExerciseFrequency** | [4 - CompleteAccountSetup/6 - ExerciseFrequency](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/6%20-%20ExerciseFrequency) | 249 | Activity | ExerciseFrequencyDelegate, `showExerciseFrequencyView` |  |  |
| **Activity** | [4 - CompleteAccountSetup/7 - Activity](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/7%20-%20Activity) | 269 | CardioFitness | ActivityDelegate, `showActivityView` |  |  |
| **CardioFitness** | [4 - CompleteAccountSetup/8 - CardioFitness](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/8%20-%20CardioFitness) | 274 | Expenditure | CardioFitnessDelegate, `showCardioFitnessView` |  |  |
| **Expenditure** | [4 - CompleteAccountSetup/9 - Expenditure](DialedIn/Core/Onboarding/4%20-%20CompleteAccountSetup/9%20-%20Expenditure) | 618 | HealthDisclaimer, NotificationsPermissions, OnboardingHealthData | ExpenditureDelegate, `showExpenditureView` |  |  |
| **HealthDisclaimer** | [5 - HealthDisclaimer](DialedIn/Core/Onboarding/5%20-%20HealthDisclaimer) | 301 | GoalSetting, HealthDisclaimerConfirmationModal | `showHealthDisclaimerConfirmationModal`, `showHealthDisclaimerView` |  |  |
| **GoalSetting** | [6 - GoalSetting](DialedIn/Core/Onboarding/6%20-%20GoalSetting) | 169 | OverarchingObjective | `showGoalSettingView` |  |  |
| **OverarchingObjective** | [6 - GoalSetting/1 - OverarchingObjective](DialedIn/Core/Onboarding/6%20-%20GoalSetting/1%20-%20OverarchingObjective) | 243 | GoalSummary, TargetWeight | `showOverarchingObjectiveView` |  |  |
| **TargetWeight** | [6 - GoalSetting/2 - TargetWeight](DialedIn/Core/Onboarding/6%20-%20GoalSetting/2%20-%20TargetWeight) | 371 | WeightRate | TargetWeightDelegate, `showTargetWeightView` |  |  |
| **WeightRate** | [6 - GoalSetting/3 - WeightRate](DialedIn/Core/Onboarding/6%20-%20GoalSetting/3%20-%20WeightRate) | 404 | GoalSummary | WeightRateDelegate, `showWeightRateView` |  |  |
| **GoalSummary** | [6 - GoalSetting/4 - GoalSummary](DialedIn/Core/Onboarding/6%20-%20GoalSetting/4%20-%20GoalSummary) | 524 |  | GoalSummaryDelegate, `showGoalSummaryView` |  |  |
| **CustomisingDietProgram** | [8 - OnboardingDiet](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet) | 169 | PreferredDiet | `showCustomisingDietProgramView` |  |  |
| **PreferredDiet** | [8 - OnboardingDiet/1 - PreferredDiet](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/1%20-%20PreferredDiet) | 236 | CalorieFloor | `showPreferredDietView` |  |  |
| **CalorieFloor** | [8 - OnboardingDiet/2 - CalorieFloor](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/2%20-%20CalorieFloor) | 253 | CalorieDistribution | CalorieFloorDelegate, `showCalorieFloorView` |  |  |
| **CalorieDistribution** | [8 - OnboardingDiet/4 - CalorieDistribution](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/4%20-%20CalorieDistribution) | 280 | ProteinIntake | CalorieDistributionDelegate, `showCalorieDistributionView` |  |  |
| **ProteinIntake** | [8 - OnboardingDiet/5 - ProteinIntake](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/5%20-%20ProteinIntake) | 249 | DietPlan | ProteinIntakeDelegate, `showProteinIntakeView` |  |  |
| **DietPlan** | [8 - OnboardingDiet/6 - DietPlan](DialedIn/Core/Onboarding/8%20-%20OnboardingDiet/6%20-%20DietPlan) | 320 | StravaConnect | DietPlanDelegate, `showDietPlanView` |  |  |
| **OnboardingCompleted** | [9 - OnboardingCompleted](DialedIn/Core/Onboarding/9%20-%20OnboardingCompleted) | 217 |  | `showOnboardingCompletedView` |  |  |
| **StravaConnect** | [9 - StravaConnect](DialedIn/Core/Onboarding/9%20-%20StravaConnect) | 209 | OnboardingCompleted | `showStravaConnectView` |  |  |

### `DialedIn/Core/Paywalls` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Paywall** | [Paywall](DialedIn/Core/Paywalls/Paywall) | 410 |  | `showPaywall` |  | PaywallPresenterTests.swift |

### `DialedIn/Core/Profile` (50 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Profile** | [DialedIn/Core/Profile](DialedIn/Core/Profile) | 643 | About, Account, AppIcon, CustomiseAnalytics, Exercises, ExpenditureSettings, FoodLogSettings, GymProfiles, Integrations, Legal, Notifications, Paywall, PreferredDiet, RatingsModal, Shortcuts, Siri, StrategySettings, Tutorials, Units, WorkoutSettings | `showProfileView`, `showProfileViewZoom` |  | ProfilePresenterTests.swift |
| **About** | [Subviews/About](DialedIn/Core/Profile/Subviews/About) | 171 | Licences | AboutDelegate, `showAboutView` |  |  |
| **Licences** | [Subviews/About/Licences](DialedIn/Core/Profile/Subviews/About/Licences) | 265 |  | LicencesDelegate, `showLicencesView` | Licence.swift |  |
| **Account** | [Subviews/Account](DialedIn/Core/Profile/Subviews/Account) | 594 | Auth, EditUsername | AccountDelegate, `showAccountView` |  |  |
| **EditUsername** | [Subviews/Account/EditUsername](DialedIn/Core/Profile/Subviews/Account/EditUsername) | 254 |  | `showEditUsernameView` |  |  |
| **AppIcon** | [Subviews/AppIcon](DialedIn/Core/Profile/Subviews/AppIcon) | 126 |  | AppIconDelegate, `showAppIconView` |  |  |
| **CustomiseAnalytics** | [Subviews/GeneralSettings/CustomiseAnalytics](DialedIn/Core/Profile/Subviews/GeneralSettings/CustomiseAnalytics) | 222 |  | CustomiseAnalyticsDelegate, `showCustomiseAnalyticsView` |  |  |
| **Integrations** | [Subviews/GeneralSettings/Integrations](DialedIn/Core/Profile/Subviews/GeneralSettings/Integrations) | 219 | SimpleAlert | IntegrationsDelegate, `showIntegrationsView` |  |  |
| **Shortcuts** | [Subviews/GeneralSettings/Shortcuts](DialedIn/Core/Profile/Subviews/GeneralSettings/Shortcuts) | 261 |  | ShortcutsDelegate, `showShortcutsView` |  |  |
| **Siri** | [Subviews/GeneralSettings/Siri](DialedIn/Core/Profile/Subviews/GeneralSettings/Siri) | 126 |  | SiriDelegate, `showSiriView` |  |  |
| **Units** | [Subviews/GeneralSettings/Units](DialedIn/Core/Profile/Subviews/GeneralSettings/Units) | 234 |  | UnitsDelegate, `showUnitsView` |  |  |
| **Legal** | [Subviews/Legal](DialedIn/Core/Profile/Subviews/Legal) | 163 |  | LegalDelegate, `showLegalView` |  |  |
| **ExpenditureSettings** | [Subviews/NutritionSettings/ExpenditureSettings](DialedIn/Core/Profile/Subviews/NutritionSettings/ExpenditureSettings) | 419 |  | ExpenditureSettingsDelegate, `showExpenditureSettingsView` |  |  |
| **FoodLogSettings** | [Subviews/NutritionSettings/FoodLogSettings](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings) | 527 | FavouriteMeasurements, LoggerBanner, LoggerFoodTiles, Optimisation, TimeSelection, TimelineFoodTiles | FoodLogSettingsDelegate, `showFavouriteMeasurementsView`, `showFoodLogSettingsView`, `showLoggerBannerView`, `showLoggerFoodTilesView`, `showOptimisationView`, `showTimeSelectionView`, `showTimelineFoodTilesView` |  |  |
| **FavouriteMeasurements** | [Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements) | 160 |  | FavouriteMeasurementsDelegate |  |  |
| **LoggerBanner** | [Subviews/NutritionSettings/FoodLogSettings/LoggerBanner](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerBanner) | 164 |  | LoggerBannerDelegate |  |  |
| **LoggerFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles) | 164 |  | LoggerFoodTilesDelegate |  |  |
| **Optimisation** | [Subviews/NutritionSettings/FoodLogSettings/Optimisation](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/Optimisation) | 134 |  | OptimisationDelegate |  |  |
| **TimeSelection** | [Subviews/NutritionSettings/FoodLogSettings/TimeSelection](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimeSelection) | 134 |  | TimeSelectionDelegate |  |  |
| **TimelineFoodTiles** | [Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles](DialedIn/Core/Profile/Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles) | 154 |  | TimelineFoodTilesDelegate |  |  |
| **StrategySettings** | [Subviews/NutritionSettings/StrategySettings](DialedIn/Core/Profile/Subviews/NutritionSettings/StrategySettings) | 295 |  | StrategySettingsDelegate, `showStrategySettingsView` |  |  |
| **ExerciseAssessment** | [Subviews/TrainingSettings/ExerciseAssessment](DialedIn/Core/Profile/Subviews/TrainingSettings/ExerciseAssessment) | 122 |  | ExerciseAssessmentDelegate, `showExerciseAssessmentView` |  |  |
| **Exercises** | [Subviews/TrainingSettings/Exercises](DialedIn/Core/Profile/Subviews/TrainingSettings/Exercises) | 109 | CreateExercise, ExerciseModelDetail | `showExercisesView` |  |  |
| **ExerciseTemplateDetail** | [Subviews/TrainingSettings/Exercises/ExerciseTemplateDetail](DialedIn/Core/Profile/Subviews/TrainingSettings/Exercises/ExerciseTemplateDetail) | 955 |  | ExerciseModelDetailDelegate, `showDeleteConfirmation`, `showExerciseModelDetailView` | ExerciseModelDetailStats.swift, ExerciseTemplateDetailDelegate.swift |  |
| **GymProfiles** | [Subviews/TrainingSettings/GymProfiles](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles) | 299 | GymProfile | `showGymProfilesView` |  | GymProfilesListPresenterTests.swift |
| **GymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile) | 1024 | EditBand, EditBodyWeight, EditCableMachine, EditFixedWeightBar, EditFreeWeight, EditLoadableAccessory, EditLoadableBar, EditPinLoadedMachine, EditPlateLoadedMachine | GymProfileDelegate, `showGymProfileView` |  | GymProfilePresenterTests.swift |
| **CreateGymProfile** | [Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile) | 181 | GymProfile | CreateGymProfileDelegate, `showCreateGymProfileView` |  |  |
| **EditBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand) | 258 | AddBand | `showEditBandView` |  |  |
| **AddBand** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand) | 267 |  | AddBandDelegate, `showAddBandView` |  |  |
| **EditBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight) | 256 | AddBodyWeight | `showEditBodyWeightView` |  |  |
| **AddBodyWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight) | 198 |  | AddBodyWeightDelegate, `showAddBodyWeightView` |  |  |
| **EditCableMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine) | 276 | AddCableMachineRange | `showEditCableMachineView` |  |  |
| **AddCableMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditCableMachine/AddCableMachineRange) | 272 |  | AddCableMachineRangeDelegate, `showAddCableMachineRangeView` |  |  |
| **EditFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar) | 250 | AddFixedWeightBar | `showEditFixedWeightBarView` |  |  |
| **AddFixedWeightBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar) | 197 |  | AddFixedWeightBarDelegate, `showAddFixedWeightBarView` |  |  |
| **EditFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight) | 256 | AddFreeWeight | `showEditFreeWeightView` |  |  |
| **AddFreeWeight** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight) | 249 |  | AddFreeWeightDelegate, `showAddFreeWeightView` |  |  |
| **EditLoadableAccessory** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory) | 168 |  | `showEditLoadableAccessoryView` |  |  |
| **EditLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar) | 249 | AddLoadableBar | `showEditLoadableBarView` |  |  |
| **AddLoadableBar** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar) | 198 |  | AddLoadableBarDelegate, `showAddLoadableBarView` |  |  |
| **EditPinLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine) | 274 | AddPinLoadedMachineRange | `showEditPinLoadedMachineView` |  |  |
| **AddPinLoadedMachineRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPinLoadedMachine/AddPinLoadedMachineRange) | 272 |  | AddPinLoadedMachineRangeDelegate, `showAddPinLoadedMachineRangeView` |  |  |
| **EditPlateLoadedMachine** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine) | 168 |  | `showEditPlateLoadedMachineView` |  |  |
| **EditWeightRange** | [Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange](DialedIn/Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange) | 243 |  | EditWeightRangeDelegate |  |  |
| **WorkoutSettings** | [Subviews/TrainingSettings/WorkoutSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings) | 356 | ExerciseAssessment, PreviousWorkoutReferenceSettings, RestTimerSettings, SmartProgressionSettings | WorkoutSettingsDelegate, `showWorkoutSettingsView` |  |  |
| **PreviousWorkoutReferenceSettings** | [Subviews/TrainingSettings/WorkoutSettings/PreviousWorkoutReferenceSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/PreviousWorkoutReferenceSettings) | 192 |  | PrevWORefSettingsDelegate, `showPreviousWorkoutReferenceSettingsView` |  |  |
| **RestTimerSettings** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings) | 404 | TimerDuration | RestTimerSettingsDelegate, `showRestTimerSettingsView` |  |  |
| **TimerDuration** | [Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration) | 446 |  | TimerDurationDelegate, `showTimerDurationView` |  | TimerDurationPresenterTests.swift |
| **SmartProgressionSettings** | [Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings](DialedIn/Core/Profile/Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings) | 232 |  | SmartProgressionSettingsDelegate, `showSmartProgressionSettingsView` |  |  |
| **Tutorials** | [Subviews/Tutorials](DialedIn/Core/Profile/Subviews/Tutorials) | 127 |  | TutorialsDelegate, `showTutorialsView` |  |  |

### `DialedIn/Core/Search` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Search** | [DialedIn/Core/Search](DialedIn/Core/Search) | 801 | AddMeal, BodyMetrics, CreateExercise, CreateFood, CreateRecipe, CreateWorkout, ExerciseDetail, ExerciseListBuilder, FoodDetail, LogWeight, ProfileViewZoom, RecipeDetail, Recipes, Shortcuts, SocialProfile, WorkoutTemplateDetail, WorkoutTracker |  |  | SearchPresenterTests.swift |

### `DialedIn/Core/Sharing` (2 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **ShareToFollower** | [ShareToFollower](DialedIn/Core/Sharing/ShareToFollower) | 237 |  | ShareToFollowerDelegate, `showShareToFollowerView` |  |  |
| **SharedItem** | [SharedItem](DialedIn/Core/Sharing/SharedItem) | 265 |  | SharedItemDelegate, `showSharedItemView` |  |  |

### `DialedIn/Core/SplitViewContainer` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **SplitViewContainer** | [DialedIn/Core/SplitViewContainer](DialedIn/Core/SplitViewContainer) | 165 |  |  | SplitViewContainer.swift, SplitViewRouter.swift |  |

### `DialedIn/Core/TabBar` (1 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **TabBar** | [DialedIn/Core/TabBar](DialedIn/Core/TabBar) | 514 | WorkoutTracker |  | DeepLink.swift |  |

### `DialedIn/Core/Training` (43 modules)

| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |
|---|---|---:|---|---|---|---|
| **Training** | [DialedIn/Core/Training](DialedIn/Core/Training) | 543 | AddTraining, CreateExercise, CreateProgram, CreateWorkout, EditTrainingProgram, ProfileViewZoom, TrainingProgramLibrary, WorkoutHistory, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker, Workouts | TrainingDelegate |  | TrainingHomePresenterTests.swift, TrainingLibraryPresenterTests.swift, TrainingSettingsPresenterTests.swift |
| **ActiveTrainingProgram** | [Subviews/ActiveTrainingProgram](DialedIn/Core/Training/Subviews/ActiveTrainingProgram) | 405 | EditTrainingProgram, WorkoutSessionDetail, WorkoutTemplateDetail, WorkoutTracker | ActiveTrainingProgramDelegate, `showActiveTrainingProgramView` |  | ActiveTrainingProgramPresenterTests.swift |
| **AddTraining** | [Subviews/AddTraining](DialedIn/Core/Training/Subviews/AddTraining) | 198 | CreateProgram, CreateWorkout | AddTrainingDelegate, `showAddTrainingView`, `showAddTrainingViewZoom` |  |  |
| **CreateExercise** | [Subviews/AddTraining/CreateExercise](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise) | 399 | MuscleGroupPicker | `showCreateExerciseView` |  | CreateExerciseEquipmentPresenterTests.swift, CreateExerciseFlowPresenterTests.swift |
| **EquipmentPicker** | [Subviews/AddTraining/CreateExercise/EquipmentPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/EquipmentPicker) | 258 |  | EquipmentPickerDelegate, `showEquipmentPickerView` |  |  |
| **ExerciseEquipment** | [Subviews/AddTraining/CreateExercise/ExerciseEquipment](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseEquipment) | 353 | EquipmentPicker, FinalExerciseDetails | ExerciseEquipmentDelegate, `showExerciseEquipmentView` |  |  |
| **ExerciseSave** | [Subviews/AddTraining/CreateExercise/ExerciseSave](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/ExerciseSave) | 441 |  | ExerciseSaveDelegate, `showExerciseSaveView` |  |  |
| **FinalExerciseDetails** | [Subviews/AddTraining/CreateExercise/FinalExerciseDetails](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/FinalExerciseDetails) | 307 | ExerciseSave | FinalExerciseDetailsDelegate, `showFinalExerciseDetailsView` |  |  |
| **MuscleGroupPicker** | [Subviews/AddTraining/CreateExercise/MuscleGroupPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateExercise/MuscleGroupPicker) | 271 | ExerciseEquipment | MuscleGroupPickerDelegate, `showMuscleGroupPickerView` |  |  |
| **CreateProgram** | [Subviews/AddTraining/CreateProgram/CreateProgram](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/CreateProgram) | 192 | NameProgram | CreateProgramDelegate, `showCreateProgramView`, `showOnboardingTrainingProgramView` |  | CreateProgramFlowPresenterTests.swift |
| **NameProgram** | [Subviews/AddTraining/CreateProgram/NameProgram](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/NameProgram) | 167 | ProgramIcon | NameProgramDelegate, `showNameProgramView` |  |  |
| **ProgramDesign** | [Subviews/AddTraining/CreateProgram/ProgramDesign](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign) | 645 | ProgramSettings, RenameWorkoutTemplateModel | EditTrainingProgramDelegate, ProgramDesignDelegate, `showEditTrainingProgramView`, `showProgramDesignView`, `showRenameWorkoutTemplateModelView` |  |  |
| **ProgramSettings** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings) | 384 | EditDayOrder, EditDeload, EditProgramColourIcon, RenameProgram | `showEditDayOrderView`, `showEditDeloadView`, `showEditProgramColourIconView`, `showProgramSettingsView`, `showRenameProgramView` |  | ProgramSettingsFlowPresenterTests.swift |
| **EditDayOrder** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDayOrder](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDayOrder) | 113 |  |  |  |  |
| **EditDeload** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDeload](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditDeload) | 120 |  |  |  |  |
| **EditProgramColourIcon** | [Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditProgramColourIcon](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramSettings/EditProgramColourIcon) | 156 |  |  |  |  |
| **RenameDayPlan** | [Subviews/AddTraining/CreateProgram/ProgramDesign/RenameDayPlan](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/RenameDayPlan) | 124 |  | RenameWorkoutTemplateModelDelegate |  |  |
| **ProgramIcon** | [Subviews/AddTraining/CreateProgram/ProgramIcon](DialedIn/Core/Training/Subviews/AddTraining/CreateProgram/ProgramIcon) | 249 | ProgramDesign | ProgramIconDelegate, `showProgramIconView` |  |  |
| **CreateWorkout** | [Subviews/AddTraining/CreateWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout) | 148 | NameWorkout | CreateWorkoutDelegate, `showCreateWorkoutView` |  | CreateWorkoutFlowPresenterTests.swift, CreateWorkoutWrapperPresenterTests.swift |
| **ChooseGymProfile** | [Subviews/AddTraining/CreateWorkout/ChooseGymProfile](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/ChooseGymProfile) | 196 | CreateGymProfile, DefineWorkoutWrapper | ChooseGymProfileDelegate, `showChooseGymProfileView` |  |  |
| **DefineWorkout** | [Subviews/AddTraining/CreateWorkout/DefineWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkout) | 355 | ExercisesPicker, SetTarget | DefineWorkoutDelegate, `showDefineWorkoutView` |  |  |
| **DefineWorkoutWrapper** | [Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/DefineWorkoutWrapper) | 202 |  | DefineWorkoutWrapperDelegate, `showDefineWorkoutWrapperView` |  |  |
| **ExercisesPicker** | [Subviews/AddTraining/CreateWorkout/ExercisesPicker](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/ExercisesPicker) | 153 |  | ExercisesPickerDelegate, `showExercisesPickerView` |  |  |
| **NameWorkout** | [Subviews/AddTraining/CreateWorkout/NameWorkout](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/NameWorkout) | 168 | ChooseGymProfile, DefineWorkoutWrapper | NameWorkoutDelegate, `showNameWorkoutView` |  |  |
| **SetTarget** | [Subviews/AddTraining/CreateWorkout/SetTarget](DialedIn/Core/Training/Subviews/AddTraining/CreateWorkout/SetTarget) | 264 |  | SetTargetDelegate, `showSetTargetView` |  |  |
| **ExerciseSettings** | [Subviews/ExerciseSettings](DialedIn/Core/Training/Subviews/ExerciseSettings) | 367 | ExerciseModelDetail, RestModal, RestTimerSettings, WorkoutNotes | ExerciseSettingsDelegate, `showExerciseSettingsView` |  |  |
| **ProgramManagement** | [Subviews/TrainingProgramLibrary](DialedIn/Core/Training/Subviews/TrainingProgramLibrary) | 336 | CreateProgram, EditTrainingProgram, PrebuiltProgramDetail, ProgramSettings | `showDeleteAlert`, `showTrainingProgramLibraryView` |  |  |
| **InactiveTrainingProgram** | [Subviews/TrainingProgramLibrary/InactiveTrainingProgram](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/InactiveTrainingProgram) | 154 |  | InactiveTrainingProgramDelegate, `showInactiveTrainingProgramView` |  |  |
| **PrebuiltProgramDetail** | [Subviews/TrainingProgramLibrary/PrebuiltProgramDetail](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/PrebuiltProgramDetail) | 220 |  | `showPrebuiltProgramDetailView` |  |  |
| **TrainingProgramDisclosureGroup** | [Subviews/TrainingProgramLibrary/TrainingProgramDisclosureGroup](DialedIn/Core/Training/Subviews/TrainingProgramLibrary/TrainingProgramDisclosureGroup) | 158 | EditTrainingProgram, ShareToFollower | TrainingProgramDisclosureGroupDelegate, `showTrainingProgramDisclosureGroupView` |  |  |
| **WorkoutHistory** | [Subviews/WorkoutHistory](DialedIn/Core/Training/Subviews/WorkoutHistory) | 356 | WorkoutSessionDetail | WorkoutHistoryDelegate, `showWorkoutHistoryView` |  |  |
| **WorkoutSessionDetail** | [Subviews/WorkoutSessionDetailView](DialedIn/Core/Training/Subviews/WorkoutSessionDetailView) | 967 | ExercisesPicker | WorkoutSessionDetailDelegate, `showDiscardChangesAlert`, `showWorkoutSessionDetailView`, `showWorkoutSessionThread` |  | WorkoutSessionDetailPresenterTests.swift |
| **WorkoutTemplateDetail** | [Subviews/WorkoutTemplateDetail](DialedIn/Core/Training/Subviews/WorkoutTemplateDetail) | 487 | CreateWorkout, ExerciseModelDetail, ShareToFollower, WorkoutTracker | WorkoutTemplateDetailDelegate, `showDeleteConfirmation`, `showWorkoutTemplateDetailView` |  |  |
| **WorkoutTracker** | [Subviews/WorkoutTracker](DialedIn/Core/Training/Subviews/WorkoutTracker) | 1824 | ExercisesPicker, GymProfile, WorkoutNotes, WorkoutSettings | `showWorkoutTrackerView` | WorkoutTrackerPresenter+Events.swift, WorkoutTrackerPresenter+Exercises.swift, WorkoutTrackerPresenter+Finish.swift, WorkoutTrackerPresenter+Notes.swift, WorkoutTrackerPresenter+Progression.swift, WorkoutTrackerPresenter+Rest.swift, WorkoutTrackerPresenter+SetValidation.swift, WorkoutTrackerPresenter+Superset.swift | WorkoutTrackerPresenterProgressionTests.swift, WorkoutTrackerPresenterTests.swift |
| **ExerciseTracker** | [Subviews/WorkoutTracker/ExerciseTracker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker) | 256 | WorkoutNotes | ExerciseTrackerDelegate |  |  |
| **SetTracker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker) | 709 | ExerciseSettings, RestModal, SetTarget, SwapExercisePicker, WarmupSetInfoModal, WarmupSets, WorkoutExerciseEquipmentSheet | SetTrackerDelegate |  | SetTrackerPresenterTests.swift |
| **SetTrackerRow** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow) | 909 | RestModal, WarmupSetInfoModal | SetTrackerRowDelegate, `showSetTrackerRowView` |  |  |
| **SetKeyboard** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard) | 887 |  |  | PlateCalculator.swift, SetKeyboardTextField.swift, WeightStepper.swift | SetKeyboardPresenterTests.swift |
| **SwapExercisePicker** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SwapExercisePicker) | 118 |  | `showSwapExercisePickerView` |  |  |
| **WarmupSets** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WarmupSets) | 180 |  | WarmupSetsDelegate, `showWarmupSetsView` |  |  |
| **WorkoutExerciseEquipmentSheet** | [Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet](DialedIn/Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/WorkoutExerciseEquipmentSheet) | 336 |  | WorkoutExerciseEquipmentSheetDelegate, `showWorkoutExerciseEquipmentSheetView` |  |  |
| **WorkoutNotes** | [Subviews/WorkoutTracker/WorkoutNotes](DialedIn/Core/Training/Subviews/WorkoutTracker/WorkoutNotes) | 157 |  | WorkoutNotesDelegate, `showWorkoutNotesView` |  |  |
| **Workouts** | [Subviews/Workouts](DialedIn/Core/Training/Subviews/Workouts) | 135 | WorkoutTemplateDetail, WorkoutTracker | WorkoutsDelegate, `showWorkoutsView` |  |  |

## Managers

| Manager | Folder | Lines | Sync engines | Models (sibling folder) | Services | Extensions | Tests |
|---|---|---:|---|---|---|---|---|
| **ABTestManager** | [DialedIn/Managers/ABTests](DialedIn/Managers/ABTests/ABTestManager.swift) | 110 |  | ActiveABTests, PaywallTestOption | ABTestService, FirebaseABTestService, LocalABTestService, MockABTestService |  | ABTestManagerTests.swift |
| **AIManager** | [DialedIn/Managers/AI](DialedIn/Managers/AI/AIManager.swift) | 63 |  |  | AIService, GoogleAIService, MockAIService |  | AIManagerTests.swift |
| **AnalyticsSettingsManager** | [DialedIn/Managers/Analytics/AnalyticsSettings](DialedIn/Managers/Analytics/AnalyticsSettings/AnalyticsSettingsManager.swift) | 57 | Document<AnalyticsSettings> | AnalyticsSettings |  |  | AnalyticsSettingsManagerTests.swift |
| **BodyMeasurementsManager** | [DialedIn/Managers/BodyMeasurements](DialedIn/Managers/BodyMeasurements/BodyMeasurementsManager.swift) | 349 | Collection<BodyMeasurementEntry> | BodyMeasurementEntry, WeightSource |  |  | BodyMeasurementsManagerTests.swift |
| **GoalManager** | [DialedIn/Managers/Goal](DialedIn/Managers/Goal/GoalManager.swift) | 94 | Document<WeightGoal> | WeightGoal, WeightGoalBuilder |  |  | GoalManagerTests.swift |
| **HKWorkoutManager** | [DialedIn/Managers/HKWorkout](DialedIn/Managers/HKWorkout/HKWorkoutManager.swift) | 533 |  |  |  |  | HKWorkoutManagerRestTests.swift |
| **HealthKitManager** | [DialedIn/Managers/HealthKitManager](DialedIn/Managers/HealthKitManager/HealthKitManager.swift) | 72 |  |  |  |  | HealthKitManagerTests.swift |
| **ImageUploadManager** | [DialedIn/Managers/ImageUpload](DialedIn/Managers/ImageUpload/ImageUploadManager.swift) | 43 |  |  | FirebaseImageUploadService, ImageUploadService, MockImageUploadService |  | ImageUploadManagerTests.swift |
| **LiveActivityManager** | [DialedIn/Managers/LiveActivities](DialedIn/Managers/LiveActivities/LiveActivityManager.swift) | 472 |  |  |  | LiveActivityManager+Events.swift | LiveActivityManagerTests.swift |
| **ActivityNotificationManager** | [DialedIn/Managers/Notifications](DialedIn/Managers/Notifications/ActivityNotificationManager.swift) | 111 |  |  |  |  | ActivityNotificationManagerTests.swift |
| **FoodManager** | [DialedIn/Managers/Nutrition/Food](DialedIn/Managers/Nutrition/Food/FoodManager.swift) | 63 | Collection<FoodModel> | FoodModel, FoodModel+MealItem, ServingUnit |  |  | FoodManagerTests.swift |
| **FoodLogSettingsManager** | [DialedIn/Managers/Nutrition/FoodLogSettings](DialedIn/Managers/Nutrition/FoodLogSettings/FoodLogSettingsManager.swift) | 88 | Document<FoodLogSettings> | FoodLogSettings |  |  | FoodLogSettingsManagerTests.swift |
| **MealLogManager** | [DialedIn/Managers/Nutrition/MealLog](DialedIn/Managers/Nutrition/MealLog/MealLogManager.swift) | 340 | Collection<MealLogModel> | MealItemModel, MealItemSourceType, MealLogModel, MealLogModel+Mocks |  |  | MealLogManagerTests.swift |
| **NutritionManager** | [DialedIn/Managers/Nutrition/NutritionManager](DialedIn/Managers/Nutrition/NutritionManager/NutritionManager.swift) | 433 | Document<DietPlan> | DailyMacroTarget, DailyNutritionBreakdown, DietPlan |  |  | NutritionManagerDietPlanTests.swift, NutritionManagerTests.swift |
| **NutritionStrategyManager** | [DialedIn/Managers/Nutrition/NutritionStrategy](DialedIn/Managers/Nutrition/NutritionStrategy/NutritionStrategyManager.swift) | 188 | Collection<NutritionDayAnnotation>, Document<CheckInRecord>, Document<LoggingBreak> | CheckInRecord, LoggingBreak, NutritionDayAnnotation |  |  | NutritionStrategyManagerTests.swift |
| **NutritionStrategySettingsManager** | [DialedIn/Managers/Nutrition/NutritionStrategySettings](DialedIn/Managers/Nutrition/NutritionStrategySettings/NutritionStrategySettingsManager.swift) | 57 | Document<NutritionStrategySettings> | NutritionStrategySettings |  |  | NutritionStrategySettingsManagerTests.swift |
| **RecipeTemplateManager** | [DialedIn/Managers/Nutrition/RecipeTemplate](DialedIn/Managers/Nutrition/RecipeTemplate/RecipeTemplateManager.swift) | 63 | Collection<RecipeTemplateModel> | RecipeIngredientModel, RecipeTemplateModel |  |  | RecipeTemplateManagerTests.swift |
| **ProgressPhotoManager** | [DialedIn/Managers/ProgressPhotos](DialedIn/Managers/ProgressPhotos/ProgressPhotoManager.swift) | 97 | Collection<ProgressPhotoModel> |  |  |  |  |
| **PushManager** | [DialedIn/Managers/Push](DialedIn/Managers/Push/PushManager.swift) | 247 |  | PushNotificationDelegate |  |  | PushManagerTests.swift |
| **ReportManager** | [DialedIn/Managers/Reports](DialedIn/Managers/Reports/ReportManager.swift) | 95 |  |  |  |  | ReportManagerTests.swift |
| **NudgeHistoryManager** | [DialedIn/Managers/Search](DialedIn/Managers/Search/NudgeHistoryManager.swift) | 38 |  |  |  |  |  |
| **RecentSearchManager** | [DialedIn/Managers/Search](DialedIn/Managers/Search/RecentSearchManager.swift) | 41 |  |  |  |  | RecentSearchManagerTests.swift |
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
| [CoreBuilder.swift](DialedIn/Root/RIBs/Core/CoreBuilder.swift) | 71 |
| [CoreInteractor+AccountDeletion.swift](DialedIn/Root/RIBs/Core/CoreInteractor+AccountDeletion.swift) | 39 |
| [CoreInteractor+CircleGoals.swift](DialedIn/Root/RIBs/Core/CoreInteractor+CircleGoals.swift) | 15 |
| [CoreInteractor+PreviousWorkoutReference.swift](DialedIn/Root/RIBs/Core/CoreInteractor+PreviousWorkoutReference.swift) | 114 |
| [CoreInteractor+Progression.swift](DialedIn/Root/RIBs/Core/CoreInteractor+Progression.swift) | 105 |
| [CoreInteractor+ScheduledPush.swift](DialedIn/Root/RIBs/Core/CoreInteractor+ScheduledPush.swift) | 10 |
| [CoreInteractor+Username.swift](DialedIn/Root/RIBs/Core/CoreInteractor+Username.swift) | 17 |
| [CoreInteractor.swift](DialedIn/Root/RIBs/Core/CoreInteractor.swift) | 302 |
| [CoreRouter.swift](DialedIn/Root/RIBs/Core/CoreRouter.swift) | 47 |

## Cloud Functions (`functions/index.js`)

| Export | Kind | Line |
|---|---|---|
| `foodAnalyze` | onCall | [index.js:112](functions/index.js#L112) |
| `mealDescribe` | onCall | [index.js:158](functions/index.js#L158) |
| `nutritionLabelAnalyze` | onCall | [index.js:199](functions/index.js#L199) |
| `chatGenerate` | onCall | [index.js:230](functions/index.js#L230) |
| `imageGenerate` | onCall | [index.js:258](functions/index.js#L258) |
| `foodSearch` | onCall | [index.js:287](functions/index.js#L287) |
| `onActivityNotificationCreated` | onDocumentCreated | [index.js:405](functions/index.js#L405) |
| `onUserBlockListChanged` | onDocumentUpdated | [index.js:446](functions/index.js#L446) |
| `onFollowRequestUpdated` | onDocumentUpdated | [index.js:477](functions/index.js#L477) |
| `onFollowRequestCreated` | onDocumentCreated | [index.js:504](functions/index.js#L504) |
| `removeFollower` | onCall | [index.js:530](functions/index.js#L530) |
| `onUserFollowingChanged` | onDocumentUpdated | [index.js:550](functions/index.js#L550) |
| `onUserPrivacyChanged` | onDocumentUpdated | [index.js:572](functions/index.js#L572) |
| `onUsernameChanged` | onDocumentWritten | [index.js:604](functions/index.js#L604) |
| `streakReminder` | onSchedule | [index.js:657](functions/index.js#L657) |
| `weeklyDigest` | onSchedule | [index.js:673](functions/index.js#L673) |
| `onUserDeleted` | onDocumentDeleted | [index.js:708](functions/index.js#L708) |
| `onReportCreated` | onDocumentCreated | [index.js:781](functions/index.js#L781) |
| `onWorkoutSessionEndedForChallenges` | onDocumentWritten | [index.js:815](functions/index.js#L815) |
| `acceptInvite` | onCall | [index.js:859](functions/index.js#L859) |
| `sessionPage` | onRequest | [index.js:918](functions/index.js#L918) |

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

**`DialedInUnitTests/Components`** (4): `AutoSelectNumberFieldTextTests`, `CalendarHeaderPresenterTests`, `ListBuilderSelectionTests`, `MetricChartReadingsTests`

**`DialedInUnitTests/Core`** (125): `AIFoodInputPresenterTests`, `ActiveTrainingProgramPresenterTests`, `AddMealPresenterTests`, `AmountPresenterTests`, `AnalyticsBodyMetricsPresenterTests`, `AnalyticsConsistencyPresenterTests`, `AnalyticsExercisePresenterTests`, `AnalyticsInsightsPresenterTests`, `AnalyticsNutritionPresenterTests`, `AnalyticsPresenterTests`, `AppShellPresenterTests`, `BarcodeScannerPresenterTests`, `BodyMeasurementTests`, `ChallengesPresenterTests`, `CheckInPresenterTests`, `CircleGoalsPresenterTests`, `CircleWeekTests`, `CommentLikesTests`, `CommentMentionsTests`, `ContentDeletionPresenterTests`, `CreateExerciseEquipmentPresenterTests`, `CreateExerciseFlowPresenterTests`, `CreateFoodFlowPresenterTests`, `CreateProgramFlowPresenterTests`, `CreateWorkoutFlowPresenterTests`, `CreateWorkoutWrapperPresenterTests`, `DashboardCirclePresenterTests`, `DashboardPresenterTests`, `DashboardSocialPresenterTests`, `DevToolsPresenterTests`, `EnergyBalancePresenterTests`, `ExerciseModelDetailPresenterTests`, `FeedLoadingTests`, `FollowersListRemoveTests`, `FoodDefinitionPresenterTests`, `FoodItemQuickAddPresenterTests`, `FoodLibraryPresenterTests`, `FoodLogSettingsStaleSnapshotTests`, `GeneralSettingsPresenterTests`, `GymEquipmentAdderPresenterTests`, `GymEquipmentEditorPresenterTests`, `GymMachineEditorPresenterTests`, `GymProfilePresenterTests`, `GymProfilesListPresenterTests`, `HabitsPresenterTests`, `InviteTests`, `MacroHeaderRemainingTests`, `MealHourHeaderPresenterTests`, `MetricDetailPresenterTests`, `MuscleBalanceTests`, `MuscleGroupDetailPresenterTests`, `NotificationGroupingTests`, `NotificationTapThroughTests`, `NotificationsFollowRequestTests`, `NotificationsScheduledPushTests`, `NutritionOverviewPresenterTests`, `NutritionPresenterTests`, `NutritionSettingsPresenterTests`, `NutritionSettingsTilePresenterTests`, `OfflineDetectionTests`, `OnboardingAccountSetupPresenterTests`, `OnboardingAuthPresenterTests`, `OnboardingCompletedRetryTests`, `OnboardingDietChoicesPresenterTests`, `OnboardingDietPlanPresenterTests`, `OnboardingEntryPresenterTests`, `OnboardingExpenditurePresenterTests`, `OnboardingFinishPresenterTests`, `OnboardingGoalSettingPresenterTests`, `OnboardingGoalSummaryEstimateTests`, `OnboardingGoalSummaryPresenterTests`, `OnboardingHeightConversionTests`, `OnboardingLifestylePresenterTests`, `OnboardingPermissionsPresenterTests`, `OnboardingWeightRatePresenterTests`, `PaywallPresenterTests`, `PrevWORefSettingsPresenterTests`, `PreviousWorkoutReferenceResolverTests`, `ProfileAccountPresenterTests`, `ProfileAppInfoPresenterTests`, `ProfilePresenterTests`, `ProgramSettingsFlowPresenterTests`, `ProgramSharingTests`, `ProgressPhotosPresenterTests`, `RecipeFlowPresenterTests`, `RecipePreparationPresenterTests`, `RecipeScalingPresenterTests`, `ReportReasonsTests`, `ReviewPromptPolicyTests`, `SaveFailureAlertTests`, `SearchPresenterTests`, `SearchQuickActionTests`, `SessionWebLinkTests`, `SetKeyboardPresenterTests`, `SetSideTrackingTests`, `SetTrackerPresenterTests`, `SettingsSnapshotRefreshTests`, `ShareCardTests`, `SignOutListenersTests`, `SocialProfilePresenterTests`, `SocialSafetyTests`, `StreakVisibilityTests`, `TimelineActionsPresenterTests`, `TimerDurationPresenterTests`, `TrainingHomePresenterTests`, `TrainingLibraryPresenterTests`, `TrainingSettingsPresenterTests`, `WeeklyReviewTests`, `WeightStepperTests`, `WeightTrendPresenterTests`, `WorkoutNotesTests`, `WorkoutPresenterTests`, `WorkoutSessionAuthorTests`, `WorkoutSessionDeleteFailureTests`, `WorkoutSessionDetailPresenterTests`, `WorkoutSessionHighlightsTests`, `WorkoutSessionSaveAsTemplateTests`, `WorkoutSessionTemplateBuilderTests`, `WorkoutTrackerFinishTests`, `WorkoutTrackerPresenterProgressionTests`, `WorkoutTrackerPresenterTests`, `WorkoutTrackerRestFeedbackTests`, `WorkoutTrackerSupersetTests`, `WorkoutTrackingRowPresenterTests`, `WorkoutTrackingSheetPresenterTests`

**`DialedInUnitTests/Extensions`** (2): `CollectionAndStringExtensionTests`, `DateExtensionTests`

**`DialedInUnitTests/Managers`** (22): `ABTestManagerTests`, `AIManagerTests`, `ActivityNotificationManagerTests`, `AdjustLastSetRepsIntentTests`, `AppIntentsTests`, `AppStateTests`, `HKWorkoutManagerRestTests`, `HealthKitManagerTests`, `ImageUploadManagerTests`, `LiveActivityEventNameTests`, `LiveActivityIntentHandlerTests`, `LiveActivityPhaseTests`, `LiveActivityScenarioTests`, `LiveActivitySetTargetLabelTests`, `PremiumAccessTests`, `PushManagerTests`, `PushPendingDeepLinkTests`, `ReportManagerTests`, `RestDurationRulesTests`, `StepsManagerTests`, `StravaManagerTests`, `WorkoutLocationTypeDescriptionTests`

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

**`DialedInUnitTests/Services/Search`** (1): `RecentSearchManagerTests`

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

**`DialedInUITests`**: `CreateExerciseUITests`, `CreateProgramUITests`, `CreateWorkoutUITests`, `ScreenDeckSmokeTests+Screens`, `ScreenDeckSmokeTests`, `UITestApp`


## Scripts, docs, CI, backend files

| File | Lines |
|---|---:|
| [scripts/codebase-map.py](scripts/codebase-map.py) | 378 |
| [scripts/contact-sheet.py](scripts/contact-sheet.py) | 42 |
| [scripts/gen-smoke-tests.sh](scripts/gen-smoke-tests.sh) | 29 |
| [scripts/screenshots-diff.py](scripts/screenshots-diff.py) | 119 |
| [scripts/screenshots.sh](scripts/screenshots.sh) | 92 |
| [docs/AppPrivacy.md](docs/AppPrivacy.md) | 101 |
| [docs/dead-settings-audit.md](docs/dead-settings-audit.md) | 279 |
| [docs/reviews/live-activity-review.md](docs/reviews/live-activity-review.md) | 260 |
| [docs/specs/adaptive-expenditure.md](docs/specs/adaptive-expenditure.md) | 281 |
| [docs/specs/live-activity-work-packages.md](docs/specs/live-activity-work-packages.md) | 372 |
| [docs/specs/live-activity.md](docs/specs/live-activity.md) | 316 |
| [docs/specs/smart-progression.md](docs/specs/smart-progression.md) | 231 |
| [docs/specs/weekly-check-in.md](docs/specs/weekly-check-in.md) | 128 |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | 219 |
| [functions/functions.test.js](functions/functions.test.js) | 502 |
| [functions/index.js](functions/index.js) | 940 |
| [functions/index.test.js](functions/index.test.js) | 675 |
| [functions/lib.js](functions/lib.js) | 727 |
| [functions/rules.test.js](functions/rules.test.js) | 397 |
| [functions/scripts/migrateEquipmentVariations.js](functions/scripts/migrateEquipmentVariations.js) | 177 |
