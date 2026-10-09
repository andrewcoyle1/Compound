# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Start with `docs/codebase-map.md`** before searching: it explains how to predict a file's path
from its name and lists every screen module, manager, sync model, Cloud Function, Firestore path
and test suite with a link. It is generated; after adding or moving files run
`python3 scripts/codebase-map.py` and commit the result.

## Build & Development

**Package manager**: Swift Package Manager only — there is no Podfile and no `.xcworkspace`. Open
`Compound.xcodeproj` directly; Xcode resolves packages on open.

**Schemes** (Production is the plain `Compound` scheme):

| Scheme | Configuration | Backend |
|---|---|---|
| `Compound - Development` | Debug | Firebase dev project |
| `Compound - Mock` | Mock | All mock services, no Firebase |
| `Compound` | Release | Firebase prod project |

**Build from the command line**:
```bash
xcodebuild -project Compound.xcodeproj -scheme 'Compound - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Run tests**:
```bash
xcodebuild test -project Compound.xcodeproj -scheme 'Compound - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The tests compile and pass (3,542 tests in `CompoundUnitTests`). Treat a `TEST FAILED` as a
regression from your change unless it is only the UI-test flake described below.

`-only-testing` works, but only under the scheme's own name for the target. The productName is
`DialedInTests`, and `-only-testing:DialedInTests` is rejected; the BlueprintName is
`CompoundUnitTests`, so a single suite runs with:

```bash
xcodebuild test -project Compound.xcodeproj -scheme 'Compound - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CompoundUnitTests/OnboardingHeightConversionTests
```

**Run the full suite only when pushing.** Not between steps, and not to confirm something a
narrower run has already shown. Measured on this machine: the whole suite is about fifteen minutes
with the UI bundle and **2.7 minutes without it** (3,542 unit tests as of the UI framework merge), one suite through
`-only-testing` is about forty-five seconds, and the package's own `swift test` is under two.
Nearly all of the fifteen minutes is the UI runner and its simulator clones, so
`-skip-testing:CompoundUITests` is the single biggest saving available. Pick the narrowest run
that could actually fail:

| Change | Run |
|---|---|
| A `Swiftful*` package | `swift test` in that package's clone |
| One module | `-only-testing:` its suite |
| Docs only | nothing |
| Chasing a flake | one invocation with `-test-iterations N -run-tests-until-failure` |

Repeat runs belong in **one** invocation with `-test-iterations`, never N invocations — the build
and simulator boot dominate, so five separate calls cost five times the setup for the same tests.

Add `-skip-testing:CompoundUITests` to anything routine. Its ten tests (plus a smoke deck that
skips unless `TEST_RUNNER_SMOKE=1`) take about seven minutes serially and need their own simulator
clone; a launch flake there is also what makes a run report `** TEST FAILED **` when every unit
test passed. To run it on its own: `-only-testing:CompoundUITests -parallel-testing-enabled NO`.
Until 4 Oct 2026 the target's `TEST_TARGET_NAME` still said `DialedIn`, so that run failed with
"UITargetAppPath should be provided" and three tests had gone stale unnoticed; all ten pass now.

**Simulator clones.** A parallel test run clones the destination simulator several times into
`~/Library/Developer/XCTestDevices` and never removes the clones. On 29 Sep 2026 that had grown
to 109 clones and about 250 GB, which macOS reports as "System Data".

- Run `scripts/clean-simulators.sh` after a full-suite run, and before starting any fan-out. It
  refuses to run while a test is in progress.
- When several agents may be testing at once, each passes `-parallel-testing-enabled NO`, so it
  creates no clones and cannot lose them to another agent's clean-up. A single suite is quick
  enough serially.
- `du` counts a clone's shared data once per clone, so its totals can exceed the size of the
  disk. Judge by free space (`df -h /System/Volumes/Data`), and allow for deletion finishing in
  the background.

Read the counts from the result bundle:

```bash
xcrun xcresulttool get test-results summary \
  --path "$(ls -td ~/Library/Developer/Xcode/DerivedData/Compound-*/Logs/Test/*.xcresult | head -1)"
```

The UI-test runner is flaky in the simulator: it either fails to launch
(`FBSOpenApplicationServiceErrorDomain Code=1`) or drops the connection mid-test (`Failed to get
matching snapshot: Lost connection to the application`). This **does** fail the run — the whole
invocation prints `** TEST FAILED **` on the strength of one UI test — so `** TEST SUCCEEDED **`
is not a reliable signal on its own. Check the unit bundle's own result instead:

```bash
B="$(ls -td ~/Library/Developer/Xcode/DerivedData/Compound-*/Logs/Test/*.xcresult | head -1)"
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

`Unit test bundle | CompoundUnitTests | Passed` is what matters. The summary's top-level
`failedTests` counts both bundles together, so it reads 1 on a clean unit run that hit the flake.

Managers take sync engines rather than a services struct, so tests build them through
**`CompoundUnitTests/Support/TestManagers.swift`**, which wires them the way `Dependencies` does
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

**The unit runner hangs when started straight after a UI run on the same simulator** ("The
test runner hung before establishing connection", seen five times on 6 Oct 2026, never on a
fresh device). Run unit suites first and the UI suite last, or `xcrun simctl shutdown` then
`boot` the device between them and wait ~10 s after `bootstatus -b` before launching. Shutting
a simulator also kills every test host on it, so when several agents test at once, each uses
its own device name and never touches another's.

**An unsigned app bundle means the build failed, not that signing is broken.** When
`build-for-testing` fails in the test target, the host `Compound.app` is left without its
signature (`codesign -dv` says "not signed at all"), and every later `test-without-building`
fails with `Simulator device failed to launch … No such process`, for unit and UI tests alike.
Erasing the simulator or restarting CoreSimulatorService does not help. Always check
`xcodebuild`'s own exit status (in zsh a pipeline's is `${pipestatus[1]}`, lower-case) before
reading test results; on 6 Oct 2026 an unchecked status hid a test-target compile error for an
afternoon.

**Known unit flakes under a full-bundle run**, each passing alone: the HealthKit import-observer
suites (`StepsManagerTests`, `MealLogHealthKitImportTests`, `BodyMeasurementsManagerTests`) time
out one at a time in `TestManagers.eventually`, and the Live Activity suites fail as a block of
about eight with `ActivityAuthorizationError.visibility` or "the app has pushed nothing"
(seen twice on 7 Oct 2026, both on a simulator that had just been erased or cycled). Rerun the
suite alone before blaming a change. The Live Activity suites are nested in a serialized parent,
so select them by its path: `-only-testing:CompoundUnitTests/WorkoutRestSharedStateTests`
(`…/LiveActivityManagerTests` alone selects nothing and reports "Executed 0 tests"). Simulator
names are not unique either — there are two "iPhone 17" and two "iPhone 17e" — so pass a UDID
(`-destination 'platform=iOS Simulator,id=…'`).

**Deployment target**: iOS 26.0 (26.1 for some targets). The project-level Swift language
version is 6.0; the test and extension targets are still on 5.0.

**Lint** (SwiftLint must be installed):
```bash
swiftlint
```

SwiftLint config (`.swiftlint.yml`): line limit 300, type body 500 lines, file length 750 lines, `trailing_whitespace` disabled.

### CI

`.github/workflows/ci.yml` runs on every pull request. Besides the Cloud Functions tests and a
**Release build (Xcode 27)** job (below), its main job runs on the
`macos-26` runner with Xcode pinned to `/Applications/Xcode_26.6.app`. In order, it:

1. Recreates the four gitignored config files from their checked-in examples — `Keys.swift`,
   `Info.plist`, and both `GoogleService-Info-{Dev,Prod}.plist` (all copied from
   `GoogleService-Info-Example.plist`). The examples are enough because only the Crashlytics
   run-script phase reads the plists and it exits early on simulator builds. The `Keys.swift`
   example defines all 33 constants the app references, so it compiles unchanged.
2. Runs `swiftlint --strict`, before the build so a style failure fails fast. `main` is at zero
   violations, so any warning fails the job. SwiftLint is **pinned** — see below.
3. Runs `xcodebuild test` for `Compound - Development` with `-skip-testing:CompoundUITests`,
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

The **Release build (Xcode 27)** job compiles the `Compound` scheme in Release, for the simulator,
on the `xcode-27` image: the configuration and toolchain releases ship with. The unit tests build
Debug on Xcode 26.6, where the optimiser never runs, and the first release crashed the compiler
on code they had passed. Simulator rather than device, so it needs no signing and the Crashlytics
phase skips.

Every action in both workflows is pinned to a commit SHA, with its tag in a trailing comment, and
the release pins `firebase-tools` to an exact version: the release runs them with prod
credentials. Bump a pin deliberately, resolving the new tag with
`gh api repos/<owner>/<repo>/commits/<tag> -q .sha`.

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

### Release (CD)

`.github/workflows/release.yml` runs on every push to `main`, which the ruleset allows only by a
merged PR whose CI passed. Both jobs use the **`release`** environment: it accepts `main` only,
holds the secrets, and waits for the owner's approval. Each run, and each **re-run** of a job,
needs approving again. The TestFlight job `needs` the Cloud Functions job, so the backend is
always deployed first and a failed deploy stops the upload; it therefore asks for its own approval
once the deploy finishes. App Review submission stays manual in App Store Connect.

**TestFlight job** — archives the `Compound` scheme and uploads with an App Store Connect API key
(`ASC_API_KEY_P8`, `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`; Admin role, because cloud-managed
distribution signing needs it). `KEYS_SWIFT` and `GOOGLE_SERVICE_INFO_PROD` are base64 of the
local files; update the secret when either file changes, or the release ships stale keys.
`manageAppVersionAndBuildNumber` takes the next free build number, so the project's own build
number stays at 1.

- It runs on the **`xcode-27`** runner image (a GitHub preview), not `macos-26` like CI. Xcode
  26.6's Swift 6.3.3 crashes in the optimizer's ClosureSpecializer on
  `CoreBuilder.weeklyReviewView`, which only an optimised build reaches, so CI's Debug tests never
  see it. `xcode-27` carries Xcode 27.0 27A266a, the same build used locally. Unknown to actionlint;
  pass `-ignore 'label "xcode-27" is unknown'`.
- `ITSAppUsesNonExemptEncryption = NO` is set on the app target, so builds skip the export
  compliance question.

**Cloud Functions job** — deploys to `dialed-c3cb5` as the **`github-release`** service account
through workload identity federation; no key is stored anywhere.

- Pool `github`, provider `github-actions` (issuer `https://token.actions.githubusercontent.com`,
  condition `assertion.repository == 'andrewcoyle1/Compound'`), project number `94958324260`.
