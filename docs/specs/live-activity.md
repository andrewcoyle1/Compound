# Live Activity — redesign spec (v1)

Replaces the lock-screen banner and Dynamic Island views in `WorkoutSessionActivity/` and adds
the one piece of state and the one intent they need. Builds on `WorkoutActivityAttributes`
(`Shared/`), `LiveActivityManager` and the intents in `Managers/Training/WorkoutRestTimerIntents.swift`.

## 1. Purpose

The activity is read with one thumb while the other hand is holding a weight. At any instant it
answers **one question** and offers **one action**. Everything else is noise and is cut.

Two things the current view gets wrong that this fixes:

- **A missed set is recorded as a hit.** `CompleteSetIntent` logs the prescribed reps as done.
  Smart progression reads that log, so a set that fell short of the target progresses the
  weight anyway. The redesign lets the user correct the reps of the set they just logged,
  during the rest that follows it, and nowhere else.
- **The best row is spent on the app icon and the workout name.** The user started the workout;
  neither tells them anything. The header goes. The workout name appears once, on the summary.

## 2. The phase model

The view no longer branches on booleans inline. A pure derivation turns the content state into
one of seven phases, and each phase has one layout. `Phase` lives in `Shared/` so the widget and
the tests both see it.

```swift
enum LiveActivityPhase: Equatable {
    case ready(target: SetTarget, position: SetPosition)          // about to lift
    case resting(until: Date, next: SetTarget?, logged: LoggedSet?, nextExerciseName: String?) // countdown running
    case restOver(next: SetTarget)                                  // rest passed, phone untouched
    case allSetsDone                                                // nothing left but Finish
    case paused                                                     // isActive == false
    case ended(Summary)                                             // isWorkoutEnded
    case unknown                                                    // no exercise, no target
}
```

`LiveActivityPhase(state:now:isStale:)` is the only derivation, in this precedence:

| Order | Condition | Phase |
|---|---|---|
| 1 | `isWorkoutEnded` | `.ended` with the `final*` fields |
| 2 | `!isActive` | `.paused` |
| 3 | `isAllSetsComplete` | `.allSetsDone` |
| 4 | `restEndsAt > now` | `.resting(until:next:logged:)` — `next` is the current `target*` fields (after `CompleteSetIntent` they already describe the next set), `logged` is `lastLogged*`, `nextExerciseName` is the current exercise's name only when `restLeadsToNewExercise` (the logged set was the last of a different exercise) |
| 5 | `restEndsAt != nil && restEndsAt <= now`, or `isStale` | `.restOver(next:)` |
| 6 | `targetSetId != nil` | `.ready` |
| 7 | otherwise | `.unknown` (renders like `.paused` without the label) |

There is no "exercise done" phase. `LiveActivityManager.exerciseIndexWithWorkLeft` always points
the state at an exercise with an incomplete set — the requested one, the next later one, or the
first anywhere — so a finished exercise is only ever described when every set is done, and row 3
has already answered.

`SetTarget` here is a display value: `weightKg`, `reps`, `durationSec`, `distanceMeters`, formatted
by one `label` in the same shape the tracker's Prev column uses (`60 kg × 8`, `12`, `1:30`,
`400 m 10:00`). `SetPosition` is `(index, total, isWarmup)` for "Set 2 of 4", counted within the
group the next set belongs to: "Warmup 1 of 2" through the warm-ups, then "Set 1 of 4".

## 3. Lock-screen banner

Fixed height across phases so the banner does not jump when a set completes. Two rows plus a
2-pt progress bar along the bottom (`progress`), inset to the 14-pt content margins so the card's
rounded corners never clip it, which is the only whole-workout indicator. Its fill is the accent
(`AccentInk`: volt on dark, olive on light), on a neutral track.

