# Live Activity — work packages

Companion to `docs/reviews/live-activity-review.md` (finding numbers F*/D*/T* refer to it).
Each package is written for a fresh agent with no context beyond this file, `CLAUDE.md` and the
files it names. Run them **in the order listed**: earlier packages shrink the code later ones
touch, and several edit the same files.

## Rules that apply to every package

- Read `CLAUDE.md` first. Branch: `feature/live-activity-redesign`.
- One package = its own commit(s). A bug found on the way is fixed in its own commit with its
  own test, not folded in.
- Narrowest test run while iterating. The Live Activity suites are run with
  `-only-testing:DialedInUnitTests/<SuiteName>` and `-skip-testing:DialedInUITests`. Do **not**
  run the full suite; that happens once, at push.
- The simulator test runner has hung twice today at "before establishing connection". If it
  does: `pkill -f 'xcodebuild test'`, boot the simulator by UDID (`xcrun simctl boot <udid>` then
  `simctl bootstatus <udid> -b`), and pass `-destination 'platform=iOS Simulator,id=<udid>'`.
- `swiftlint` must report zero violations before you commit. File limit 750 lines, type body 500.
- Kill every process you started (xcodebuild, simulators you booted) before reporting done.
- `#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)` guards stay. Nothing in
  `Shared/` may import app-only types.
- `ContentState` is `Codable` and shared with the widget; removing or renaming a field is fine
  (app and widget ship together) but the widget target must still compile: it builds
  `Shared/*`, `Managers/Training/WorkoutRestTimerIntents.swift`, `Extensions/ColorScheme+EXT.swift`,
  `Extensions/String+EXT.swift` and `WorkoutSessionActivity/*`. Build the
  `WorkoutSessionActivityExtension` scheme too if you touch any of those.
- Report: what changed, which tests were added, exact test counts from the result bundle, and
  anything you left undone.

Key files:

| Area | Path |
|---|---|
| Phase model, labels | `Shared/LiveActivityPhase.swift` |
| Content state | `Shared/WorkoutActivityAttributes.swift` |
| App group storage | `Shared/SharedWorkoutStorage.swift` |
| Handler protocol | `Shared/LiveActivityIntentHandling.swift` |
| Banner / island views | `WorkoutSessionActivity/LiveActivityPhaseViews.swift`, `LiveActivityView.swift`, `WorkoutSessionActivity.swift` |
| Manager | `DialedIn/Managers/LiveActivities/LiveActivityManager.swift` (+`+Events`, `LiveActivityUpdating.swift`, `Activity+Sendable.swift`, `CoreInteractor+LiveActivity.swift`) |
| Handler impl | `DialedIn/Managers/LiveActivities/LiveActivityIntentHandler+App.swift` |
| Intents | `DialedIn/Managers/Training/WorkoutRestTimerIntents.swift` |
| Rest timer | `DialedIn/Managers/HKWorkout/HKWorkoutManager.swift` |
| Tracker | `DialedIn/Core/Training/Session/WorkoutTracker/WorkoutTrackerPresenter*.swift`, `WorkoutTrackerInteractor.swift` |
| Registration | `DialedIn/Root/AppDelegate.swift` |
| Tests | `DialedInUnitTests/Managers/LiveActivity*Tests.swift`, `AdjustLastSetRepsIntentTests.swift`, `HKWorkoutManagerRestTests.swift`, `DialedInUnitTests/Services/Training/LiveActivityManagerTests.swift`, `DialedInUnitTests/Core/WorkoutTrackerPresenterTests.swift`, doubles in `DialedInUnitTests/Support/` |
| Spec | `docs/specs/live-activity.md` |

---

## WP1 · Make the branch green: warm-up label and the uncommitted RestRing change  (F3, §7.5)

**Size:** small. **Depends on:** nothing.

1. `Shared/LiveActivityPhase.swift:113`: change `"Warmup set"` to `"Warmup"`. Spec §2 and both
   tests want `"Warmup 1 of 2"`.
