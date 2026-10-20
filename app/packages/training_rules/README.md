# training_rules

Pure Dart port of the workout tracker's and smart progression's rules.
`contracts/fixtures/progression-parity.json` holds 830 deterministic cases recorded from the Swift
app's `ProgressionParityTests.swift`; `test/parity_test.dart` checks this port against them.

| Dart | Swift |
|---|---|
| `ProgressionEngine`, `ProgressionInput`, `SuggestedSet`, `ProgressionSuggestion` | `ProgressionEngine.swift`, `ProgressionModels.swift` |
| `ProgressionPlanner`, `ProgressionContext` | `ProgressionPlanner.swift` (gym resolution left to the caller) |
| `LoadIncrement`, `EffortScale`, `AmrapProgression`, `MesocycleDeload` | the files of the same names |
| `SessionPrefill`, `prefillWorkingSets` | `WorkoutSessionModel+Prefill.swift` |
| `WeightRoundingRule`, `WeightStep`, `PlateCalculator` | `WeightRoundingRule.swift`, `WeightStepper.swift` (`WeightStep`), `PlateCalculator.swift` |
| `RestDurationRules`, `SetValidation` | `RestDurationRules.swift`, `SetValidation.swift` |
| `WarmUps` | `WorkoutSessionModel+WarmupSets.swift` |
| `ActiveWorkout`, `Stopwatch`, `RestRestore` | `ActiveWorkout.swift`, `ActiveWorkout+*.swift` |
| `pairedSetCount`, `pairedSetIds`, `splittingSides`, `joiningSides`, `matchingSet` | `WorkoutSetPairing.swift` |

The value types (`WorkoutSet`, `WorkoutExercise`, `WorkoutSession`, `SetTarget`,
`WorkoutSettings`) carry only the fields the rules read; mapping `compound_models` onto them is a
later slice's job. Where the Swift returns words (log titles, spoken labels, the plan summary), the
port returns the decision they are worded from (`ProgressionReason`, `NextPiece`, `SetProblem`) and
the app words it.

The fixture was recorded from the Swift app, which was removed from the repository on 20 Oct
2026 (it is archived at the `swift-final` tag and the `archive/swift` branch). It is now frozen:
this port is the source of truth, and the fixture stays as its regression check.

Coverage is held at 100%.
