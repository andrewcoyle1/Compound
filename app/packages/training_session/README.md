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
  it, retries a failure that could pass, forgets it once stored, and stamps the weekly streak on
  the session and in the private settings. Standalone sessions only: a mesocycle's rest days,
  moving the macrocycle on, Strava, Apple Health and the Live Activity come later.
- Words (titles, toasts, spoken labels, the bar's chip) are the app's: the controller answers with
  the decisions they are worded from (`LogResult`, `SetCorrection`, `UndoName`, `SaveProgress`).

`test/src/parity_test.dart` checks the port against `CompoundUnitTests/Fixtures/tracker-parity.json`,
which `TrackerParityTests.swift` records from the Swift: every item of the contract's full gym
resolved to a weight step in both units, and six sessions built from a template over that gym. To
regenerate it after changing the Swift:

```bash
TEST_RUNNER_RECORD_PARITY=1 xcodebuild test -project Compound.xcodeproj \
  -scheme 'Compound - Development' -destination 'platform=iOS Simulator,id=…' \
  -only-testing:CompoundUnitTests/TrackerParityTests -parallel-testing-enabled NO
```

Coverage is held at 100%.