2. Commit the uncommitted `WorkoutSessionActivity/LiveActivityPhaseViews.swift` and
   `WorkoutSessionActivity.swift` changes (countdown drawn inside `RestRing`, bare ring in the
   island's compact slots). First: remove the duplicated doc-comment line above `RestRing`
   ("The circular rest countdown." followed by "The rest countdown as a ring…" — keep the second
   paragraph), and change both `Date()...until` expressions (in `RestRing` and in
   `WorkoutSessionActivity.compactTrailing`) to `Date()...max(until, Date())` so a rest that
   ends between phase derivation and render cannot trip `ClosedRange`'s precondition (F10).
3. Update `docs/specs/live-activity.md` §7.5 to describe the new ring (system label suppressed
   with an empty `currentValueLabel`, countdown overlaid at `0.3 × size`, `showsCountdown: false`
   for the compact slots) and the §3 `.resting` row ("rest ring with countdown inside").

**Tests:** `LiveActivityPhaseTests`, `LiveActivityScenarioTests` go green. No new tests.
**Done when:** those two suites pass and `swiftlint` is clean. Two commits: the label fix, then
the ring.

---

## WP2 · Delete the dead hand-off machinery  (D1, D2, D3, D4, D7, D8, D12)

**Size:** medium, mostly deletion. **Depends on:** WP1.

Delete, in this order, building between steps:

1. **D1 – fallback slots.** In `Shared/SharedWorkoutStorage.swift` remove `PendingSetCompletion`,
   `PendingSetAdjustment`, `PendingWorkoutCompletion`, their three keys, getters/setters and
   `clear…` methods. Keep `restEndTime`, `clearRestEndTime`, `hkStartedSessionId`,
   `clearHKStartedSessionId`. In `WorkoutRestTimerIntents.swift` remove every
   `if handler == nil { … }` branch, `buildPendingSetCompletion`, the `fabricatingRest` parameter
   and body of `applyRestLogic` (it becomes "set `isProcessingIntent = false`"; see WP6 which
   removes it entirely), and `defaultRestDurationSeconds`. In
   `LiveActivityIntentHandler+App.swift` remove `drainFallbackSlots`, `drain`, `setReps`. In
   `AppDelegate.registerLiveActivityIntentHandler` remove the `Task { await handler.drainFallbackSlots() }`.
   Delete the three "Draining…" tests in `LiveActivityIntentHandlerTests`. Rationale for the
   commit message: a `LiveActivityIntent` performs in the app process after
   `didFinishLaunching` has registered the handler, so the slot can never be written.
2. **D2 – rest polling.** Remove `HKWorkoutManager.syncRestEndTimeFromSharedStorage` and its call
   in `startWorkoutTimer` (the timer keeps updating `metrics.elapsedTime`), the
   `CoreInteractor.syncRestEndTimeFromSharedStorage` wrapper, and the three "Widget Changes"
   tests in `HKWorkoutManagerRestTests`. Keep the `SharedWorkoutStorage.restEndTime` writes in
   `startRest`/`cancelRest`/`endRest`: the handler's `runningRestEndTime` reads it after a cold
   launch.
3. **D3 – view state and push token.** Remove `ActivityViewState`, `LiveActivityManager.activityViewState`,
   `setup(withActivity:)`'s state construction, the `contentUpdates` half of `observeActivity`,
   `Data.hexadecimalString`, `CoreInteractor.liveActivityViewState`; change `pushType: .token`
   to `pushType: nil`. `updateRestAndActive` currently reads `activityViewState?.contentState`;
   make it read `lastContentState` (WP4 reworks it further, this is just to compile). Keep the
   `activityStateUpdates` loop for `cleanupDismissedActivity`.
4. **D4 – `SendableActivity`.** Delete the private wrapper at the bottom of
   `LiveActivityManager.swift` and call `activity.update` / `activity.end` directly;
   `Activity+Sendable.swift` already provides the conformance. If strict concurrency still
   complains, keep the wrapper and delete `Activity+Sendable.swift` instead — one of the two, not
   both.
5. **D7 – interactor surface.** In `CoreInteractor+LiveActivity.swift` delete `endActivity(with:)`,
   `updateRestAndActive`, `discardLiveActivity` and their doc comments. In
   `WorkoutTrackerPresenter.discardWorkout` replace
   `await interactor.discardLiveActivity(); interactor.endLiveActivity(...)` with just the
   `endLiveActivity(session:isCompleted: false, statusMessage: "Workout Discarded")` call (it
   already uses `.immediate` dismissal). Remove `discardLiveActivity` from
   `WorkoutTrackerInteractor` and the doubles in `DialedInUnitTests/Support/WorkoutTrackerDoubles.swift`.
   Delete `LiveActivityManager.discardLiveActivity`.
6. **D8.** Delete `WorkoutSessionManager.restEndTime` and the `#else` branch of
   `CoreInteractor.restEndTime` (`WorkoutSessionManager.swift` ~line 233); the `#if` body stays.
7. **D12.** Delete `Shared/ElapsedTimeView.swift` (no references). Move `Shared/MetricsModel.swift`
   to `DialedIn/Managers/HKWorkout/MetricsModel.swift` and remove it from the widget target in
   `project.pbxproj` (it is a synchronized folder: check whether `Shared/` is a
   `PBXFileSystemSynchronizedRootGroup` for the extension and whether the file needs an exception
   or a plain move).

**Tests:** all nine Live Activity suites plus `WorkoutTrackerPresenterTests` and
`WorkoutTrackerFinishTests`. Expected: fewer tests than before (six deleted), none failing.
**Done when:** both the app and `WorkoutSessionActivityExtension` build, tests pass, lint clean.
Update `docs/specs/live-activity.md` §7.2 (no fallback), §7.3 (polling gone), §4 (marked
superseded by §7).

---

## WP3 · Cold launch: every handler action must reach the activity  (F1, F12, F14, T1)

**Size:** small code, important. **Depends on:** WP2.

1. `LiveActivityManager`:
   - Add a private `resolveActivity(sessionId:)` that returns `currentActivity` if set, else
     `Activity<WorkoutActivityAttributes>.activities.first { $0.attributes.sessionId == sessionId }`,
     storing it in `currentActivity` and calling `observeActivity` on it.
   - `updateLiveActivity(params:)` knows `params.session.id`; make it call `resolveActivity` before
     the private overload, or pass the id through. Move `lastContentState = contentState`
     **below** the `guard let activity` (F14).
   - `endLiveActivity(session:…)` → `endActivity` must resolve by `session.id` the same way.
   - `startLiveActivity` currently reuses `Activity.activities.first` for any session (F12): reuse
     only a match on `sessionId`; end any other lingering `WorkoutActivityAttributes` activity
     with `.immediate` before requesting a new one.
   - `ensureLiveActivity`'s `existingActivity(for:)` requires `.active`; accept `.stale` too.
2. `AppLiveActivityIntentHandler.push` can stay as `updateLiveActivity(params:)` once the manager
   resolves the activity itself. Do not add an `ensureLiveActivity` call there unless (1) proves
   insufficient.
3. **T1:** in `LiveActivityScenarioTests.makeRig` build the `LiveActivityManager` with a
   `LogManager(services: [spy])` where `spy` records event names (copy `SpyLogService` from
   `LiveActivityManagerTests` into `DialedInUnitTests/Support/`), and at the end of each scenario
   `#expect(!spy.trackedEventNames.contains("LiveActivityMan_UpdateLiveActivity_Fail"))`.
   This will fail before your change and pass after **only if** the resolution finds an activity —
   which it cannot in a test process. So the rig also needs a seam: give `LiveActivityManager` an
   internal `activityLookup: (String) -> Activity<WorkoutActivityAttributes>?` you can stub, or
   accept that T1 asserts the *fail is logged* today and document that. Prefer the stub; it is one
   closure, not a protocol.
4. Add a `LiveActivityManagerTests` case: with `currentActivity == nil` and the lookup returning
   nil, `updateLiveActivity` logs Fail and does **not** record `lastContentState`.

**Done when:** the scenario suite and manager suite pass, the new tests fail on the old code
(check by stashing), lint clean.

---

## WP4 · Paired sets: half a pair is not the end of the workout  (F2, T2)

**Size:** small. **Depends on:** WP2.

1. `LiveActivityManager.computeTotals`: `completedSetsCount` becomes
   `session.exercises.reduce(0) { $0 + Self.fullyCompletedRows(in: $1.sets).pairedSetCount }`.
   Same change in `endLiveActivity`'s `completedSetsCount`. `totalSetsCount`, `progress` and
   `isAllSetsComplete` follow from it.
2. `WorkoutTrackerPresenter.completedSetsCount` has the same overcount (`24/24` after the left
   half of the last pair). Use the same helper; consider moving `fullyCompletedRows` onto the
   `Collection where Element == WorkoutSetModel` extension in `WorkoutSetPairing.swift` as
   `fullyCompletedPairedSetCount` so both callers share one line.
3. **T2:** add to `LiveActivityManagerTests`:

   ```swift
   @Test func aHalfDoneLastPairIsNotAllSetsDone() { … }
   ```
   Session with one unilateral exercise, sets `1L, 1R, 2L` done and `2R` not. Assert
   `state.targetSetId == "2R"`, `state.isAllSetsComplete == false`, `progress < 1`, and
   `LiveActivityPhase(state:now:isStale:)` is `.ready` with `SetPosition(index: 2, total: 2)`.
   Also extend `LiveActivityScenarioTests.session()` so the **last** exercise is unilateral (or
   add a second scenario) — the existing one never hits the bug.

**Done when:** the new test fails before, passes after; scenario and manager suites pass.

---

## WP5 · One rest push, in order; `updateRestAndActive` through the front door  (F5, F6, T4)

**Size:** medium. **Depends on:** WP2, WP3.

1. `HKWorkoutManager`: add a private `cancelRestTimer()` that cancels/nils `restTimer` and nils
   `restEndTime` and clears the shared copy, with no Live Activity push. `cancelRest()` calls it
   and then pushes (as today). `startRest` calls `cancelRestTimer()` instead of `cancelRest()`.
2. `LiveActivityManager.updateRestAndActive`: build from `lastContentState` (guard non-nil), copy
   it as a `var`, set `isActive`, `restEndsAt`, `statusMessage` (statusMessage goes away in WP7;
   fine to keep for now), then call `updateLiveActivity(contentState:)`. Delete the 40-line
   memberwise rebuild and the inner `Task`. It now logs, gates on equality and records
   `lastContentState` like every other push. Keep `relevanceScore: 100` if you want it: put it on
   the single `activity.update` call for all pushes.
3. Delete both `liveActivityUpdater?.endLiveActivity(...)` calls in
   `HKWorkoutManager.consumeSessionStateChange` (F5). Every finish path ends the activity itself
   with the real session; this one used the session as it was at `startWorkout` and raced the
   real end. `activeSessionModel` may then be unused except for the `endRestNoSession` guard —
   keep it for that.
4. **T4:** `HKWorkoutManagerRestTests`: after `startRest` while a rest is already running,
   `spy.restAndActiveUpdates` gained no entry with `restEndsAt == nil` and `spy.fullUpdates.last`
   carries the new end. Also: `cancelRest()` still produces exactly one nil-rest update (existing
   test covers it).
5. `LiveActivityManagerTests`: `updateRestAndActive` with an identical rest is suppressed (no
   Start logged); with a changed rest logs Start then Fail (no activity in tests).

**Done when:** `HKWorkoutManagerRestTests`, `LiveActivityManagerTests`,
`LiveActivityIntentHandlerTests`, `LiveActivityScenarioTests` pass.

---

## WP6 · `CompleteSetIntent`: one push, button disabled until the app has done the work  (F8, T5)

**Size:** small. **Depends on:** WP2.

1. In `CompleteSetIntent.perform`, with the fallback gone: push the loading state
   (`isProcessingIntent = true`, existing `updateLoading`), then `await handler?.completeSet(id:)`.
   Delete `applyLoggedSet`, `applyOptimisticProgress`, `applyRestLogic`, `pushUpdate`. The
   handler's push (via `makeContentState`) carries `isProcessingIntent: false`, `lastLogged*`, the
   rest and the advanced target, so the optimistic guesses are not needed. If
   `LiveActivityIntentHandler.current` is nil (only possible in a unit test), clear
   `isProcessingIntent` again so the button does not stay dead.
2. Apply the same shape to `AdjustRestTimerIntent`, `SkipRestTimerIntent` and
   `AdjustLastSetRepsIntent`: loading push, await handler. `AdjustLastSetRepsIntent` keeps its
   optimistic `lastLoggedReps` write because that is the one the user is watching change under
   their thumb; `AdjustLastSetRepsDecision` stays as the testable guard.
3. Update `docs/specs/live-activity.md` §7.2.

**Tests:** `AdjustLastSetRepsIntentTests` unchanged. Nothing new is testable here without an
`Activity`; say so in the report.
**Done when:** app and extension build, lint clean.

---

## WP7 · Trim `ContentState` and the update params  (D5, D9)

**Size:** medium, mechanical. **Depends on:** WP5, WP6.

1. Remove from `WorkoutActivityAttributes.ContentState`: `statusMessage`, `totalVolumeKg`,
   `endedSuccessfully`, `lastIntentTimestamp`, `finalTotalExercisesCount`. Remove
   `Summary.totalExercisesCount`. Fix every initialiser call site (manager, intents, tests,
   previews).
2. Remove `LiveActivityUpdateParams.statusMessage`, `.totalVolumeKg`, `.elapsedTime`, and the
   `statusMessage` parameter from `ensureLiveActivity`, `updateRestAndActive`, `endLiveActivity`
   throughout (`LiveActivityUpdating`, `CoreInteractor+LiveActivity`, `WorkoutTrackerInteractor`,
   the presenter's `refreshLiveActivity`, the handler's `push`, `HKWorkoutManager`, the doubles).
   Replace `MakeContentStateParams` with a plain
   `makeContentState(session:isActive:currentExerciseIndex:restEndsAt:)`.
3. `WorkoutSessionActivity.swift`: delete `previewOld`, `stale`, `someMetrics` and the six
   `#Preview` blocks. Add one `#Preview("Banner", as: .content, …)` with one content state per
   phase (`ready`, `resting`, `restOver`, `allSetsDone`, `paused`, `ended`) built through a small
   `static func preview(_ phase: …)` helper, and one `.dynamicIsland(.expanded)` preview reusing
   them. Keep `LiveActivityView.swift`'s preview pointed at the same states.
4. `WorkoutActivityAttributes.workoutTemplateId` and `startedAt` have no readers; delete them.

**Tests:** all Live Activity suites compile and pass; counts unchanged.
**Done when:** both targets build, lint clean, previews render in Xcode (open one to check).

---

## WP8 · Always point at work left; delete `.exerciseDone`  (F7, F11, D6)

**Size:** small. **Depends on:** WP7.

1. `LiveActivityManager.exerciseIndexWithWorkLeft`: after the forward search fails, fall back to
   the first exercise anywhere with an incomplete set; only then keep `requested`.
   `AppLiveActivityIntentHandler.currentExerciseIndex(in:)` already does first-anywhere; make the
   manager the single owner and have the handler call it (it is `static`).
2. Delete `LiveActivityPhase.exerciseDone`, the `nextExercise*` five fields on `ContentState`,
   `deriveNextExerciseData`/`NextExerciseData`, the `doneRow`/`nextExerciseRow` branch for it in
   `LiveActivityPhaseContent`, and the three `.exerciseDone` tests in `LiveActivityPhaseTests` and
   the two "next exercise" tests in `LiveActivityManagerTests`. Row 6 in the derivation goes; row
   numbering in comments and spec §2 shifts.
3. Add a `LiveActivityManagerTests` case: exercises A (incomplete), B (done), C (done), requested
   index 2 → state describes A with a target.
4. Update spec §2 (seven phases, table rows) and §3 (drop the `.exerciseDone` row).

**Done when:** phase, manager and scenario suites pass; the scenario still walks all four
exercises (it already asserts the index advances).

---

## WP9 · Finish from the Lock Screen is the same finish as the tracker's  (F4, T3)

**Size:** medium. **Depends on:** WP2.

1. `WorkoutTrackerPresenter`: in `adoptSavedSessionIfChanged`, when `interactor.activeSession`
   is nil and the screen's `workoutSession.endedAt == nil` (i.e. it was not this screen that
   finished it), call `router.dismissScreen()` and set a flag so `saveWorkoutProgress` no longer
   writes. Simplest: a `private var isFinishedElsewhere = false` checked at the top of
   `saveWorkoutProgress()`.
