# Adaptive expenditure — algorithm spec

Status: implemented. Written 2026-09-22; the estimator and the proposal were rebuilt on
2026-10-09 as one Kalman filter and a deadband controller (§3, §4). Companion to
`docs/dead-settings-audit.md`, which lists the eleven settings this engine gives meaning to.

## 1. Purpose

Replace the one-shot formula TDEE (`NutritionManager.estimateTDEE`) with an estimate that adapts
to what the user actually logs: daily energy intake from meal logs and the trend in scale weight.
The formula stays as the **prior** — the estimate before there is enough data, and the anchor that
bounds the adaptive figure. Nothing in this spec deletes or bypasses the existing formula code.

The prior itself is `FormulaExpenditure` (`Managers/Nutrition/NutritionManager/`), which the
onboarding Expenditure step also runs: resting rate × a physical activity level (PAL).

- Resting rate: Mifflin-St Jeor by default (Mifflin 1990; within 10% for about three in four people,
  Frankenfield 2005, Madden 2016), −78 as the midpoint when sex is not given, revised
  Harris-Benedict as an option, and Cunningham 1980 (500 + 22 × fat-free mass) when body fat is
  logged and opted into. Cunningham replaced Katch-McArdle (O'Neill 2023; Tinsley 2019); its stored
  value is still `katchMcArdle`.
- PAL: sedentary 1.40, light 1.55, moderate 1.70, active 1.85, very active 2.00 — values Compound
  chose inside the FAO/WHO/UNU 2004 bands (1.40–1.69 / 1.70–1.99 / 2.00–2.40). The old table started
  at 1.2 and added up to 0.20 for training frequency; the frequency term is gone, because the bands
  include habitual exercise and expenditure plateaus at high activity (Pontzer 2016). The 2023 DRI
  EER equations were not adopted: several of their coefficients and band edges are unverified
  (`docs/research/citation-verification-checklist.md`, discrepancies 1–2).
- Digestion is shown as 10% of the total (Westerterp 2004). Floor: 1,000 kcal.

The engine is **pure**: a value-type `ExpenditureEngine` in
`DialedIn/Managers/Nutrition/Expenditure/` that takes daily samples and settings and returns a
per-day estimate history. It has no manager dependencies, no `@MainActor`, no `Date()` calls
(the caller passes "today"), and is exhaustively unit-testable. `CoreInteractor` gathers the
samples from the managers and feeds the engine.

## 2. Inputs

### 2.1 Daily samples

One `DailySample` per calendar day in the user's current calendar/timezone, from the first day
with any data up to and including **yesterday**. Today is never included: it is incomplete.

```
struct DailySample {
    let day: Date            // start of day
    let intakeKcal: Double?  // nil when the day has no meal logs
    let weightKg: Double?    // nil when no weigh-in that day
    let steps: Int?          // nil when no steps record
}
```

- `intakeKcal` = sum of `MealLogModel.totalCalories` over all meal logs whose `dayKey` is that
  day. A day with one or more meal logs but zero total calories counts as **logged with 0 kcal**,
  not as unlogged; a day with no meal logs is `nil`.
- `weightKg` = the day's earliest `BodyMeasurementEntry.weightKg` with `deletedAt == nil` (the
  morning reading; a tie keeps the entry listed first).
- `steps` = `StepsModel.number` for that day, ignoring records with `deletedAt != nil`. If more
  than one record exists for a day, take the largest.

### 2.2 Settings (from `NutritionStrategySettings`)

| Setting | Meaning in this engine |
|---|---|
| `calculationMode` | `.dynamic`: run the filter. `.fixed`: every day's estimate is the prior; the engine still returns a history (and still runs the filter, so the trend weight is there), with `isProvisional = false` and `source = .fixed`. |
| `calculationStartDate` | Samples strictly before this day are discarded before anything else runs. The replay starts fresh (prior only) from this day. `nil` means use all samples. |
| `algorithmVersion` | `.version1` (stored `"v1"`) selects the filter below. The raw value is kept so stored settings decode; the 2026-10 rewrite replaced what v1 computes rather than adding a v2. |
| `stepInformedUpdates` | Enables the step nowcast in §3.7. |
| `predictiveGoalAdjustments` | **No longer read** and no longer on the Expenditure screen. It switched on a rate-error correction in the proposal that counted the same gap twice (§4). Kept in the model so stored documents decode and round-trip. |
| `estimationMethod`, `bmrEquation` | Shape the **prior** through `resolvedBMREquation`. The engine takes the prior as a number. |

### 2.3 Other inputs

- `priorKcal: Double` — the formula TDEE (`NutritionManager.estimateTDEE`).
- `kcalPerKg: Double` — the energy in a kilogram of weight change, from `EnergyDensity`
  (`CoreInteractor.expenditureKcalPerKg`: Forbes-partitioned with a body fat reading from the
  last 90 days, else 7,700). Defaults to 7,700.
- `today: Date`, `calendar: Calendar`.

A sample also carries `isExcluded` (partial or in a logging break) and `isFastingDay` (the user
marked a fast). `weightKg` is the day's **first** weigh-in, not the mean.

