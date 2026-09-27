# UI framework: fan-out plan

Turns `docs/ui-audit.md` into fifteen work packages (WPs) for parallel agents. Each WP file is
written for a fresh agent with no context beyond `CLAUDE.md`, `docs/codebase-map.md`,
`docs/ui-audit.md`, `CONTRACT.md` and its own file.

`CONTRACT.md` is the one place names are decided. Wave 1 creates the tokens and Wave 2 the
primitives; Wave 3 agents only consume them. An agent that wants a token or primitive that does
not exist adds nothing: it uses the nearest existing one and lists the gap in its report.

## Waves

| Wave | WPs | Parallel | Starts when |
|---|---|---|---|
| 1 Foundation | 01 Tokens, 02 Dead code, 03 Bug fixes, 04 Shell | 4 | now |
| 2 Primitives | 05 Surfaces, 06 Rows & inputs, 07 Actions & scaffolds | 3 | WP-01 and WP-02 merged |
| 3 Migration | 08 Nutrition, 09 Active workout, 10 Training library, 11 Dashboard & social, 12 Profile & paywalls, 13 Onboarding, 14 Analytics | ≤4 at a time | all of Wave 2 merged |
| 4 Lock-in | 15 Cleanup, lint rules, strings, docs | 1 | all of Wave 3 merged |

Suggested Wave 3 order: 09, 08, 14, 12 first (largest), then 10, 11, 13 as slots free.

## Ownership

Every WP lists the paths it **owns**. It may edit only those, plus new files it creates in its
own folders. Anything else it needs changed goes in its report. This is what keeps merges clean.

Files no WP may commit changes to, and why:

| File | Rule |
|---|---|
| `DialedIn/Localizable.xcstrings` | Every build rewrites it. Run `git checkout -- DialedIn/Localizable.xcstrings` before each commit. List new or changed user-facing strings in the report; WP-15 translates them. |
| `DialedIn.xcodeproj/project.pbxproj` | Folders are synchronized, so new, moved and deleted files need no project edit. If you think you need one, stop and report. |
| `Screenshots/` | Only WP-15 regenerates the committed deck. Agents may run the deck into their own worktree to look at it, but do not commit it. |
| `docs/codebase-map.md`, `CLAUDE.md` | WP-15 only. |
| `Root/Dependencies/*`, `Root/RIBs/Core/CoreInteractor*.swift` | Nobody. This is UI work; no manager wiring should change. |

## Rules for every WP

- Read `CLAUDE.md`, then `CONTRACT.md`, then your WP. Work in your own worktree **outside** the
  repo, `~/.wt-wpNN`, on branch `ui/wpNN-<slug>` cut from `feature/ui-framework`. Use
  DerivedData `~/.dd-wpNN` via `-derivedDataPath`.
- Build with the `DialedIn - Development` scheme. Compile the tests with `build-for-testing` after
  your last change, because protocol and API changes break test doubles on other branches.
- **Tests:** run only suites you added or changed, once, at the end, with
  `-only-testing:DialedInUnitTests/<Suite>` and `-skip-testing:DialedInUITests`. Never the full
  suite. Presenter logic you change (new haptic calls, new formatting) gets a test. Pure visual
  changes do not.
- **Visual check** (Wave 3): run `DERIVED=~/.dd-wpNN scripts/screenshots.sh --diff <your-sim-udid>`
  once before you start and once at the end. Open the changed images and confirm each change is
  intended. Create your own simulator (`xcrun simctl clone` or `create`), boot it by UDID, and
  delete it when done. The shared one gets shut down under you otherwise.
- `swiftlint` zero violations and zero new build warnings before every commit. `@available(…,
  deprecated:)` warnings from Wave 2 are the exception: they are the migration to-do list, and
  Wave 3 removes them.
- One logical change per commit, message prefixed `[UI]`, `[Fix]` or `[Chore]` like the existing
  history. A real bug found on the way is fixed in its own `[Fix]` commit with a test that would
  have caught it. Verify it is real first by tracing call sites.
- Keep behaviour. This is a styling and structure pass. The only intended behaviour changes are
  the bug fixes and the pattern changes the WP names, such as haptics and toolbar roles.
- **Clean up.** Kill every process you start. Bound any wait loop with a timeout. Delete your
  simulator. Before reporting, confirm `pgrep -f xcodebuild` shows none of yours.
- **Report:** commits (hash and title), what changed, the tests added with pass counts from the
  result bundle, any strings added or changed, gaps in the contract, and anything left undone and why.

## Orchestrator checklist

- Cut `feature/ui-framework` from the agreed base. The working tree currently has uncommitted
  edits to `project.pbxproj`, `Info.plist.example` and `AppDelegate.swift`. Commit or stash them
  first, because worktrees do not see them.
- Free disk before a wave. Each worktree build is about 6 GB; there was 55 GB free at audit time.
  Four concurrent agents is the ceiling.
- **Merge each branch as it reports.** After each merge run `build-for-testing` and `swiftlint`.
  Watch the hunks where two branches appended to the same file end: the closing brace gets eaten.
- After each wave, run `scripts/screenshots.sh --diff` on the merged branch and review it.
- Reap on merge: `git worktree remove -f -f ~/.wt-wpNN`, `git worktree prune`, delete the branch
  and `~/.dd-wpNN`.
- Full suite once, at the end, before pushing.

## Decisions (confirmed 2026-09-27)

1. **Brand accent.** Stays monochrome (`labelColor`) for now. It must be used in every place
   where the brand or interactive emphasis is meant, so that one asset change later recolours the
   whole app. See `CONTRACT.md` § Accent.
2. **Calories colour.** Blue, which is what `Macro.cals.colour` already says. Protein stops being
   blue anywhere.
3. **Finish Workout.** It stays in the tracker's menu. In addition, once every set is completed,
   a Finish button animates into the bottom safe area. See WP-09.
4. **List row text.** Titles use `.body` and subtitles use `.subheadline`. Both are Dynamic Type
   text styles. WP-06 carries the accessibility-size layout rules.
