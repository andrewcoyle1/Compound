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
- **Dynamic Type, always.** Any fixed type size in a file you own is replaced with a Dynamic Type
  equivalent, whatever else the WP says:
  - `.font(.system(size:))` without a text style
  - `Font.custom(_:size:)` without `relativeTo:`
  - a hardcoded `UIFont` point size
  - a fixed `.frame(height:)` that clips text

  Use a text-style token from `CONTRACT.md` for text and `.iconSize(_:)` for symbols. Where a size
  has to stay proportional, use `@ScaledMetric(relativeTo:)`. The only exceptions are share cards
  rendered to images and the widget; `CONTRACT.md` names them. If you see a fixed size in a file
  you do not own, list it in your report. WP-15 sweeps the leftovers and its lint rule stops new
  ones.
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

## Follow-up decisions (confirmed 2026-09-28)

| # | Decision | Owner |
|---|---|---|
| 1 | Grams keep one decimal on nutrition labels and food/recipe detail. Everywhere else rounds as `Format.grams` does. | WP-08 (asked mid-run) |
| 2 | "lb" everywhere. Change `WeightUnitPreference.abbreviation` and `ExerciseWeightUnit.abbreviation` from "lbs", and fix any tests that assert "lbs". | WP-15 |
| 3 | Goal Progress, its entries and its chart follow the user's weight unit, not kg. Add presenter tests. | WP-15 |
| 4 | The session volume total converts each exercise to the user's body-weight unit before summing. | WP-09 (asked mid-run) |
| 5 | Macro lines in item rows wrap to a second line instead of truncating. | WP-08 (asked mid-run) |
| 6 | The weekly target grid shows the over-target caret only when a cell is well over target: define "well" as over 110% and put it in a named constant. VoiceOver still says "over target" for any cell over 100%. | WP-15 |
| 7 | Mac Catalyst is out of scope for this swarm. It is a separate task, because the build was already broken in `CoreInteractor`, `BarcodeScanner`, `HKWorkoutManager` and the tracker interactor. | — |
| 8 | US spelling in user-facing strings ("Favorites", "Analyzing", "Customize", "Colour" → "Color" and so on). Change the English source strings and keep their Spanish translations. Identifiers and comments stay as they are. | WP-15 |

Also for WP-15:
- **Set-count plurals.** "1 sets" appears in Muscle Balance and in Shared Item's rows. Pluralise every
  set, rep and exercise count through the string catalog (grep `sets"`), and treat a fractional
  count as plural.
- **Search shortcut tap targets.** WP-11 made the Search shortcuts `Chip`s, which are about 20 pt
  tall, below the 44 pt minimum tap target. Make them controls at least 44 pt tall (`.glass`
  buttons, or a `Chip` whose `contentShape` is padded out to 44 pt), and check any other tappable
  `Chip` for the same problem.
- Muscle Balance also hides its footer by comparing the header to the localised word
"Lower", so the footer disappears in other languages. Fix it with a test seam.
