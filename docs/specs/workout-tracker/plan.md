# Workout tracker overhaul — execution plan

## Context

`feature/workout-tracker-redesign` replaces the old tracker (overview stats card + every exercise as a
`DisclosureGroup` + bottom rest pill) with one open exercise card, Up Next / Completed lists, a pinned
progress header, an inline rest row and a single bottom CTA. Eleven agent audits (containers, UX,
HIG, perf, product, input model, edge states, system, accessibility, UIKit/motion, learnability —
in `scratchpad/*.md`, to be copied into `docs/specs/workout-tracker/`) converged on:

- **Keep the vertical List + one card. No pager.** Borrow MacroFactor's *map* (exercise strip) and
  superset-as-one-card, not its paging.
- **The input model is the bigger problem:** weight is known before a set, reps/RIR only after.
  Log first, correct during the rest.
- A list of real bugs: library fetched per keystroke, double non-atomic session writes, half-typed
  values propagated to sibling sets, App Group id mismatch, `.timeSensitive` without the
  entitlement, two logging code paths (phone vs Lock Screen), gym profile never loaded, relaunch
  loses rest/pause/HealthKit, VoiceOver focus lost on every log, text down to 6.6 pt, no supersets
  in the rest rules.

Mixpanel has one user (the owner), so no A/B. Decisions come from the three no-code tests in
`learn-decide.md` §B5 after Wave 2.

**Owner decisions (fixed; do not re-argue):**
- Keypad **Done only closes** (reverses hig-decisions 5d). The Log button is always visible above the keypad.
- **Skip Rest stays primary during rest** (the "Log stays primary" proposal is rejected); fix its hazards instead.
- **Stay on a finished exercise during its rest**; advance on Next or when the rest ends; auto-advance skips completed exercises (`exerciseAutoNext` redefined).
- **Pause / Finish / Notes visible as toolbar items at regular width** (iPad); menu on iPhone. iPad two-pane layout is **out** of scope.
- App Group → `group.com.compound.app`; delete the orphan `WorkoutSessionActivity/WorkoutSessionActivity.entitlements`; add the time-sensitive notifications entitlement.
- In scope: set kinds in the model, assisted (negative) weight + hold stopwatch + placeholder defaults, exercise strip + directional card swap behind a switch, bodyweight contribution badge/labels when `showBodyweightContribution` is on, and decoupling `bodyWeightContribution` from `isBodyweight` in exercise creation (+ prebuilt data pass).
- **Workflow:** one Opus agent per work package in its own git worktree off `feature/workout-tracker-redesign`, delivered as a PR into that branch; Fable reviews and merges.

**Bodyweight contribution reference** (owner screenshot): a capsule beside the exercise title with a
ring filled to the share, reading `83.95 kg` / `+52.6 kg (63%)` — effective load = external load +
63 % × bodyweight. `isBodyweight` means only "cannot be loaded beyond bodyweight"; the contribution is
a property of the movement and applies to weighted pull-ups, dips, Smith good mornings, squats.

## Facts that shape the plan

