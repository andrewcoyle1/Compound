# Programs: coach-grade plans, built in the app or imported

## Why

Two published 12-week programs (a 5-day bodybuilding block pair and a 5-day "min-max" phase)
were compared against the app on 7 Oct 2026. They are the most complex plan a user is expected
to bring, and the gap list is the scope here. Each exercise row in such a sheet carries: a
last-set intensity technique, a warm-up set count (sometimes a range), a working set count, a
rep range or fixed reps ("20", "10 per leg"), an effort target (early-set vs last-set RPE, or an
RIR per set), a rest range, up to two substitutions, coaching notes and a video link. Weeks
differ inside a block (a set is added in week 2 and again in week 9; the intro week lowers
effort and turns techniques off; a deload week does the same mid-block). Supersets are marked
"S1:", "S2:" with no rest on the first member. The same exercise appears twice in a row (a heavy
6–8 set, then a 1 × 20 back-off).

What the app already covers: blocks → `Macrocycle` of `Mesocycle`s; days and rest days →
templates; rep range and an RIR target per set (`SetTarget`); double progression; per-set RPE
logging; myo-reps, drop sets, AMRAP, rest-pause, cluster (`SetKind`, behind Workout Settings ›
Set Plan); per-side sets; supersets in the session; Swap in the tracker; generated warm-ups.

## Decisions (fixed)

- **Branch:** `feature/programs`, cut from `feature/workout-tracker-redesign` at `cce675f2`
  (it needs the set plan). Packages are PRs into it; it goes to `development` after PR #66.
- **The template exercise grows the per-exercise columns** (WP-P1): notes, warm-up set count
  (nil = the automatic generator), rest, substitutions, superset group, link. All optional and
  decoded with `decodeIfPresent`, so every saved template still decodes.
- **Week-to-week variation is per exercise, not per week:** `setTargetsByMicrocycle`, a list of
  `{ from_microcycle, set_targets }` overrides; the base `setTargets` are microcycle 1. An intro
  week or a deload week is a variation like any other. The mesocycle-level `deload` (a 35 %
  weight cut) stays as it is.