2. Extract the tracker's finish body (`WorkoutTrackerPresenter+Finish.completeFinish` minus the
   toasts) into one place both callers use. The natural home is a `WorkoutFinisher` free
   function or a method on `CoreInteractor` taking the managers, but the handler does not have
   an interactor. Lowest-ceremony option: a `static func finish(session:…)` in
   `WorkoutTrackerPresenter+Finish` is wrong (handler must not depend on a presenter). So: a
   small `WorkoutFinishing` file under `Managers/Training/` with one `@MainActor func
   finishWorkout(session:sessions:hk:liveActivity:streak:strava:programs:) async -> SaveOutcome`
   that both the presenter and the handler call; the presenter keeps its retry/toast loop around
   it. Include `preCompleteConsecutiveRestDays` and `setActiveWorkoutGymProfile(nil)` in the
   shared part. Do not add a protocol for it.
3. **T3:** `WorkoutTrackerPresenterTests`: set `interactor.activeSession = nil`, call
   `adoptSavedSessionIfChanged()`, assert the router recorded a dismiss and a subsequent
   `updateExerciseNotes` does not call `updateActiveSession`. `LiveActivityIntentHandlerTests`:
   `completeWorkout` calls `preCompleteConsecutiveRestDays` (through whatever double the shared
   finisher takes).

