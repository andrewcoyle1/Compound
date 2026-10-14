# compound_maths

Pure Dart port of the figures the Compound app computes for the user. The Swift app is the source
of truth; `functions/coach-maths.js` is the server's copy, and all three are checked against
`CompoundUnitTests/Fixtures/coach-parity.json`.

| Dart | Swift |
|---|---|
| `expenditureHistory`, `ExpenditureFilter` | `ExpenditureEngine.swift`, `ExpenditureFilter.swift`, `ExpenditureWindowStats.swift` |
| `expenditureSamples` | `ExpenditureSampleBuilder.swift` |
| `estimateTdee`, `resolvedBmrEquation` | `FormulaExpenditure.swift`, `NutritionManager.estimateTDEE`, `NutritionStrategySettings.resolvedBMREquation` |
| `energyDensityKcalPerKg` | `EnergyDensity.swift` |
| `weightTrend`, `WeighInNoise` | `WeightTrendCalculator.swift` |
| `estimatedOneRepMax`, `exerciseOneRepMax` | `ExerciseOneRMAggregator.swift` |
| `hardSets`, `weeklyMuscleSets` | `MuscleVolume.swift` |
| `pairedSetCount` | `WorkoutSetPairing.swift` |

Dates are day keys (`YYYY-MM-DD`, in the user's time zone), as in the JavaScript: the caller turns
timestamps into day keys once.

`test/parity_test.dart` runs every fixture case with the tolerance the Swift and JavaScript tests
use (within a millionth); `test/maths_test.dart` covers the rules the Swift suites check and the
edges the fixture does not reach. Coverage is held at 100% (`.github/workflows/flutter.yml`).
