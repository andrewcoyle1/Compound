# Smart progression — algorithm spec (v1)

Status: specification for implementation. Written 2026-09-22. Gives meaning to the three
`WorkoutSettings` fields the dead-settings audit lists as `feature`:
`smartProgressionInitialLogFill`, `smartProgressionAdjustmentMode`,
`smartProgressionApplyInSession`.

## 1. Purpose

Suggest the weight, reps, duration or distance for each working set of an exercise at the start
of a session, from what the user did last time and the template's rep targets, using
**double progression**: work up the rep range at a weight, then add weight and drop back to the
bottom of the range. Optionally re-suggest the remaining sets of an exercise live, after each
set is completed.

The engine is **pure**: a value-type `ProgressionEngine` in
`DialedIn/Managers/Training/Progression/` with no manager dependencies, no `@MainActor`, no
`Date()`. Rounding to gym equipment is `WeightRoundingRule`, built from the keyboard's `WeightStepper`; the engine takes a rounding closure so it does not
need the gym profile.

## 2. Inputs

```
struct ProgressionInput {
    let trackingMode: TrackingMode                 // .weightReps, .repsOnly, .timeOnly, .distanceTime
    let setTargets: [SetTarget]                    // from the template's WorkoutExerciseModel
    let history: [ProgressionHistorySession]       // most recent first, at most 3, see §2.1
    let adjustmentMode: ProgressionAdjustmentMode  // .weightFirst / .repsFirst
    let roundWeight: (Double) -> Double            // kg in, kg rounded to equipment/unit out
    let minimumIncrementKg: Double                 // smallest step the rounding can express; see §2.2
}

struct ProgressionHistorySession {
    let workingSets: [WorkoutSetModel]             // completed, non-warm-up, in index order
}
```

### 2.1 History

History is resolved per exercise by `CoreInteractor.previousSessions(forExerciseTemplateId:workoutTemplateId:authorId:trainingProgramId:limit:)`, the single place `previousWorkoutReference`
is honoured — the tracker's "Prev" column goes through the same call, so Auto and Prev can never
disagree about what last time was. Its three scopes are `.anyExercise` (the last sessions that
included this exercise, whatever workout they were, via
`getLastCompletedSessionsContainingExercise(...)`), `.sameWorkout` (the last completed sessions of
this workout template, in any program — the default) and `.workoutsInProgram` (the same, filtered
by `trainingProgramId`). The two template scopes fall back to the any-exercise lookup when this
template holds no history for the exercise, so an exercise new to a template still progresses from
wherever it was last performed. The lookup returns the last **three** completed sessions
(`limit: 3`), because the deload rule in §3.4 needs to see two consecutive misses. The exercise's history is the sets of the
exercise with the same `templateId` in each of those sessions, filtered to
`isWarmup == false && completedAt != nil`. Sessions where the exercise has no completed working
set are dropped from the history. Per-side exercises: the two rows of a set are one set; use the
row with `side == .left` (or the first row) as the set's values.

### 2.2 Rep range and increment

For target set `i` (1-based `setNumber`), `minReps`/`maxReps` come from `setTargets[i]`. When
either is nil, derive from the reference set (§3.1): `minReps = prevReps`, `maxReps = prevReps + 2`. When the template has fewer targets than the previous session had sets, the last target
applies to the extra sets.

`minimumIncrementKg`: the caller passes the equipment's increment when the exercise is on a
pin-loaded or cable machine, else 2.5 kg when the preferred unit is kg and 5 lb (2.268 kg) when
it is lb.

**Percentage increments (2026-10, `LoadIncrement.swift`).** The step is a share of the working
weight by `ExerciseType` (`ProgressionInput.exerciseType`, from the library exercise): 5 % for
`compoundLower`, 2.5 % for `compoundUpper` and an untyped exercise, 5 % for isolation and core —
within ACSM's 2–10 % (ACSM 2009, *Med Sci Sports Exerc* 41:687). The engine adds
`max(weight × p, minimumIncrementKg)` and rounds through `roundWeight`; if rounding brings the
weight back to the previous value it adds twice the step and rounds again. Assistance (a
negative weight) steps by `minimumIncrementKg` alone.

**Rep fallback.** When the rounded step is more than 10 % of the working weight (2 kg on a 12 kg
dumbbell is 17 %), the set gets `reps + 1` at the same weight instead, until Epley says the reps
done carry the heavier weight for the bottom of the range:
`weight × (1 + reps/30) ≥ heavier × (1 + minReps/30)`. Load and rep progression grow muscle
equally (Plotkin 2022, *PeerJ* 10:e14142). When every progressable set falls back, the
rationale is `.addReps`. The 10 % limit and the Epley gate are Compound's own choices.

