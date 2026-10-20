# training_session

The workout tracker's engine, without UI (M3-10). The rules are `training_rules`'; this package
puts `compound_models` (the Firestore shapes) onto them and keeps the workout under way.

| Dart | Swift |
|---|---|
| `mapping.dart`: `rulesSet`, `rulesExercise`, `rulesSession`, `rulesSettings`, `modelSet(s)`, `modelExercises` | — (the Swift rules work on the stored models) |
| `WeightStepper`, `weightRoundingRule` | `WeightStepper.swift`, `WeightStack`'s pins and loads, `WeightRoundingRule.init(exercise:…)` |
| `SessionLoadChoice`, `takingLoad`, `refittingLoad`, `stampingMachineBase` | `SessionLoadChoice.swift`, `WorkoutExerciseModel.machineBaseKg` |
| `sessionFromTemplate`, `defaultSets`, `applyingSetPlan`, `addingSet`, `addedExercise`, `swapping`, `emptySession` | `WorkoutSessionModel(template:)`, `WorkingSetPrefill`, `WorkoutTrackerPresenter.swapping`, `addSelectedExercises`, `startBlankWorkout` |
| `SessionHistory`, `sessionPrefill`, `plannedSession` | `WorkoutSessionManager`'s lookups, `CoreInteractor+PreviousWorkoutReference`, `+Progression`, `plannedSession` |
| `ActiveSessionController` | `WorkoutTrackerPresenter` and its extensions, less the screen; the rest and pause `HKWorkoutManager` keeps |
| `ActiveSessionStore` (`InMemory…`, `File…`) | `WorkoutSessionManager.activeSession`, `ActiveWorkoutScreenState`, `SharedWorkoutStorage` |
| `WorkoutFinisher`, `StreakRecord`, `RetryBackoff` | `WorkoutFinishing.swift`, the presenter's retry, `recordWeeklyStreak` |

- The active session stays on the device until it is finished: every change is kept within
  `ActiveSessionController.saveDebounce` (300 ms), a logged set at once. `FileActiveSessionStore`
  writes a temporary file and renames it over the last; a file it cannot read is moved aside, never
  deleted. `ActiveSessionController.resume` carries on after the app is killed, ending a rest that
  ran out meanwhile.
- `ActiveSessionController.finish` ends the session (paused time recorded, only logged sets kept,
  each stamped with its unit and load count) and keeps it on the device; `WorkoutFinisher` saves
  it, retries a failure that could pass, and stamps the weekly streak on the session and in the
  private settings. The device keeps its copy (`SavedFinish.awaitingServer`, never opened in the
  tracker) until the server confirms the save, then forgets it; a refusal turns it into
  `SavedFinish.refused`, which the tracker offers again and which is not sent to Health or Strava
  a second time. After a relaunch `WorkoutFinisher.settleKept` asks the server
  (`sessionOnServer`) instead. Unlike Swift, which forgets it once Firestore has queued it. Standalone sessions only: a mesocycle's rest days,
  moving the macrocycle on, Strava, Apple Health and the Live Activity come later.
- Words (titles, toasts, spoken labels, the bar's chip) are the app's: the controller answers with
  the decisions they are worded from (`LogResult`, `SetCorrection`, `UndoName`, `SaveProgress`).

`test/src/parity_test.dart` checks the port against `contracts/fixtures/tracker-parity.json`,
which the Swift app's `TrackerParityTests.swift` recorded: every item of the contract's full gym
resolved to a weight step in both units, and six sessions built from a template over that gym.
The fixture was recorded from the Swift app, which was removed from the repository on 20 Oct
2026 (it is archived at the `swift-final` tag and the `archive/swift` branch). It is now frozen:
this port is the source of truth, and the fixture stays as its regression check.

Coverage is held at 100%.
