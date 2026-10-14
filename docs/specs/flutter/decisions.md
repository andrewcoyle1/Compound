# Flutter build: decisions log

Judgement calls made while building without the owner present. Each entry says what was decided,
why, and what would change it. Review these with the `feature/flutter` → `development` PR.

| Date | Slice | Decision | Why | Revisit if |
|---|---|---|---|---|
| 14 Oct 2026 | Plan | Integration branch `feature/flutter`; slice PRs merge into it after CI | Agreed with the owner for hands-off overnight work | — |
| 14 Oct 2026 | M1 scaffold | Android and iOS only; the template's web, macOS and Windows folders were removed | Those are the shipping platforms. Mac Catalyst's replacement is an M6 decision | macOS is wanted at M6 |
| 14 Oct 2026 | M1 scaffold | iOS `development` = `com.andrewcoyle.compound.flutter.dev`, `staging` = `…flutter.stg`; `production` stays `com.andrewcoyle.compound` | Dev builds install beside the Swift dev app; production must become the App Store app at M6 | — |
| 14 Oct 2026 | M1 scaffold | Removed the template's MIT `LICENSE` and its `app/.github` | The repo is proprietary; GitHub never runs workflows from a subfolder | — |
| 14 Oct 2026 | M1 CI | `ci.yml` skips PRs into `feature/flutter`; `flutter.yml` runs only for `app/`, `contracts/` or itself | Slice PRs don't touch Swift, and the Swift jobs take about 30 minutes each. The `feature/flutter` → `development` PR still runs everything | A slice has to change Swift code |
| 14 Oct 2026 | M1 CI | App coverage `min_coverage: 0` (reported); packages are held to 100% in their own tests | As planned: the app's screens churn in the early milestones | M5 |
| 14 Oct 2026 | M1 Firebase | Firebase config files are gitignored, with a placeholder `.example` for CI | **The repo is public.** This matches the Swift app's gitignored plists | — |
| 14 Oct 2026 | M1 Firebase | Registered in `compound-development` only: iOS `1:672259004423:ios:3d911896a395a5599332a2`, Android `1:672259004423:android:a28ac39f010d67f09332a2`, and the standard debug keystore's SHA-1/256 (keystore created on this Mac) | Agreed with the owner: dev project only | — |
| 14 Oct 2026 | M1 contract (#83) | Timestamps in fixtures have millisecond precision, with exactly 3 digits | Swift `Date` is a Double, so sub-microsecond noise can't round-trip | A model needs finer precision |
| 14 Oct 2026 | M1 contract (#83) | Legacy cases come in pairs with `.expected.json` (what Swift writes back after reading them) | Swift and Dart then check exactly the same thing | — |
| 14 Oct 2026 | M1 contract (#83) | Dart decoding is as strict as Swift: an unknown enum value, a missing required field or a wrong type throws (Doubles accept ints) | Swift silently drops documents it can't decode, so Dart must not be more lenient | — |
| 14 Oct 2026 | M1 contract (#83) | Field-name constants go in `…Keys` classes; the Dart models are generated from one field table | The constructor, decoding, encoding and keys can't drift apart | — |
| 14 Oct 2026 | M1 contract (#83) | A `compound_models` CI job at 100% coverage, pinned to Dart 3.13.5 | The app job runs at 0% and wouldn't enforce the package | — |
| 14 Oct 2026 | M1 app_ui (#84) | Colours use the iOS system values, so the Flutter and Swift apps match; the accent is `colorScheme.primary` and on-accent is `onPrimary` | One brand on both platforms | The brand palette changes |
| 14 Oct 2026 | M1 app_ui (#84) | Secondary text is darker than iOS (`#6C6C70` light, `#AEAEB2` dark) | It passes 4.5:1 contrast | — |
| 14 Oct 2026 | M1 app_ui (#84) | System font with iOS sizes and tabular figures, not SF Rounded | SF Rounded can't be bundled on Android | A brand font is chosen |
| 14 Oct 2026 | M1 app_ui (#84) | Icons are Flutter's built-in Material Icons (rounded); no new package | No extra dependency | An icon set is chosen |
| 14 Oct 2026 | M1 app_ui (#84) | `AppFormat` only formats numbers and unit symbols; words and plurals live in the app's ARB strings | app_ui stays free of translations | — |
| 14 Oct 2026 | M1 app_ui (#84) | Deferred to the first screen that needs them: Dashboard, BarChip, sheet presets, `Format.load`, haptics | YAGNI | — |
| 14 Oct 2026 | Maths (#85) | `compound_maths` ports `functions/coach-maths.js` and is checked against `coach-parity.json` with the Swift and JS tolerance (1e-6) | Three copies of the maths, one fixture | — |
| 14 Oct 2026 | Maths (#85) | Dates are `YYYY-MM-DD` day keys, as in the JS; age is passed in by the caller (default 30) | No clock inside the maths | — |
| 14 Oct 2026 | Maths (#85) | `median([])` returns null, as in Swift (the JS returns NaN) | A straight port would crash on a log with no weigh-ins | — |
| 14 Oct 2026 | M1 auth (#86) | `production` flavor throws `UnsupportedError` at launch | The prod Firebase project is out of bounds until the owner decides | M4/M6 |
| 14 Oct 2026 | M1 auth (#86) | Staging starts signed in as `mock_user_123` (alice@example.com, "Alice Cooper"); sign out and sign in work in memory | Staging is the mock build (owner's requirement) | — |
| 14 Oct 2026 | M1 auth (#86) | Linking: signing in from an anonymous account links the provider; if the credential belongs to another account, sign in to that one instead | Same behaviour as SwiftfulAuthenticating | — |
| 14 Oct 2026 | M1 auth (#86) | `userChanges()` rather than `authStateChanges()` | Linking must update the AppBloc | — |
| 14 Oct 2026 | M1 auth (#86) | iOS: an in-repo build phase copies the flavor's gitignored `GoogleService-Info.plist` and adds its `REVERSED_CLIENT_ID` URL scheme; Sign in with Apple entitlement on development only | Nothing secret committed; no flutterfire CLI needed at build time | — |
| 14 Oct 2026 | M1 auth (#86) | Android: google-services plugin 4.4.4 with `missingGoogleServicesStrategy = WARN`; Kotlin 2.2.20 | Staging and production have no `google-services.json`; Flutter 3.47 rejects Kotlin 2.2.10 | — |
| 14 Oct 2026 | M1 check | Registered App Check debug token `Flutter dev - iPhone 17 simulator (12E2A36D)` on the Flutter iOS dev app | Firestore and Auth aren't enforced in dev, but callables enforce App Check in code (M3 and later) | — |
| 14 Oct 2026 | M2-1 (#87) | A set's `side`, `kind` and `weight_unit` stay as the stored strings, with typed getters | A value a newer build writes survives a Dart round trip | — |
| 14 Oct 2026 | M2-1 (#87) | Int fields accept whole-number doubles, as Swift's decoder does | Parity with Swift | — |
| 14 Oct 2026 | M2-1 (#87) | The repository returns `compound_models` types directly; documents that fail to decode are skipped and reported | Same as Swift; no separate domain model needed yet | Domain logic diverges from storage |
| 14 Oct 2026 | Nutrition engine (#89) | Nutrition rules join `compound_maths`, checked against `nutrition-parity.json`: 741 cases run through the real Swift, including `NutritionManager.computeDietPlan`, with 1e-6 tolerance | One fixture, recorded from Swift | — |
| 14 Oct 2026 | Nutrition engine (#89) | Goals come in as numbers (signed rate, target weight); the caller filters by goal status. `ProteinIntake`, `PreferredDiet` and `CalorieDistribution` live in compound_maths | No dependency from the maths on the models | — |
| 14 Oct 2026 | Nutrition engine (#89) | `TargetProposal.Reason` dropped (it had one case); `CalorieFloor` became `calorieFloor(gender)` | Simpler API, same behaviour | A second reason appears |
| 14 Oct 2026 | M1 shell (#90) | Five tabs (Today, Training, Nutrition, Progress, Social), each with its own navigation stack; paths `/today`…`/social` match the Swift `compound://tab/<name>` deep links | Parity with the Swift tab bar and deep links | — |
| 14 Oct 2026 | M1 shell (#90) | Profile is a full-screen route from a button in every tab's app bar; unset values show "Not Set" | Matches the Swift full-screen cover | — |
| 14 Oct 2026 | M1 shell (#90) | The 8-line Timestamp converter is copied per repository rather than shared | Too small to justify a package yet | A third repository needs it (extract then) |
| 14 Oct 2026 | M1 shell (#90) | `--dart-define=INITIAL_LOCATION` sets the start screen, for screenshots | The simulator can't be tapped from automation | — |
| 14 Oct 2026 | M2-3 (#91) | One `nutrition_repository`; `watchMeals` applies the Apple Health de-duplication itself | No screen can count food twice | — |
| 14 Oct 2026 | M2-3 (#91) | Missing or undecodable food-log settings come back as Swift's defaults; a missing diet plan comes back as null | Parity with Swift | — |
| 14 Oct 2026 | M2-3 (#91) | Fixture tag `{"$double": "NaN"}` (input only) for NaN/inf cases | JSON can't hold NaN | — |
| 14 Oct 2026 | Training rules (#92) | `training_rules` is pure Dart with local value types (not `compound_models`) for now; a later slice maps the models onto them | The training models were landing in parallel | The tracker UI slice |
| 14 Oct 2026 | Training rules (#92) | Rules that return words (log titles, spoken labels, badges) are ported as decisions (`ProgressionReason`, `NextPiece`, `SetProblem`); the words go in ARB | Translations live in the app | — |
| 14 Oct 2026 | Training rules (#92) | Progression is checked against `progression-parity.json`: 830 deterministic cases recorded from Swift | The riskiest logic gets the broadest fixture | — |
| 15 Oct 2026 | M2-2 (#93) | History is reached from a minimal Training home (Library › Workout History, `/training/history`); detail at `/training/history/:sessionId` | Mirrors the Swift Training home's library entry | — |
| 15 Oct 2026 | M2-2 (#93) | Row volume uses the unit most sets were logged in (tonnes from 1,000 kg), as Swift's row does; the detail total uses the profile's weight unit | Parity with Swift | — |
| 15 Oct 2026 | M2-2 (#93) | Unlike Swift, the detail lists warm-up sets and set-kind chips; only RPE shows, since RIR isn't stored on sets | More complete read-only view | The owner prefers Swift's layout |
| 15 Oct 2026 | M2-2 (#93) | Follow-up: bodyweight sets show "@ 0 kg"; Swift's treatment should be matched | Found in the screenshot review | — |
| 15 Oct 2026 | M2-5 (#94) | One `body_repository` holding body measurements, steps, analytics settings and the current goal; deleted entries are left out, lists come oldest first | One read-only source for the body screens | — |
| 15 Oct 2026 | M2-5 (#94) | An empty `currentGoalId` falls back to the uid (Swift would crash on an empty document id); the staging goal is stored under the uid | Safer than Swift, same behaviour otherwise | — |
| 15 Oct 2026 | M2-5 (#94) | Step goal default 8,000 as in Swift; the age-adjusted goal belongs to the Today slice | Matches Swift's split | — |
| 15 Oct 2026 | M2-4 (#95) | The calendar is a swipeable week strip rather than Swift's year-long scroller; marks are keyed by `day_key` | Simpler, and correct across time zones | The owner wants the long scroller |
| 15 Oct 2026 | M2-4 (#95) | The macro header changes page on tap or swipe rather than a `PageView` (which breaks at large text sizes); F/P/C letters become icons | Accessibility at large text sizes | — |
| 15 Oct 2026 | Analytics (#96) | Event names and `uauth_*` keys match Swift; parameters are cleaned like the Swift service (String/num only, bool → 1/0, dates ISO 8601, lists as sorted text, 40/100/25 limits) | Analytics stay continuous across the two apps | — |
| 15 Oct 2026 | Analytics (#96) | No names or emails go to Firebase Analytics or Crashlytics; Mixpanel gets them on identify only | Google Analytics' terms forbid personal data (Swift sends them; see findings) | — |
| 15 Oct 2026 | Analytics (#96) | The Mixpanel token comes from the gitignored `app/dart_defines.json` (`MIXPANEL_TOKEN`); empty means Mixpanel is off | Public repo | — |
| 15 Oct 2026 | Analytics (#96) | A failing analytics service is logged and swallowed | Analytics must never break the app | — |

To regenerate the gitignored dev config, run this from `app/`:

```bash
flutterfire configure --project=compound-development --platforms=ios,android \
  --ios-bundle-id=com.andrewcoyle.compound.flutter.dev --android-package-name=com.andrewcoyle.compound.dev \
  --out=lib/firebase_options_development.dart \
  --ios-out=ios/flavors/development/GoogleService-Info.plist --ios-build-config=Debug-development \
  --android-out=android/app/src/development/google-services.json --yes
```