**Done when:** `WorkoutTrackerPresenterTests`, `WorkoutTrackerFinishTests`,
`LiveActivityIntentHandlerTests` pass.

---

## WP10 · Weight unit on the Lock Screen  (F9, T6)

**Size:** small. **Depends on:** WP7.

1. Add `var weightUnit: LiveActivityWeightUnit = .kilograms` to `ContentState`.
2. `LiveActivityManager` needs the preference: give `LiveActivityUpdateParams` (or the
   `makeContentState` signature) a `weightUnit:` argument. Callers: the presenter has
   `exerciseUnitPreferences[templateId]`; the handler gets `ExerciseUnitPreferenceManager` injected
   (register it in `AppDelegate` like the others) and reads
   `getPreference(templateId: exercise.templateId).weightUnit`; `HKWorkoutManager.startRest` passes
   what it was given (add the parameter). Map `ExerciseWeightUnit` → `LiveActivityWeightUnit` with
   a one-line extension in the app target.
3. Views: replace every `LiveActivityLayout.weightUnit` with `state.weightUnit`; delete the
   constant and its "follow-up" comment.
4. **T6:** `LiveActivityManagerTests`: state built with `.pounds` yields `.pounds`;
   `LiveActivityIntentHandlerTests`: a preference of pounds for the exercise reaches the push.