- This repo uses GitHub's **immutable subject** format, so the token's `sub` is
  `repo:andrewcoyle1@200482452/Compound@1064429405:environment:release`, IDs included. The
  Workload Identity User grant on `github-release` names exactly that subject. The usual guides
  show `repo:andrewcoyle1/Compound:environment:release`, which never matches and fails as
  `Permission 'iam.serviceAccounts.getAccessToken' denied`. Check the format with
  `gh api repos/andrewcoyle1/Compound/actions/oidc/customization/sub`.
- `github-release` holds the least the deploy was shown to need, found by re-running the job with
  nothing changed (every function is skipped, but every pre-deploy check runs):
  - Project: Cloud Functions Admin, Cloud Scheduler Admin (the scheduled functions' jobs), Secret
    Manager Viewer, and the custom role **Release deploy reads** (`releaseDeployReads`):
    `firebase.projects.get`, `datastore.databases.getMetadata`,
    `artifactregistry.repositories.get`, `resourcemanager.projects.get`,
    `serviceusage.services.get`. None of them reads app data, which is why no Firebase viewer role
    is used: those include Firestore, Realtime Database and Storage reads.
  - Service Account User on **only** two accounts: `94958324260-compute@developer` (the functions'
    runtime account) and `dialed-c3cb5@appspot` (firebase-tools checks actAs on it before every
    deploy, though nothing runs as it). Never project-wide: that would let it act as the Admin SDK
    account.
- Not yet exercised: deploying a **new** callable, which sets its invoker policy and may need one
  more permission. If a deploy fails on a permission, add it to `releaseDeployReads` (reads) or the
  narrowest role that grants it, and record it here.
- The workflow requests a token with `gcloud auth print-access-token` before deploying, because
  firebase-tools reports any credential failure as "have you run firebase login?".
- The Cloud Billing API is enabled on the project because firebase-tools checks billing and the
  deploy account cannot enable APIs.

## Branching

Two long-lived branches, `main` and `development`.

- **`development`** is the stable development build. Cut every feature, fix and agent branch from
  it and merge back into it. Delete the branch, its worktree and its DerivedData on merge.
- **`main`** is the release branch. Merges into it are periodic, by pull request from
  `development`, and the repository owner decides when. Do not merge or push to `main` unprompted.

CI runs on pull requests only, so a direct push to `development` is not checked by CI: compile
and run the unit suite locally first.

`main` is protected by the **Protect main** ruleset: no direct pushes, force pushes or deletion,
and a PR merges only once `Lint, build and unit test` and `Cloud Functions unit tests` have
passed on a branch up to date with `main`. Each merge then starts `.github/workflows/release.yml`
(the push itself, not a second CI run), which waits for the owner's approval on the `release`
environment, uploads to TestFlight from the `xcode-27` image and deploys Cloud Functions to prod.

Before reviewing or changing code, `git fetch` and confirm the checkout is level with
`origin/development`. Do not order branches by commit date, because a merge commit is stamped
when it is merged: compare what each side has that the other lacks
(`git rev-list --count --no-merges A..B`).

## First-Time Setup

Copy example files and fill in credentials. All three destinations are gitignored, and the app
will not build or sign in without them:

- `Compound/Utilities/Keys.swift.example` → `Compound/Utilities/Keys.swift` — 33 constants:
  OpenAI, Mixpanel, the RevenueCat dev and prod SDK keys, the Strava client ID (its secret is the `STRAVA_CLIENT_SECRET` Functions secret), and 28 `*ManagerKey` strings used as
  local-persistence path names. The manager keys are arbitrary but must stay stable: changing
  one orphans data already persisted under the old name.
- `Compound/Info.plist.example` → `Compound/Info.plist` — already contains the real reversed
  client IDs for both Firebase projects and the `compound` deep-link scheme, so this is a
  straight copy. Google Sign-In fails at runtime without it.
- `Compound/SupportingFiles/GoogleServicePLists/GoogleService-Info-Example.plist` →
  `GoogleService-Info-Dev.plist` and `GoogleService-Info-Prod.plist` (same folder)

## Repository Layout

```
Compound/                    # the app target (Core, Components, Managers, Root, Extensions,
                             #   Utilities, SupportingFiles)
WorkoutSessionActivity/      # Live Activity / Dynamic Island widget extension
Shared/                      # code shared between the app and the widget extension
CompoundUnitTests/           # unit tests (target productName is DialedInTests)
CompoundUITests/             # UI tests
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
CompoundApp
  └── Dependencies(config:)        ← creates all managers based on BuildConfiguration
        └── DependencyContainer    ← service locator, registered by type
              └── CoreInteractor   ← resolves all managers from container
                    └── CoreBuilder / screen builders
```

**Build configurations** (`BuildConfiguration` enum):
- `.mock(isSignedIn:)` — all mock services, no Firebase. Used for unit tests and previews.
- `.dev` — Firebase dev project, `LocalABTestService`, RevenueCat
- `.prod` — Firebase prod project, `FirebaseABTestService`, RevenueCat

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

App-owned managers live in `Compound/Managers/` and are accessed through `CoreInteractor`.
Those marked *(package)* are aliases from the section above, not code in this repo:

| Manager | Purpose |
|---|---|
| `AuthManager` *(package)* | Firebase auth (Apple, Google, anonymous) |
| `UserManager` | Firestore user profile |
| `WorkoutSessionManager` | Logging and syncing workout sessions |
| `WorkoutTemplateManager` | Workout template CRUD + prebuilt seeding |
| `ExerciseModelManager` | Exercise library (local SwiftData + Firestore) + prebuilt seeding |
| `ExerciseUnitPreferenceManager` | Per-exercise weight/distance unit preferences |
| `MesocycleManager` | Mesocycles (a program of day plans run for N microcycles) with local/remote sync |
| `MacrocycleManager` | Macrocycles: ordered mesocycles, the current mesocycle's start and skips. `MesocycleSchedule` derives today's workout and microcycle progress from it (a queue, not a calendar) |
| `GymProfileManager` | Available equipment per gym |
| `NutritionManager` / `MealLogManager` | Food logging and nutrition targets |
| `FoodManager` / `RecipeTemplateManager` | Food and recipe library |
| `BodyMeasurementsManager` | Body measurements and scale weight |
| `StepsManager` | Daily step history |
| `GoalManager` | The weight goal. Each goal is its own document in `users/{uid}/goals` (`goal_id`), and the user's `currentGoalId` names the running one; documents from before goal ids sit under the user id. The rules freeze where a goal started (`starting_weight_kg`, `created_at`), so editing changes only objective, target and rate, and a fresh start is a new goal with the old one marked abandoned (`WeightGoalChoices`) |
| `WeeklyStreak` (`Core/Social/CircleGoals`) | The one streak: consecutive weeks meeting the weekly session goal (`CircleWeek.goal`). Stamped on sessions as `week_streak_count`, and copied to `users/{uid}/private/settings` (`week_streak`, `week_sessions`, `week_goal`, `week_ends_at`, `last_trained_at`) for the streak reminder. SwiftfulGamification (+Firebase) is still linked in the project but nothing imports it; remove it from the project when convenient |
| `CoachManager` | The AI coach (see Backend and `docs/specs/ai-coach.md`): streams answers from `coachChat`, reads the saved chats in `users/{uid}/coach_chats` (the function writes them; the app only reads and deletes), and holds consent in private settings (`coach_consent`, written `false` on withdrawal because saves merge). The coach screen checks premium, then consent, itself, so every way in behaves the same. A screen offers it by adopting `AskCoachRouter` and passing a `CoachContext` |
| `HealthKitManager` / `HKWorkoutManager` | HealthKit read/write |
| `LiveActivityManager` | Dynamic Island / Lock Screen workout tracking |
| `StravaManager` | Strava, with the tokens on the server (see Backend). Each finished workout is queued and uploaded with its sets (JSON strength format, so Strava draws its muscle map) and a set summary in its description; the queue is kept per account and sent at sign-in and after each finish, like a sync engine's pending writes, and past workouts can be queued from Integrations. The activity id is stamped on the session as `strava_activity_id`. Imported runs and rides (`importedActivities`) show on the owner's own screens only — Integrations, the weekly review, their own profile — never anywhere followers see, per Strava's terms. Built-in exercises map to Strava types in `StravaExerciseType`; add a line there for each new one |
| `PurchaseManager` *(package)* | RevenueCat in dev and prod, each with its own SDK key; StoreKit config files for local testing |
| `LogManager` *(package)* | Multi-service analytics (Console, Firebase, Mixpanel, Crashlytics) |
| `ABTestManager` | A/B tests via Firebase Remote Config (prod) or local (dev) |
| `AIManager` | Food photo, meal description and label analysis, and image generation, via Cloud Functions |
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
through `9 - OnboardingCompleted` (there is no `1 -` or `7 -`; Get Started goes straight to sign-in, and the account-setup and goal folders open on their first question rather than an intro screen). Each step is its own VIPER module.
Notifications, Apple Health and Strava are not onboarding steps: each is offered where it is
first used. Progress is
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
`Compound/Components/DesignSystem/`, one file per concern, app target only:

| File | Provides |
|---|---|
| `Spacing.swift` | `Spacing.xxs…xxl`, `Radius.s…xl` (always `style: .continuous`), `ControlSize`, `ChartHeight`, `ContentWidth.readable` (the 700 pt column every routed screen centres on iPad and Mac, via the SwiftfulRouting fork's `readableContentWidth`, set once in `CompoundApp`) |
| `Palette.swift` | `surface`, `canvas`, `tintedSurface(_:)`, the macro colours, `success/warning/danger`, `warmup/superset/personalRecord`, `Color.Metric.*`. `onAccent` is generated from the `OnAccent` asset. |
| `Typography.swift` | `Font.display/metricLarge/metric/metricSmall/sectionTitle/rowTitle/rowDetail/label`, and `.iconSize(_:)` for symbols. All Dynamic Type. |
| `Motion.swift` | `Animation.quick/standard/emphasis/progress`, applied only through `withReducedMotionAnimation` / `reducedMotionAnimation` |
| `Symbols.swift` | `Symbol.*`: one SF Symbol per concept |
| `Format.swift` | `Format.kcal/grams/weight/reps/sets/repRange/duration/distance/percent/placeholder` for every displayed quantity |
| `Presentation.swift` | Sheet presets `.compact/.half/.full` |
| `Dashboard.swift` | `Dashboard { Section… }`: a tab root's sections as a `List` on a phone and two card columns from `ContentWidth.twoColumns` up. Today uses it; Progress instead widens via `preferredReadableContentWidth` and lets `AnalyticsCardGrid` add columns (2–4). |
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
(`Core/Social/ShareCard/`, `WeeklyReviewShareCardView.swift`) render to fixed-size images and
the widget (`WorkoutSessionActivity/`) has no design system, so both are exempt where a rule
cannot apply. If a rule fires, use the token; do not suppress it.

## Calculations and their sources

Every figure the app works out for the user, rather than reads back from their logs, rests on a
published source and says so. The research behind each choice, with the full reference list
(R1–R113), is `docs/research/algorithms-evidence.md`; how each DOI and number was checked, and the
ones still to read in the paper, is `docs/research/citation-verification-checklist.md`.

- `Components/Science/Citations.swift` is the catalogue: one `Citation` per source, named after
  the first author and year (`Citation.morton2018`), linking to its DOI. Cite only from it.
- `MethodInfo` (`Components/Science/MethodInfo+Energy|Nutrition|Training|Volume|Habits.swift`)
  is the user-facing account of one calculation: a plain summary, the formula exactly as the code
  computes it, its limits, the constants that are Compound's own choices (`ownChoices`), and the
  citations. Never present a design choice as a finding.
- `MethodInfoButton(.someMethod)` is the ⓘ beside the figure; `MethodInfoHeader(title:info:)` puts
  it at a section header's trailing edge. Settings › Methods & Sources lists every method.
- **A new or changed calculation needs its `MethodInfo` updated in the same change**, and a button
  wherever it is shown.

What the main calculations now are, and where they are specified:

| Area | Method | Spec |
|---|---|---|
| Resting energy | Mifflin-St Jeor (default), revised Harris-Benedict, Cunningham 1980 when body fat is known (stored raw value `katchMcArdle`) | `docs/specs/adaptive-expenditure.md` |
| Formula expenditure | RMR × FAO/WHO/UNU 2004 PAL band (1.4 / 1.55 / 1.7 / 1.85 / 2.0), no exercise-frequency add-on, TEF shown as 10% | same |
| kcal per kg | `EnergyDensity`: Forbes/Hall partition when body fat is known, else 7,700. The only conversion | same |
| Weight trend and expenditure | One Kalman filter (`ExpenditureFilter`, `WeightTrendCalculator`): trend weight, intake, expenditure, with an SD and a calibrating state | same |
| Calorie target | Deadband controller in `TargetProposal`, at most weekly and ±150 kcal, adherence checked before lowering | same, and `weekly-check-in.md` |
| Nutrition targets | `NutritionTargets`: protein tiers on a reference weight at BMI ≥ 30, fat floor, keto 30 g, sex-specific floors, rates as % of body weight | `adaptive-expenditure.md` |
| Strength | `ExerciseOneRMAggregator.estimated1RM` (Epley on reps + RIR, none past ten), `LoadIncrement`, `MesocycleDeload`, tapered warm-ups, rest by exercise type | `docs/specs/smart-progression.md` |
| Volume | `MuscleVolume.hardSets` (RPE ≥ 6, drops 0.5, secondaries 0.5), one 10–20 band with four tiers, `VolumeRecommendation` | `docs/specs/training-volume.md` |

## UI and the HIG

Check UI work against Apple's live Human Interface Guidelines with the **`apple-hig` skill**
(user-level, `~/.claude/skills/apple-hig`), not from memory — the guidance for bars, buttons,
materials and colour was rewritten for Liquid Glass and is still changing. If the skill is not
installed, say so and mark HIG claims as unverified.

```bash
python3 ~/.claude/skills/apple-hig/scripts/hig.py get tab-bars toolbars --platform ios
```

**Platforms.** The app ships to iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), iOS 26.0+,
with Mac Catalyst enabled on the app and the widget extension. Pass `--platform ios` by default
and `--platform ipados` when the change affects layout or navigation at regular width. Read
`designing-for-ios` once per session.

**Precedence.** Where this project has already decided, the decision wins and the HIG fills in the
rest: the Design System section above, `docs/specs/ui-framework/CONTRACT.md` and the Decisions
list in that folder's `README.md`. If a HIG page contradicts one of those, report it with the
source URL — do not change the contract from inside a feature.

**Pages by area:**

| Area | Read |
|---|---|
| Tab shell, navigation | `tab-bars`, `toolbars`, `searching`, `sheets`, `modality` |
| Onboarding (`Core/Onboarding/`) | `onboarding`, `privacy`, `healthkit`, `managing-notifications`, `sign-in-with-apple`, `managing-accounts` |
| Paywalls | `apple-in-app-purchase` |
| Active workout, Live Activity (`WorkoutSessionActivity/`) | `workouts`, `live-activities`, `playing-haptics` |
| Analytics and charts | `charting-data`, `charts` |
| Logging forms (food, sets, measurements) | `entering-data`, `pickers`, `text-fields`, `virtual-keyboards` |
| Lists and rows | `lists-and-tables`, `buttons`, `menus`, `context-menus` |
| Everything | `accessibility`, `typography`, `color`, `materials` |

**Reviews** go in `docs/reviews/`, one file per review, in the skill's finding format (severity,
`file:line`, quoted guideline with source URL, fix). State which appearances and text sizes were
actually checked.

