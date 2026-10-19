# Compound in Flutter: build plan

Flutter replaces the SwiftUI app: Android first, then iOS. Agreed 14 Oct 2026; work started the same evening. Judgement calls made during the build are logged in [decisions.md](decisions.md).

### Decisions already made
- **Flutter replaces the SwiftUI app** on both platforms: Android first, iOS at M6.
  - From "go", the Swift app gets **fixes only**, because new Swift features would be thrown
    away.
  - It keeps shipping to iOS users until M6.
- **Lives in `app/` in this repo** and shares `functions/`, `firestore.rules`, the fixtures and CI.
- **Stack:**
  - Very Good Core (`very_good create flutter_app`) using the VGV **layered architecture**:
    `packages/*_repository` plus `lib/<feature>/{bloc,view}`, Bloc/Cubit, go_router.
  - The Wingspan cycle (brainstorm → plan → technical review → build → review) per feature slice.
- **Flavors:** `development` → `compound-development`, `production` → `dialed-c3cb5`, and
  `staging` repurposed as the old Mock: in-memory repositories, no Firebase, for previews and
  demos.
- **No sync-engine port.** Repositories sit directly on `cloud_firestore` (`withConverter`,
  `Stream`/`Future`), and Firestore's own disk cache and write queue do the offline work.
- **soaring_\* packages:**
  - Don't use the two data-manager packages. They have a cross-user cache bug, re-introduce
    sync bugs Swift has since fixed, and duplicate Firestore's own cache.
  - Use soaring_auth and soaring_auth_firebase as *reference only*: write `auth_repository`
    fresh on firebase_auth 6 and google_sign_in 7 with constructor injection. Their linking and
    reauthentication logic is the part worth copying.
  - Fold soaring_logging into an `analytics_repository` (Mixpanel, Firebase Analytics,
    Crashlytics). Fix its broken test mock and limit event parameter values to String and num.
- **Coverage:** 100% on `packages/` (VGV gate) and reported for `lib/`. Raising `lib/` to 100% is
  a later call.

### Decisions from 14 Oct 2026 discussion
- **Look:** Compound's **own brand design system** (`app_ui`) on both platforms, not Material 3 and
  not Cupertino. Platform touches only where users expect them: back-swipe, sheets, adaptive
  switches/pickers, haptics, and system fonts with Dynamic Type. Liquid Glass can't be reproduced
  exactly, so iOS users will notice the change at M6; that trade is accepted.
- **Daily development on the iOS Simulator**, with a regular check on the Android emulator. The
  Flutter iOS dev build first used bundle id `com.andrewcoyle.compound.flutter.dev` so it installed
  alongside the Swift dev app; since 16 Oct 2026 it uses the Swift dev app's `com.andrewcoyle.compound.dev`
  and replaces it (`decisions.md`).
- **M2 (read-only mirror) stays.**
- **Android 1.0 ships at full parity**: social, coach, programs and Strava are all in. M4 becomes
  an internal milestone, and the public release moves to the end of M5.

### How the build runs
- **Hands-off:** the user expects to leave it running overnight.
- **Integration branch `feature/flutter`** off `development`.
  - Each slice is a PR into it, merged once its checks pass.
  - In the morning the user gets one PR, `feature/flutter` → `development`.
  - `development` is never touched without the user.
- **Claude approves each slice's brainstorm and plan** against this plan, and logs every judgement
  call in `docs/specs/flutter/decisions.md`. It stops only for something outside the plan: a new
  paid service, a change to Swift code, or anything touching prod.
- **Firebase: the dev project only** (`compound-development`), and only once M1 starts.
  - Register the Android app `com.andrewcoyle.compound.dev`; iOS uses the Swift dev app's
    registration, `com.andrewcoyle.compound.dev` (originally `com.andrewcoyle.compound.flutter.dev`).
  - Add the debug SHA fingerprints and the App Check debug provider.
  - Never touch `dialed-c3cb5`.
- **Pace:** M1 runs the scaffold first and alone, then `app_ui`, the contract harness and the strings
  conversion as parallel agents in worktrees. M2 onward runs mostly serially, with pure-logic ports
  (maths, tracker rules) running in parallel alongside.