Only sets whose `setType` is `.standard` or `.failure` are progressed. `.drop` and `.myo` sets
are prefilled with previous values (never progressed) so the intensity technique stays what the
template author designed.

## 3. Algorithm (session-start suggestion)

### 3.1 Reference

`ref = history[0]` (the most recent session with completed working sets). Reference set for
target `i` is `ref.workingSets[i]` if it exists, else the last working set of `ref`.

No history → `rationale = .noHistory`; suggestions are nil for every field, and the caller falls
back to the existing behaviour (template defaults). The engine never invents a starting weight.

### 3.2 Classification (per exercise, weight/reps mode)

Let `top` be the number of working sets in `ref` that reached `maxReps` (reps ≥ maxReps) and
`missed` the number that fell below `minReps`. Let `rpeOK` be true unless a set has `rpe`
logged **and** the target has `rirTarget` **and** `rpe > 10 − rirTarget + 0.5` (the set was
harder than prescribed; RPE and RIR are the same scale from opposite ends, Zourdos 2016). A
compound exercise (`compoundUpper`/`compoundLower`) whose target has no `rirTarget` is held to
1 RIR (`LoadIncrement.defaultReserve`), the low end of the 1–3 suggested for compounds; RPE 10
at the top then does not earn weight. Isolation and untyped exercises get no default.
A **failed miss** is a set below `minReps` that was not stopped short: RPE ≥ 9.5, or no RPE.

| Condition | Class |
|---|---|
| `missed > 0`, the previous session (`history[1]`) at a weight ≥ this one, and both sessions have a failed miss | `.deload` (a reset) |
| `missed > 0` | `.hold` |
| not `rpeOK`, or the top criterion below not met | `.addReps` |
| no set of `ref` has an RPE, and `history[1]` (at a weight ≥ this one) did not also meet the top criterion | `.addReps` |
| otherwise | `.progressWeight` |

Top criterion: `.weightFirst` needs `top × 2 > workingSets.count` (a majority); `.repsFirst`
needs `top == workingSets.count`. Without RPE the reps alone do not say how hard the top was, so
the top must be reached on two sessions running at this weight (ACSM 2009's "two consecutive
sessions"). The RPE 9.5 trigger and the 1-RIR default are Compound's own choices.

### 3.3 Suggestion per class (weight/reps)

- `.progressWeight`: every progressable set gets the increased weight of §2.2 and
  `reps = minReps`, or `refReps + 1` at `refWeight` where the step is too big (§2.2).
- `.addReps`: each set keeps `refWeight`; `reps = min(refReps + 1, maxReps)`. A set that was
  already at `maxReps` keeps `maxReps` (in `.repsFirst` this is the set waiting for the others).
- `.hold`: every set keeps `refWeight` and `refReps` exactly. One miss is a bad day, not a signal.
- `.deload` (an exercise-level reset): the weight is re-derived from the reference set's
  estimated one-rep max (§9) at the bottom of the range with reps in reserve —
  `e1RM ÷ (1 + (minReps + RIR)/30)`, RIR the target's `rirTarget` else 2
  (`LoadIncrement.resetReserve`) — clamped to 85–95 % of `refWeight`, rounded down if the
  rounding is ambiguous; `reps = minReps`. With no estimate (more than ten reps to failure)
  it is `refWeight × 0.90`, the practitioner convention it replaces (Starting Strength,
  5/3/1). Assistance gets ×1.10 more assistance. The 2-RIR and 85–95 % limits are Compound's
  own choices.

Reference weight is per set: set `i` progresses from its own `ref` set, so a session logged with
descending weights stays descending.

### 3.4 Other tracking modes

- `.repsOnly` (bodyweight): classification as §3.2 with `top`/`missed` on reps; `.progressWeight`
  becomes **raise the range**: `reps = maxReps + 1` on every set (and the caller shows the target
  range shifted by one). `.addReps`, `.hold` as above. `.deload`: `reps = minReps`.
- `.timeOnly`: the reference value is `durationSec`. No rep range: suggest
  `duration = roundTo5s(refDuration × 1.10)` when every set was completed, else hold.
- `.distanceTime`: reference `distanceMeters`; suggest `roundTo50m(refDistance × 1.05)` when every
  set was completed, else hold; `durationSec` carried over unchanged.

### 3.5 Output

```
struct ProgressionSuggestion: Equatable {
    let rationale: Rationale                // .noHistory, .progressWeight, .addReps, .hold, .deload
    let sets: [SuggestedSet]                // one per target set, index-aligned with the working sets
}
struct SuggestedSet: Equatable {
    let weightKg: Double?
    let reps: Int?
    let durationSec: Int?
    let distanceMeters: Double?
}
extension ProgressionSuggestion.Rationale {
    var hint: String   // "Add weight", "Add a rep", "Repeat last session", "Lighter this week", ""
}
```

## 4. Live in-session adjustment (`smartProgressionApplyInSession`)

Per product decision this toggle means **live set-to-set re-suggestion**. When it is on, after a
working set is completed (`SetTrackerRowPresenter.onSetComplete`), the engine's
`adjustRemaining(completed: WorkoutSetModel, target: SetTarget, remaining: [WorkoutSetModel], mode: TrackingMode, roundWeight:, minimumIncrementKg:) -> [SuggestedSet?]` runs over the
**not-yet-completed** sets of that exercise:

| Completed set | Remaining sets |
|---|---|
| reps < minReps − 1 (missed by two or more) | weight × 0.95 rounded, reps = minReps |
| reps == minReps − 1 (missed by one) | same weight, reps = minReps |
| reps ≥ maxReps + 2 and (rpe logged ≤ 8 or no rpe) | weight + one step (§2.2), reps = minReps; nothing when the step is too big |
| otherwise | nil (no change) |

Weight/reps mode only in v1; other modes return all-nil.

**Never overwrite what the user typed.** A remaining set is only rewritten when its current
values still equal the engine's last suggestion for that set (the presenter keeps the
session-start `ProgressionSuggestion` per exercise and updates it as it applies live changes).
A set the user has edited is left alone and the hint shows the suggestion instead.

