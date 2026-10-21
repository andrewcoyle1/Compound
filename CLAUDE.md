# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Compound is a training, nutrition and body-composition app. The app is the **Flutter** app in
`app/` (iOS and Android); its backend is Firebase, with Cloud Functions in `functions/`. The
SwiftUI app it replaced was removed on 20 Oct 2026 and lives on in the archive (see
[The SwiftUI app (archived)](#the-swiftui-app-archived)).

## Repository layout

```
app/                 # the Flutter app: lib/<feature>/{bloc,view}, packages/, ios/, android/
contracts/           # data shared by app/ and functions/: the Firestore contract, parity
                     #   fixtures and the bundled exercise catalogue (see contracts/README.md)
functions/           # Firebase Cloud Functions (Node, Genkit/Vertex AI)
hosting/             # Firebase Hosting public folder
scripts/             # flutter-ui-check.py, arb-spanish.py (+ data/), coach-parity-expected.mjs,
                     #   flutter-screenshots.sh, rest-chime.py
docs/                # specs (docs/specs/flutter/ for the app), research, reviews, privacy
firestore.rules, storage.rules, firestore.indexes.json, firebase.json
```

The app's icons are in `app/ios/Runner/AppIcons/`. The old exercise and equipment source art
(`AppIcons/`) and `Dialed.icon` were removed on 20 Oct 2026; they are in tag `swift-final`.

## Flutter app (`app/`)

The plan, the milestones and the parity table are in `docs/specs/flutter/`. Build agents read
`agent-brief.md` there first, and judgement calls made without the owner are logged in
`decisions.md`. Platforms: iOS first (iPhone and iPad), then Android.

- **Stack:** Very Good Core template with VGV layered architecture. Packages live in `app/packages/`
  and features in `app/lib/<feature>/{bloc,view}`. Bloc, go_router, very_good_analysis.
- **Flavors:**
  - `development` uses `compound-development`. Its iOS bundle id is `com.andrewcoyle.compound.dev`
    (the old Swift dev app's), with App Group `group.com.compound.app`.
  - `staging` uses in-memory fakes and no Firebase.
  - `production` (iOS only) uses the prod project `dialed-c3cb5` and the App Store app's ids:
    `com.andrewcoyle.compound`, its extension `com.andrewcoyle.compound.WorkoutSessionActivity` and
    `group.com.compound.app`. App Attest with a DeviceCheck fallback, RevenueCat (it refuses to
    start without `REVENUECAT_APPLE_API_KEY_PROD`), Remote Config A/B tests. Keys come from `*_PROD`
    entries in `dart_defines.json`. Build with
    `flutter build ios --release --flavor production -t lib/main_production.dart --dart-define-from-file=dart_defines.json`.
    Agents may read only prod's iOS app config, never write there. Android production is not configured.
  - Run with `flutter run --flavor development -t lib/main_development.dart` from `app/`.
- **Config is gitignored** because the repo is public: `app/dart_defines.json`,
  `lib/firebase_options_*.dart`, `google-services.json` and `GoogleService-Info.plist`. Regenerate
  the Firebase ones with `flutterfire configure` (the arguments are in
  `docs/specs/flutter/decisions.md`); `app/README.md` lists the `dart_defines.json` keys. CI copies
  `lib/firebase_options_{development,production}.dart.example`.
- **iOS native code** (Live Activity widget, App Intents, home-screen widget snapshot) is in
  `app/ios/WorkoutSessionActivity/` and `app/ios/Shared/`. Plugins come in through Swift Package
  Manager; there is no CocoaPods.
- **Tests:** use the very_good_cli MCP `test` tool. A hook blocks `very_good test` and
  `very_good create` in the shell. Packages are held to 100% coverage. Run the narrowest suite
  that could fail (`paths` for one file, `directory` for one package).
- **UI:** follow `docs/specs/flutter/ui-contract.md`. Reuse an `app_ui` widget before building one,
  and put any new component in `app_ui`, not the screen. Feature code uses tokens only and no raw
  Material buttons, rows, cards or dialogs; `scripts/flutter-ui-check.py` (CI) blocks new ones.
  `scripts/flutter-screenshots.sh` shoots the staging screens.
- **Strings:** user-facing strings use US spelling and are 100% Spanish. After adding English ARB
  messages (`app/lib/l10n/arb/`), run `python3 scripts/arb-spanish.py`. It copies the Spanish from
  the Swift app's catalog, kept at `scripts/data/Localizable.xcstrings`; translate whatever it
  lists by hand. CI runs `--check`.

## Shared data (`contracts/`)

`contracts/README.md` is the reference. In short:

- `contracts/firestore/` is the **Firestore contract**: every model's `full`, `minimal` and
  `legacy-*` documents, which must round-trip through the Dart models
  (`compound_models/test/contract_test.dart`). No Flutter code may write to a collection whose
  model fails it. App Store Swift clients still read these documents and silently drop any they
  cannot decode, so the shapes stay **frozen as Swift-compatible**: new fields optional, nothing
  renamed or retyped. `docs/specs/flutter/firestore-contract.md` has the rules.
- `contracts/fixtures/` holds the parity fixtures the Swift app recorded (`coach`, `nutrition`,
  `progression`, `tracker`, `program`) and the program-import samples. They are frozen; the Dart
  ports are now the source of truth.
- `contracts/catalogue/` holds the bundled `Prebuilt*.json`, embedded byte for byte by
  `training_library_repository` (regenerate with the commands in its README).
  `functions/data/PrebuiltExercises.json` must stay an exact copy of
  `contracts/catalogue/PrebuiltExercises.json`; `functions/coach.test.js` checks it.

## Calculations and their sources

Every figure the app works out for the user, rather than reads back from their logs, rests on a
published source and says so. The research behind each choice, with the full reference list, is
`docs/research/algorithms-evidence.md`; how each DOI and number was checked is
`docs/research/citation-verification-checklist.md`.

- `app/lib/science/method_info.dart` holds the catalogue of `Citation`s (named after the first
  author and year) and the `MethodInfo` for each calculation: a plain summary, the formula exactly
  as the code computes it, its limits, the constants that are Compound's own choices
  (`ownChoices`), and the citations. Cite only from it. Never present a design choice as a finding.
- `MethodInfoButton` is the ⓘ beside the figure and `MethodInfoHeader` puts it at a section
  header's trailing edge (`app/lib/science/view/method_info_button.dart`).
- **A new or changed calculation needs its `MethodInfo` updated in the same change**, and a button
  wherever it is shown.

The maths live in `app/packages/compound_maths` (energy, nutrition, volume) and
`app/packages/training_rules` (progression, tracker); each README maps them to their specs:

| Area | Method | Spec |
|---|---|---|
| Resting energy | Mifflin-St Jeor (default), revised Harris-Benedict, Cunningham 1980 when body fat is known (stored raw value `katchMcArdle`) | `docs/specs/adaptive-expenditure.md` |
| Formula expenditure | RMR × FAO/WHO/UNU 2004 PAL band (1.4 / 1.55 / 1.7 / 1.85 / 2.0), no exercise-frequency add-on, TEF shown as 10% | same |
| kcal per kg | `energyDensityKcalPerKg`: Forbes/Hall partition when body fat is known, else 7,700. The only conversion | same |
| Weight trend and expenditure | One Kalman filter (`ExpenditureFilter`, `weightTrend`): trend weight, intake, expenditure, with an SD and a calibrating state | same |
| Calorie target | Deadband controller (`evaluateTarget`, `proposeTarget`), at most weekly and ±150 kcal, adherence checked before lowering | same, and `docs/specs/weekly-check-in.md` |
| Nutrition targets | `proteinGrams`, `dailyMacros`, `calorieFloor`: protein tiers on a reference weight at BMI ≥ 30, fat floor, keto 30 g, sex-specific floors, rates as % of body weight | `docs/specs/adaptive-expenditure.md` |
| Strength | `estimatedOneRepMax` (Epley on reps + RIR, none past ten), `LoadIncrement`, `MesocycleDeload`, tapered warm-ups, rest by exercise type | `docs/specs/smart-progression.md` |
| Volume | `hardSets` (RPE ≥ 6, drops 0.5, secondaries 0.5), one 10–20 band with four tiers | `docs/specs/training-volume.md` |

## UI and the HIG

Check iOS UI work against Apple's live Human Interface Guidelines with the **`apple-hig` skill**
(user-level, `~/.claude/skills/apple-hig`), not from memory. If the skill is not installed, say so
and mark HIG claims as unverified.

```bash
python3 ~/.claude/skills/apple-hig/scripts/hig.py get tab-bars toolbars --platform ios
```

The app ships to iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). Pass `--platform ios` by
default and `--platform ipados` when the change affects layout or navigation at regular width.

**Precedence.** Where this project has already decided, the decision wins and the HIG fills in the
rest: `docs/specs/flutter/ui-contract.md` and the `app_ui` tokens. If a HIG page contradicts one of
those, report it with the source URL; do not change the contract from inside a feature.

| Area | Read |
|---|---|
| Tab shell, navigation (`app/lib/shell`) | `tab-bars`, `toolbars`, `searching`, `sheets`, `modality` |
| Onboarding (`app/lib/onboarding`) | `onboarding`, `privacy`, `healthkit`, `managing-notifications`, `sign-in-with-apple`, `managing-accounts` |
| Paywalls (`app/lib/paywall`) | `apple-in-app-purchase` |
| Active workout, Live Activity (`app/lib/workout_tracker`, `app/ios/WorkoutSessionActivity`) | `workouts`, `live-activities`, `playing-haptics` |
| Analytics and charts | `charting-data`, `charts` |
| Logging forms (food, sets, measurements) | `entering-data`, `pickers`, `text-fields`, `virtual-keyboards` |
| Lists and rows | `lists-and-tables`, `buttons`, `menus`, `context-menus` |
| Everything | `accessibility`, `typography`, `color`, `materials` |

**Reviews** go in `docs/reviews/`, one file per review, in the skill's finding format (severity,
`file:line`, quoted guideline with source URL, fix). State which appearances and text sizes were
actually checked.

## Backend (Cloud Functions)

`functions/` holds Firebase Cloud Functions v2 (Node, ES modules) using Genkit with Vertex AI.
Twelve `onCall` callables, all in `us-central1` except `coachChat`: `foodAnalyze`,
`mealDescribe`, `nutritionLabelAnalyze`, `imageGenerate`, `foodSearch`, `removeFollower`,
`acceptInvite`, `coachChat`, and four for Strava: `stravaConnect`, `stravaAccessToken`,
`stravaConnection` and `stravaDisconnect`. Strava's client secret lives only in the
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
  Imported runs and rides must show on the owner's own screens only, never anywhere followers see, per
  Strava's terms.
- `stravaWebhook` (HTTP; verify token in the `STRAVA_WEBHOOK_VERIFY_TOKEN` secret) only queues
  events in `strava_events`; `onStravaEventCreated` processes them: activity create, update and
  delete, and a deauthorization, believed only after a forced refresh fails, because webhooks are
  unsigned.
- Disconnecting, a refused refresh, deauthorization and account deletion all remove the
  connection and every imported activity.
- Removing a function from the source does not delete it: delete it by hand first
  (`firebase functions:delete <name> --project <id> --force`), or the release's
  `--non-interactive` deploy aborts.
- One-time setup per project: set `STRAVA_WEBHOOK_VERIFY_TOKEN`, deploy, then create Strava's
  push subscription (`POST https://www.strava.com/api/v3/push_subscriptions` with `client_id`,
  `client_secret`, `callback_url` = the deployed `stravaWebhook` URL, `verify_token`). Strava
  allows one subscription per app, so dev and prod need separate Strava apps.
- Strava's rate limits (200 requests per 15 minutes, 2,000 a day by default) are per **app**, not
  per athlete: every user's uploads, backfills and imports share them.

**AI coach** (`docs/specs/ai-coach.md`). `coachChat` (options `COACH_CALLABLE_OPTIONS`) answers
read-only questions about the caller's own data with Gemini 3.5 Flash (3.8 Flash as the last try)
on Vertex's `eu` multi-region endpoint, beside Firestore's `eur3`. It streams `{ text }` chunks and
returns `{ chatId, messageId, text, remainingToday }`. Checks run in order, so a refusal costs
nothing:
- Consent: `users/{uid}/private/settings.coach_consent === true`.
- Premium: RevenueCat REST v2 `active_entitlements`, with a V2 key that can only read customer
  information (`REVENUECAT_SECRET_KEY` secret; project id `REVENUECAT_PROJECT_ID` in
  `functions/.env.<project>`). A yes is cached five minutes, a 404 means not premium, any other
  failure answers `unavailable`, and `compound-development` skips the check.
- Quota: 50 messages a day in the user's timezone plus 5 a minute, in the server-only
  `coach_usage/{uid}`.

The model reads data only through the ten tools in `functions/coach.js`, one allowed area each;
there is no tool for Strava, progress photos or anything social, and tests enforce that. The
app's expenditure engine, formula TDEE, weight trend, estimated 1RM and weekly muscle sets are
copied in `functions/coach-maths.js`. `contracts/fixtures/coach-parity.json` is checked by both
`coach-maths.test.js` and `compound_maths`' `test/parity_test.dart`, so changing either copy
without the other fails a test. After changing the maths in both, rewrite its expected values with
`node scripts/coach-parity-expected.mjs`. Run `node scripts/coach-eval.js` from `functions/`
(application-default credentials, `GCLOUD_PROJECT=compound-development`) after changing the
prompt, the tools or the model.

**Streak reminder.** `streakReminder` reads the app's weekly streak from the private settings doc
(`week_streak`, `week_sessions`, `week_goal`, `week_ends_at`, `last_trained_at`) and pushes only
when every remaining day of the week is needed and none is logged today.

**App Check.** Every callable shares `CALLABLE_OPTIONS = { region: REGION, enforceAppCheck: true }`
(the Strava ones extend it as `STRAVA_CALLABLE_OPTIONS` with the secret) and calls
`requireAuth(request)`, which throws `unauthenticated` when `request.auth` is missing. Keep both
on any new callable: they are the only thing stopping an arbitrary rebuilt client from calling
the backend, since the Firebase API keys are public by design. The client activates App Check in
`app/lib/firebase_app.dart`, with the providers chosen per flavor in `app/lib/main_*.dart`: App
Attest with DeviceCheck fallback and Play Integrity in production, debug providers in
development. A debug token must be registered in the **dev** Firebase project only, never prod.
- App Check **enforcement** is a per-service toggle in the Firebase console, separate from the
  `enforceAppCheck` flag here.
- Enabling enforcement breaks already-shipped app versions that predate the App Check wiring.
  Check App Check metrics for unverified traffic before turning it on.

**Deploying and testing.** Each release to `main` deploys the functions to prod (see Release).
Outside a release, deploy with `firebase deploy --only functions --project <id>`; the dev project
is only ever deployed by hand. In `functions/`:
- `npm test` runs every `*.test.js` with `node --test`, no emulator: the pure helpers, the coach
  and its maths, a source check that every `onCall` takes `CALLABLE_OPTIONS` and opens with
  `requireAuth`, and more. The emulator-backed suites skip.
- `npm run test:triggers`, `test:rules` and `test:storage-rules` run those suites under the
  Firestore (and Storage) emulator; they need Java.
- `npm ci` needs the lock file in sync with `package.json`; if it fails with "Missing: … from lock
  file", run `npm install` and commit the lock.

## CI

Both workflows run on pull requests only.

- **`.github/workflows/flutter.yml`** runs on every PR. Its `Flutter changes` job checks whether
  the PR touches `app/`, `contracts/`, `scripts/flutter-ui-check.py`, `scripts/arb-spanish.py`,
  `scripts/data/` or the workflow itself; if not, every other job skips. The jobs: `Flutter app`
  (the app, through Very Good Workflows' `flutter_package.yml`, coverage reported, not gated), one
  job per package in `app/packages/` (held at 100%), `UI contract` (`flutter-ui-check.py`) and
  `Spanish strings` (`arb-spanish.py --check`). A reusable-workflow job reports as
  `<job name> / build`, for example `Flutter app / build`. **`Flutter CI`** always runs last and
  fails only if a job that ran failed or was cancelled; it is the check `main` requires. A new
  job must go in its `needs:` list and get the same `needs: changes` / `if:` pair as the others.
- **`.github/workflows/ci.yml`** runs `Cloud Functions unit tests` (`npm ci && npm test` in
  `functions/`, Node 22, Ubuntu) on every PR.

Every action in the workflows is pinned to a commit SHA, with its tag in a trailing comment, and
the release pins `firebase-tools` to an exact version: the release runs them with prod
credentials. Bump a pin deliberately, resolving the new tag with
`gh api repos/<owner>/<repo>/commits/<tag> -q .sha`. Lint the workflows with
`actionlint -ignore 'label "xcode-27" is unknown' .github/workflows/*.yml`.

## Release

`.github/workflows/release.yml` runs on every push to `main`, which the ruleset allows only by a
merged PR whose checks passed. Both jobs use the **`release`** environment: it accepts `main` only,
holds the secrets, and waits for the owner's approval. Each run, and each **re-run** of a job,
needs approving again. The TestFlight job `needs` the Cloud Functions job, so the backend is
always deployed first and a failed deploy stops the upload; it therefore asks for its own approval
once the deploy finishes. App Review submission stays manual in App Store Connect.

**TestFlight job**: the Flutter app, production flavor. Flutter 3.47.7 (`subosito/flutter-action`,
pinned), the three gitignored config files from secrets (`FLUTTER_DART_DEFINES`,
`FLUTTER_FIREBASE_OPTIONS_PROD`, `FLUTTER_GOOGLE_SERVICE_INFO_PROD`, base64 of
`app/dart_defines.json`, `app/lib/firebase_options_production.dart` and
`app/ios/flavors/production/GoogleService-Info.plist`; update a secret whenever its file changes),
`flutter build ios --config-only --flavor production`, then `xcodebuild archive` of
`ios/Runner.xcworkspace`, scheme `production`, and an upload with an App Store Connect API key
(`ASC_API_KEY_P8`, `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`; Admin role, because cloud-managed
distribution signing needs it). `manageAppVersionAndBuildNumber` takes the next free build number.
The export is not internal-only, so a release build can go to external testers and App Review.

- **Development certificates.** The archive step creates an Apple Development certificate
  ("Created via API") for each throwaway runner; at the account's limit of twelve the archive
  fails with "Your account has reached the maximum number of certificates" (20 Oct 2026, after a
  month of releases). The job's last step runs `scripts/revoke-ci-dev-certificates.mjs`, which
  revokes every development certificate named "Created via API". Certificates made in Xcode carry
  the owner's name and are never touched.
- It runs on the **`xcode-27`** runner image (a GitHub preview), Xcode 27.0. Unknown to
  actionlint, hence the `-ignore` above.
- `KEYS_SWIFT` and `GOOGLE_SERVICE_INFO_PROD` were the Swift build's secrets; nothing reads them now.

**Cloud Functions job**: deploys to `dialed-c3cb5` as the **`github-release`** service account
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
  it and merge back into it. Delete the branch and its worktree on merge.
- **`main`** is the release branch. Merges into it are periodic, by pull request from
  `development`, and the repository owner decides when. Do not merge or push to `main` unprompted.

CI runs on pull requests only, so a direct push to `development` is not checked by CI: run the
affected Flutter tests and `npm test` in `functions/` locally first.

`main` is protected by the **Protect main** ruleset: no direct pushes, force pushes or deletion,
and a PR merges only once its required checks have passed on a branch up to date with `main`.
Those are `Cloud Functions unit tests` and `Flutter CI` (the summary job above, so a PR that
changes nothing Flutter still reports). The ruleset is edited in GitHub's settings or with
`gh api repos/andrewcoyle1/Compound/rulesets/24390967`.
Each merge then starts `.github/workflows/release.yml` (the push itself, not a second CI run),
which waits for the owner's approval on the `release` environment, uploads to TestFlight from the
`xcode-27` image and deploys Cloud Functions to prod.

Before reviewing or changing code, `git fetch` and confirm the checkout is level with
`origin/development`. Do not order branches by commit date, because a merge commit is stamped
when it is merged: compare what each side has that the other lacks
(`git rev-list --count --no-merges A..B`).

## The SwiftUI app (archived)

The SwiftUI app (`Compound/`, `Compound.xcodeproj`, its unit and UI tests, widget extension and
SwiftLint config) was removed from this branch on 20 Oct 2026. It is preserved on GitHub:

- tag **`swift-app-store`**: exactly what is released on the App Store;
- tag **`swift-final`** and branch **`archive/swift`**: the newest Swift code.

Never delete or move them. Read the Swift source there (`git show swift-final:<path>`) when a spec
in `docs/` names a Swift file, or to check that a Firestore change stays readable by App Store
Swift clients. Its build, test, architecture and design-system notes are in that version of this
file.
