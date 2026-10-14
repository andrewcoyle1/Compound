# training_rules

Pure Dart port of the workout tracker's and smart progression's rules. The Swift app is the source
of truth. `CompoundUnitTests/Fixtures/progression-parity.json` holds 830 deterministic cases that
`ProgressionParityTests.swift` records from the Swift and checks; `test/parity_test.dart` checks
this port against the same file.

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

To regenerate the fixture after changing the Swift:

```bash
TEST_RUNNER_RECORD_PARITY=1 xcodebuild test -project Compound.xcodeproj \
  -scheme 'Compound - Development' -destination 'platform=iOS Simulator,id=…' \
  -only-testing:CompoundUnitTests/ProgressionParityTests -parallel-testing-enabled NO
```

Coverage is held at 100%.
