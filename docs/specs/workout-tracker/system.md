# The workout tracker as a system

Scope: the live tracker (`Compound/Core/Training/Subviews/WorkoutTracker/`), Live Activity and
Dynamic Island (`WorkoutSessionActivity/`, `Compound/Managers/LiveActivities/`, `Shared/`), the
intents (`Compound/Managers/Training/WorkoutRestTimerIntents.swift`), rest notifications
(`Compound/Managers/HKWorkout/RestOverNotifying.swift`), `HKWorkoutManager`, the Training
accessory, the minimised state, and a future Watch app.

Read from the working tree on `feature/workout-tracker-redesign` (uncommitted edits included),
6 Oct 2026. Line numbers are for that tree. **[unverified]** marks claims about platform
behaviour, or ones that follow from the code but have no test and were not run on a device.

---

## Ranked findings

| # | Sev | Finding | Where |
|---|---|---|---|
| 1 | High | **There are two ways to log a set, and they disagree.** The phone's `logSet` checks the set first, uses a rest set by hand on the row, and runs live progression. The Lock Screen's `completeSet` does none of these. It also does not move to the superset partner unless the tracker happens to be alive. | `WorkoutTrackerPresenter+ActiveExercise.swift:239-272` vs `LiveActivityIntentHandler+App.swift:77-98, 196-224` |
| 2 | High | **What the screen is showing lives only in presenter memory.** Minimising releases the presenter, and reopening builds a new one. The new one goes back to the first incomplete exercise. It loses `restStartedAt`, the per-row custom rests and the acknowledged progression notes. It also **re-captures `progressionBaseline` from the current values**, so a set the user edited before minimising now looks engine-filled, and live progression can overwrite it. | `WorkoutTrackerPresenter.swift:58-67, 93, 121-145, 282-284`; `+Progression.swift:30-36, 84-86` |
| 3 | High | **A stale `restStartedAt` hides the inline rest row for a rest started from the Lock Screen.** The value is kept after a phone rest runs out (only Skip clears it). A set logged later from the Lock Screen has `completedAt > restStartedAt`, so `restAnchor` returns nil and the row disappears, while the footer still shows Skip Rest. The comment's "`nil` for a rest started from the Lock Screen" holds only for a fresh presenter. **[unverified by test]** | `WorkoutTrackerPresenter.swift:59-61`; `+Rest.swift:89-95, 128`; `ActiveWorkoutState.swift:144-145`; `+ActiveExercise.swift:174-182` |
| 4 | High | **After a cold relaunch the phone shows no rest while the Live Activity counts one down.** `restEndTime` reads only `HKWorkoutManager.restEndTime`, which is nil in a new process. Only the intent handler falls back to the app group. Nothing re-arms `endRest`, and the pause state (`pausedAt`, `pausedDuration`) is in memory only, so a paused workout comes back running with its paused time added to the clock. | `WorkoutSessionManager.swift:281-287`; `LiveActivityIntentHandler+App.swift:259-263`; `HKWorkoutManager.swift:26, 37-42` |
| 5 | High | **The Apple Health session is never restarted after the app is killed.** `hkStartedSessionId` survives the process, and `onAppear` returns early when it matches. The code calls no `recoverActiveWorkoutSession`. With no session, iOS no longer keeps the app running behind the lock, so rest-over falls back to the notification, and heart rate and energy stop being collected. **[unverified: what iOS does with a session whose process died]** | `SharedWorkoutStorage.swift:49-62`; `WorkoutTrackerPresenter.swift:192-212` |
| 6 | High | **Focus probably silences the rest-over notification.** It asks for `.timeSensitive`, but neither app entitlements file has `com.apple.developer.usernotifications.time-sensitive`. Without that capability the level is treated as `.active`. **[unverified on device]** | `RestOverNotifying.swift:68-70`; `Compound/SupportingFiles/Compound.entitlements`, `Compound-Debug.entitlements` |
| 7 | High | **The App Group name in code is not the one the entitlements grant.** The code uses `group.com.dialedin.app`. The app and the extension (`CODE_SIGN_ENTITLEMENTS = WorkoutSessionActivityExtension.entitlements`) are granted `group.com.compound.app`. `UserDefaults(suiteName:)` on an ungranted group gives a store private to each process. The rest fallback in #4 still works because the handler runs in the app, but the home widgets probably read an empty snapshot. A stray `WorkoutSessionActivity/WorkoutSessionActivity.entitlements` still names the old group. **[unverified on device]** | `Shared/SharedWorkoutStorage.swift:12`; `Compound/Utilities/Constants.swift:62`; `project.pbxproj:1091, 1129, 1168, 1358, 1453` |
| 8 | High | **Minimised with the app open, a rest ends with no signal at all when the Live Activity is off.** The in-app sound and haptic come from the tracker's `.task`, which is cancelled on minimise. The notification is muted while the app is open. When the Live Activity is on, whether its alert shows to an app in front is **[unverified]**. | `WorkoutTrackerView.swift:110-112`; `PushManager.swift:184-186`; `HKWorkoutManager.swift:454-472` |
| 9 | Med | **Finishing from the Live Activity shows the phone nothing.** The tracker just dismisses: no summary, and no first-workout Strava offer, which hangs off the summary. A failed save is never retried and the user is not told; the activity ends at once with no summary. | `WorkoutTrackerPresenter.swift:405-412`; `LiveActivityIntentHandler+App.swift:147-166`; `WorkoutTrackerView.swift:425-434`; `LiveActivityManager.swift:128` |
| 10 | Med | **On the Lock Screen, a superset is not worked round-robin.** The handler keeps the activity on the exercise just logged while it has sets left. The phone moves to the partner, but only if its presenter is alive and adopts the save. Minimised or after a cold launch, a superset is done straight through on the Lock Screen. | `LiveActivityIntentHandler+App.swift:95`; `LiveActivityManager.swift:447-456`; `WorkoutTrackerPresenter+Superset.swift:23-35`; `WorkoutTrackerPresenter.swift:538-544` |
| 11 | Med | **+15s, Skip and the reps correction move the activity off the exercise the user chose.** All three push using "first exercise with work left from index 0". | `LiveActivityIntentHandler+App.swift:117, 127, 144, 268-270` |
| 12 | Med | **"Incomplete" is defined four ways, and "next" two.** `isComplete` treats an exercise with no sets as incomplete, so auto-advance can land on it; the other three skip it. `advanceAfterExerciseCompletion` does not wrap round, while the log button's Next and the Live Activity do. So after the last exercise, with an earlier one put off, the card stays on the finished exercise while the Live Activity already shows the skipped one. | `WorkoutTrackerPresenter.swift:329-331, 454-456, 491-500`; `ActiveWorkoutState.swift:154-165`; `LiveActivityManager.swift:447-456` |
| 13 | Med | **Progress counts disagree.** The tracker header counts working sets only. The accessory and the Live Activity count warm-ups too, although the accessory's comment says it "matches the screen behind it". | `ActiveWorkoutState.swift:65-75`; `TrainingAccessoryPresenter.swift:61-68`; `LiveActivityManager.swift:395-399` |
| 14 | Med | **The Mac (Catalyst) tracker is broken, a known deferral** (`docs/release-checklist.md:59`). See §4. | — |
| 15 | Low | **The accessory's clock includes paused time**, and keeps running while paused. The tracker's clock leaves it out. | `TrainingAccessoryView.swift:61, 121`; `WorkoutTrackerPresenter.swift:165-171` |
| 16 | Low | **A Lock Screen log cannot be corrected unless a rest follows it.** The correction exists only during that rest, so with rest timers off, or on a set whose rule gives no rest, the prescribed reps stand. | `LiveActivityIntentHandler+App.swift:105, 203, 211-216`; `WorkoutRestTimerIntents.swift:158-159` |
| 17 | Low | **With Auto Next off, the card stays on a finished exercise** while the Live Activity has already moved on. | `WorkoutTrackerPresenter.swift:494-499` |
| 18 | Info | **The iPhone is portrait-only**, so "iPhone landscape" is not a case today. | `project.pbxproj:1045, 1406, 1500` |