## 3. Algorithm

The 2026-10 rewrite follows `docs/research/algorithms-evidence.md`, "One filter replaces
two EMAs, a blend, a clamp and a second loop". It replaced: a 0.10/day EMA trend with a ±2.5%
clamp (and a separate 0.25-per-weigh-in EMA on the Weight Trend screen), a raw 28-day energy
balance at 7,700 kcal/kg, a 0.30 daily blend capped at ±150 kcal, and a 14-day minimum.

Constants live in `ExpenditureEngine.Constants`, `ExpenditureFilter` and `WeighInNoise`. Every
value marked *design choice* has no published source and is to be tuned by replaying anonymised
histories (one-step weigh-in prediction error, 80%-interval coverage, proposals per user-month).

### 3.1 The weight trend (`WeightTrendCalculator`, `WeighInNoise`)

One trend for the chart and the engine. Weigh-in noise R = max((0.005·L)², 0.3²): 0.5% of body
weight from Schneditz 2023's 0.53% day-to-day SD (R30); the 0.3 kg floor is a design choice.

- **Robust update.** Innovation v = y − L, S = P_LL + R. R_eff = R·max(1, (|v|/(2.5·√S))²) (a
  Huber-type robust Kalman update; 2.5 is a design choice). A reading with |v| > max(3 kg, 4%·L)
  is **held**; if the next weigh-in is also that far off in the same direction, the shift is
  confirmed (P_LL += v², then a plain update), otherwise the held reading is dropped. This
  replaces the ±2.5% clamp.
- **The chart** (`WeightTrendCalculator.trend(data:calendar:)`): a local-linear-trend filter
  [L, b] with the real gap Δt in calendar days, Q = 0.004²·[[Δt³/3, Δt²/2],[Δt²/2, Δt]] +
  diag(0.05²·Δt, 0) (design choices; 0.004 kg/day ≈ (q_E + q_T)/ρ² of the engine, giving a 7–10
  day time constant like the Hacker's Diet, R39), started at the median of the first three
  weigh-ins with slope 0 ± 0.1 kg/day, then a Rauch–Tung–Striebel smoothing pass (R41). Only the
  first weigh-in of a day updates it. `exponentialMovingAverage(data:)` is kept as an alias.

### 3.2 The filter (`ExpenditureFilter`)

State x = [L (kg), E (kcal/day), T (kcal/day)], E and T on the user's logging scale. One step a
day: L ← L + (E − T)/ρ; E, T carried. Process SDs per day (design choices): L 0.05 kg, E 30 kcal,
T 13 kcal (≈35 kcal a week). A weigh-in observes L (rules of §3.1); a complete logged day observes
E with SD σ_I. Start (on the first weigh-in): L = median of the first three weigh-ins with
P_LL = R; E = T = prior; SD(E) = 500; SD(T) = max(0.15·prior, 340) (340 is NASEM 2023's RMSE,
R14; 15% is a design choice). Mass-driven TDEE drift (ε ≈ 24 kcal/day per kg) is **not**
modelled: the citation checklist flags its interpretation, and q_T absorbs it.

### 3.3 Intake observations

A day's intake is read when it is logged, not excluded, and either marked as a fast or at least
`partialDayFraction` (0.5, design choice) of the current T. Every other logged day is treated as
partly logged: predicted through, not observed. σ_I is the SD of the complete logged days in the
28 days ending that day, held in 300–500 kcal (400 with fewer than seven), doubled when fewer than
60% of those days are complete (design choices). Unlogged days need no rule: the filter predicts
through them and its variance grows.

### 3.4 Calibration

The estimate for day D is read from the filter after day D−1. It is **calibrated** when all hold
(design choices; Hall & Chow 2011, R34, for the four-week order of magnitude):

- at least `minDays` (21) days since the first sample;
- at least `minWeighIns` (14) weigh-ins used;
- √P_TT < `maxCalibratedSDKcal` (200);
- complete logged days ≥ `calibratedLoggedFraction` (0.8) of the sample days in the 28-day window.

While calibrating, `kcal` is the prior, `source = .prior`, `isProvisional = true`. Someone who
only weighs in never calibrates: without logs only E − T is identifiable. They still get the
trend and the rate.

### 3.5 Output

`kcal = clamp(T, 0.6·prior, 1.6·prior) + nowcast`, rounded (the band is a guard only; the filter
state is not clamped). `sdKcal = √P_TT` (nil in Fixed mode and before the first weigh-in).
`weeklyTrendChangeKg = 7·(E − T)/ρ` and its SD once there are 21 days and 14 weigh-ins.
`recentIntakeKcal` is the mean of the last seven window days' complete logged intakes.
`likelyRange` is the 80% interval kcal ± 1.28·SD; `confidence` is high below 120 kcal SD, medium
to 250, low above (design choices). Sanghvi 2015 (R35) found ≈215 kcal/day individual RMSD even
with good data, so nothing tighter is claimed.

### 3.6 Fixed mode

`kcal = prior`, `source = .fixed`, `isProvisional = false`, `sdKcal = nil`. The filter still
runs, so trend weight and rate are populated.

### 3.7 Step nowcast (optional)

Unchanged in shape: when `stepInformedUpdates` is on, the estimate is calibrated and at least half
the window's days have steps, `(mean of the last 7 step days − mean of the window's step days) ×
kcalPerStepPerKg × trend weight`, capped at ±300 kcal, added for display and proposals only.
`kcalPerStepPerKg` is now **0.0004**, the net walking cost (≈0.49 kcal/kg/km from the ACSM walking
equation, R21, at 1,300–1,400 steps/km — the step length is an assumption); 0.0005 was roughly the
gross figure.

## 4. Proposal (`TargetProposal`)

Propose-and-confirm is unchanged: the estimate never rewrites a `DietPlan` by itself. The
controller is feedforward with a deadband, evaluated at most weekly:

```
target = T + ρ·r_goal/7            r_goal = active goal's signedWeeklyChangeKg (0 without one)
target = max(target, CalorieFloor.minimumValue(for: sex))
nil unless calibrated, not Fixed, a plan exists
nil unless |target − current| > max(50, sdKcal)
adherence: if target < current, recentIntakeKcal > 1.10·current and weeklyTrendChangeKg > r_goal
           → AdherenceNote (shown in the check-in), no proposal
