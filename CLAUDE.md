# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Start with `docs/codebase-map.md`** before searching: it explains how to predict a file's path
from its name and lists every screen module, manager, sync model, Cloud Function, Firestore path
and test suite with a link. It is generated; after adding or moving files run
`python3 scripts/codebase-map.py` and commit the result.

## Build & Development

**Package manager**: Swift Package Manager only — there is no Podfile and no `.xcworkspace`. Open
`DialedIn.xcodeproj` directly; Xcode resolves packages on open.

**Schemes** (there is no scheme called plain `DialedIn`):

| Scheme | Configuration | Backend |
|---|---|---|
| `DialedIn - Development` | Debug | Firebase dev project |
| `DialedIn - Mock` | Mock | All mock services, no Firebase |
| `DialedIn - Production` | Release | Firebase prod project |

**Build from the command line**:
```bash
xcodebuild -project DialedIn.xcodeproj -scheme 'DialedIn - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Run tests**:
```bash
xcodebuild test -project DialedIn.xcodeproj -scheme 'DialedIn - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The tests compile and pass (3,542 tests in `DialedInUnitTests`). Treat a `TEST FAILED` as a
regression from your change unless it is only the UI-test flake described below.

`-only-testing` works, but only under the scheme's own name for the target. The productName is
`DialedInTests`, and `-only-testing:DialedInTests` is rejected; the BlueprintName is
`DialedInUnitTests`, so a single suite runs with:

```bash
xcodebuild test -project DialedIn.xcodeproj -scheme 'DialedIn - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DialedInUnitTests/OnboardingHeightConversionTests
```

**Run the full suite only when pushing.** Not between steps, and not to confirm something a
narrower run has already shown. Measured on this machine: the whole suite is about fifteen minutes
with the UI bundle and **2.7 minutes without it** (3,542 unit tests as of the UI framework merge), one suite through
`-only-testing` is about forty-five seconds, and the package's own `swift test` is under two.
Nearly all of the fifteen minutes is the UI runner and its simulator clones, so
`-skip-testing:DialedInUITests` is the single biggest saving available. Pick the narrowest run
that could actually fail:

| Change | Run |
|---|---|
| A `Swiftful*` package | `swift test` in that package's clone |
| One module | `-only-testing:` its suite |
| Docs only | nothing |
| Chasing a flake | one invocation with `-test-iterations N -run-tests-until-failure` |

Repeat runs belong in **one** invocation with `-test-iterations`, never N invocations — the build
and simulator boot dominate, so five separate calls cost five times the setup for the same tests.

Add `-skip-testing:DialedInUITests` to anything routine. It is three tests, one of them
chronically flaky, and it needs its own simulator clone; it is also what makes a run report
`** TEST FAILED **` when every unit test passed.

Read the counts from the result bundle:

```bash
xcrun xcresulttool get test-results summary \
  --path "$(ls -td ~/Library/Developer/Xcode/DerivedData/DialedIn-*/Logs/Test/*.xcresult | head -1)"
```

The UI-test runner is flaky in the simulator: it either fails to launch
(`FBSOpenApplicationServiceErrorDomain Code=1`) or drops the connection mid-test (`Failed to get
matching snapshot: Lost connection to the application`). This **does** fail the run — the whole
invocation prints `** TEST FAILED **` on the strength of one UI test — so `** TEST SUCCEEDED **`
is not a reliable signal on its own. Check the unit bundle's own result instead:

```bash
B="$(ls -td ~/Library/Developer/Xcode/DerivedData/DialedIn-*/Logs/Test/*.xcresult | head -1)"
xcrun xcresulttool get test-results tests --path "$B" | python3 -c '
import json,sys
d=json.load(sys.stdin)
def walk(n):
    for c in n:
        if c.get("nodeType") in ("Unit test bundle", "UI test bundle"):
            print(c["nodeType"], "|", c.get("name"), "|", c.get("result"))
        walk(c.get("children", []))
walk(d.get("testNodes", []))'
```

`Unit test bundle | DialedInUnitTests | Passed` is what matters. The summary's top-level
`failedTests` counts both bundles together, so it reads 1 on a clean unit run that hit the flake.