---

## 1. What can be done without the phone screen, and how the screen reacts on return

### 1.1 What the Live Activity and Dynamic Island offer

| Phase | Controls | Source |
|---|---|---|
| `ready`, `restOver` | **Complete** (`CompleteSetIntent`) | `LiveActivityPhaseViews.swift:73-83, 188-212` |
| `resting` | **−/+ rep** on the set just logged (only when a logged set exists), **+15s**, **Skip** | `:77-79, 156-184, 216-264` |
| `allSetsDone` | **Finish** (`CompleteWorkoutIntent`) | `:85-87, 266-280` |
| `paused` | None. It reads "Resume in the app". | `:89-91, 282-295` |
| Anywhere | A tap opens `compound://workout`, which goes through `showWorkoutTrackerView` and its duplicate guard | `LiveActivityView.swift:47`; `WorkoutTrackerView.swift:441-453` |

The Live Activity cannot do the following:

- Finish early (before every set is logged).
- Pause or resume.
- Change weight, duration, distance or RIR.
- Undo a logged set.
- Choose which exercise to do.
- Discard the workout.

Spec §8 excludes weight editing and the Watch on purpose (`docs/specs/live-activity.md:312-316`).

Each control calls `LiveActivityIntentHandler.current` in the app's own process
(`WorkoutRestTimerIntents.swift:30-45`). The handler is set up in `AppDelegate.swift:73-93`.