When the toggle is off, nothing runs after set completion.

## 5. `smartProgressionInitialLogFill`

In `WorkoutSessionModel.init(template:previousWorkoutSession:…)` the prefill block currently
implements `.previousValues` unconditionally (and its comment says so). Add a
`prefill: SessionPrefill` parameter:

```
enum SessionPrefill {
    case previousValues                        // today's behaviour, unchanged
    case empty                                 // working sets keep nil weight/reps/duration/distance
    case suggestions([String: ProgressionSuggestion])   // by exercise templateId
}
```

The presenter maps the setting to the case: `.previousValues` → `.previousValues`; `.empty` →
`.empty`; `.smartProgression` → runs the engine per exercise and passes `.suggestions`; an
exercise with `.noHistory` falls back to `.previousValues` for that exercise (which yields
nothing too, and then the template defaults apply). Warm-up generation keeps using the first
working set's values, so warm-ups follow the suggestion automatically.

## 6. Integration points

1. `WorkoutSessionManager.getLastCompletedSessionsForTemplate(templateId:authorId:inTrainingProgramId:limit:)` — new, sorted most recent first; the existing single-session function becomes `limit: 1`.
1. `WorkoutSessionManager.getLastCompletedSessionsContainingExercise(exerciseTemplateId:authorId:inTrainingProgramId:limit:)` — the any-exercise lookup the `.anyExercise` scope and the fallback use.
2. `WorkoutTrackerPresenter`: holds `progressionSuggestions: [String: ProgressionSuggestion]`;
   builds the session with the right `SessionPrefill`; exposes
   `progressionHint(for exerciseId:) -> String?` for the exercise header.
3. `SetTrackerRowPresenter.onSetComplete`: when `workoutSettings.smartProgressionApplyInSession`,
   call the presenter's `applyLiveProgression(after:in:)`.