### Package layout (`app/`)
```
app/lib/<feature>/{bloc,view}            features (today, training, nutrition, …)
app/packages/compound_models/            pure Dart: every Firestore-shaped model + contract tests
app/packages/compound_maths/             pure Dart: ExpenditureFilter, TargetProposal, NutritionTargets,
                                         1RM, MuscleVolume, progression (parity-tested)
app/packages/app_ui/                     tokens from Compound/Components/DesignSystem (Spacing, Radius,
                                         Palette, Typography, Motion, Format) + primitives (Card, Stat, Chip…)
app/packages/compound_charts/            charts on app_ui's tokens (CustomPainter, no chart library)
app/packages/auth_repository/            firebase_auth + google_sign_in 7 (+ Apple at M6)
app/packages/<domain>_repository/        one per Swift manager, each taking FirebaseFirestore
contracts/firestore/                     shared fixtures (repo root: Swift, Dart and functions read them)
```
Strings: a script converts `Compound/Localizable.xcstrings` to ARB (en and es), so the existing
Spanish carries over, and the 100% Spanish rule continues as an ARB check.

### The Firestore contract
See [firestore-contract.md](firestore-contract.md). In short: shared fixtures in `contracts/firestore/`, checked by a Swift test with the real Firestore encoder and decoder and by a Dart test, so a Flutter write can never produce a document the Swift app can't read.

### Milestones (each ends in an installable build and a demo)
| # | Milestone | Scope | Exit criteria |
|---|---|---|---|
| **M0** | Toolchain | Flutter 3.47.7, very_good_cli 1.5.0, Android SDK, JDK 21 | Done 14 Oct 2026 |
| **M1** | Foundation | Scaffold `app/`; flavors; Firebase apps (dev project) and App Check; `auth_repository` (Google, anonymous); `user_repository`; `app_ui` tokens; ARB strings; contract harness on both sides with **UserModel and PrivateUserSettings**; Flutter CI job | The development flavor, on the iOS Simulator and the Android emulator, signs into an *existing* account on `compound-development` and shows its profile; CI green; contracts pass |
| **M2** | Read-only mirror | Today, workout history and session detail, the meal log day, weight trend, basic progress. Contracts for the session, meal log, measurement, goal and settings trees, used **read-only** | One account side by side on the iOS app and the Android emulator shows identical data. No writes yet, so there's no corruption risk while decoding is checked against real data |
| **M3** | Logging MVP (first writes) | Onboarding 0–9 (`OnboardingStepRouter` logic); exercise library and prebuilt seeding; workout tracker (templates, sets, rest timer, finish, Android ongoing notification); food logging (`foodSearch`, quick add, barcode); weigh-in. Contract and rules tests for every written model | Data written on Android opens unchanged on iOS (contracts plus a manual cross-check). Play Console account created once this build is worth releasing (user's call); closed test then starts the 14-day clock if it's a personal account |
| **M4** | Engine and monetization (internal) | `compound_maths` ported, checked against `coach-parity.json` plus new fixtures recorded from the Swift suites (`ExpenditureFilterTests`, `TargetProposalTests` …); weekly check-in; Progress tab; paywall (RevenueCat Play); FCM push including the streak reminder | Internal build with maths parity, check-in, Progress, paywall and push all working |
| **M5** | Android parity and 1.0 | Programs (meso/macrocycles); social (feed, follows, comments, challenges, invites, shares); AI coach (streaming `coachChat`); Strava (OAuth via app link); Health Connect; progress photos; AI food scanners; notifications inbox; the rest of settings; deep links | A parity checklist made from the 198 modules in `docs/codebase-map.md` is fully ticked, then **Android 1.0 goes public** on Play (Play Console account created by then) |
| **M6** | iOS on Flutter, SwiftUI retired | iOS flavors under the existing bundle ids; HealthKit through `health`; Live Activity and widgets: keep the `WorkoutSessionActivity` Swift extension, driven over a platform channel and an App Group; Sign in with Apple; iPad layouts; Siri/App Intents and Mac Catalyst (keep natively, or drop: decided then). Before the switch, a final Swift release that flushes pending local writes. RevenueCat (uid) and Strava (server-side) carry over | TestFlight side by side, then an App Store update of `com.andrewcoyle.compound` from Flutter. Contracts flip to Dart as the source of truth; the Swift targets are removed |

Each milestone is a sequence of PR-sized slices into `feature/flutter`, one feature area per Wingspan
cycle. `feature/flutter` reaches `development` only by a PR the owner reviews.

### Known risks
- **Tracker complexity.** The workout tracker is about 27k Swift lines and 40+ test suites. Port
  its pure rules (`ActiveWorkout+*`, correction, propagation, progression) as Dart unit tests
  first, then the UI.
- **Maths drift.** There are three copies until M6 (Swift, JS, Dart). The shared fixtures are the
  guard.
- **Unsynced data at the switch.** At M6, local-only Swift data (SwiftData pending writes) doesn't
  migrate into Flutter's Firestore cache. A final Swift release that flushes on launch handles
  this.