## Backend (Cloud Functions)

`functions/` holds Firebase Cloud Functions v2 (Node, ES modules) using Genkit with Vertex AI.
Thirteen `onCall` callables, all in `us-central1` except `coachChat` (`europe-west4`): `foodAnalyze`,
`mealDescribe`, `nutritionLabelAnalyze`, `imageGenerate`, `foodSearch`, `removeFollower`,
`acceptInvite`, `coachChat`, and five for Strava: `stravaConnect`, `stravaAccessToken`, `stravaConnection`,
`stravaDisconnect` and `stravaToken`. Strava's client secret lives only in the
`STRAVA_CLIENT_SECRET` Functions secret (`firebase functions:secrets:set` per project).

**Strava.** The tokens live server-side in `strava_connections/{uid}`, which no client can read,
so a connection belongs to the Compound account, not the device: signing out keeps it.
- `stravaConnect({clientId, code | refreshToken})` connects. The refresh-token form migrates an
  older build's Keychain token; a code without `activity:write` is refused with
  `failed-precondition`. One Compound account per athlete: connecting takes the athlete from any
  other account.
- `stravaAccessToken` hands the app a short-lived token, which it uses to call Strava directly. It
  answers `not-found` when not connected, and `permission-denied` when Strava refuses the
  refresh, which also drops the connection.
