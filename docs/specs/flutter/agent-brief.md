# Brief for agents building the Flutter app

Read this first, then `plan.md` and `firestore-contract.md` in this folder. `CLAUDE.md` at the repo
root describes the Swift app you are porting, and `docs/codebase-map.md` locates any Swift screen,
manager or model by name.

## Where you work
- **Your own git worktree and branch,** as named in your task. Branch from `feature/flutter`, and
  open your PR **into `feature/flutter`**. Never push to `development` or `main`, and never merge a
  PR yourself: the orchestrating session merges once CI passes.
- **The Flutter app is `app/`** (Very Good Core, flavors `development`, `staging` and `production`).
  New packages go in `app/packages/<name>/`, referenced by path from `app/pubspec.yaml`.
- **Do not edit the Swift app** (`Compound/`, `Shared/`, `WorkoutSessionActivity/`). Tests under
  `CompoundUnitTests/` and `functions/` are allowed only where your task says so.

## How you build
- **Use the VGV skills** through the Skill tool: `vgv-ai-flutter-plugin:layered-architecture`,
  `:bloc`, `:testing`, `:ui-package`, `:internationalization`, `:navigation`, `:accessibility`.
- **Use the `very_good_cli` MCP tools** (`create`, `packages_get`, `test`). A hook refuses any
  shell command containing `very_good test` or `very_good create`, and that includes text inside
  a commit message passed with `-m`. Write such messages to a file and commit with `-F`.
- **Toolchain:** Dart 3.13, so use primary constructors where the skills ask for them. Lints come
  from very_good_analysis 11.
- **Architecture:**
  - Repositories take every SDK object (`FirebaseFirestore`, `FirebaseAuth`, `GoogleSignIn`)
    through the constructor. Blocs and Cubits hold the state. Widgets never touch a repository
    or Firebase directly.
  - **Firestore writes never wait for the server.** Wrap every `set`, `update` and batch
    `commit` in `writeLocally` and take an `onWriteError` (`WriteErrorReporter`) in the
    constructor (`firestore-contract.md`, Policy). A repository's write future then means
    "saved on this device"; a later refusal by the server goes to `onWriteError`, not the
    caller. So a bloc can await a save offline, and its failure state covers only an error
    raised while starting the write. Never await a raw cloud_firestore write future.
- **Widget tests fail after 30 seconds** (`app/test/flutter_test_config.dart`); never raise it.
  A timeout means the test hangs. The usual causes:
  - awaiting, in a `testWidgets` body, something only a pump completes, such as a fake
    stream's `.first` or a cubit future (pump first, or use `tester.runAsync`);
  - `addTearDown(bloc.close)` on a bloc its `BlocProvider` already closes.
- **The very_good MCP `test` server is shared by every agent and runs one request at a time.**
  Run your new test files first and fix any hang; run the whole suite only once they pass.
- **Swift work happens in your own worktree,** never in `/Users/andrewcoyle/Compound`, which is
  the owner's checkout.
- **The `staging` flavor is the mock build.** It has no Firebase, and the app must be fully usable
  in it.
  - Every repository has an in-memory implementation alongside its Firebase one.
  - `main_staging.dart` wires those in, seeded with realistic sample data in the spirit of the
    Swift app's `.mock` values: a signed-in user, workouts, meals, weigh-ins and the rest.
  - Every screen you build must work in staging. Check it with
    `flutter run --flavor staging -t lib/main_staging.dart` on a simulator if your task allows
    one; otherwise widget-test the screen with the in-memory repositories.
- **Coverage:** packages under `app/packages/` must reach **100%**. The app itself is reported
  only. Run the package's tests with the MCP `test` tool and `min_coverage: "100"`.
- **Before you push:** `dart format`, `flutter analyze` with no issues, and tests passing.

## Never
- **Commit Firebase config.** The repo is **public**.
  - `lib/firebase_options_*.dart`, `google-services.json` and `GoogleService-Info.plist` are
    gitignored.
  - Real copies exist only in `/Users/andrewcoyle/Compound/app/`. Copy them into your worktree
    if you need to run the app.
  - CI uses `lib/firebase_options_development.dart.example`.
- **Touch the production Firebase project** (`dialed-c3cb5`) or any prod resource. Only
  `compound-development` exists for Flutter.
- **Add a paid service, change Swift app code, or deploy anything.** Stop and report it instead.
- **Write to Firestore** from a repository whose model has no passing contract on both sides
  (`firestore-contract.md`).

## When you finish
1. Commit, ending each message with the attribution lines your task gives you.
2. Push, and open a PR into `feature/flutter`.
   - In its body, include a **Decisions** section listing every judgement call: what you chose,
     why, and what would change it. The orchestrator copies these into `decisions.md`, so don't
     edit that file yourself; parallel edits would conflict.
3. Report back in under 300 words:
   - the PR URL;
   - what is done and what isn't;
   - the decisions;
   - anything blocked;
   - the test and coverage results.