Managers take sync engines rather than a services struct, so tests build them through
**`DialedInUnitTests/Support/TestManagers.swift`**, which wires them the way `Dependencies` does
for `.mock` but with `enableLocalPersistence: false` — otherwise each engine opens SwiftData
storage under its `managerKey`, shared between tests and left behind after them.

A sync engine applies a write when its listener next emits, on its own task, so
`currentCollection` and `currentUser` are not up to date the instant `saveDocument` or `signIn`
returns. Assert through `TestManagers.eventually { … }` rather than reading straight after the
call or sleeping for a fixed time. For the same reason a manager holds nothing until it has
signed in, even when its mock remote is already populated.

`UserModel.mock` and the other model mocks are computed properties built from `Date()`, so two
reads of one are never equal — capture the value once and compare against that.

If a build fails with `build.db is locked`, Xcode is building the same DerivedData
concurrently — wait and retry rather than changing anything.

**Deployment target**: iOS 26.0 (26.1 for some targets). The project-level Swift language
version is 6.0; the test and extension targets are still on 5.0.

**Lint** (SwiftLint must be installed):
```bash
swiftlint
```

SwiftLint config (`.swiftlint.yml`): line limit 300, type body 500 lines, file length 750 lines, `trailing_whitespace` disabled.

### CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`, as one job on the
`macos-26` runner with Xcode pinned to `/Applications/Xcode_26.6.app`. In order, it:

1. Recreates the four gitignored config files from their checked-in examples — `Keys.swift`,
   `Info.plist`, and both `GoogleService-Info-{Dev,Prod}.plist` (all copied from
   `GoogleService-Info-Example.plist`). The examples are enough because only the Crashlytics
   run-script phase reads the plists and it exits early on simulator builds. The `Keys.swift`
   example defines all 30 constants the app references, so it compiles unchanged.
2. Runs `swiftlint --strict`, before the build so a style failure fails fast. `main` is at zero
   violations, so any warning fails the job. SwiftLint is **pinned** — see below.
3. Runs `xcodebuild test` for `DialedIn - Development` with `-skip-testing:DialedInUITests`,
   writing `TestResults.xcresult`, which is uploaded as an artifact only when the job fails.

The simulator destination is **discovered, not hardcoded**: a step picks the newest installed iOS
runtime and the first available iPhone on it, and fails if that runtime is below iOS 26. Do not
replace this with a fixed device name — the lineup differs between runner images, and older
runtimes that cannot run an iOS 26 deployment target are usually installed alongside the new one.

SwiftPM checkouts are cached, keyed on `Package.resolved`, at `~/SourcePackages` via
`-clonedSourcePackagesDirPath`. That path is **outside the repository on purpose**: the app's
`Run Script` build phase runs bare `swiftlint` from the project root on every build. Checking
dependencies out inside the working directory made that phase lint RevenueCat, promises,
mixpanel-swift and the rest, failing the build on their `force_cast`, `large_tuple` and
`identifier_name` violations. Locally the equivalent sources sit in DerivedData, well away from the
linted tree, which is why this only ever appeared on CI.

Belt and braces, `SourcePackages` is also in the `excluded:` list in `.swiftlint.yml` and in
`.gitignore` (along with `TestResults.xcresult/`), so resolving into the repo locally is safe too.
Keep both: the exclusion alone would still leave the checkouts inside the tree for every other tool.

Code signing is left **enabled** in the test step. A simulator build needs no provisioning profile
and signs ad-hoc, as it does locally. `CODE_SIGNING_ALLOWED=NO` looks like a harmless CI tidy-up but
skips entitlement processing, which costs the test host its keychain access and fails the eight
`StravaManagerTests` that read and write Strava tokens (`.notConnected`, and a
`KeychainHelper.read` returning nil).

`concurrency` cancels superseded runs per ref; `timeout-minutes: 60`.

**SwiftLint is pinned to a single `SWIFTLINT_VERSION` env var at the top of the workflow**
(currently `0.59.1`). CI downloads the official `portable_swiftlint.zip` for that exact version,
caches it keyed on the version, and fails the job if `swiftlint version` does not match before
linting. It does **not** use `brew install swiftlint`.