- `stravaConnection` answers the status and athlete; `stravaDisconnect` revokes at `/oauth/revoke`
  with Basic client credentials.
- Imported activities live in `users/{uid}/strava_activities` (owner read-only). Compound's own
  uploads (`external_id` "compound-…") are never imported. Connecting queues a 365-day import.
- `stravaWebhook` (HTTP; verify token in the `STRAVA_WEBHOOK_VERIFY_TOKEN` secret) only queues
  events in `strava_events`; `onStravaEventCreated` processes them: activity create, update and
  delete, and a deauthorization, believed only after a forced refresh fails, because webhooks are
  unsigned.
- Disconnecting, a refused refresh, deauthorization and account deletion all remove the
  connection and every imported activity.
- `stravaToken` remains only for builds older than the server-held tokens; remove it once none
  are in use.
- One-time setup per project: set `STRAVA_WEBHOOK_VERIFY_TOKEN`, deploy, then create Strava's
  push subscription (`POST https://www.strava.com/api/v3/push_subscriptions` with `client_id`,
  `client_secret`, `callback_url` = the deployed `stravaWebhook` URL, `verify_token`). Strava
  allows one subscription per app, so dev and prod need separate Strava apps.
- Strava's rate limits (200 requests per 15 minutes, 2,000 a day by default) are per **app**, not
  per athlete: every user's uploads, backfills and imports share them.