### 1.2 What each action does, and what the phone shows afterwards

The phone notices the change in one of two ways:

- **(a) The presenter is alive**, with the tracker presented and the app in the background. The
  presenter watches `activeSession` (`WorkoutTrackerPresenter.swift:388-397`), so it adopts the
  save straight away, even in the background. It does so again when the app becomes active
  (`:215-223`).
- **(b) The presenter is gone**, because the tracker was minimised or the process was killed.
  Opening the tracker builds a new presenter (`:108-146`).

| Action | Handler | Phone, case (a) | Phone, case (b) |
|---|---|---|---|
| **Log set** | `completeSet`: stamps `completedAt` on the set's existing values with no check (`LiveActivityIntentHandler+App.swift:77-98`). Rests by the rules without the row's custom rest. No progression. Pushes the same exercise, or the next one with work left. | `handleWorkoutSessionChange` moves on: to the next exercise if this one is finished (with Auto Next on), else to the superset partner (`WorkoutTrackerPresenter.swift:527-547`). It then pushes again, which overrides the handler's superset choice. **Live progression is not run** (`+Progression.swift:44` is called only from `logSet` and the row). The **rest row is missing** if an earlier phone rest ran out (#3). | The card goes to the first incomplete exercise (`:137-145`), not to what the activity shows. The rest is shown correctly while the process lives, since `restStartedAt` is nil and the row anchors under the logged set with `startedAt = completedAt` (`+ActiveExercise.swift:181`). After a relaunch there is **no rest at all** (#4). |
| **Adjust reps** | `adjustLastSetReps`, only while resting, clamped to 0–99 (`:104-118`) | The corrected done row is adopted. `propagateEdit` skips completed sets (`:470`), which is correct. **Progression is not re-run**, so a set short on reps never lowers the sets still to come. | Same, on reopen. |
| **+15s** | Goes through `startRest` with the remaining time (`:120-138`). The push uses index 0, so the activity jumps exercise (#11). | `restEndTime` is observable, so the countdown and footer follow. The bar's total grows. | After a relaunch, nothing shows (#4). |
| **Skip** | `cancelRest` (`:141-145`) | The row reads Ready, as at a natural end, and the footer goes back to Log. This matches. | Matches. |
| **Finish** | The shared `finishWorkout` (`WorkoutFinishing.swift:90-126`), tried once | The tracker dismisses itself (`WorkoutTrackerPresenter.swift:405-412`). No summary, no Strava offer, no toast (#9). | Training simply has no active session. A failed save means Training offers Resume, but Apple Health was already ended at `WorkoutFinishing.swift:94`. Resuming starts a **second** Apple Health session, because `hkStartedSessionId` was cleared at `:93`. **[unverified: two HKWorkouts]** |

How the other parts of the screen follow:

- **Up Next order.** The Live Activity never reorders, so the order holds. Up Next is derived
  from the card (`+ActiveExercise.swift:24-31`), so it shifts whenever the card does: case (b)
  resets the card, and #12 can leave it on a finished exercise.
- **The progression note** shows only while the exercise on the card has no logged set
  (`+ActiveExercise.swift:143-148`). A first set logged from the Lock Screen therefore removes
  the note before the user ever sees it.
- **Superset round-robin** happens on return only in case (a) (#10).

---

## 2. The handoff: what the phone shows first on return

Options considered:

- **The next set, ready.** Right, but on its own it hides what happened away from the phone. A
  set short on reps that was never corrected becomes invisible.
- **A confirmation sheet.** It blocks the next set, and HIG modality guidance argues against
  confirming something already done. Rejected.
- **Nothing (today).** The card can disagree with the Live Activity (#2, #10, #11, #12), and the
  rest row can disappear (#3, #4).

### Proposed resume rule

> **The phone resumes exactly where the Live Activity is, and owns up to what changed.** On every
> return (foreground, reopen or relaunch) the card shows the exercise and next set that the Live
> Activity last showed. The rest, its countdown and its anchor are the rest owner's, never the
> screen's. Sets logged elsewhere since the screen was last seen appear as a single dismissible
> receipt line where the progression note sits ("Logged from Lock Screen: Set 2 · 100 kg × 8",
> with an Edit button that focuses that row). The receipt goes away on the next action. A workout
> finished elsewhere opens on its summary, not on nothing.

What the rule needs, in the order to build it:

1. **One focus value, persisted.** Store `focusExerciseId` beside the active session; the session
   model or the active-session persistence are both fine. The presenter, the handler and
   `makeContentState` all read and write it. `expandedExerciseId` and `currentExerciseIndex`
   become views of it. This fixes #2, #10, #11 and #17.
2. **One rule for what comes next.** Make it pure, in `ActiveWorkout` (§3):
   `focus(afterLogging:in:settings:)`, covering superset round-robin, exercise completion, Auto
   Next and wrapping. Delete the four copies (#12).
3. **The rest owner records `restStartedAt` with `restEndTime`**, in `HKWorkoutManager` and the
   app group. The screen stops keeping its own copy. This fixes #3, and #4 once the owner reloads
   both from the app group at launch.
4. **Remember "last seen".** Keep `lastSeenSetCompletion: Date` in the presenter. Any set with
   `completedAt` later than it, not logged by this presenter, goes into the receipt.
5. **A finish from elsewhere** pushes `showWorkoutSummary` before dismissing, or Training shows
   it the next time the app comes to the front.

---

## 3. An Apple Watch companion

### 3.1 Is `ActiveWorkoutState.swift` the shared module? Partly.

It is pure and well tested (`CompoundUnitTests/Core/ActiveWorkoutStateTests.swift`), but it is
not self-contained:

- **Portable as they are, once the models move:** `currentSet`, `rowState`, `progress`,
  `latestCompletedSet`, `restAnchor` and `primaryAction` (`:43-165`). They depend only on
  `WorkoutExerciseModel`, `WorkoutSetModel` and the pairing helpers in `WorkoutSetPairing.swift`,
  all of which are in the app target.
- **Not portable:**
  - `progressionReason`, `logTitle`, `figures` and both summaries (`:83-239`) use `Format`
    (design system, app only), `ProgressionSuggestion` and `SetTarget.repTargetDescription`.
  - `Shared/LiveActivityPhase.swift:159-190` already re-implements `Format` to get around this.
    That copy would become a third one.
- **Missing, and the reason the system disagrees with itself:**
  - The focus/advance rules are in the presenter (`WorkoutTrackerPresenter.swift:491-500`,
    `+Superset.swift:23-35`) and in `LiveActivityManager.exerciseIndexWithWorkLeft`.
  - The rest rules are already shared (`RestDurationRules`), which is the model to follow.
  - The set validation is in `SetTrackerRowPresenter.problem`.
  - Live progression is in `+Progression.swift`.

**Recommendation.** Make a local package, or grow `Shared/`, holding the session models, the
pairing helpers, `RestDurationRules`, the logic half of `ActiveWorkout`, and one
**`ActiveWorkoutEngine`**. The engine is a value-type reducer:
`apply(_ command: WorkoutCommand, to state: ActiveWorkoutSnapshot, settings:) -> (snapshot, effects)`.
`WorkoutCommand` is the five verbs of `LiveActivityIntentHandling` plus the ones it lacks:

- `logSet(id, values?)`
- `undoSet`
- `editSet`
- `adjustReps`
- `startRest` / `adjustRest` / `skipRest`
- `focus(exerciseId)`
- `pause` / `resume`
- `finish` / `discard`

The presenter's `logSet`, the intent handler and a Watch would all dispatch to the engine. That
removes #1 by construction. The text formatting stays per platform.

### 3.2 What the Watch needs from the phone's state

- **A snapshot richer than `ContentState`.** It needs every set's values (to log offline), the
  `focusExerciseId`, `restStartedAt` and `restEndsAt`, pause state, units per exercise, rest
  rules, and the progression baseline per set.
- **Values that today exist only in presenter memory must move into persisted state:**
  `customRestSeconds`, `acknowledgedProgressionNotes`, `progressionBaseline`, focus and
  `restStartedAt` (`WorkoutTrackerPresenter.swift:58-67, 93`). That is the same list as #2.
- **Changes merged per set, not whole sessions.** Today `adoptSavedSessionIfChanged` replaces the
  whole session (`:403-418`), and inline edits bind straight into `workoutSession`
  (`WorkoutTrackerView.swift:175-181`). With a Watch both sides can edit at once, so merge per
  set id, latest write wins, with `completedAt` treated as a one-way latch except on Undo.
- **One Apple Health owner.** When the Watch runs the `HKWorkoutSession`, the phone has to mirror
  it (`startMirroringToCompanionDevice` / `workoutSessionMirroringStartHandler`), not start its
  own. Today the phone always starts one (`WorkoutTrackerPresenter.swift:209-211`; and
  `CoreInteractor.swift:275-278`, which calls `startWorkout` before any configuration).
  `hkStartedSessionId` needs to record the device. **[unverified: mirroring API names]**
- **One rest alerter.** The rest owner is whichever device holds the session. The phone's
  notification and the Watch's haptic must not both go off; extend the `RestOverAlert.channel`
  decision with a `.watch` case.
- **Transport.** The mirrored session's data channel (`sendToRemoteWorkoutSession`) or
  WatchConnectivity. The active session itself stays in the phone's local persistence.

### 3.3 What the phone layout must give up or expose

- **Give up as screen-only state:** the card selection, the rest start, the custom rest per row,
  and dismissed notes. All of these become state in the snapshot.
- **Give up:** the assumption that the screen is the only writer. The `isProcessingUpdateSet`
  guard (`WorkoutTrackerPresenter.swift:96, 438-440`) protects only `updateSet`, not edits typed
  into a field.
- **Expose:** the receipt line (§2), so remote writes are visible; Undo on logged sets, which the
  Watch will want too; and the device a set was logged from, if the receipt is to say "from
  Watch".

### 3.4 Cheaper first step

Add `.supplementalActivityFamilies([.small])` to the `ActivityConfiguration`
(`WorkoutSessionActivity.swift:25`). That puts Complete, +15s and Skip in the Watch Smart Stack
using the intents that already exist; nothing calls it today. **[unverified: whether Smart Stack
buttons run `LiveActivityIntent` on the phone on watchOS 26]** Build a Watch app only when heart
rate from the wrist, or logging without the phone nearby, is needed.

---

## 4. iPad at regular width, iPhone landscape, Stage Manager, Mac Catalyst

### 4.1 Layout today

- The tracker is one `List`, in this order: card, Up Next, Completed, Add Exercise
  (`WorkoutTrackerView.swift:26-40`). It is presented as a full-screen cover (`:450`).
- On iPad it is centred in the 700 pt readable column (`Spacing.swift:65`, set at the root).
- The iPhone is portrait-only (`project.pbxproj:1045`), so landscape means iPad only. Keep the
  iPhone portrait-only; a lifter's phone on a bench is not turned sideways.

### 4.2 Proposed two-pane layout

Switch on the container's width, not the device, so Stage Manager and Split View step down
correctly. Reuse `ContentWidth.twoColumns` (740, `Spacing.swift:69`) as the breakpoint, as
`Dashboard` does.

- **Leading pane, about 320 pt: exercise overview.**
  - The progress header.
  - Every exercise in workout order, with its state (done, current, up next) and its summary
    line (`upNextSummary`).
  - Drag handles always shown. There is room, so the "Reorder" toggle (`:203-214`) goes away;
    Do Next and Do Later stay in the context menu.
  - Add Exercise last.
  - Selecting a row calls `onExerciseSelected`. The current exercise stays in the list,
    highlighted, rather than being removed into a card.
- **Trailing pane: set table.** The current exercise card (the `ExerciseTracker` module
  unchanged), the inline rest row, the progression note, and the `.bottomCTA` (Log, or Skip and
  +15s) attached to this pane only.
- **Build.** Use an `HStack` of two `List`s inside the cover's existing stack, not a
  `NavigationSplitView`. There is no navigation between the panes, only selection, and a split
  view would bring a second toolbar and column-visibility state the cover does not need.

### 4.3 Toolbar

Same roles. At regular width, promote **Pause/Resume** and **Finish** out of the menu into
visible buttons. Notes, Workout Settings, Gym Settings and Discard stay in the overflow
(`:349-396`). The minimise chevron and the title with its clock stay as they are.

### 4.4 Keyboard shortcuts

These are proposals. Attach them with `.keyboardShortcut` on the existing buttons so they show in
the ⌘-hold overlay.

| Key | Action |
|---|---|
| ⌘↩ | Primary action (Log, Next or Finish) |
| ⌘= | +15s |
| ⌘⌫ | Skip Rest |
| ⌘P | Pause/Resume |
| ⌥⌘↓ / ⌥⌘↑ | Next / previous exercise |
| Esc | Minimise |

- Return inside a field already logs through the set keyboard's Done.
- ⌘1–⌘5 switch tabs app-wide (`DialedInApp.swift:45-58`) and probably still fire under the
  cover. **[unverified]** Disable them while the tracker is up.

### 4.5 Stage Manager and multiple windows

- A narrow window must fall back to the single column (handled by the width switch above).
- `showWorkoutTrackerView` checks for an existing tracker only within its own router
  (`WorkoutTrackerView.swift:442`). Two windows can therefore each present a tracker, with two
  presenters both writing the session and adopting each other's saves. The rest owner and the
  Live Activity are one per process. Either move the duplicate check to app level (one tracker
  per process), or make the presenter state shared (§3.2). Whether multiple scenes are enabled
  is **[unverified]**: the generated scene manifest is on (`project.pbxproj:1034`), and
  `UIApplicationSupportsMultipleScenes` is not set explicitly.
- `isIdleTimerDisabled` is set for the whole process on appear and is not cleared on minimise
  (`WorkoutTrackerPresenter.swift:190, 282-284`).

### 4.6 Mac Catalyst

Mac Catalyst ships switched on, but the Mac release is deferred (`docs/release-checklist.md:59`).
These break:

- **No rest timer at all.** The whole of `HKWorkoutManager`, rest timer included, is compiled out
  (`HKWorkoutManager.swift:9`), and `restEndTime` returns nil (`WorkoutSessionManager.swift:281-287`).
  `startRestTimer` sets only `restStartedAt` (`+Rest.swift:128-131`), so the row reads "Ready"
  immediately. There is no countdown, no Skip or +15s, and no sound. Fix: move the rest timer
  out of `HKWorkoutManager`. It has nothing to do with Apple Health and is already isolated in
  `HKWorkoutManager.swift:340-521`.
- **Pause does nothing**, but the menu still offers it, and `isActive` is always true
  (`WorkoutTrackerPresenter.swift:50-56, 288-294`).
- **`endedAt` is never stamped** (`+Finish.swift:81-83`). The saved session has
  `activeDuration == nil` (`WorkoutSessionModel.swift:270-272`).
- **Finishing skips its side effects.** The Catalyst branch only saves
  (`WorkoutTrackerInteractor.swift:179-182`). It skips the weekly streak stamp, the macrocycle
  advance, rest-day pre-completion, the widget snapshot, the review prompt and the Strava upload
  (`WorkoutFinishing.swift:90-126` is non-Catalyst only).
- **The set keyboard never appears.** It is a UIKit `inputView`
  (`SetKeyboardTextField.swift:81`), which the Mac does not show **[unverified]**. Done-logs,
  Next/Prev, the plate calculator, the steppers and RIR are therefore unreachable; typing still
  works. `isKeyboardVisible` never becomes true, so the log button always shows, which is fine.
  The Mac and iPad-with-hardware-keyboard layout should offer the keyboard's steppers and plate
  calculator inline or as a popover.
- **No Live Activity.** That is correct, but the rest-over alert then has no channel either.
- **Haptics do nothing.** Every confirmation that relies on `.success`/`.warning` alone needs a
  visible counterpart.

---

## 5. Interruptions: what the design must guarantee

| Interruption | Today | Guarantee to hold |
|---|---|---|
| **Phone call** | The rest is an absolute `Date` (`HKWorkoutManager.swift:371-374`), so it keeps counting. The in-app sound uses `.ambient` (`SwiftfulSoundEffects+Alias.swift:58`), which mixes, and is quiet under the silent switch. **[unverified: in-call behaviour]** | Every timer is wall-clock. Nothing auto-pauses. On return, rule §2 applies. |
| **Screen lock** | With Apple Health running, the app stays alive and `endRest` fires on time, so the Live Activity alerts. Without it, the notification is the alert. `staleDate = restEndsAt` turns the activity to "Rest over" even when the app is suspended (`LiveActivityManager.swift:221`; `LiveActivityPhase.swift:260-274`; `RestOverNotifying.swift:46-55`). | Already well designed. Keep "the notification is always scheduled; whoever gets there first withdraws it". |
| **App killed mid-set** | Survives: the session and `restEndTime` (app group). Lost: Apple Health (#5), pause (#4), the rest shown on the phone and the accessory (#4), focus and presenter state (#2). The scheduled notification still fires. | At launch, the rest owner reloads `restEndTime`/`restStartedAt` and pause state from storage and re-arms `endRest`. Apple Health is recovered, or restarted when it cannot be recovered. Focus is persisted. A test kills and relaunches with the mock managers. |
| **Low Power Mode** | Nothing reads `isLowPowerModeEnabled`. The Live Activity timers are drawn by the system, so they are unaffected. `keepAlive` holds the screen on even when minimised (#4.5). **[unverified: Apple Health and Live Activity throttling under Low Power Mode]** | Nothing time-critical depends on in-app timers, which the backstop notification already provides. Clear `isIdleTimerDisabled` on minimise. Consider ignoring `keepAlive` in Low Power Mode. |
| **Focus / silent switch** | `.timeSensitive` without the entitlement (#6) means silenced. The sound is ambient, so the silent switch mutes it. The haptic plays only with the app in front. Minimised in the app with the Live Activity off: silent (#8). **[unverified: whether Focus filters Live Activity alerts]** | At least one signal that is not sound in every state: the Live Activity alert lights the screen, the notification banner, or the haptic. Add the Time Sensitive capability. Move the in-app announcement from the tracker's `.task` to an app-level observer, so the minimised state is covered. |

---

## Not checked

- No build, test or device run. Platform behaviour is marked **[unverified]**.
- The `ExerciseTracker/`, `SetTracker/` and `SetKeyboard/` internals were read only where they
  bear on logging (`SetTrackerRowPresenter.swift:44-73`) and the keyboard (`SetKeyboardTextField`).
- The live HIG was not consulted (the `apple-hig` skill was not run). The HIG points above are
  from the existing `docs/reviews/hig-active-workout.md` context, not freshly verified.
