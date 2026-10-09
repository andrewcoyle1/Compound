# Training volume — hard sets, tiers and the per-muscle suggestion

Where weekly sets per muscle come from, how they are read, and the suggestion on a muscle's
detail screen. Sources are the report's (`reports/Defensible fitness app algorithms.md`, Volume
section) and are listed in the app under each ⓘ (`MethodInfo+Volume.swift`).

## Hard sets (`MuscleVolume.hardSets`)

- A set counts when it is finished, not a warm-up, and not logged below **RPE 6**. A set with no
  RPE counts in full, so users who do not log effort are not penalised. Direction from Robinson
  2024 and Refalo 2023 (closer to failure builds more); the RPE 6 cut-off is Compound's own.
- Each finished drop (a sub-set of kind `drop`), or mini-set of a `myo` or `restPause` set, adds
  **0.5**, capped at **2** per set. Cluster pieces, partials, stretches and holds add nothing.
  Both constants are Compound's own.
- A left/right pair is one set (as `pairedSetCount`), worth its better half.
- Credit per muscle: **1** primary, **0.5** secondary — the fractional count Pelland 2026 found
  predicted growth and strength best.
- Not adopted from the report: the 5–30 rep window (it would drop heavy triples and timed sets
  with no reps) and the optional RIR effort weights.
- `completedWorkingSets` still counts every finished working set, for set counts on screen.

Mirrored in `functions/coach-maths.js` (`hardSets`, `weeklyMuscleSets`); the coach reads sets with
their `id`, `kind`, `rpe` and `parentSetId`.

## Tiers (`MuscleVolume.tier`)

One band for every muscle — no meta-analysis supports a lower one for small muscles, and
Baz-Valle 2022 found triceps did better above 20:

| Weekly hard sets | Tier |
|---|---|
| < 4 | Below maintenance |
| 4 to < 10 | Maintaining |
| 10–20 | Productive |
| > 20 | High (fine while progressing and recovering) |

10–20 rests on Pelland 2026, Schoenfeld 2017 and Baz-Valle 2022; the 4 and 10 cut-points and the
labels are Compound's own (4 loosely anchored on Spiering 2021). The old 6–12 band for small
muscles is gone. The Pelland follow-up preprint's figures are not quoted.

## Suggestion (`VolumeRecommendation`)

Shown on the muscle detail screen (`VolumeRecommendationSection`); it never edits templates.

```
baseline  = median weekly hard sets, last 4 weeks (fewer than 4 trained weeks: clamp into 10–20;
            fewer than 2: "keep logging")
trend     = median, over exercises where the muscle is primary, of the least-squares e1RM slope
            ÷ mean × 7 × 100 (%/week), each from ≥ 3 sessions over ≥ 7 days
            (ExerciseOneRMAggregator.aggregate)
adherence = planned sets done ÷ planned sets (setTargets), primary exercises only
RPE drift = later-half minus earlier-half mean RPE at the load used most on both sides

adherence < 80%                → be consistent first
trend < −0.5 or drift ≥ +1     → reduce 20–33%
trend > +0.5                   → keep
otherwise                      → add max(10%, 1 set) to 20%
floor 4 sets (6 from age 60); whole sets; baseline > 20 shows a high-volume note
```

The +10–20% step follows Scarpelli 2022 and Camargo 2026, the floor Spiering 2021. Every
threshold (window, ±0.5 %/week, 80%, drift 1, 20–33%) is Compound's own and should be tuned on
replayed training logs. Not implemented: recovery inputs (none are logged) and "one step per
block" (no suggestion history is stored).

Tests: `MuscleBalanceTests`, `VolumeRecommendationTests`, `WeeklyReviewTests`,
`functions/coach-maths.test.js`.