**AI coach.** `coachChat` (options `COACH_CALLABLE_OPTIONS`) answers read-only questions about the
caller's own data with Gemini 2.5 Flash on Vertex in `europe-west4`, beside Firestore's `eur3`. It
streams `{ text }` chunks and returns `{ chatId, messageId, text, remainingToday }`. Checks run in
order, so a refusal costs nothing:
- Consent: `users/{uid}/private/settings.coach_consent === true`.
- Premium: RevenueCat REST v2 `active_entitlements`, with a V2 key that can only read customer
  information (`REVENUECAT_SECRET_KEY` secret; project id `REVENUECAT_PROJECT_ID` in
  `functions/.env.<project>`). A yes is cached five minutes, a 404 means not premium, any other
  failure answers `unavailable`, and `compound-development` skips the check.
- Quota: 50 messages a day in the user's timezone plus 5 a minute, in the server-only
  `coach_usage/{uid}`.

The model reads data only through the ten tools in `functions/coach.js`, one allowed area each;
there is no tool for Strava, progress photos or anything social, and tests enforce that. The
app's expenditure engine, formula TDEE, weight trend, estimated 1RM (Epley on reps + RIR, none past
ten reps to failure, Reynolds 2006: `ExerciseOneRMAggregator.estimated1RM`, the app's only copy) and
weekly muscle sets are copied in `functions/coach-maths.js`. `CompoundUnitTests/Fixtures/coach-parity.json`
is checked by both `CoachParityTests.swift` and `coach-maths.test.js`, so changing either copy
without the other fails a test. After changing the maths in both, rewrite its expected values with
`node scripts/coach-parity-expected.mjs`. `functions/data/PrebuiltExercises.json` must stay a
byte-for-byte copy of the app's file, which a test checks. Run `node scripts/coach-eval.js` from
`functions/` (application-default credentials, `GCLOUD_PROJECT=compound-development`) after
changing the prompt, the tools or the model.