This pin exists because Homebrew tracks latest: the first CI run installed a newer SwiftLint whose
`legacy_swiftui_aspect_ratio` rule reported 12 violations under `--strict` that do not exist
locally. The pin must stay **in step with the version developers install locally** — if you upgrade
your local SwiftLint, bump `SWIFTLINT_VERSION` too, and the reverse holds: bumping the pin means
fixing whatever the new rules report, as its own change rather than folded into an unrelated PR. If
CI reports violations you cannot reproduce, compare `swiftlint version` first.

## First-Time Setup

Copy example files and fill in credentials. All three destinations are gitignored, and the app
will not build or sign in without them:

- `DialedIn/Utilities/Keys.swift.example` → `DialedIn/Utilities/Keys.swift` — 33 constants:
  OpenAI, Mixpanel, RevenueCat, the two Strava values, and 28 `*ManagerKey` strings used as
  local-persistence path names. The manager keys are arbitrary but must stay stable: changing
  one orphans data already persisted under the old name.
- `DialedIn/Info.plist.example` → `DialedIn/Info.plist` — already contains the real reversed
  client IDs for both Firebase projects and the `compound` deep-link scheme, so this is a
  straight copy. Google Sign-In fails at runtime without it.
- `DialedIn/SupportingFiles/GoogleServicePLists/GoogleService-Info-Example.plist` →
  `GoogleService-Info-Dev.plist` and `GoogleService-Info-Prod.plist` (same folder)

## Repository Layout

```
DialedIn/                    # the app target (Core, Components, Managers, Root, Extensions,
                             #   Utilities, SupportingFiles)
WorkoutSessionActivity/      # Live Activity / Dynamic Island widget extension
Shared/                      # code shared between the app and the widget extension
DialedInUnitTests/           # unit tests (target productName is DialedInTests)
DialedInUITests/             # UI tests
functions/                   # Firebase Cloud Functions (Node, Genkit/Vertex AI)
```

## Architecture

The app uses a **custom VIPER-like pattern** where `CoreInteractor` is a single global struct that exposes all managers, and each screen defines its own interactor protocol as an extension on `CoreInteractor`.

### The Four Components Per Screen

**1. Interactor (protocol + CoreInteractor extension)**
Defines the data/operations a screen needs. Never instantiated separately — the screen just receives a `CoreInteractor` typed as its specific protocol:
```swift
@MainActor
protocol BodyMetricsInteractor: GlobalInteractor {
    var measurementHistory: [BodyMeasurementEntry] { get }
    func readAllLocalWeightEntries() throws -> [BodyMeasurementEntry]
}

extension CoreInteractor: BodyMetricsInteractor { }
```

**2. Presenter (`@Observable @MainActor class`)**
Holds the interactor and router. Transforms data for the view. All user actions and lifecycle events are methods here:
```swift
@Observable
@MainActor
class BodyMetricsPresenter {
    private let interactor: BodyMetricsInteractor
    private let router: BodyMetricsRouter

    func onViewAppear() { interactor.trackScreenEvent(event: Event.onAppear) }
    func onSomethingPressed() { router.showSomeView(...) }
}
```
Events are defined as a nested `enum Event: LoggableEvent` on the presenter.

**3. View (SwiftUI View)**
Holds the presenter as `@State`. Calls presenter methods for all interactions:
```swift
struct BodyMetricsView: View {
    @State var presenter: BodyMetricsPresenter

    var body: some View {
        // reads presenter properties, calls presenter methods on actions
    }
}
```

**4. Router (protocol extending `GlobalRouter`)**
Declares navigation methods. The actual implementation uses `SwiftfulRouting`'s `AnyRouter`. `GlobalRouter` provides `dismissScreen()`, `showAlert(...)`, `showLoadingModal()`, etc. for free.

### Dependency Flow