1. **The redesign is uncommitted.** The branch tip is `development` + one Today commit. WP-0 commits the working tree first, or worktrees contain none of it.
2. **File-system synchronized groups:** new files need no `project.pbxproj` edit — the main lever for keeping parallel packages apart.
3. **`AppToast` cannot carry Undo:** it renders in `AppView` under the tracker's `fullScreenCover` and has no action. Undo lives in the in-tracker correction row + `UndoManager` (shake / ⌘Z). *Owner: this reads "Undo toast" as "an Undo affordance after every log".*
4. **`.atomic` is a package change** (`andrewcoyle1/SwiftfulDataManagers`, `FileManager+EXT.swift`, pinned 1.2.0) → fork PR, tag 1.2.1, `Package.resolved` bump.
5. **Firestore rules need no change for set kinds** (`workout_sessions` validated at document level only).
6. `bodyWeightContribution` is `Int` percent 0–100; only display and the create flow read it; `coach-maths.js` / `coach-parity.json` don't. Bodyweight source: `CoreInteractor.currentWeightKilograms`. `WorkoutSettings.showBodyweightContribution` exists, read nowhere in a view.
7. **`WorkoutSettings` has synthesized `Decodable`:** every new field must be `Optional` with a default accessor (the `showOnLockScreen` pattern) + a decode test.
8. Prebuilt exercises seed by version (`ExerciseModelManager.currentSeedingVersion = 15` → 16 on any JSON edit). `functions/data/PrebuiltExercises.json` must stay byte-identical (`functions/coach.test.js:294`).
9. The quick-finish CTA calls `onFinishConfirmed()` directly; the menu's `onFinishPressed()` already shows the "Finish Workout" notes sheet — routing the CTA through it *is* the Finish confirmation.
10. Near SwiftLint limits: `WorkoutTrackerPresenter.swift` (608), `HKWorkoutManager.swift` (656), `SetTrackerRowView.swift` (494), `WorkoutTrackerView.swift` (463), `SetTrackerView.swift` (435). New logic goes in new files.
11. Live Activity intents (`LiveActivityIntentHandler+App.swift`) call managers directly, never the presenter. `onTask`/`workoutTemplate` in the presenter are dead. TipKit unused. `ActiveWorkoutState.swift` + `ActiveWorkoutStateTests` is the home for pure rules.
12. The local simulator wedged mid-session ("Launchd job spawn failed" for every app launch after `simctl shutdown all`). Before Wave 0 verification: `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, or run from Xcode; `scripts/clean-simulators.sh` after.

Path prefixes: `WT/` = `Compound/Core/Training/Subviews/WorkoutTracker/`, `ST/` = `WT/ExerciseTracker/SetTracker/`, `ROW/` = `ST/SetTrackerRow/`, `KB/` = `ROW/SetKeyboard/`, `UT/` = `CompoundUnitTests/Core/`.

## Working rules for every package (agents read these first)

- Branch from the latest `feature/workout-tracker-redesign` into your own worktree. Copy in the four gitignored config files (`Keys.swift`, `Info.plist`, both `GoogleService-Info-*.plist`).
- **Pure rules first**, in a new `ActiveWorkout+<Topic>.swift` (extension on `enum ActiveWorkout`) or `RestDurationRules`, with its own Swift Testing suite, in its own commit — so the lead can merge the rules alone if the UI half stalls.
- New `WorkoutSettings` fields: `Optional` + default accessor + decode test.
- **Strings:** edit `Compound/Localizable.xcstrings` by hand, inserting only your keys with Spanish (US spelling). Revert any Xcode build rewrite before committing. On rebase conflict take base and re-insert your keys. List new keys in the PR body.
- Tests: `-parallel-testing-enabled NO -skip-testing:CompoundUITests -only-testing:CompoundUnitTests/<Suite>`. UI suite only when your package lists it.
- **One simulator per package.** The lead assigns each package its own device name (`iPhone 17`, `iPhone 17 Pro`, `iPhone 17 Pro Max`, `iPhone 17e`, …); use it in every `-destination` and never shut down or boot any other device. Shutting a simulator SIGKILLs every test host on it, and on 6 Oct 2026 one package's `simctl shutdown` killed the lead's review run twice. The lead reviews on `iPhone 17 Pro Max`.
- Check `xcodebuild`'s exit status before reading results (zsh: `${pipestatus[1]}`). A failed test-target build leaves `Compound.app` unsigned and every later launch fails with "No such process" — that is the build, not the simulator. Use your own `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/Compound-<WP>` so parallel packages do not share build products. **Each tree is ~7 GB: delete yours (`rm -rf` that path) as the last step before returning**, and the lead runs `df -h /System/Volumes/Data` plus `scripts/clean-simulators.sh` before launching a wave. On 6 Oct 2026 four trees plus a review tree filled the disk and stalled every agent.
- Touch only files under your **Owns**; a file marked *shared (disjoint hunks)* only in the named functions.
- If you add/move files: `python3 scripts/codebase-map.py` after the final rebase.
- Tokens only (`Spacing`, `Radius`, `Palette`, `Font.*`, `Symbol.*`, `Format.*`); animate only via `withReducedMotionAnimation` / `reducedMotionAnimation`; no new `swiftlint:disable`.
- Zero build warnings, `swiftlint --strict` clean, no `try?` swallowing a save, no new index-based bindings.

---

## Wave 0

### WP-0 · Baseline commit, specs into repo, decisions, mechanical split · S
**Lead:** commit the working tree (build 3 schemes zero warnings, lint, unit suite, push). Copy the 11 reports + this plan to `docs/specs/workout-tracker/`. Record in `docs/reviews/hig-decisions.md` and `docs/specs/ui-framework/README.md`: 5d reversed; 5b/README 3 amended (regular-width toolbar items); `exerciseAutoNext` redefined; "Log primary during rest" recorded as rejected.
**Agent (pure moves, no behaviour change):**
- `WT/WorkoutTrackerView.swift` → keep body + modifiers; new `WorkoutTrackerView+Toolbar.swift` (`toolbarContent`, `titleView`), `WorkoutTrackerView+Exercises.swift` (sections, `exerciseRow`, `supersetLabel`, `delegate(for:)`), `WorkoutPrimaryCTA.swift` (the `.bottomCTA` content), `WorkoutProgressHeader.swift`.
- `WT/WorkoutTrackerPresenter.swift` → new `+Persistence.swift` (`saveWorkoutProgress`, `startObservingActiveSession`, `adoptSavedSessionIfChanged`, `onScenePhaseChange`, `minimizeSession`) and `+SessionChanges.swift` (`updateSet`, `isComplete`, `propagateChanges`, `advanceAfterExerciseCompletion`, `handleWorkoutSessionChange`, `propagateEdit`, `firstNewlyCompletedSetExerciseIndex`). Moved members go `private` → internal.
**Accept:** diff is moves only; zero warnings; lint; `WorkoutTrackerPresenterTests`, `WorkoutTrackerSupersetTests`, `ActiveWorkoutStateTests`, `WorkoutTrackerQuickFinishTests`, `WorkoutTrackerFinishTests`, `WorkoutTrackerUITests` (4) green; codebase-map regenerated.
**Blocks:** everything.

---

## Wave 1 — bug fixes (A, B, C, D in parallel; merge order D, A, B, C)

### WP-A · Keystroke and save path · M
**Owns:** `Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift`; `WT/+Persistence.swift`, `+SessionChanges.swift`, `+Finish.swift`, `+Events.swift`; `KB/SetKeyboardPresenter.swift`; `Package.resolved`; fork PR on `SwiftfulDataManagers`. **Don't touch:** presenter main file, any view, `ST/*`.
**Pure rule:** `ActiveWorkout+Propagation.swift` — `propagate(edit:original:in:)` lifted from `propagateChanges`; `PropagationRuleTests` (same side only, open siblings only, match the *original* value, the 100/100/80 back-off case).
**Changes:** `imageName(in library: @autoclosure () -> [ExerciseModel])`; debounced `saveWorkoutProgress()` (300 ms) + `flushSave()` from `logSet`/`updateSet`, scene → non-active, `minimizeSession`, finish, discard; `adoptSavedSessionIfChanged` returns early while a save is pending; propagate on **commit** (pending `(setId, originalBeforeFirstKeystroke)` committed on another set edited, a log, keyboard hide, or flush) instead of per keystroke; `SetKeyboardPresenter.close()` sets `editingSet = nil`; finish haptics: `.success` at commit, `.error` with failure toast, `.success` again only on retried save; fork: `data.write(to:options: .atomic)` → tag 1.2.1 → bump (if fork PR blocked, ship the rest with a `ponytail:` note).
**Accept:** `PropagationRuleTests`, new `WorkoutTrackerSaveCoalescingTests`, `WorkoutTrackerPropagationTests`; updated `SetKeyboardPresenterTests`, `WorkoutTrackerFinishTests`; existing tests reading `activeSession` right after an edit call `flushSave()`. Manual: `-com.apple.CoreData.SQLDebug 1` shows no SELECT while typing; `_printChanges` on `TabBarView` once per burst.

### WP-B · Presenter state and data fixes · M/L
**Owns:** `WT/WorkoutTrackerPresenter.swift` (main), `+Progression.swift`, `+Exercises.swift`, `+Rest.swift`, `+ActiveExercise.swift` (only `progressionNote`, `onProgressionNoteAcknowledged`), `WT/WorkoutTrackerInteractor.swift`, new `WT/ActiveWorkoutScreenState.swift`, `ROW/SetTrackerRowPresenter.swift` (only the two `favouriteGymProfile` reads), `ROW/SetTrackerRowInteractor.swift`, `WT/ActiveWorkoutState.swift` ("Top" selection in the two summaries only). **Don't touch:** `+Persistence`, `+SessionChanges`, `+Finish`, views.
**Pure rules:** "Top" = longest duration (timeOnly) / farthest (distanceTime); `ActiveWorkoutScreenState: Codable { sessionId, acknowledgedNoteTemplateIds, progressionBaseline, customRestSeconds }` in the App Group defaults under one key, discarded for a different session; `ActiveWorkoutScreenStateTests`.
**Changes:** delete dead `onTask`/`workoutTemplate`; in `onAppear` resolve template → `gymProfileId` → `getGymProfile` → `setActiveWorkoutGymProfile`, fallback favourite; rows read `workoutGymProfile`; `onGymProfilePressed` hidden/disabled only when no gym; `init` loads screen state and captures the baseline only when none stored (fixes minimise recapture); acknowledgements keyed by templateId; delete exercise: lone partner clears `supersetGroupId`, deleting the rested exercise/set cancels the rest, card goes to the *next* exercise in order; add exercise mid-workout: per-side rows, `loadPrevious(for:)` + suggestions for new template ids, card stays.
**Accept:** `ActiveWorkoutScreenStateTests`, `WorkoutTrackerGymProfileTests`, `WorkoutTrackerAddExerciseTests`; `WorkoutTrackerSupersetTests` (+ partner delete); `WorkoutTrackerPresenterProgressionTests` (+ minimise keeps edited set); `ActiveWorkoutStateTests`; `WorkoutTrackerDoubles` extended under `// MARK: WP-B`.

### WP-C · Set table and card menus · M
**Owns:** `ST/SetTrackerView.swift`, `ST/SetTrackerPresenter.swift`, `ROW/SetTrackerRowView.swift`, `KB/SetKeyboardTextField.swift`, `WT/ExerciseTracker/ExerciseTrackerView.swift`, `WT/WorkoutTrackerView+Exercises.swift`, new `WT/WorkoutTrackerPresenter+Swap.swift`. **Don't touch:** `ROW/SetTrackerRowPresenter.swift`, presenter main.
**Changes:** set bindings by id (perf #8); logged warm-ups stay visible, collapsed to one row "2 warm-ups ✓" expanding on tap, editable; text floors (drop `minimumScaleFactor(0.6)` on headings, `minimumFontSize = 11`, `@ScaledMetric` set circle); set-number menu gains "Rest Timer…" and destructive "Delete Set" after a `Divider`; `allowsFullSwipe: false`; card menu: "Split L/R" as `Toggle`, ellipses on "Equipment…/Warmup Sets…/Targets…/Swap…/Superset…", Gym Settings hidden with no gym; notes `lineLimit(3)` + "More"; weightless previous set reads "8 reps"; unit "Convert Values" converts open sets only, rounded to gym increment, dialog copy "for this exercise everywhere"; Swap keeps logged sets on the old exercise (marked done) and inserts the new one after it with the open sets (`insertSwappedExercise(after:new:)` via `ExerciseTrackerDelegate.onSwap`), `openCount` excludes warm-ups, Last/suggestions reload; Up Next rows lose the chevron.
**Strings:** the menu items above, "More", "%lld warm-ups" (plural), unit-dialog copy.
**Accept:** `SetTrackerPresenterTests` (+ convert/swap cases), new `WorkoutTrackerSwapTests`, `WorkoutTrackerUITests` updated for identifiers. Manual: AX5 no text < 11 pt; delete first set with keyboard open on last — no crash.

### WP-D · App Group, entitlements, legacy-store migration · S
**Owns:** `Shared/SharedWorkoutStorage.swift`, `Compound/Utilities/Constants.swift`, `Compound/SupportingFiles/Compound.entitlements`, `Compound-Debug.entitlements`, delete `WorkoutSessionActivity/WorkoutSessionActivity.entitlements`, `AppDelegate.swift` (one launch call).
**Changes:** group id → `group.com.compound.app` in both code sites; add `com.apple.developer.usernotifications.time-sensitive`; `SharedWorkoutStorage.migrateLegacy(from:to:)` copies `restEndTime` + `hkStartedSessionId` once then clears the legacy suite, called at launch.
**Accept:** `SharedWorkoutStorageMigrationTests` (two in-memory suites); extension scheme zero warnings. **Owner before merge:** enable Time Sensitive Notifications on the App ID; confirm the App Group exists for both App IDs. Manual: Lock Screen widget shows real data.

---

## Wave 2 — input loop and rules (E, F, G, H in parallel; merge order H, G, E, F). Then cut TestFlight and run the three no-code tests.

### WP-E · CTA safety, toolbar, pause, scroll · L
**Owns:** new `WT/ActiveWorkout+PrimarySlot.swift`; `WT/WorkoutPrimaryCTA.swift`, `WT/WorkoutTrackerView.swift`, `+Toolbar.swift`, `+Finish.swift`; `+ActiveExercise.swift` *shared*: `runningRestEnd`, `primaryActionTitle`, `onPrimaryActionPressed` only; `CompoundUITests/WorkoutTrackerUITests.swift`. **Don't touch:** `RestDurationRules.swift`, `logSet`.
**Pure rules:** `enum SlotAction { log, skipRest, next, finish, resume }`; `slotAction(primary:restEnd:graceUntil:isPaused:now:)` — a naturally expired rest shows "Rest done · Log set 3 · …" disabled until `restEnd + 1 s`; `acceptsTap(lastActionChangeAt:now:)` ≥ 0.4 s keyed on **action** changes; `PrimarySlotTests` with injected clock.
**Changes:** one `CallToActionButton` identity for every action (a11y C1); Skip Rest label "Skip rest" with time as `accessibilityValue`, `Text(timerInterval: min(.now,end)...end)`, "+15s" equal width (style not size), input labels "Plus 15"/"Add 15 seconds"; delete `isKeyboardVisible` + both keyboard observers (CTA rides above the keypad); move both List-level `reducedMotionAnimation` modifiers onto the CTA, drop the row VStack animation; `ScrollViewReader` scrolls the new current row into view only when off-screen; Finish CTA → `onFinishPressed()` (notes sheet = confirmation); paused: "Paused" in place of the clock, header bar secondary tint, slot "Resume Workout"; menu grouped with `Divider`s (Pause+Finish | Notes, Settings, Gym | Discard), "Workout Notes…"; at `.regular` width Pause/Resume, Finish, Notes become `ToolbarItem`s; `⌘↩` on the CTA.
**Strings:** "Rest done", "Paused", "Resume Workout", "Workout Notes…", "Skip rest", "Plus 15".
**Accept:** `PrimarySlotTests`, `WorkoutTrackerQuickFinishTests` (CTA reaches notes sheet via router spy), `WorkoutTrackerFinishTests`; UI: double-tap test (one log, rest not skipped) + keyboard-open test (Log hittable). Manual: Slow Animations no List bounce; Reduce Motion fades only; iPad shows three toolbar items. **Depends:** A.

### WP-F · Correction row, Undo, Done closes, keypad accessibility · L
**Owns:** `WT/InlineRestTimerRow.swift`, new `WT/WorkoutTrackerPresenter+Correction.swift`; `+SessionChanges.swift` *shared*: one `recordUndo(from:)` call at the top of `updateSet` and `handleWorkoutSessionChange`; `KB/SetKeyboardPresenter.swift`, `KB/SetKeyboardView.swift`; `ROW/SetTrackerRowPresenter.swift`; `ST/SetTrackerView.swift`; `ExerciseTrackerView.swift` (`ExerciseCard` fields); `+Exercises.swift` (wiring).
**Pure rules:** `ActiveWorkout+Correction.swift` — `correctionTarget(in:latestLogged:)` (under the latest logged set of the card's exercise until the next log or card change, rest or not); `rirChip(_:)` → RPE via `EffortScale` (4+ → RPE 6); `CorrectionRuleTests`.
**Changes:** `InlineRestTimerRow` becomes the correction row `✓ Set 2 · 100 kg × 8 [−][+] Undo` + RIR chips 0–4+ when `rirTracking` + rest bar/time, vertical at AX sizes, no `.fixedSize()`; reps −/+ via `updateSet` + `applyLiveProgression`; Undo un-logs (cancels rest); `SetKeyboardPresenter.done()` only closes — delete `onOfferCompletion`, `offerCompletion`, `Event.keyboardOfferedCompletion`; RPE chips in the reps keypad only when editing a logged set; `UndoManager` via `@Environment(\.undoManager)` in `SetTrackerView` handed through `ExerciseCard.onUndoManager`, registering log/un-log/delete with action names, coalescing reps taps, weak self, `removeAllActions(withTarget:)` on disappear; keypad a11y: `.isKeyboardKey`, announce new value after key/step/chip, stepper row as one adjustable element, Done hint "Closes the keypad".
**Strings:** "Undo", "Reps in reserve", "4+", "Undo Log Set %@", "Undo Delete Set", "Closes the keypad".
**Accept:** `CorrectionRuleTests`, `SetKeyboardPresenterTests` (Done never logs), new `WorkoutTrackerCorrectionTests` (−1 rep re-suggests; RIR stored as RPE; Undo cancels rest; action names; 3 taps = 1 undo). Manual: shake undoes; ⌘Z on iPad; VoiceOver hears "102.5 kilograms". **Depends:** A, C. Merge after G.

### WP-G · Focus and superset rules · L
**Owns:** new `WT/ActiveWorkout+Focus.swift`, new `WT/WorkoutTrackerPresenter+Focus.swift`; `WT/ActiveWorkoutState.swift` (`primaryAction`, `progress`); `Managers/Training/WorkoutSettings/RestDurationRules.swift`, `Models/WorkoutSettings.swift`; `WorkoutSettingsView.swift`, `WorkoutSettingsPresenter.swift`; `+Superset.swift`; `+SessionChanges.swift` (advance block only); `+Rest.swift` (rest-end hook); `+ActiveExercise.swift` *shared*: `primaryAction` and the rest call in `logSet` only; `WT/WorkoutProgressHeader.swift`.
**Pure rules:** `blocks(_:)` (a superset group = one block); `primaryAction` walks interleaved rounds inside a block skipping complete members, "next" wraps and skips complete exercises; `focus(afterLogging:in:settings:restFollows:)` — inside block → next member in the round; exercise finished with a rest → **stay**; else next incomplete block; `focusWhenRestEnds` (Skip counts as rest end); `progress` reports "Superset n of m"; `RestDurationRules.restAfterCompleting(_:in:workout:settings:context:custom:)` — workout's last open set gets **no rest**; a member whose partner still has a set this round gets `supersetTransitionRestSeconds` (Optional, default nil = none); after the round base rest; after the last round between-exercises rest; keep the single-exercise overload. Suites: `ActiveWorkoutFocusTests`, `RestDurationRulesTests` (+ final set, A→B, after round, after last round, circuit of 3), `WorkoutSettingsDecodingTests`.
**Changes:** `+Superset` and `advanceAfterExerciseCompletion` route through one `setFocus(_:reason:)` in `+Focus` (the only place the card moves; I/J/K hook here); on `workoutRestDidComplete` or Skip apply `focusWhenRestEnds` when staying; settings row "Rest between superset partners" (Off/15 s/30 s); `exerciseAutoNext` copy → "Move to the next exercise when its rest ends".
**Strings:** "Superset %lld of %lld", "Rest between superset partners", new auto-next subtitle.
**Accept:** suites above + `WorkoutTrackerSupersetTests` (A1 rest 0; CTA alternates) + `WorkoutTrackerPresenterTests` (stay during rest, advance on rest end). Manual: superset round = 2 taps. **Depends:** B.

### WP-H · Exercise definition: contribution decoupled from `isBodyweight`, prebuilt data pass · S/M
**Owns:** `Core/Training/Subviews/AddTraining/CreateExercise/FinalExerciseDetails/FinalExerciseDetailsView.swift` + `Presenter.swift`; `ExerciseEquipment/ExerciseEquipmentPresenter.swift` (75 % preset); `Exercises/ExerciseTemplateDetail/ExerciseTemplateDetailView.swift`; `Compound/SupportingFiles/Resources/PrebuiltExercises.json` + `functions/data/PrebuiltExercises.json` (byte-identical); `Managers/Training/Exercise/ExerciseModelManager.swift` (seeding 15 → 16).
**Pure rule:** `ExerciseDefinitionRules` — `isValid(contribution:)` 0…100; `bodyweightConflict(isBodyweight:metrics:)` true when `isBodyweight` with `.weight`/`.weightPerSide`/`.weightPerSidePersistent` (assistance allowed); `ExerciseDefinitionRulesTests`.
**Changes:** always show the contribution control (default 0; keep the 75 % preset when Bodyweight toggles on); remove the `isBodyweight ? … : 0` gate (`Presenter:68`) and the `canContinue` gate (`:36`); inline conflict message blocks Next; detail screen shows contribution when > 0; data pass — Chest Dip and "Weighted Hammer Grip Pull-Up on Dip" `is_bodyweight` → false keep 100; new values (**owner to confirm**): squat/lunge patterns ≈ 85, hinges ≈ 60, machines/isolation 0; user exercises untouched; keys unchanged.
**Accept:** `ExerciseDefinitionRulesTests`; `CreateExerciseEquipmentPresenterTests` (loaded exercise *keeps* its value); new `FinalExerciseDetailsPresenterTests`; `ExerciseTemplateModel*Tests`; `npm test` in `functions/`. **Depends:** WP-0 only.

---

## Wave 3 — structure and system (I, J, K, L in parallel; merge order K, L, I, J)

### WP-I · Superset block card · L
**Owns:** new `WT/SupersetBlockView.swift`; `+Exercises.swift` (`currentExerciseSection`, Up Next superset chip, labels); `ROW/SetTrackerRowView.swift` (`badgeLabel` on the delegate; set circle only); `ST/SetTrackerView.swift` (expose the single-row builder).
**Changes:** block card when the block has > 1 member — a header line per member (name + its "…"), one interleaved table in round order from existing `SetTrackerRowDelegate` with each row's own exercise binding, letter badge in `superset` tint (A1, A2, B1…), headings dropped when tracking modes differ; one correction/rest row per block; Up Next rows carry `Chip(…, tint: .superset)`; labels letter per group + number per member. Fallback if mixed modes misbehave: stacked member mini-tables in one card, CTA still alternating.
**Accept:** `WorkoutTrackerSupersetTests` (two-group labels); new UI test from a `UI_TEST_SUPERSET` mock (log A1 then B1, no rest between, one card). Manual: VoiceOver order follows rounds. **Depends:** G, F.

### WP-J · Exercise strip + directional card swap, behind a switch · M
**Owns:** new `WT/ExerciseStrip.swift`; `WT/WorkoutTrackerView.swift` (body); `WT/WorkoutProgressHeader.swift`; `+Focus.swift` (`blockEntryEdge` inside `setFocus` only); `WorkoutSettings.swift` (`showExerciseStrip: Bool?` default off) + settings row.
**Pure rules:** `stripProgress(for:)`; `entryEdge(from:to:order:)`; `ExerciseStripTests`.
**Changes:** with the switch on, the strip replaces the bar in the `safeAreaBar` (thumbnails + underline, `.isSelected`, followed by `ScrollViewReader` not a second `scrollPosition`; text + `Menu` fallback at AX sizes); List `.id(currentBlockId)` with `.transition(reduceMotion ? .opacity : .push(from: blockEntryEdge))`, edge set in the same mutation as focus; remove `.background(Color.canvas)` on the header and try `.automatic` scroll edge.
**Accept:** `ExerciseStripTests`, `WorkoutSettingsDecodingTests`. Manual (all required): edge effect re-attaches after a swap; keypad resigns cleanly; Reduce Motion fades; switch off = pixel-identical. Prototype T5 in the first hour; fallback 1 opacity transition, fallback 2 strip only. **Depends:** G, E.

### WP-K · One log rule shared by the phone and the Live Activity · L
**Owns:** new `WT/ActiveWorkout+Log.swift`, new `Managers/Training/WorkoutSession/SetValidation.swift` (moved from `SetTrackerRowPresenter.problem`/`validateSetData`); `ROW/SetTrackerRowPresenter.swift` (delegates); `+ActiveExercise.swift` (`logSet` only); `+SessionChanges.swift` (live progression on adopted remote logs); `Managers/LiveActivities/LiveActivityIntentHandler+App.swift`, `LiveActivityManager.swift`; `Shared/WorkoutActivityAttributes.swift` (`targetSide`, `canComplete`), `Shared/LiveActivityPhase.swift`; `WorkoutSessionActivity/LiveActivityPhaseViews.swift`; `ActiveWorkoutScreenState.swift` (+ `focusExerciseId`); `+Focus.swift` (persist focus); `TrainingAccessoryPresenter.swift` (working-set counts).
**Pure rule:** `ActiveWorkout.log(setId:in:settings:context:custom:now:) -> LogOutcome { session, problem?, restSeconds?, focus }`; `ActiveWorkoutLogRuleTests`.
**Changes:** both callers use it; handler reads/writes `focusExerciseId` (+15s/Skip/Adjust reps stop using index 0); Complete disabled when not ready; "Set 1L"/"1R"; Live Activity + accessory count working sets only; handler passes the row's custom rest.
**Accept:** `ActiveWorkoutLogRuleTests`, `LiveActivityIntentHandlerTests` (A1 → B; no rest after final set; invalid refused), `LiveActivityScenarioTests`, `LiveActivityPhaseTests`, `LiveActivitySetTargetLabelTests`, `AdjustLastSetRepsIntentTests`; extension zero warnings. **Depends:** G, B.

### WP-L · Resume rule, cold-relaunch recovery, idle prompt · L
**Owns:** `Managers/HKWorkout/HKWorkoutManager.swift` (rest section → new `HKWorkoutManager+Rest.swift`); `Shared/SharedWorkoutStorage.swift` (`restStartedAt`, `pausedAt`, `pausedDuration`); `WorkoutSessionManager.swift`; `WT/WorkoutTrackerPresenter.swift` (remove `restStartedAt`; `lastSeenSetCompletion`); `+Rest.swift`; `+ActiveExercise.swift` (`restTimer(for:)`, `progressionNote` only); `+Persistence.swift` (idle check on foreground; clear `isIdleTimerDisabled` on minimise; finish-elsewhere shows summary); `AppDelegate.swift`; new `Managers/Training/IdleWorkoutReminder.swift`.
**Pure rules:** `IdleWorkoutReminder.isIdle(lastActivity:now:threshold: 60 min)`; `receipt(setsLoggedAfter:notBy:)`; `IdleWorkoutReminderTests`, `WorkoutResumeRuleTests`.
**Changes:** rest owner records `restStartedAt` with `restEndTime` in the App Group; on launch reload rest + pause and re-arm/end `endRest`; HealthKit `recoverActiveWorkoutSession`, else restart when `hkStartedSessionId` matches but nothing runs (never a second session); remote log shows a one-line receipt in the progression-note slot ("Logged from Lock Screen: Set 2 · 100 kg × 8"); "Still training?" local notification 60 min after the last log (rescheduled per log, cancelled on finish/discard) + foreground alert Finish-at-last-set / Keep Going.
**Strings:** "Logged from Lock Screen: %@", "Still training?", "Finish at %@", "Keep Going".
**Accept:** `HKWorkoutManagerRestTests`, `HKWorkoutManagerPauseTests`, new `WorkoutRelaunchRecoveryTests` (fresh manager over a pre-populated in-memory suite), the two rule suites. Manual: kill mid-rest and relaunch → countdown matches Lock Screen. **Depends:** D, B.

---

## Wave 4 — model and polish (M, N, O, P in parallel; merge order M, O, N, P)

### WP-M · Set kinds: model, counts, rest, progression · M
**Owns:** `WorkoutSetModel.swift` (`kindRawValue: String?`, `parentSetId: String?`, tolerant like `sideRawValue`), new `SetKind.swift` (standard, drop, amrap, myo, restPause, cluster); `WorkoutSetPairing.swift` (`pairedSetCount` skips rows with `parentSetId`); `RestDurationRules.swift` (no rest between sub-sets except `intraSetRestSeconds`, Optional default 15 for myo/restPause/cluster); `WorkoutSessionModel.swift` (template `SetTarget.setType` → `kind` on creation); `Progression/ProgressionPlanner.swift` (ignore sub-sets); `functions/coach-maths.js` (mirror) + `CompoundUnitTests/Fixtures/coach-parity.json` (regenerate with one drop-set case); `WorkoutSettings.swift`.
**Accept:** new `SetKindTests` (unknown kind → standard; old docs decode); `CoachParityTests`; `npm test`; `RestDurationRulesTests`, `WorkoutSessionPrefillTests`, muscle-volume tests. If parity can't be kept, ship counts unchanged and finish parity in Q. **Depends:** K.

### WP-N · Assisted weight, stopwatch, placeholders, `isBodyweight` in the tracker · L
**Owns:** `KB/WeightStepper.swift` (negatives when assisted); `KB/SetKeyboardPresenter.swift`, `KB/SetKeyboardView.swift` (± key when assisted); `SetValidation.swift` (negative only when assisted); `WorkoutSetModel.volumeKg` (nil for negative without bodyweight context); `ExerciseOneRMAggregator.swift` (skip negatives); `WorkoutSessionModel.swift` (duration/distance defaults → nil placeholders); `ROW/SetTrackerRowView.swift` (`inputFields` only: stopwatch + placeholder hint); `KB/SetKeyboardTextField.swift` (placeholder); `WorkoutTrackerInteractor.swift` (assisted template ids).
**Rules:** assisted = library metric `.weightPerSideAssistance`, stored as negative kg; `isBodyweight` with no weight metric hides the weight field; with assistance allows ≤ 0; progression unchanged (+2.5 on −30 = less assistance; test it); log title has no figures until a duration is entered; timeOnly row gets start/stop counting up (optional countdown to target).
**Accept:** new `AssistedWeightTests`, `StopwatchRuleTests`; `WeightStepperTests`; `WorkoutTrackerPresenterProgressionTests` (assisted); `ActiveWorkoutStateTests` (placeholder title). **Depends:** K, H.

### WP-O · Bodyweight contribution in the tracker · M
**Pure helper:** new `Managers/Training/Exercise/BodyweightLoad.swift` — `contributionKg(bodyweightKg:percent:)`, `effectiveKg(external:contribution:)`, `share`, `label(weightKg:unit:showsBodyweight:)` → "BW + 20 kg", "BW × 8", "BW − 20 kg"; `BodyweightLoadTests` (kg/lb, 0 %, nil bodyweight, negative).
**Badge:** new `WT/BodyweightContributionBadge.swift` — capsule at the trailing end of the card title row before "…", wrapping below the title at AX sizes (`ViewThatFits`); `Gauge(value: share)` `.accessoryCircularCapacity` tinted `.success`, two lines: bodyweight in the exercise's unit ("83.95 kg") and "+52.6 kg (63%)"; hidden when the setting is off, contribution 0, or no bodyweight known; a11y label "Bodyweight contribution", value "63 percent of 83.95 kilograms, 52.6 kilograms" (ring never the only signal).
**Labels/volume:** with the setting on, log title, Last column and summaries read "BW + 20 kg × 8"; `computeTotalVolumeKg` and the finish summary use effective load (`ponytail:` today's bodyweight; snapshot on the session if history must stay fixed).
**Owns:** `ExerciseTrackerView.swift` (header); `ActiveWorkoutState.swift` (`figures`, `logTitle` weight part); `+ActiveExercise.swift` (title context); `ROW/SetTrackerRowView.swift` (`previousValueContent` only); `WT/WorkoutTrackerPresenter.swift` (`computeTotalVolumeKg`); `WorkoutTrackerInteractor.swift` (`currentWeightKilograms`, contribution lookup); session summary presenter.
**Strings:** "BW", "Bodyweight contribution", "%@ of %@" + Spanish.
**Accept:** `BodyweightLoadTests`, `ActiveWorkoutStateTests`, `WorkoutSessionDetailPresenterTests`. Manual: badge light/dark and AX5. **Depends:** H.

### WP-P · Accessibility and polish · M
**Owns:** `WT/WorkoutTrackerView.swift`, `WorkoutPrimaryCTA.swift`, `WorkoutProgressHeader.swift`, `+Toolbar.swift`, `+Exercises.swift`; new `WT/WorkoutTrackerPresenter+Announcements.swift`; `ROW/SetTrackerRowView.swift` (row container + labels only); `InlineRestTimerRow.swift` (contrast); `CompoundUITests/WorkoutTrackerUITests.swift`.
**Changes (a11y.md refs):** C1 `AccessibilityFocusState` back to the CTA after log/skip/next; S1 announcements on log, rest over (regardless of sound/haptic settings), exercise change; S3 AX5 header stacks, CTA short form, rest row vertical; S4 text on tints `.primary` with colour on the icon, current-row outline `.tint` 1.5 pt, increased contrast respected; S5 input labels + set-numbered control names; M1 Up Next actions Do Next/Do Later/Move Up/Move Down; M2 Magic Tap (log/skip) + Escape (minimise); M4 each row a container "Set 2, next to log"; M8 remove the suite-wide audit exclusions, filter by element, add passes with keyboard open / "Ready" / `AccessibilityXXXL` / light mode with a warm-up row. **Also remove the `XCTSkip` on `testTheTrackerPassesTheAccessibilityAudit`** (added 6 Oct 2026): the audit reports one "Potentially inaccessible text" with no element that survived labelling the menu texts, the +15s text and auditing a settled screen; dump every leaf element's screenshot with its label to find it (the earlier dump showed only the then-unlabeled "1" and "Kg" menu buttons). TipKit deferred unless test 1 shows the Done change confuses people.
**Accept:** narrowed audit passes; `WorkoutTrackerUITests` serial. Manual: the VoiceOver walk-through below. **Depends:** E, J, F.

## Tail (serial, gated)
- **WP-Q · Set-kind UI · M** (needs M): "Set Type" picker in the set-number menu; "Add Drop Set"/"Add Mini-Set" → indented sub-row; AMRAP chip; log titles "Log drop set"/"Log AMRAP set"; Last matched by kind.
- **WP-R · Docked current-set bar · L** (input.md §7: one shared `SetKeyboardInputHost` in the bottom inset, steppers from `WeightStep`): build only if decision test 2 shows ≥ 0.3 keypad edits per set or ≥ 2 lifters name keypad friction; otherwise close as not needed.

## Dependency graph

```
WP-0 ─┬─ A ─┬─ E ─┬─ J ─┐
      │     └─ F ─┼─ I  ├─ P
      ├─ B ─┬─ G ─┼─────┘
      │     │     ├─ K ─┬─ M ─ Q
      ├─ C ─┘     │     └─ N
      ├─ D ───────┴─ L
      └─ H ─────────── O, N          R gated on the Wave-2 user tests (+E, F)
```

| Wave | Packages | Why together |
|---|---|---|
| 0 | WP-0 | Committed base + file split that prevents most later conflicts |
| 1 | A, B, C, D | Disjoint owners: save path / presenter state / set table / platform plumbing |
| 2 | E, F, G, H | The core loop the user tests judge; H is independent filler |
| 3 | I, J, K, L | Structure and system on top of G's focus rule and B's sidecar |
| 4 | M, N, O, P | Model on top of K and H; polish once views are final |

## Dispatch and review (how this runs)

**Per package:** `Agent(subagent_type: "SwiftUI Developer" (views/presenters) or "general-purpose" (managers/model), model: "opus", isolation: "worktree")` with a prompt containing: the Working rules, the package's full text from this plan, the paths of the spec files in `docs/specs/workout-tracker/`, and "open a PR into `feature/workout-tracker-redesign` titled `[Tracker] WP-X · <goal>` with the new strings and suites listed; end the PR body with the attribution lines". One wave at a time; the next wave's agents launch when their dependencies are merged.

**Lead review on every PR** (apply in this order, stop at the first failure and request changes):
1. Rebased on the branch tip; only **Owns** files changed; shared files only in named functions.
2. Development, Mock and `WorkoutSessionActivityExtension` build with zero warnings; no new Release warnings; test log has no `warning:`.
3. `swiftlint --strict` = 0; no new `swiftlint:disable`.
4. The package's named suites green serially; full unit bundle green before merge (`CompoundUnitTests | Passed` in the xcresult); UI suite only where listed.
5. Pure rules + tests in their own commit; new `WorkoutSettings` fields Optional with a decode test.
6. Strings: every new key has Spanish; no wholesale catalog rewrite; keys listed in the PR body; counts via plural variations or `Format`.
7. `codebase-map.md` regenerated when files added/moved.
8. Decisions doc reflects behaviour changes (5d → E/F; 5b/README 3 → E; `exerciseAutoNext` → G).
9. In-scope HIG findings addressed and cited by `hig.md` section.
10. Perf (A, E, J, O): `_printChanges` on `WorkoutTrackerView`, `SetTrackerRowView`, `TabBarView` — a keystroke re-renders no more than before.
11. No `try?` swallowing a save; every flush path covered (A); no new index-based bindings.
12. `/code-review` on the diff for correctness; merge with `gh pr merge --squash`; delete branch, worktree, DerivedData; `scripts/clean-simulators.sh`.

## Verification

**After each wave, on device (6.1" and 6.9"; iPad for E and J):**

| Check | Pass condition |
|---|---|
| Slow Animations | Log a set and the final set, rest on/off: identical List motion, no List bounce, CTA morphs rather than swaps |
| Reduce Motion | No x/y motion; structure instant; labels fade; the T5 swap is a fade |
| VoiceOver | Log → "Set 2 logged…" → focus stays on the CTA → rest over announced → Next → exercise announced; Magic Tap logs/skips; shake-undo announced |
| AX5 | Header stacks; first set row visible under the bars; CTA figures not truncated; badge wraps; no text < 11 pt |
| Light-mode contrast | "W", "Ready", "Not loadable", current-row outline ≥ 4.5:1 / 3:1 (Accessibility Inspector) |
| Kill and relaunch mid-rest | Countdown matches the Lock Screen; pause survives; Health shows one workout |
| Lock Screen round trip | Log 1L from the Lock Screen → shows "1L", rests, phone shows receipt + correction row; superset partner advances to B; invalid set refused |
| Superset round | A1 → B1 with no/transition rest, rest after B1, one card, CTA alternates, 2 taps per round |
| Double tap / expiry | Double-tap Log = one log; tap at 0:00 does nothing for 1 s then logs; Skip Rest double-tap never finishes |
| Keypad | Done never logs; Log always visible above the keypad; typing prints no SQL |

**Decision tests after Wave 2** (learn-decide B5; write the rules down and date them first): (1) Figma/paper tap-through with 5 lifters — card / card+strip / paged — decides the strip default (J stays off unless 4 of 5 succeed faster) and closes the pager question; (2) observed gym session on the post-Wave-2 TestFlight, 3–5 lifters — decides the WP-R gate and whether caption sizes fail at 60 cm; (3) Wizard-of-Oz pager from a Photos album — decides whether "I want to swipe" is real.

## Risks and fallbacks

| Risk | Mitigation / fallback |
|---|---|
| T5 swap: edge effect doesn't re-attach, two Lists alive, keypad focus | Prototype in the first hour of J; fallback opacity transition; then strip only; the switch defaults off so shipping without it costs nothing |
| `UndoManager` + `@Observable` | Weak self, undo by set id through `updateSet`, skip if `completedAt` changed since, `removeAllActions` on disappear; check the keypad registers no `UITextField` typing undo; if unstable ship the row's Undo button only |
| Set-kind migration | Optional raw strings decode both ways; old builds read sub-sets as plain sets; JS mirror + parity fixture in the same PR; else counts unchanged until Q |
| Save debounce (≤ 300 ms at risk; sync-save assumptions in tests) | Flush on background/minimise/log/finish/discard; tests call `flushSave()`; if flaky, fall back to "skip the nested save" + `.atomic` |
| App Group / entitlement signing | Owner enables the capability first; legacy migration covers mid-workout installs; if CI signing fails, hold the entitlement hunk, merge the code |
| HealthKit recovery API (unverified) | Device test before merging L; on failure restart and log `hk_recovered=false`; never a second session for the same id |
| File-length limits | New logic in new files; `HKWorkoutManager+Rest` extracted; reject any new file-wide disable |
| String catalog conflicts | Wave merge order; later PRs rebase and re-insert keys |
| Superset card with mixed tracking modes | Stacked member mini-tables in one card; G's rule unchanged |
| An agent can't finish | Merge its green pure-rules commit; split the rest into a follow-on package; never merge red or with warnings; revert rather than patch |

## Owner action items
- Enable **Time Sensitive Notifications** on the App ID and confirm the App Group for both App IDs before WP-D merges.
- Merge the `SwiftfulDataManagers` fork PR (atomic write) during WP-A.
- Confirm the prebuilt contribution values (squats/lunges ≈ 85, hinges ≈ 60) before WP-H merges.
- Confirm Undo as an in-tracker affordance (correction row + shake/⌘Z) rather than a toast.