**Streak reminder.** `streakReminder` reads the app's weekly streak from the private settings doc
and pushes only when every remaining day of the week is needed and none is logged today.
`user_streaks` is no longer read.

All of them share `CALLABLE_OPTIONS = { region: REGION, enforceAppCheck: true }` (the Strava ones
extend it as `STRAVA_CALLABLE_OPTIONS` with the secret) and call
`requireAuth(request)`, which throws `unauthenticated` when `request.auth` is missing. Keep both
on any new callable — they are the only thing stopping an arbitrary rebuilt client from calling
the backend, since the API keys in the bundled plists are public by design.

App Check on the client is wired in `Compound/Utilities/AppCheckProviderFactory.swift`:
App Attest where available, DeviceCheck as fallback, and a debug provider for simulators. A
simulator debug token must be registered in the **dev** Firebase project only, never prod.

Two things live outside the code and are easy to miss:
- App Check **enforcement** is a per-service toggle in the Firebase console, separate from the
  `enforceAppCheck` flag here.
- Enabling enforcement breaks already-shipped app versions that predate the App Check wiring.
  Check App Check metrics for unverified traffic before turning it on.

Each release to `main` deploys them to prod (see Release (CD)). Outside a release, deploy with
`firebase deploy --only functions --project <id>`; it is not part of the Xcode build, so changes
under `functions/` have no effect until deployed, and the dev project is only ever deployed by hand.

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