```
DialedInApp
  └── Dependencies(config:)        ← creates all managers based on BuildConfiguration
        └── DependencyContainer    ← service locator, registered by type
              └── CoreInteractor   ← resolves all managers from container
                    └── CoreBuilder / screen builders
```

**Build configurations** (`BuildConfiguration` enum):
- `.mock(isSignedIn:)` — all mock services, no Firebase. Used for unit tests and previews.
- `.dev` — Firebase dev project, `LocalABTestService`, RevenueCat
- `.prod` — Firebase prod project, `FirebaseABTestService`, StoreKit

### SwiftUI Previews

Use `DevPreview.shared` to get a pre-configured mock container:
```swift
#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let presenter = SomePresenter(interactor: interactor, router: MockRouter())
    return SomeView(presenter: presenter)
}
```

### GlobalInteractor

`GlobalInteractor` protocol provides every interactor with:
- `trackEvent(event:)` / `trackScreenEvent(event:)` — analytics
- `playHaptic(option:)` — haptics

All event tracking uses types conforming to `LoggableEvent` (eventName, parameters, LogType).

## Package-Provided Infrastructure

Most of the infrastructure layer is **not in this repo**. It comes from the `Swiftful*` SPM
packages and is surfaced through `*+Alias.swift` typealias files so app code never imports the
packages directly:

| Alias file | Provides |
|---|---|
| `Managers/Auth/SwiftfulAuthenticating+Alias.swift` | `AuthManager`, `UserAuthInfo`, `SignInOption`, `MockAuthService` |
| `Managers/Logs/SwiftfulLogging+Alias.swift` | `LogManager`, `LoggableEvent`, `LogType`, the analytics services |
| `Managers/Purchases/SwiftfulPurchasing+Alias.swift` | `PurchaseManager`, `AnyProduct`, `PurchasedEntitlement` |
| `Managers/Routing/SwiftfulRouting+Alias.swift` | `AnyRouter`, `RouterView`, `ResizableSheetConfig` |
| `Managers/DataManagers/SwiftfulDataManagers+Alias.swift` | `CollectionSyncEngine`, `DocumentSyncEngine`, `DataSyncModelProtocol`, the persistence types |
| `Managers/Gamification/SwiftfulGamification+Alias.swift` | `StreakManager`, `ProgressManager`, `ExperiencePointsManager` |
| `Managers/Haptics`, `Managers/SoundEffects`, `Utilities/SwiftfulUtilities+Alias.swift` | `HapticManager`, `SoundEffectManager`, `Utilities` |
| `Components/Views/Charts/QuickCharts+Alias.swift` | `TimeSeries`, `TimeSeriesDatapoint`, `ChartScreen`, `LineChart`, `BarChart`, `StackedBarChart`, `ComboChart`, `ChartConfiguration`, `ContributionChart` and its pieces (`ContributionGrid`, `ContributionGridView`, `ContributionLegend`, `ContributionStyle`, `ContributionLayout`, `ContributionCell`) (from `andrewcoyle1/QuickCharts`) |

So when a symbol like `AuthManager` or `CollectionSyncEngine` cannot be found in this
repository, it is a package type — look in the alias file, then the package source. Editing its
behaviour means changing the package, not the app.

**Several of these packages are forks under `andrewcoyle1/`** rather than upstream
`SwiftfulThinking/`: SwiftfulAuthenticating (+Firebase), SwiftfulGamification (+Firebase),
SwiftfulDataManagers (+Firebase), SwiftfulRouting. The forks carry changes the app depends on,
and each `*Firebase` wrapper fork must point its dependency at the matching fork or SwiftPM
reports a conflicting-identity warning for that package.

## Key Managers

App-owned managers live in `DialedIn/Managers/` and are accessed through `CoreInteractor`.
Those marked *(package)* are aliases from the section above, not code in this repo:

| Manager | Purpose |
|---|---|
| `AuthManager` *(package)* | Firebase auth (Apple, Google, anonymous) |
| `UserManager` | Firestore user profile |
| `WorkoutSessionManager` | Logging and syncing workout sessions |
| `WorkoutTemplateManager` | Workout template CRUD + prebuilt seeding |
| `ExerciseModelManager` | Exercise library (local SwiftData + Firestore) + prebuilt seeding |
| `ExerciseUnitPreferenceManager` | Per-exercise weight/distance unit preferences |
| `TrainingProgramManager` | Training programs with local/remote sync |
| `GymProfileManager` | Available equipment per gym |
| `NutritionManager` / `MealLogManager` | Food logging and nutrition targets |
| `FoodManager` / `RecipeTemplateManager` | Food and recipe library |
| `BodyMeasurementsManager` | Body measurements and scale weight |
| `StepsManager` | Daily step history |
| `GoalManager` | User goals |
| `StreakManager` / `ProgressManager` / `ExperiencePointsManager` *(package)* | Gamification |
| `HealthKitManager` / `HKWorkoutManager` | HealthKit read/write |
| `LiveActivityManager` | Dynamic Island / Lock Screen workout tracking |
| `StravaManager` | Strava OAuth and activity import |
| `PurchaseManager` *(package)* | RevenueCat (dev) / StoreKit (prod) |
| `LogManager` *(package)* | Multi-service analytics (Console, Firebase, Mixpanel, Crashlytics) |
| `ABTestManager` | A/B tests via Firebase Remote Config (prod) or local (dev) |
| `AIManager` | Google AI / OpenAI integration via Cloud Functions |
| `PushManager` / `ImageUploadManager` / `ReportManager` | Notifications, image upload, reporting |
| `WorkoutSettingsManager` / `ExerciseSettingsManager` / `FoodLogSettingsManager` | User-facing settings |
| `HapticManager` / `SoundEffectManager` *(package)* | Feedback |

The full registration list is in `Dependencies.init(config:)`; `CoreInteractor` resolves each one
from the container by type.

Each manager has `Mock*Services` and `Production*Services` implementations selected in `Dependencies.swift`.

## Data Sync Pattern

Each manager owns one or more `CollectionSyncEngine` / `DocumentSyncEngine` instances (from
SwiftfulDataManagers) that listen to Firestore and mirror into local persistence, so screens read
the manager's in-memory collection rather than fetching.

`CoreInteractor.syncAllRemoteDataIfLoggedIn()` no longer performs a sync itself — the listeners
already keep data current, so it only posts `Constants.remoteDataSyncDidComplete` via
`NotificationCenter` for screens that want to refresh derived state. Treat it as "tell everyone
to re-read", not "go fetch".

## Live Activities

`WorkoutSessionActivityExtension` target provides the Dynamic Island / Lock Screen UI during workouts. Uses `ActivityKit` guarded with `#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)` throughout.

## Onboarding Flow

Onboarding lives under `Core/Onboarding/`, in folders numbered by step: `0 - WelcomeView`
through `9 - OnboardingCompleted` (there is no `7 -`, and both `9 - StravaConnect` and
`9 - OnboardingCompleted` share the 9 prefix). Each step is its own VIPER module. Progress is
persisted to Firestore. After completion, `AppState.startingModuleId` is updated to
`Constants.tabBarModuleId`.

`UserModel.inferredOnboardingStep` derives the resume point from the stored profile, and any
screen that needs to resume onboarding routes via **`OnboardingStepRouter`**
(`Core/Onboarding/OnboardingStepRouter.swift`): a protocol whose extension holds the single
`routeToOnboardingStep(_:onComplete:)` switch. Six presenters used to carry their own copies of
that switch and had drifted out of sync. Add new steps there, not in a presenter.

## Body Measurements

The eighteen circumference measurements (neck, waist, left bicep, …) are **one** VIPER module,
not eighteen. `BodyMeasurementKind`
(`Core/Analytics/Subviews/BodyMetrics/LogMeasurement/BodyMeasurementKind.swift`) is a table with
one line per measurement carrying everything that differs: display name, cm and inch picker
ranges, the two defaults, the `KeyPath` that reads it off `BodyMeasurementEntry`, and the
`CircumferenceUpdate` that writes it back. `LogMeasurementView` and its presenter are driven by
that kind, and `BodyMetricsRouter` exposes a single `showLogMeasurementView(kind:)`.

