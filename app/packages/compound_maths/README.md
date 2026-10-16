# compound_maths

Pure Dart port of the figures the Compound app computes for the user. The Swift app is the source
of truth; `functions/coach-maths.js` is the server's copy, and all three are checked against
`CompoundUnitTests/Fixtures/coach-parity.json`.

| Dart | Swift |
|---|---|
| `expenditureHistory`, `ExpenditureFilter` | `ExpenditureEngine.swift`, `ExpenditureFilter.swift`, `ExpenditureWindowStats.swift` |
| `expenditureSamples` | `ExpenditureSampleBuilder.swift` |
| `estimateTdee`, `resolvedBmrEquation` | `FormulaExpenditure.swift`, `NutritionManager.estimateTDEE`, `NutritionStrategySettings.resolvedBMREquation` |
| `energyDensityKcalPerKg`, `dailyKcalForWeeklyChange` | `EnergyDensity.swift` |
| `weightTrend`, `WeighInNoise` | `WeightTrendCalculator.swift` |
| `estimatedOneRepMax`, `exerciseOneRepMax` | `ExerciseOneRMAggregator.swift` |
| `hardSets`, `weeklyMuscleSets` | `MuscleVolume.swift` |
| `pairedSetCount` | `WorkoutSetPairing.swift` |
| `calorieFloor`, `referenceWeightKg`, `proteinGrams`, `dailyMacros`, `dailyCalories`, `highDayIndices` | `NutritionTargets.swift`, `CalorieFloor.minimumValue(for:)` |
| `goalTargetKcal`, `dietPlanDays`, `signedWeeklyChangeKg` | `NutritionManager.goalTarget`, `computeDietPlan`, `WeightGoal.signedWeeklyChangeKg` |
| `evaluateTarget`, `proposeTarget`, `dismissedProposalKey` | `TargetProposal.swift` |
| `checkInState`, `checkInWeekStart` | `CheckInSchedule.swift` |
| `sumMacros`, `macroRemaining`, `macroProgress`, `macroShare`, `planDayTarget` | `MealLogManager.getDailyTotals`, `MacroHeader`, `NutritionPresenter`, `NutritionManager.getDailyTarget` |

Dates are day keys (`YYYY-MM-DD`, in the user's time zone), as in the JavaScript: the caller turns
timestamps into day keys once.

The nutrition rules have their own fixture, `CompoundUnitTests/Fixtures/nutrition-parity.json`,
recorded from the real Swift by `NutritionParityTests.swift` (`TEST_RUNNER_RECORD_PARITY=1` to
re-record) and checked here by `test/nutrition_parity_test.dart`.

`test/parity_test.dart` runs every fixture case with the tolerance the Swift and JavaScript tests
use (within a millionth); `test/maths_test.dart` covers the rules the Swift suites check and the
edges the fixture does not reach. Coverage is held at 100% (`.github/workflows/flutter.yml`).