**Done when:** those suites pass, extension builds.

---

## WP11 · Small fixes and missing tests  (F13, T7, T8, T9)

**Size:** small. **Depends on:** WP9.

1. `WorkoutTrackerPresenter.onScenePhaseChange`: condition becomes `newPhase == .active`. Test:
   `(old: .inactive, new: .active)` adopts a changed session.
2. `RestDurationRulesTests` (new, `DialedInUnitTests/Managers/`): a table over the cases in
   `RestDurationRules.restAfterCompleting` — custom rest wins unscaled; warm-up scaled by
   `warmUpRestScaling`; last warm-up with `restAfterLastWarmUp == false` → nil; left half of a
   pair uses `sideSetRestScaling` and `restBetweenSideSets == false` → nil; last working set
   uses `betweenExercisesRestScaling`; scaling to 0 → nil; zero override treated as none.
3. `WorkoutTrackerPresenterTests`: `updateSet` while a differing `activeSession` arrives is not
   overwritten (`isProcessingUpdateSet`). Drive it by setting `interactor.activeSession` inside
   the double's `updateActiveSession` hook.

**Done when:** new tests pass and fail when the guarded line is removed (spot-check one).

---

## Finishing

After WP11: run the full unit suite once
(`-skip-testing:DialedInUITests`, read the unit bundle's result per `CLAUDE.md`), `swiftlint`,
build all three app schemes and the extension for warnings, and update
`docs/specs/live-activity.md` §6 (tests list) to match what exists. Then push.