| Phase | Row 1 | Row 2 |
|---|---|---|
| `.ready` | exercise image · **Exercise name** · `Set 2 of 4` | **60 kg × 8** · [✓ Complete] |
| `.resting` | `Logged 60 kg × 8` · [−] [+] on reps | rest ring with countdown inside · `Next 60 kg × 8` (or, after an exercise's last set, `Next: Incline press` over `40 kg × 10`) · [+15s] [Skip] |
| `.restOver` | exercise image · **Exercise name** · `Set 3 of 4` | `Rest over` · **60 kg × 8** · [✓ Complete] |
| `.allSetsDone` | ✓ **All sets complete** | [Finish] |
| `.paused` | exercise image · Exercise name, dimmed | `Paused` · `Resume in the app` |
| `.ended` | ✓ **Workout name** | Duration · Sets · Volume (volume only if > 0) |

Rules:

- One prominent button per phase, never two. Skip and +15s are `.bordered`; Complete and Finish
  are `.borderedProminent`.
- Row 1 in `.resting` is the **correction window** (§4). When there is no `logged` set (rest
  started from the app for a set logged there) row 1 shows exercise name and position instead.
- The exercise image is kept: recognition beats reading at a glance. 38 pt, rounded 6.
- Text colours are semantic (`.primary`, `.secondary`, `.green` for done). Labels on
  `.borderedProminent` use `colorScheme.foregroundSecondary` because the widget's accent is the
  label colour; see §7 on changing that instead.
- Nothing shows the elapsed workout time, total volume, the status message, or the −15s button.

## 4. Correcting the logged set

> **Superseded by §7.** The state and the no-op rules below still hold; the hand-off does not.
> `AdjustLastSetRepsIntent` now calls `LiveActivityIntentHandler.current?.adjustLastSetReps(id:delta:)`
> and there is no `pendingSetAdjustment` slot (§7.2, §7.3).

`CompleteSetIntent` continues to log the prescribed set and start the rest; that keeps the
pre-lift state to one button. Correction happens **during the rest**, when both hands are free and
the number is fresh, and closes when the rest ends or the next set is logged.

### State

Three fields on `ContentState`, written by `CompleteSetIntent` (optimistically) and by
`LiveActivityManager` when the app logs a set itself:

```swift
var lastLoggedSetId: String?
var lastLoggedReps: Int?
var lastLoggedWeightKg: Double?   // display only; weight is not editable here
```

`LiveActivityManager` clears all three when the rest ends or a new `targetSetId` becomes current.

### Intent

```swift
struct AdjustLastSetRepsIntent: LiveActivityIntent {
    @Parameter var delta: Int     // −1 or +1
}
```

- No-op unless the activity's state has `lastLoggedSetId` and `restEndsAt > now`.
- Clamps `lastLoggedReps + delta` to `0...99`.
- Updates the activity optimistically so the label changes at once, then awaits the handler,
  which finds the set by id in the active session, clamps the set's own reps by `delta`, saves
  and pushes. If the set is not found (session changed underneath), it is dropped silently.

### What it does not do

Weight, RPE, duration and distance are not editable from the activity. A rep count is the one
number a user knows the instant a set ends; everything else is an app decision.

## 5. Dynamic Island

The island is always rendered on black; it uses semantic colours and never reads the scheme.

| Region | Content |
|---|---|
| Minimal | rest ring while `.resting`; ✓ in `.allSetsDone`; exercise image otherwise |
| Compact leading | exercise image, or rest ring while resting |
| Compact trailing | `60 kg × 8` in `.ready`/`.restOver`; countdown while resting; `Done` in `.allSetsDone` |
| Expanded | the banner's two rows for the current phase, minus the progress line, minus `.ended` (the island is dismissed on end) |

## 6. Tests

All under `DialedInUnitTests/`. The phase derivation is where the behaviour lives; the views are
one switch each, and there are no UI tests.

- `LiveActivityPhaseTests` (`Managers/`): one case per row of the §2 table, plus the precedence
  rules — ended beats paused, paused beats resting; `isStale` with a live `restEndsAt` still
  gives `.restOver`; rest with no `lastLoggedSetId` gives `.resting(logged: nil)`; a
  half-finished last pair is still `.ready`; the last exercise with its sets done is
  `.allSetsDone`, never a per-exercise "done".
- `LiveActivitySetTargetLabelTests`: the four tracking shapes, kg and lb, fractional kg keeps one
  decimal, distances over a kilometre read in km, nil pieces omitted, a logged set reads like a
  target.
- `LiveActivityEventNameTests`: the start events are named the way update and end are.
- `WorkoutRestSharedStateTests` (`Support/`, `@Suite(.serialized)`): an empty parent whose
  serialisation reaches the four suites nested under it, one per file. They share what the
  runner cannot partition — the rest end time in the app group, which the intent handler reads
  back as a rest in progress, the rest-complete notification, and ActivityKit itself, which has
  answered nil to two suites requesting at once.
- `LiveActivityScenarioTests` (under the parent; requests a real `Activity`): a four-exercise
  workout completed entirely from the activity, checking the phase after every tap; a workout
  ending on a unilateral exercise is not done after the left half of its last pair; a reps
  correction during the rest reaches the activity; the last set of an exercise moves the
  activity to the next; the exercise's pounds preference reaches the push.
- `LiveActivityManagerTests` (`Services/Training/`, under the parent): a push with no activity
  is reported and not remembered; an unchanged push reports nothing, but still lands while the
  activity is loading; rest updates are gated and logged like any push and dropped before the
  first one; `weightUnit` follows the current exercise; `lastLogged*` populated during a rest and
  empty without one; a finished exercise index advances to the next with work left, or the first
  anywhere, and the last keeps its index; half-done pairs count as neither a completed set nor
  all sets done.
- `LiveActivityIntentHandlerTests` (under the parent, on `TestManagers`): `completeSet`
  logs exactly that set with its own targets, starts the settings-derived rest (none with rest
  timers off), pushes the saved session, drops an unknown or already-logged set but still
  pushes so the button re-enables; `adjustLastSetReps` changes only reps, clamps to 0…99, is a
  no-op outside the rest or for an unknown id, and finds the rest after a cold launch;
  `adjustRest` moves the end time (extends the stored one after a cold launch); `skipRest` ends
  it; `completeWorkout` ends the session, pre-completes the rest days that follow, and does
  nothing without a session; completing the last set advances the activity.
- `AdjustLastSetRepsIntentTests`: the correction applies the delta during the rest, is nothing
  without a logged set, closes with the rest, and clamps to 0…99.
- `HKWorkoutManagerRestTests` (under the parent): starting a rest sets and shares the end
  time and puts one countdown on the activity; negative and non-finite durations are sanitised;
  a rest that runs out announces itself (even without an updater) and clears the shared copy; a
  cancelled rest announces nothing and pushes exactly one cleared countdown; a second rest
  replaces the first and never pushes a cleared one; ending or discarding the workout cancels
  the rest silently; a manager released mid-rest is deallocated.
- `RestDurationRulesTests`: one case per row of `RestDurationRules.restAfterCompleting` —
  custom rest unscaled; warm-up scaling; last warm-up with `restAfterLastWarmUp` off → nil; left
  half of a pair uses `sideSetRestScaling` and `restBetweenSideSets` off → nil; right half rests
  between sets; last working set uses `betweenExercisesRestScaling` and `restBetweenExercises`
  off → nil; scaling to 0 → nil; the base is the narrowest setting, with a zero override treated
  as none.
- `WorkoutTrackerPresenterTests` (`Core/`, the "Live Activity's writes" section): a session
  saved elsewhere is adopted; an unchanged one is not re-adopted; another workout's session is
  ignored; a workout finished elsewhere dismisses the screen and stops its writes; coming to the
  foreground (`.inactive → .active`) adopts; a session arriving mid-`updateSet` is not adopted.

## 7. In-process intent handling (v1.1, replaces the shared-storage hand-off)

A `LiveActivityIntent` runs **in the app's process**: the system launches or wakes the app in the
background and calls `perform()` there. The v1 hand-off ignored that. Each intent wrote a
"pending" slot into the app-group defaults, and a one-second timer inside the same process read
it back — a timer that only started once HealthKit's `beginCollection` succeeded, so on the
simulator and for any user who declined HealthKit nothing the widget wrote was ever consumed. A
rest started from the widget also had no branch in the app's rest sync, so it never started the
app's timer even when polling ran.

### 7.1 The handler

```swift
// Shared/
@MainActor protocol LiveActivityIntentHandling: AnyObject {
    func completeSet(id: String) async
    func adjustLastSetReps(id: String, delta: Int) async
    func adjustRest(by seconds: Int) async
    func skipRest() async
    func completeWorkout() async
}

@MainActor enum LiveActivityIntentHandler {
    static weak var current: (any LiveActivityIntentHandling)?
}
```

The app registers one implementation when `Dependencies` is built (the background launch for an
intent runs `AppDelegate` first, so it is in place before any `perform()`), built on the managers
it already has:

- `completeSet(id:)`: find the set in `workoutSessionManager.activeSession`; fill weight, reps,
  duration and distance from its own target values (not from the activity's `target*` fields),
  set `completedAt`, save through `updateActiveSession`; then start the rest through
  `HKWorkoutManager.startRest` with the duration the set-row presenter would have used
  (`WorkoutSettings.restDurationsByExerciseType`, per-exercise override, default — extract that
  lookup from `SetTrackerRowPresenter.baseRestDuration(for:)` into a shared helper so both call
  one function); then push the Live Activity from the saved session.
- `adjustLastSetReps(id:delta:)`: the set must exist and the rest must be running
  (`HKWorkoutManager.restEndTime > now`); clamp `reps + delta` to `0...99`, save, push.
- `adjustRest(by:)` / `skipRest()`: the existing `HKWorkoutManager` rest calls, then push.
- `completeWorkout()`: the existing end path the tracker's Finish uses.

Every action ends with a push from the saved session, so the app is the single source of truth
for the activity. The intent's optimistic update covers only the gap until that push lands.

### 7.2 The intents

Each intent is a thin wrapper with one shape: push the current state with `isProcessingIntent`
on, then `await LiveActivityIntentHandler.current?.<action>`. That loading push is the intent's
only ActivityKit update. The handler's push — built by `LiveActivityManager.makeContentState`,
which sets `isProcessingIntent: false` and derives `lastLogged*`, the rest and the advanced
target from the saved session — is what re-enables the button. Nothing is guessed in between:
the optimistic progress, "logged set" and rest-clearing pushes are gone, so one tap is one
update from the intent and one from the app rather than three.

`AdjustLastSetRepsIntent` keeps one optimistic write, `lastLoggedReps`, carried on the loading
push: that is the number changing under the user's thumb. `AdjustLastSetRepsDecision` stays as
the guard that decides whether the tap does anything at all.

There is no fallback: a `LiveActivityIntent` performs in the app process, after
`didFinishLaunching` has registered the handler, so a tap without a handler cannot happen. If
`current` is nil anyway (a unit test), the intent pushes the state again with the flag off so the
button cannot stay dead.

The handler owes a push on every path, including the ones that change nothing: a tap on a set
already logged, a correction after the rest ran out, "+15s" with no rest running. Each early
return pushes the active session as it is. `LiveActivityManager`'s equality gate lets that
unchanged push through while the activity's own state has `isProcessingIntent` up, since the
loading push went straight to ActivityKit behind the manager's memory of the last push.

### 7.3 What goes

- `HKWorkoutManager`'s per-second polling of `pendingSetCompletion`, `pendingSetAdjustment` and
  `pendingWorkoutCompletion`, and the three properties and clear methods on it, the session
  manager, `CoreInteractor` and `WorkoutTrackerInteractor`.
- `WorkoutTrackerPresenter.startObservingPendingCompletions` and the three `sync…FromWidget`
  methods. In their place the presenter observes `interactor.activeSession` and, when a saved
  session arrives that differs from its own copy and it is not mid-update itself, adopts it —
  that is how a set logged by the handler appears on screen while the tracker is open.
- `SharedWorkoutStorage.pendingSetCompletion/Adjustment/WorkoutCompletion`, the intents' fallback
  writes and the handler's registration-time drain. Only the app ever wrote or read them.
- `HKWorkoutManager.syncRestEndTimeFromSharedStorage` and its per-second call. The app is the only
  writer of `SharedWorkoutStorage.restEndTime`, so there was nothing to poll for. The **write** in
  `startRest`/`cancelRest`/`endRest` stays: the handler's `runningRestEndTime` reads it after a
  cold launch, when the manager's own `restEndTime` is nil.
- `ActivityViewState`, the push-token observation (`pushType` is now `nil`) and the
  `CoreInteractor` wrappers `endActivity(with:)`, `updateRestAndActive` and `discardLiveActivity`.
  Discard is the one `endLiveActivity(isCompleted: false)` call, which dismisses immediately.

### 7.4 Tests

- `LiveActivityIntentHandlerTests`: with `TestManagers`, `completeSet` marks exactly that set
  complete with its own targets, starts a rest of the settings-derived duration, and pushes an
  activity update whose `lastLogged*` name it; `adjustLastSetReps` changes only reps, clamps, and
  is a no-op with no running rest or an unknown id; `skipRest`/`adjustRest` reach the HealthKit
  manager; `completeWorkout` ends the session.
- Intent tests: with a handler registered, `CompleteSetIntent` calls it and writes no shared
  slot; with none, it writes the slot as before.
- `WorkoutTrackerPresenterTests`: a changed `activeSession` from the interactor is adopted;
  the presenter's own in-flight update is not overwritten.
- Removed polling: `HKWorkoutManagerTests` no longer reference the pending properties.

### 7.5 Duplicate countdown

`ProgressView(timerInterval:countsDown:)` in the circular style draws the remaining time as its
own label, at a size it picks that does not fit inside a row-height ring, and `.labelsHidden()`
does not remove it. `RestRing` suppresses it by passing an empty `currentValueLabel` and draws the
countdown itself, as a `Text(timerInterval:)` overlaid on the ring at `0.3 × size`. The island's
compact leading and minimal slots use `showsCountdown: false` for the bare ring, since the
trailing slot already shows the time. Both timer ranges are `Date()...max(until, Date())`, so a
rest that ends between phase derivation and render cannot trip `ClosedRange`'s precondition.

## 8. Out of scope

Editing weight, RPE or duration from the activity; per-side (left/right) sets, which show as one
target; the Apple Watch; push-driven updates from the server; and changing the widget's
`AccentColor` asset away from `labelColor`. That last one is worth doing separately: with a real
accent the prominent labels can drop their explicit inverse colour.