To add a measurement: add a field to `BodyMeasurementEntry` with its `CircumferenceUpdate` and
`ClearedField` cases, then add one line to the `BodyMeasurementKind` table. Do not copy a module.

The detail screens behind those loggers are collapsed the same way:
`MeasurementDetails/BodyMeasurementDetail.swift` holds one `MetricDetailPresenter` for all
eighteen, reached by `showBodyMeasurementDetailView(kind:themeColor:)`. `BodyRatioMetric` and
`VisualBodyFatMetric` are genuinely different and stay as their own files.

`BodyMeasurementKind` is the **only** table for these eighteen. `BodyMetricType` (which also
covers `scaleWeight` and `visualBodyFat`, so it cannot simply be replaced) maps into it via
`measurementKind`, and its `value(from:)` and `displayTitle` defer to that rather than keeping
their own keypath and title dictionaries.

Together these two passes removed ~7,400 lines across 90 files whose only real differences were
the values now in the table.

## Design System

**Use a token or primitive, never a literal.** Everything lives in
`DialedIn/Components/DesignSystem/`, one file per concern, app target only:

| File | Provides |
|---|---|
| `Spacing.swift` | `Spacing.xxs…xxl`, `Radius.s…xl` (always `style: .continuous`), `ControlSize`, `ChartHeight` |
| `Palette.swift` | `surface`, `canvas`, `tintedSurface(_:)`, the macro colours, `success/warning/danger`, `warmup/superset/personalRecord`, `Color.Metric.*`. `onAccent` is generated from the `OnAccent` asset. |
| `Typography.swift` | `Font.display/metricLarge/metric/metricSmall/sectionTitle/rowTitle/rowDetail/label`, and `.iconSize(_:)` for symbols. All Dynamic Type. |
| `Motion.swift` | `Animation.quick/standard/emphasis/progress`, applied only through `withReducedMotionAnimation` / `reducedMotionAnimation` |
| `Symbols.swift` | `Symbol.*`: one SF Symbol per concept |
| `Format.swift` | `Format.kcal/grams/weight/reps/sets/repRange/duration/distance/percent/placeholder` for every displayed quantity |
| `Presentation.swift` | Sheet presets `.compact/.half/.full` |
| `Card.swift`, `Stat.swift`, `Chip.swift`, `ListRow.swift`, `NumberField.swift`, `BottomCTA.swift`, `InlineMessage.swift`, `OnboardingStepScaffold.swift` | The primitives: `.cardSurface`, `Stat`, `Chip` (+ `.chipTapTarget()`), `ListRow`/`ListRowButton`/`ListRowToggle`/`SelectableRow`, `NumberField`, `.bottomCTA`, `InlineMessage`, `OnboardingStepScaffold` |

`docs/specs/ui-framework/CONTRACT.md` is the contract: every name above, the accent rules
(`.tint`/`Color.accentColor`, never `.primary` or `labelColor` standing in for the brand), and the
screen patterns (close/confirm roles, one `CallToActionButton` via `.bottomCTA`, inline titles,
`ContentUnavailableView` empty states, haptics after every save). The accent is two assets,
`AccentColor` and `OnAccent`; changing both recolours the app.

User-facing strings use US spelling and go through `Localizable.xcstrings`, which is kept 100%
Spanish-complete. Counts use the catalog's plural variations (`"\(n) sets"`) or `Format.sets`,
never a hand-written "s".

Eight `custom_rules` in `.swiftlint.yml` enforce this at **error** severity, and CI runs
`swiftlint --strict`: `no_corner_radius_modifier`, `no_foreground_color`, `no_fixed_font_size`,
`no_rgb_color_literal`, `no_bare_with_animation`, `accent_spelling`, `no_color_scheme_surfaces`
and `no_drawn_close_button`. They skip comments. Share cards
(`Core/Dashboard/ShareCard/`, `WeeklyReviewShareCardView.swift`) render to fixed-size images and
the widget (`WorkoutSessionActivity/`) has no design system, so both are exempt where a rule
cannot apply. If a rule fires, use the token; do not suppress it.

## Backend (Cloud Functions)

