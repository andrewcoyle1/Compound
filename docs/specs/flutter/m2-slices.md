# M2: read-only mirror, slice plan

Researched on 14 Oct 2026 from the Swift sources; paths are relative to `Compound/`. M2 reads the
same Firestore data the Swift app writes and **never writes**. Each slice is one PR into
`feature/flutter`.

| # | Slice | Contains | Size |
|---|---|---|---|
| 1 | Training contracts + `workout_session_repository` | Training enums (`TrackingMode`, `SetSide`, `SetKind`, `ExerciseWeightUnit`, `EquipmentKind`, `EquipmentRef`). `EquipmentVariation` (lossy decoder). `SetTargetSetType`: legacy `{rawValue}` and `{name}` objects are read, a plain string is written. `SetTarget`. `WorkoutSetModel`: custom decoder, camelCase `isWarmup`. `WorkoutExerciseModel`: `substitute_exercise_ids` is left out when empty. `WorkoutSessionModel`. Read path: `users/{uid}/workout_sessions` where `author_id == uid` | L |
| 2 | Workout history + session detail | Finished, non-rest sessions, newest first. Rows show set count, volume, active duration and highlights. Detail shows each exercise and its sets. Per-exercise unit: `exercise.weightUnit`, then `set.weightUnit`, then kg. Bodyweight contribution is left out | M |
| 3 | Nutrition contracts + `meal_log_repository`, `diet_plan_repository` | `NutrientMap`: unknown keys and NaN/inf are dropped. `MealItemSourceType`: unknown values become `ingredient`. `MealItemModel`, `DietPlan` and `DailyMacroTarget`: camelCase keys. `MealLogModel`. `FoodLogSettings`. The Apple Health de-duplication rule (`Managers/Nutrition/MealLogManager.swift:30-34`) | M |
| 4 | Meal log day view | Calendar strip with calorie markers, `MacroHeader` rings, the hour timeline (`startHour`, `endHour`, `hideEmptyHours`), meal sections | M |
| 5 | Body + goal contracts + repositories, with the trend port in parallel | `BodyMeasurementEntry`, `StepsModel`, `AnalyticsSettings`, `WeightGoal`. Legacy: no `goal_id` means the id is `user_id`; the document id is `currentGoalId ?? uid`. `OverarchingObjective` is a **keyed map**. In parallel, `WeightTrendCalculator` (a Kalman filter with RTS smoothing, self-contained) goes into `compound_maths`, with fixtures recorded from `WeightTrendCalculatorTests` | M |
| 6 | Scale Weight + Weight Trend screens | One shared metric-detail widget: a chart (scale weight plus trend) and a list of entries | S |
| 7 | Today tab | Checklist, streak card (`WeeklyStreak.make`) and protein gap. Training shows only "done today" or "nothing planned", because the planned day needs `MesocycleSchedule` (programs, M5) | M |
| 8 | Progress overview | Cheap cards: habits, macros, protein, scale weight, steps, workouts sparkline, plus Weight Trend and Goal Progress. Hidden until M4 or M5: Expenditure, Energy Balance, Muscle Groups, Exercises. Honours `hiddenSectionIds` | M |

**Left out of all of M2:** every write and edit flow, the check-in card (M4), the weekly review
(it needs the expenditure engine), social, Strava, Ask Coach, and today's planned workout.

If the trend port slips, slices 6 and 8 ship scale weight only, and Weight Trend and Goal Progress
move to M4.