The Production scheme builds at the default `-O`. Its test action has
`shouldAutocreateTestPlan = "NO"`, and that is load-bearing under **Xcode 27.0**:

- Xcode 27's auto-created test plan turns code coverage on, and the scheme applies that to every
  build through it, not only to tests. Production was being compiled with `-profile-generate
  -profile-coverage-mapping`.
- Coverage instrumentation plus `-O` crashes the Swift 6.4 compiler: an LLVM verifier failure,
  "Instruction does not dominate all uses", which Xcode shows as "Command SwiftCompile failed
  with a nonzero exit code". The function is the optimiser's specialised copy of
  `WeeklyReviewPresenter.init`, where `self.week` is assigned from a ternary. Without coverage
  the same source compiles.
- The crash is reported against whichever file is first in the target, because specialised code
  is emitted into the first file's unit. Do not chase the named file.
- A target-level `CLANG_COVERAGE_MAPPING = NO` does not help; the scheme overrides it. Check what
  a scheme resolves to with `xcodebuild -showBuildSettings -scheme … | grep CLANG_COVERAGE_MAPPING`.
- Editing the scheme in Xcode may write `shouldAutocreateTestPlan` back to `YES`. If Production
  stops compiling, look there first.

The Development and Mock schemes still auto-create a plan, so their builds are instrumented. They
compile at `-Onone`, where it is harmless.

Treat any new warning as something to
fix rather than accumulate.

Building a scheme does not compile the test target, so a warning in `CompoundUnitTests` shows up
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

`Components/Science/Citations.swift` and the five `MethodInfo+*.swift` files disable `line_length`:
they hold full references and user-facing prose, which read worse broken across lines.

Ten single-line `swiftlint:disable:next` comments also exist:
- `function_body_length` in `DevPreview.swift`, `CoreInteractor.swift` and
  `WorkoutSessionModel.swift`; in `Dependencies.swift` it also covers `cyclomatic_complexity`.
- `large_tuple` in `PushManager.swift` and `NutritionOverviewPresenter.swift`.
- `function_parameter_count` in `AddMealView.swift` and `ExpenditureEngine.swift`.
- `cyclomatic_complexity` in `WeightStepper.swift`.
- `no_rgb_color_literal` in `SignInWithGoogleButtonView.swift`, for the dark fill Google's
  branding guidelines fix.