`functions/` holds Firebase Cloud Functions v2 (Node, ES modules) using Genkit with Vertex AI.
Six `onCall` callables, all in `us-central1`: `foodAnalyze`, `mealDescribe`,
`nutritionLabelAnalyze`, `chatGenerate`, `imageGenerate`, `foodSearch`.

All six share `CALLABLE_OPTIONS = { region: REGION, enforceAppCheck: true }` and call
`requireAuth(request)`, which throws `unauthenticated` when `request.auth` is missing. Keep both
on any new callable — they are the only thing stopping an arbitrary rebuilt client from calling
the backend, since the API keys in the bundled plists are public by design.

App Check on the client is wired in `DialedIn/Utilities/AppCheckProviderFactory.swift`:
App Attest where available, DeviceCheck as fallback, and a debug provider for simulators. A
simulator debug token must be registered in the **dev** Firebase project only, never prod.

Two things live outside the code and are easy to miss:
- App Check **enforcement** is a per-service toggle in the Firebase console, separate from the
  `enforceAppCheck` flag here.
- Enabling enforcement breaks already-shipped app versions that predate the App Check wiring.
  Check App Check metrics for unverified traffic before turning it on.

Deploy with `firebase deploy --only functions` — this is not part of the Xcode build, so changes
under `functions/` have no effect until deployed.

`npm test` in `functions/` runs five `node:test` cases (`index.test.js`) with no emulator: the
pure helpers in `lib.js`, a source check that every `onCall` takes `CALLABLE_OPTIONS` and opens
with `requireAuth`, and a `.run()` of each callable without auth expecting `unauthenticated`.
CI runs them in a separate `functions` job on Ubuntu. `npm ci` needs the lock file in sync with
`package.json`; if it fails with "Missing: … from lock file", run `npm install` and commit the
lock.

## Code Health Baseline

As of the UI framework merge, the Development and Mock schemes and the
`WorkoutSessionActivityExtension` scheme build with **zero warnings**, and `swiftlint --strict`
reports **zero violations** across 1,520 files, including the design-system custom rules.

Under **Xcode 27.0** the Production (Release, whole-module-optimised) build crashes the compiler:
an LLVM verifier failure, "Instruction does not dominate all uses", in the `DialedIn` module. Before
the UI framework merge it already failed, one step earlier, on an optimizer crash that
`WeeklyReviewPresenter`'s `now:` default now avoids, so this is the toolchain rather than the
swarm's code. CI pins Xcode 26.6; check
Production there, or with 26.6 installed, before treating it as a regression. Treat any new warning as something to
fix rather than accumulate.

Building a scheme does not compile the test target, so a warning in `DialedInUnitTests` shows up
only under `xcodebuild test`. Check the test run's log for `warning:` as well as the three builds
before claiming the baseline holds.

Two file-wide suppressions exist, each documented at the site:
- `Dependencies.swift` disables `type_body_length`/`file_length` — it is one long DI root whose
  switch arms bind ~32 locals that a shared registration block consumes.
- `StravaManager.swift` scopes an iOS 26 deprecation on `presentationAnchor(for:)` with
  `@available(iOS, deprecated: 26.0)` — not a SwiftLint rule — because every spelling of a
  scene-less `UIWindow` is deprecated and Swift has no per-call suppression.

`DesignSystem/Spacing.swift` disables `identifier_name` so `Spacing.s`, `Radius.m` and the
rest can be one letter.

Ten single-line `swiftlint:disable:next` comments also exist:
- `function_body_length` in `DevPreview.swift`, `CoreInteractor.swift` and
  `WorkoutSessionModel.swift`; in `Dependencies.swift` it also covers `cyclomatic_complexity`.
- `large_tuple` in `PushManager.swift` and `NutritionOverviewPresenter.swift`.
- `function_parameter_count` in `AddMealView.swift` and `ExpenditureEngine.swift`.
- `cyclomatic_complexity` in `WeightStepper.swift`.
- `no_rgb_color_literal` in `SignInWithGoogleButtonView.swift`, for the dark fill Google's
  branding guidelines fix.