- **Three new techniques** (WP-P2): lengthened partials after failure (`partials`, a reps piece),
  loaded static stretch (`stretch`, a timed piece with no load) and weighted static hold (`hold`,
  a timed piece at the set's weight). Drop step gains 25 %.
- **The same exercise twice in one workout** is matched to history by occurrence (first, second …
  of that exercise in the workout), everywhere the tracker and the planner look up "last time".
- **Ranges import as single values:** rest → the midpoint rounded to 15 s; warm-ups → the upper
  bound; RPE → RIR = 10 − upper RPE; RIR per set as given.
- **Import** (WP-P6) reads the sheet layout above from `.xlsx` and `.csv` (header row recognised
  by column names, week/day markers in the first column, "S1:" prefixes, hyperlinks on exercise
  cells) and the app's own JSON. Unmatched exercise names are mapped on a review screen before
  anything is saved. No new dependency: `.xlsx` is a zip of XML, read with `Compression`
  (raw DEFLATE) and `XMLParser`. Published programs are never shipped as prebuilt content.
- **Video links** live on the template exercise (`link_url`), not the shared exercise model.

## Working rules (every package)

Same as `docs/specs/workout-tracker/plan.md` § Working rules, in short:

- Branch from the latest `feature/programs` into your own worktree; copy in the four gitignored
  config files (`Keys.swift`, `Info.plist`, both `GoogleService-Info-*.plist`).
- Pure rules and model changes first, with their own Swift Testing suite, in their own commit.
- New fields on synced models are `Optional` (or defaulted on decode) with a decode test that
  reads a document written without them.
- Strings: edit `Compound/Localizable.xcstrings` by hand, your keys only, with Spanish (US
  spelling). Revert any build-time catalog rewrite before committing. List new keys in the PR.
- One simulator per package, by UDID, never shut down or boot another's. Own
  `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/Compound-<WP>`; delete it last.
  `-parallel-testing-enabled NO -skip-testing:CompoundUITests -only-testing:CompoundUnitTests/<Suite>`.
  Check `xcodebuild`'s exit status (zsh `${pipestatus[1]}`) before reading results.
- Touch only files under **Owns**; shared files only in the named functions.
- Added or moved files: `python3 scripts/codebase-map.py` after the final rebase.
- Tokens only; animate only through `withReducedMotionAnimation`; no new `swiftlint:disable`;
  zero build warnings; `swiftlint --strict` clean.
- PR into `feature/programs` titled `[Programs] WP-Px · <goal>`, body listing new strings and
  suites, ending with the attribution lines.

Path prefixes: `M/` = `Compound/Managers/Training/`, `AT/` =
`Compound/Core/Training/Subviews/AddTraining/`, `WT/` =
`Compound/Core/Training/Subviews/WorkoutTracker/`, `UT/` = `CompoundUnitTests/`.

---

## Wave 1 (P1 and P2 in parallel; merge P1 first)

### WP-P1 · The template exercise carries the plan · M

**Owns:** `M/Exercise/Models/WorkoutTemplateExercise.swift`, new
`M/Exercise/Models/MicrocycleSetTargets.swift`, `M/WorkoutSession/Models/WorkoutExerciseModel.swift`,
`M/WorkoutSession/Models/WorkoutSessionModel.swift` (the `init(template:)` only),
`M/WorkoutSession/Models/WorkoutSessionModel+WarmupSets.swift`,
`M/WorkoutSettings/RestDurationRules.swift` (`ExerciseContext` only), the three
`ExerciseContext(...)` call sites (`WT/WorkoutTrackerPresenter+ActiveExercise.swift`,
`WT/ExerciseTracker/SetTracker/SetTrackerRow/SetTrackerRowPresenter.swift`,
`Compound/Managers/LiveActivities/LiveActivityIntentHandler+App.swift`), tests.

**Model:**
- `WorkoutTemplateExercise` gains `notes: String?`, `warmupSetCount: Int?` (nil = automatic),
  `restSeconds: Int?`, `substituteExerciseIds: [String]` (default `[]`), `supersetGroupId: String?`,
  `linkURL: String?`, `setTargetsByMicrocycle: [MicrocycleSetTargets]` (default `[]`). Snake-case
  keys (`warmup_set_count`, `rest_seconds`, `substitute_exercise_ids`, `superset_group_id`,
  `link_url`, `set_targets_by_microcycle`). Hand-written `init(from:)` with `decodeIfPresent`.
- `MicrocycleSetTargets: Codable, Equatable, Hashable { fromMicrocycle: Int; setTargets: [SetTarget] }`
  (`from_microcycle`, 1-based). `WorkoutTemplateExercise.setTargets(forMicrocycle n: Int) -> [SetTarget]`:
  the override with the greatest `fromMicrocycle ≤ n`, else the base list. `n` nil or < 1 → base.
- `WorkoutExerciseModel` gains `planNotes: String?` (`plan_notes`), `restSeconds: Int?`
  (`rest_seconds`), `linkURL: String?` (`link_url`), `substituteExerciseIds: [String]`
  (`substitute_exercise_ids`, default `[]`), all `decodeIfPresent`, `encodeIfPresent` / skip empty.
  The user's own `notes` stays what it is.
- `WorkoutSessionModel.init(template:…)` gains `microcycleIndex: Int? = nil`; uses
  `setTargets(forMicrocycle:)` for the targets, copies `notes → planNotes`, `restSeconds`,
  `linkURL`, `substituteExerciseIds`, `supersetGroupId`, and passes `warmupSetCount` to the
  generator. Two template entries for the same exercise find their previous exercise by
  occurrence: the nth entry of exercise X matches the nth exercise with that `templateId` in the
  previous session (`WorkoutSessionModel.occurrence(of:)` → `Int`, and
  `exercise(templateId:occurrence:)`; both used by WP-P4).
- Warm-ups: `generateWarmupSets(…, count: Int?)`. nil → today's rule. 0 → none. 1 → 60 %;
  2 → 50/70; 3 → 45/65/85; 4 → 45/60/75/85 (of the working weight, rounded as today); more than 4
  → the 4-set pyramid plus 90 % steps. Reps as today.
- Rest: `ExerciseContext` gains `planRestSeconds: Int?`, read **first** in `baseRestDuration`
  (session exercise → exercise settings → type → global); zero reads as nil like the others. The
  three call sites pass the session exercise's `restSeconds`.

**Accept:** `WorkoutTemplateExerciseDecodingTests` (old document decodes; round trip; variation
lookup), `WarmupSetGenerationTests` (each count; nil unchanged), `WorkoutSessionModelTests`
(microcycle picks the override; plan fields copied; same exercise twice matched by occurrence),
`RestDurationRulesTests` (plan rest wins; zero ignored). Existing suites green.
**Blocks:** P3, P4, P5, P6.

### WP-P2 · Partials, loaded stretch, static hold; drop 25 % · M

**Owns:** `M/Exercise/Models/SetTargetSetType.swift`, `M/Exercise/Models/SetTarget.swift`
(`partialReps: Int?` `partial_reps`, `holdSeconds: Int?` `hold_seconds`),
`M/WorkoutSession/Models/SetKind.swift`, `M/WorkoutSession/Models/WorkoutSessionModel.swift`
(`applyingSetPlan` only), `AT/CreateWorkout/SetTarget/SetTargetPlan.swift`,
`SetPlanDetailPresenter.swift`, `SetPlanDetailView.swift`, `WT/ActiveWorkout+Pieces.swift`,
`WT/ActiveWorkoutState.swift` (`kindName(of:)`, log title), `WT/ExerciseTracker/SetTracker/SetTrackerRow/SetTrackerRowView.swift`
(the piece row's chip and the timed piece's input only), `Shared/LiveActivityPhase.swift`
(`LiveActivitySetKind`), `Compound/Managers/LiveActivities/LiveActivityManager+Pieces.swift`,
`WorkoutSessionActivity/` kind labels, `M/Progression/ProgressionEngine.swift` (treat the new
kinds like drop/myo: prefill, never progress), tests.

**Rules:**
- `SetTargetSetType` + `partials`, `stretch`, `hold`; `SetKind` + the same three.
  `restsWithinTheSet` false for all three (the piece follows the set without a rest).
- `applyingSetPlan`: `partials` → one piece `kind: .partials`, `reps: partialReps`, the set's
  weight. `stretch` → one piece `kind: .stretch`, `durationSec: holdSeconds`, no weight.
  `hold` → one piece `kind: .hold`, `durationSec: holdSeconds`, the set's weight.
- Timed pieces log through the existing stopwatch (`SetStopwatch`) counting down from
  `durationSec`; the log title reads "Log 30 s stretch" / "Log 30 s hold"; a partials piece
  reads "Log partials".
- `SetTargetPlan.kinds` adds the three; titles "Lengthened partials", "Loaded stretch",
  "Static hold"; summaries "then partials to failure" / "then a 30 s stretch" / "then a 30 s
  hold"; `dropSteps = [10, 20, 25, 30]`; `holdSecondsChoices = [15, 20, 30, 45, 60]`,
  `partialRepsRange = 1...10` (nil = to failure).
- Live Activity: `LiveActivitySetKind` + the three, labels; `countingPieces` unchanged (a piece
  is a piece). Sub-sets stay out of counts and progression (`parentSetId`).
- The coach parity fixture is untouched: sub-sets are already excluded by `parentSetId`.

**Accept:** `SetKindTests` (+3), `SetTargetPlanSummaryTests`, `SetTargetPlanPresenterTests`,
`ActiveWorkoutPiecesTests` (hints for each), `LiveActivityPieceTests`, `WorkoutSessionPrefillTests`
(a timed piece carries `durationSec`), `ProgressionEngineTests` (new kinds never progress).
**Strings:** titles, summaries, chips, log titles, Live Activity labels, in both languages.

---

## Wave 2 (P3, P4, P5, P6 in parallel; merge order P5, P4, P3, P6)

### WP-P3 · The editor: per-exercise fields, supersets, weekly variation · L

**Owns:** `AT/CreateWorkout/SetTarget/*` (except `SetTargetPlan.swift`), new
`AT/CreateWorkout/SetTarget/ExercisePlanDetail/` module (`ExercisePlanDetailPresenter/View/Router`),
new `AT/CreateWorkout/SetTarget/MicrocycleVariations/` module, `AT/CreateWorkout/DefineWorkout/*`,
`AT/CreateWorkout/ExercisesPicker/*` (a multi-select mode for substitutions), tests.

**Changes:**
- `SetTargetView` gains a second section: Warm-up sets (Automatic / 0 / 1 / 2 / 3 / 4), Rest
  (Automatic / picker 15 s … 10 min in 15 s steps), Notes (multi-line), Link (URL field, validated
  `http(s)`), Substitutions (opens the exercise picker in multi-select; shows chips, swipe to
  remove), and "Varies by week" (opens the variations module).
- Variations module: a list of overrides, "From week N" stepper (2 … 52, unique, sorted), each
  opening the same set-target editor for its list; "Copy from week 1" seeds a new one; delete.
  Summary row reads "Weeks 1–1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets".
- `DefineWorkoutView`: select mode "Superset" → tap two or more exercises → one group id;
  grouped rows carry a `Chip` in the `superset` tint with the letter (A, B…) per group; an exercise
  row's context menu "Remove from superset". Rows show a one-line summary of the plan fields
  ("3 warm-ups · 2 min · 2 alternatives · notes").
- Reorder keeps groups together (moving a member moves the group), like the tracker's blocks.
- `WorkoutSessionTemplateBuilder` (save as template) keeps `supersetGroupId`, `planNotes`,
  `restSeconds`, `linkURL`, `substituteExerciseIds`.

**Accept:** `SetTargetPlanPresenterTests` (+ fields, validation), new
`ExercisePlanDetailPresenterTests`, `MicrocycleVariationsPresenterTests` (unique weeks, sorted,
summary text), `DefineWorkoutPresenterTests` (grouping, ungrouping, move keeps the group),
`WorkoutSessionTemplateBuilderTests`; `CreateWorkoutUITests` extended with one test that sets a
warm-up count and groups a superset. **Depends:** P1, P2.

### WP-P4 · The tracker reads the plan · M

**Owns:** `WT/WorkoutTrackerPresenter+Rest.swift` (`loadPrevious`), `WT/WorkoutTrackerPresenter+ActiveExercise.swift`
(`previousExercises` reads), `WT/WorkoutTrackerView+Exercises.swift`, `WT/ExerciseTracker/ExerciseTrackerView.swift`
(card header: plan notes + link), `WT/ExerciseTracker/SetTracker/SwapExercisePicker/*`,
`M/Progression/ProgressionPlanner.swift` (`history(forTemplateId:occurrence:in:)`), the swap
presenter, tests.

**Changes:**
- Plan notes under the card title in `.rowDetail`, `lineLimit(2)` with "More" (like the user's
  notes row), a11y label "Plan notes". A "Watch" item in the card menu when `linkURL` is set
  (opens in Safari via `openURL`).
- "Last time" and the planner's history are keyed by `(templateId, occurrence)`:
  `previousExercises` keyed by `"\(templateId)#\(occurrence)"` through one helper
  `ActiveWorkout.historyKey(for:in:)`; `loadPrevious` matches the nth exercise with that
  template id in the previous session; `ProgressionPlanner.history` the same. First occurrence
  behaves exactly as today.
- Swap picker: a "Planned alternatives" section first when the exercise has
  `substituteExerciseIds`, then the library. Swapping to an alternative keeps the plan fields
  (notes, rest, link, targets) on the new exercise.
- Template supersets arrive on the session from P1; the tracker's block card needs no change.
  Add one test that a session built from a template with a group shows one block.

**Accept:** new `WorkoutTrackerHistoryKeyTests` (second occurrence gets its own last time and
suggestion), `ProgressionPlannerTests` (occurrence), `WorkoutTrackerSwapTests` (alternatives
first; plan fields kept), `WorkoutTrackerSupersetTests` (template group → one block),
`WorkoutTrackerUITests` extended: plan notes visible from a `UI_TEST_PLAN_NOTES` seed.
**Depends:** P1.

### WP-P5 · The mesocycle start passes the week · S

**Owns:** `Compound/Core/Training/Subviews/ActiveMesocycle/*`, `WorkoutTemplateDetail/*`
(delegate, interactor, presenter, view: a "Week N" plan summary), `TrainingInteractor.swift`,
`Compound/Managers/AppIntents/AppIntentsInteractor.swift`, `Compound/Root/RIBs/Core/CoreInteractor.swift`
(`startWorkout(for:in:microcycleIndex:)`), `Compound/Core/Training/Components/TodaysWorkoutCard/MesocycleSchedule.swift`
(`todayItem` carries `cycleIndex`), `MesocycleLibrary/PrebuiltMesocycleDetail` (shows variations),
tests.

**Changes:** every start path passes the 1-based microcycle the slot belongs to (Active
Mesocycle, Today card, App Intents, widget), defaulting to nil for a standalone template. The
template detail view shows the week's targets ("Week 3 · 3 sets · 8–10 · RIR 1") and the plan
fields per exercise read-only. Deload cut unchanged.

**Accept:** `ActiveMesocyclePresenterTests`, `MesocycleScheduleTests` (`todayItem.cycleIndex`),
`TodaysWorkoutCardPresenterTests`, `AppIntentsTests`; one `WorkoutSessionModelTests` case through
the interactor. **Depends:** P1.

### WP-P6 · Import a program · L

**Owns:** new `M/ProgramImport/` (`ProgramSheet.swift` the parsed intermediate, `ProgramSheetParser.swift`,
`XLSXReader.swift`, `CSVReader.swift`, `ProgramImporter.swift` → `Macrocycle` + `[Mesocycle]`,
`ExerciseNameMatcher.swift`), new `Compound/Core/Training/Subviews/ImportProgram/` module
(file picker → parse → review unmatched names → save), the Training library entry point
("Import Program…" in the add menu), `docs/specs/programs/import-format.md`, fixtures under
`UT/Fixtures/programs/` (synthetic, made-up exercise names: one `.xlsx` written with openpyxl
by a script committed beside it, one `.csv`, one `.json`), tests.

**Parser (pure):**
- Rows are scanned for a header row containing "Exercise". Columns are found by name,
  case-insensitive, prefix match: Exercise; Technique (contains "Intensity" or "Technique");
  Warm-up Sets; Working Sets; Reps or Rep Range; Early Set RPE / Last Set RPE; RIR (Set n)…;
  Rest; Substitution Option n…; Notes. Unknown columns are ignored.
- The first column marks structure: "Week N" / "Intro Week" / "Deload Week" start a microcycle;
  a line that is neither a week nor a known day and comes before a week header starts a block
  (its text is the mesocycle name; the sheet title is the macrocycle name); a day name on an
  exercise row starts a day, filled down over following rows; "Rest Day" is a rest day.
- A cell that Excel turned into a date is a range: `2025-06-08` → 6–8, `2025-10-12` → 10–12,
  `2025-02-03` → 2–3 (month = low, day = high). A plain "6-8" string is the same range. "20" is
  20–20; "10 per leg" is 10–10 per side; "0-1" warm-ups → 1.
- Technique → set type on the **last** working set: "Failure" → `amrap` with RIR 0; "LLP" /
  "Lengthened" / "Extend" → `partials`; "Myo" → `myo` (mini-sets 3); "Drop Set(s)" with
  "~N%" → `drop` (count from "Two"/"Three"/digits, step N); "Static Stretch (Ns)" → `stretch`;
  "Static Hold (N sec)" → `hold`; "N/A" / "-" → standard.
- Effort: "Early Set RPE" applies to all but the last set, "Last Set RPE" to the last;
  RIR = 10 − upper RPE; "RIR (Set n)" per set as given; "-" = none; "N/A" = none.
- Rest "1-2 min" → 90 s; "30-60 sec" → 45 s; "2-4 min" → 180 s; "-" → nil (superset first
  member). Hyperlink on the exercise cell → `linkURL`. "S1:"-style prefixes group a superset and
  are stripped from the name.
- Two consecutive rows with the same exercise name on one day are two template entries.
- Weeks: each week yields a full set of day templates; the importer keeps microcycle 1 as the
  base and emits a `MicrocycleSetTargets` override wherever a later week's targets differ from
  the previous week's. Day names must match across weeks; a day whose exercises differ by name
  from microcycle 1 in the same block is an error naming the week and day. Blocks become
  mesocycles with `numMicrocycles` = their week count; `deload: .none` (the sheet spells its
  deload out).
- CSV: the same grid with commas; the JSON format is the app's own `Mesocycle` array
  (`docs/specs/programs/import-format.md` documents all three).

**Matcher:** exact → `alternateNames` → case- and punctuation-insensitive → token expansion
("DB" ↔ "Dumbbell", "BB" ↔ "Barbell", "1-Arm" ↔ "Single-Arm", "SM" ↔ "Smith Machine") →
unmatched. Never a fuzzy guess that could pick the wrong lift.

**Screen:** Import Program: `fileImporter` (`.xlsx`, `.commaSeparatedText`, `.json`) → parse on a
background task with a progress state → review: a list of unmatched names, each a row that opens
the exercise picker (search prefilled with the name) or "Create '<name>'" (a user exercise:
weight + reps, muscle groups unset, flagged for the user to finish later) → summary (blocks,
weeks, days, exercises, techniques used) → Save creates the mesocycles and a macrocycle, not
started. Errors are inline (`InlineMessage`) with the sheet row.

**Accept:** `ProgramSheetParserTests` (every rule above, from the fixtures), `XLSXReaderTests`
(shared strings, inline strings, dates, hyperlinks, merged cells filled down),
`CSVReaderTests` (quotes, newlines in cells), `ProgramImporterTests` (blocks, overrides only
where weeks differ, supersets, double entries, rest-day days), `ExerciseNameMatcherTests`,
`ImportProgramPresenterTests` (unmatched flow, create, save). The `.xlsx` fixture is written by
`UT/Fixtures/programs/make-fixture.py` (openpyxl) and committed. **Depends:** P1, P2.

---

## Lead review (every PR)

As `docs/specs/workout-tracker/plan.md` § Dispatch and review: rebased on the branch tip; Owns
respected; Development, Mock and `WorkoutSessionActivityExtension` build with zero warnings;
`swiftlint --strict` 0; the package's suites green, then the full unit bundle; UI suite where
listed; strings complete in both languages; map regenerated; `gh pr merge --squash`; delete
branch, worktree and DerivedData.

## Dependency graph

```
P1 ─┬─ P3 (also P2)
    ├─ P4
    ├─ P5
    └─ P6 (also P2)
P2 ─┘
```

## Status

- 7 Oct 2026: branch and plan created. Wave 1 merged the same evening: P1 (#67, `70a0ff75`)
  and P2 (#68, `66c17918`). Two notes from P2 for a later tidy: a lone partials, stretch or hold
  piece still reads "Mini-set 1 of 1" on the Live Activity (`SetPiece` knows only drop and
  mini-set) and its delete action says "Delete Mini-Set". Wave 2 (P3, P4, P5, P6) dispatched.
- 8 Oct 2026: Wave 2 merged: P4 (#69), P5 (#70), P3 (#71), P6 (#72). The importer was then run
  against the two purchased programs (never committed) and needed four parser fixes
  (`3e812eb8`): sheets that start past column A, structural lines merged across the row, an
  intro or deload label above the "Week N" header, and RIR columns named under the header. Both
  now import in full: two blocks each, named days and rest days, warm-up counts, rests,
  supersets, techniques and week overrides where sets or RIR change. The tip was verified with
  the full unit bundle (4510 passing) and the WorkoutTracker, CreateWorkout and CreateMesocycle
  UI suites (20 passing). PR #66's CI failure (Xcode 26.6 crashing on a thunk in
  `DayChecklistCard`) was fixed on the tracker branch (`361f8e6e`) and merged here.
- A TestFlight build of the branch was uploaded on 8 Oct 2026 from `bcea7344` (App Store Connect
  assigns the build number).
- 8 Oct 2026, later: Import Program… is also on the Macrocycles screen (plus menu and empty
  state), and a program imported there opens as its macrocycle once saved, ready to Start. The
  importer hands the saved macrocycle back through `ImportProgramDelegate.onImported`.
- 8 Oct 2026, later still: the matcher gained three safe tiers (same words any order; a library
  name adding only a position or equipment word; a sheet name adding words to a library name) and
  more abbreviations, and the review screen offers up to three suggestions per unmatched name.
  Unmatched names on the two sheets fell from 89 to 51 and 62 to 43, every remaining one absent
  from the 64-exercise prebuilt library (a plain dumbbell curl, goblet squat, Nordic curl,
  standing calf raise…). Growing the prebuilt library is the next lever.
- Follow-ups: The two P2 Live Activity labels above.
  The in-session set-target editor on the tracker does not show the Plan section (edits there
  would be dropped), by design for now.