nil unless the plan is ≥ 7 days old (createdAt to the estimate's day)
proposed = current + clamp(target − current, −150, +150), rounded
dismissal: hidden while within 50 kcal of the dismissed figure
```

The old rate-error term, clamp((goal − trend rate)·7700/7, ±200), is **deleted**: the filter is
already an integral-type estimator, so when the rate was off because TDEE was wrong it counted the
gap twice, and when it was off because the user ate above target it lowered a target they were
already missing. `Reason` keeps only `.expenditureMoved`. The 50 kcal, the SD deadband, the 150 kcal
step, the 7 days and the 10% margin are design choices; the structure follows SmartLoss (R43) and
MacroFactor's published logic (R42, unreviewed). The optional maintenance band and the
glycogen-burst level noise from the report are not implemented.

## 5. Integration points

1. `NutritionManager.computeDietPlan(user:delegate:trainingProgram:expenditureKcal:)` gains an
   optional `expenditureKcal: Double? = nil`; when non-nil it replaces `estimateTDEE(user:)` for
   the target calculation and is what lands in `DietPlan.tdeeEstimate`.
2. `CoreInteractor`:
   - `var expenditureHistory: [ExpenditureEstimate]` — built from `mealLogs`,
     `bodyMeasurements`, `stepsHistory`, `nutritionStrategySettings`, the existing
     `estimateTDEE(user:)` prior, and `Date()` as today.
   - `var currentExpenditure: ExpenditureEstimate`.
   - `var targetProposal: TargetProposal?`.
   - `func acceptTargetProposal() async throws` and `func dismissTargetProposal()`.
3. Expenditure Settings screen: show `currentExpenditure.kcal` with its 80% interval and a
   one-line status ("Adaptive · 21 of 28 days logged", "Calibrating: estimated from your profile
   until 21 days and 14 weigh-ins are logged", "Fixed"). The expenditure detail screen charts
   `expenditureHistory` with today's interval and confidence badge above the list. The Energy
   Balance screen, the Progress deficit cards and the carousel read the adaptive estimate per day
   and average intake over logged days only (`EnergyBalanceSummary`).
6. Every figure here has an ⓘ (`MethodInfo.weightTrend`, `.adaptiveExpenditure`,
   `.energyDensity`, `.energyBalance`, `.targetProposal`, `.checkInRules` in
   `MethodInfo+Energy.swift`).
4. Nutrition overview: a dismissible "New targets suggested" card driven by `targetProposal` with
   Accept and Not now. Minimal; the check-in flow will restyle it later.
5. `DietPlan` needs no schema change.

## 6. Test cases

`CompoundUnitTests/Managers/Nutrition/ExpenditureEngineTests.swift` (the replay),
`ExpenditureFilterTests.swift` (the filter on its own), `TargetProposalTests.swift`,
`CompoundUnitTests/Utilities/WeightTrendCalculatorTests.swift`, and the same rules in
`functions/coach-maths.test.js`. Among them: convergence to the true expenditure through noise on
the scale and the log; calibration on day 21 and not before; weigh-ins without logs never
calibrate but give a rate; unlogged days only widen the SD; a wild weigh-in is held and dropped, a
smaller one is down-weighted; a partial day is skipped and a marked fast is read; the 80% gate
after a logging break; Fixed mode; the nowcast at 0.0004; feedforward without double counting; the
SD deadband, the 150 kcal step and the 7-day cadence; adherence before lowering.

## 7. Not done

Any persistence of estimates; running the old engine in shadow behind a flag (the report suggests
it until replay shows the intervals are calibrated); tuning the design choices on replayed
histories; the opt-in menstrual-window R inflation (its source is unconfirmed, checklist item 15);
the post-target-change glycogen burst in q_L; the optional maintenance band; mass-driven TDEE drift
ε; a BMI-based body fat estimate for ρ when none is logged.