4. Exercise tracker header: a one-line hint from the rationale (e.g. "Smart Progression: add
   weight"), hidden when `.noHistory`. No new screens.
5. `SmartProgressionSettingsPresenter`: no change; the three controls already save.

## 7. Test cases (`DialedInUnitTests/Managers/Training/ProgressionEngineTests.swift`)

Helpers: `sets(_ pairs: [(kg: Double, reps: Int, rpe: Double?)])`, `targets(min:max:count:rir:)`,
`roundToHalfKg`, `minimumIncrementKg: 2.5`. Weight/reps unless stated.

1. **No history** → `.noHistory`, every field nil.
2. **Weight-first, top set hit max**: targets 8–12 ×3, ref 60 kg × (12, 10, 9) → `.progressWeight`,
   all sets 62.5 kg × 8.
3. **Reps-first, same data** → `.addReps`: 60 × (12, 11, 10).
4. **Reps-first, all at max** → `.progressWeight` 62.5 × 8 ×3.
5. **Hold on one miss**: ref 60 × (12, 8, 6) with min 8 → `.hold`, values identical to ref.
6. **Reset on two misses**: history[0] 60 × (7, 7, 6), history[1] 60 × (7, 6, 6) → `.deload`,
   55.5, 55.5, 54 kg × 8 (each set's e1RM ÷ (1 + 10/30)).
7. **Second miss at a lighter weight is not a deload**: history[1] at 55 kg with misses → `.hold`.
8. **RPE gate**: weight-first, top hit but rpe 9.5 with rirTarget 2 (limit 8.5) → `.addReps`.
9. **Missing rep range**: no targets, ref 60 × 10 → range 10–12; `.addReps` → 60 × 11.
10. **Rounding that lands on the same weight adds a second increment**: rounding to 5 kg,
    ref 60, increment 2.5 → 65.
11. **Per-set reference**: ref 100 × 12, 90 × 12, 80 × 12 weight-first → 102.5, 92.5, 82.5.
12. **Drop set untouched**: target 3 is `.drop`; under `.progressWeight` sets 1–2 progress and
    set 3 keeps ref values.
13. **Fewer targets than sets**: 2 targets, 3 ref sets → third set uses target 2's range.
14. **Reps-only raise the range**: targets 8–12, ref (12, 12, 12) → `.progressWeight`, reps 13.
15. **Time**: ref 60 s all completed → 66 s (rounded to 5 s → 65). One incomplete → hold.
16. **Distance**: ref 1000 m → 1050 m.
17. **Live: missed by two** (min 8, did 6 at 60) → remaining 57 kg (60 × 0.95 = 57, rounded to 0.5) × 8.
18. **Live: missed by one** → 60 × 8.
19. **Live: beat max by two, rpe 7** → 62.5 × 8. Same with rpe 9 → nil.
20. **Live: user-edited set is not overwritten** (presenter-level test in
    `WorkoutTrackerPresenterProgressionTests`): set 2 edited to 55 kg before set 1 completes with
    a miss → set 2 stays 55, set 3 changes.
21. **Prefill `.empty`** (`WorkoutSessionModel` test): working sets have nil weight and reps even
    with a previous session.
22. **Prefill `.suggestions`**: the session's working sets equal the suggestion, warm-ups derive
    from the suggested first set.

## 8. Out of scope for v1

Periodisation across weeks, autoregulation from RPE trends, per-exercise overrides of the
increment, and per-exercise calibration of the e1RM slope (the report's Phase 5: a per-user,
per-exercise `k` in `%1RM(n) = 1/(1 + n/k)`, prior 30). The calibration is not built: it needs
heavy sets (n ≤ 3) that most users rarely log, so the prior would dominate, and no source
validates the update rule.

## 9. Related training methods (2026-10)

Each is shown to the user through a `MethodInfo` (`MethodInfo+Training.swift`) with its sources.

- **Estimated one-rep max** (`ExerciseOneRMAggregator.estimated1RM`, the only copy; mirrored in
  `functions/coach-maths.js`): Epley on reps to failure `n = reps + (10 − RPE)` (no RPE → reps),
  the weight itself at `n ≤ 1`, and no estimate above `n = 10` (Reynolds 2006, *J Strength Cond
  Res* 20:584). Used by the Progress tab, exercise detail, records, the volume recommendation,
  the reset above and the coach.
- **Mesocycle deload** (`MesocycleDeload`, `WorkoutSessionModel.applyDeload`): each exercise
  keeps `⌈working sets × 0.5⌉` (at least one; drops and the right half of a pair go with their
  set; warm-ups kept), every weight × 0.90 rounded to the exercise's equipment
  (`CoreInteractor.deloadRounding`), reps as planned. Replaces load × 0.65 with sets unchanged:
  practitioners cut volume and effort and keep frequency (Rogerson 2024; Bell 2022, 2023;
  Coleman 2024). 0.5 and 0.90 are Compound's choices within the 0.5–0.6 and 0.85–0.95 bands.
- **Warm-ups** (`WorkoutSessionModel+WarmupSets.swift`): without a plan count, isolation/core
  get 1; compounds by working reps (≤ 6 → 3, 7–12 → 2, > 12 → 1, unknown → 2). Ramps 1: 60 %;
  2: 50/75 %; 3: 45/65/82 %; 4+: 45/60/75/85/90 %. Reps taper by load: ≤ 50 % → 8, ≤ 70 % → 5,
  ≤ 85 % → 3, above → 2 (weight/reps mode; bodyweight keeps the working reps). Without a plan
  count, warm-ups that round onto the working weight or the previous warm-up are dropped
  (Ribeiro 2020, 2021).
- **Rest defaults** (`RestDurationRules.defaultSeconds`): with no plan, exercise or type time
  set, compound sets of ≤ 6 reps rest 180 s, other compound 120 s, isolation 90 s, core 60 s;
  an untyped exercise keeps `defaultRestDurationSeconds` (ACSM 2009; Singer 2024).
