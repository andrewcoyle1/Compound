# Audit: gym equipment, exercise variations, load and rep progression

**Date:** 10 Oct 2026 · **Commit:** `development` at `2aad9f7a` (level with origin; `main` at `6817cebd`)

**Method**
- Four read-only audits ran in parallel, one per area:
  1. gym equipment and the load resolver;
  2. exercise variations and how they bind to a gym;
  3. the progression engine;
  4. how a live session's loads reach everything that reads them.
- Each finding was traced end to end. Some were replayed in scratch scripts, using either verbatim copies of the Swift or Python mirrors of it.
- Findings marked ✔ were re-read against the code a second time while this report was written.
- Nothing was built or tested. This commit's unit bundle is green (4,735 of 4,735), so every finding below is behaviour the tests do not cover.

## Fix first

| # | Finding | Severity |
|---|---|---|
| 1 | Plates listed in a variation are taken as the load: last time's 180 kg leg press prefills as 25 kg | critical ✔ |
| 2 | Plates entered in the other unit round every barbell weight down to the bare bar. Greedy plate loading misses common totals | high ✔ |
| 3 | Unlogged sets are saved with their prefilled figures and counted as done almost everywhere | high ✔ |
| 4 | Prefill and warm-ups are built without the gym, so a warm-up can be lighter than the bar | high ✔ |
| 5 | Progression stalls at the same weight with reps reset to the bottom of the range, session after session | high ✔ |
| 6 | With no rep range (the default target), weight never goes up and reps climb forever | high ✔ |
| 7 | Reps-only progression stops at max + 1 for good | high ✔ |
| 8 | Live in-session adjustment overwrites drops, pieces and back-off sets | high |
| 9 | Every session starts on variation 1, and history ignores variation | high |
| 10 | The new loading bar says "Not loadable" for the weight that + just produced (lb users) | high |

**Fix 4 together with 1, 2 and 15, not alone.** Production prefill currently rounds to the unit grid because it has no gym. Passing the gym routes prefill through the resolver bugs in 1 and 2. It also brings out finding 15, where prefill snaps a progression suggestion back to last week's weight.

---

## 1. Gym equipment and the load resolver

### 1. Plates in a variation are resolved as the load · critical ✔

**Where:** `Compound/Managers/Training/GymProfile/Loading/WeightStepper.swift:178-186, 231-234`

**Cause:** `steps(for refs:)` takes the first non-band ref the gym has. Its `.freeWeight` case never skips `isPlates` items, so a plate set returns `.list` of single plate weights.

**Failures:**
- Smith Machine Back Squat lists `freeWeight:bumper_plates` first, so it always resolves to [5, 10, 15, 20, 25] kg.
- 45° Leg Press, Overhand Grip Plate-Loaded Row and Smith FFE Split Squat list the machine first. The machine is off in a default gym (45 of 55 plate-loaded machines start off), so the plates win again.
- Prefill, warm-ups and progression all round 180 kg to **25 kg**. No loading bar appears.

**Fix:** Plates only ever feed `availablePlates`. Skip them as a load candidate when the variation has any other item.

**Test:** add a catalogue-wide test that resolves each prebuilt exercise's first variation in the default gym.

### 2. Plate search is a grid scan of greedy loads · high ✔

**Where:** `Loading/PlateCalculator.swift:53-88`

**Defect 1, plates in the other unit:** `nearest` steps per-sleeve weights on a 0.25 grid. Converted plates (1.134 kg, 2.268 kg, 2.756 lb …) never land on that grid, so the scan falls through to `return bar`.
- A kg user whose kg plates are switched off rounds 100 kg to **20.41 kg**, the bare bar.
- An lb user with kg-only plates rounds 225 lb to 281 lb.

**Defect 2, greedy loading:** greedy only works when the plate set has every small denomination. It does not in the default lb gym, where only the bumpers 10/25/35/45/55 are on.
- Per-side 30, 40, 50, 60 and 70 lb all report not loadable, yet the keyboard's + lands on exactly those totals.
- The kg set misses 1.5 and 2 kg per side.

**Note:** the `ponytail:` comment in the file says misses only come from limited plate counts. That is not true.

**Fix:** a bounded subset-sum over the plates and their counts, used by both `load` and `nearest`.

### 10. The loading bar rejects the weight + just produced · high

**Where:** `SetKeyboardPresenter.swift:381-386`

**Cause:** `shownWeight` parses the field text, which is formatted to 2 decimals. The bar base is 44.092 lb and the plate check's epsilon is 0.001.

**Failure:** + steps to 224.092, the field shows "224.09", and the bar reads "Not loadable: 219.09 or 224.09".

**Fix:** when the text equals `format(stored)`, use the stored value.

### 15. Prefill and progression disagree on coarse plates · high (latent until fix 4)

**Where:** `WeightRoundingRule.swift:59-65`, `WorkoutSessionModel+Prefill.swift:67,75`

**Cause:** `forProgression` drops the plate constraint when the smallest plate is over 2.5 kg, but prefill rounds with the constrained rule.

**Failure:** in a gym whose plates are [5, 10, 20], the suggestion is 62.5 kg and the prefill is 60 kg × min reps, every session. The engine's "double the step" guard never fires.

**Also:** the same check ignores `sleeves`, so a one-sleeve machine with 5 kg plates is given 2.5 kg jumps.

**Fix:** decide the policy (open question 5), then make prefill and the engine use one rule.

### Medium

**Stack top off its grid**
- **Where:** `WeightStepper.swift:313-320`
- **Defect:** a 5–100 stack in 7s rounds to and steps to 100, but the real top pin is 96.
- **Fix:** use `max: stack.pinPositions.last`.

**`nearestLoadable` past plate capacity**
- **Where:** `PlateCalculator.swift:48-50,79`
- **Defect:** beyond what the plate counts allow, it returns the total unchanged (200 with a capacity of 110).
- **Fix:** clamp to the maximum the counts allow.

**Convert Values ignores assistance and the rule**
- **Where:** `SetTrackerPresenter.swift:256-264`
- **Defect:** −30 kg assistance becomes 0 or +5 lb, on a coarse grid.
- **Fix:** go through `WeightRoundingRule` with `.assisted`.

**Set Plan drops snap to 0.5 kg, not the equipment**
- **Where:** `WorkoutSessionModel.swift:390-417`
- **Defect:** the result can be a 17 kg dumbbell or 36.38 lb, and assisted drops get harder. The code comment claims "the tracker snaps later", but nothing does.
- **Fix:** reuse `ActiveWorkout.dropWeightKg`.

### Low

**Plate Calculator sheet**
- With every plate off it shows "Empty bar = 20 kg" for a 100 kg set, and the keyboard loses the entry point.
- `plateChoices` counts inactive plates but `availablePlates` does not (`PlateCalculatorPresenter.swift:57-75`, `SetKeyboardPresenter.swift:347`).

**Plate Calculator Done**
- It sets the workout gym before the save succeeds.
- It saves a whole-gym copy taken when the sheet opened (`SetTrackerRowPresenter.swift:301-313`). PLAUSIBLE.

**Gym editors**
- The loadable-accessory unit picker is never saved (`EditLoadableAccessoryPresenter.swift:11,22`).
- The weight, bar and fixed-bar adders accept 0 or negative weights with Save enabled.
- A plate count below 2 on a two-sleeve bar silently drops the plate.

**Rounding**
- Ties round up on `.increment` (`WeightStepper.swift:92`) but down for plates and lists.
- The mirrored assistance grid ignores `lightestPin` (`WeightStepper.swift:119-121`).

**Gym icon default**
- The default is spelled `"dumbell"` (`GymProfileModel.swift:38`). The decoder uses "dumbbell". No view reads `icon` yet.

---

## 2. Exercise variations and binding

### 9. Variation is never carried over, and history ignores it · high

**Variation is never carried over**
- **Where:** `WorkoutSessionModel.swift:203`, `WorkoutTrackerPresenter+Exercises.swift:46`
- **Defect:** both create exercises with `chosenVariationId: nil`, and `WeightRoundingRule.swift:41` falls back to variation 1. Last session's choice is never read, and `ExerciseFilters.isPerformable` is not consulted.
- **Failure:** a Bulgarian split squat done on the barbell at 80 kg prefills next time at 57.5 kg, rounded to the dumbbell rack.

**History is keyed by exercise only**
- **Where:** `ProgressionPlanner.history(forTemplateId:)`, `WorkoutTrackerPresenter+Rest.swift:62-75`
- **Defect:** history and the previous-values column are keyed by `templateId#occurrence`, with nothing about the variation. Dumbbell history feeds a barbell suggestion. Pin-loaded and plate-loaded variants of one exercise also share history.

**Changing variation mid-session does nothing to the sets**
- **Where:** `SetTrackerPresenter.swift:41-45`
- **Defect:** it only sets the id. Open sets keep loads the new equipment cannot make, and suggestions are not reloaded.

**Templates freeze a copy of the exercise**
- **Where:** `WorkoutSessionModel.swift:116,204`
- **Defect:** templates embed a frozen copy of `ExerciseModel`, so seed fixes never reach them. Progression rounds through the library's first variation while the keyboard uses the copy's, so the two can round on different equipment.

These four are the core of the planned load-first variation work: gym id on the session, defaults from last time at this gym, history keyed by load.

### Medium

**Three seed refs name catalogue types that don't exist**
- **Where:** `PrebuiltExercises.json:1463, 1423, 913`
- **Refs:** `plateLoadedMachine:pec_deck_machine`, `plateLoadedMachine:incline_chest_press_machine` and `supportEquipment:squat_rack`.
- **Effect:** Lever Pec Deck Fly and Lever Incline Hammer Press are hidden in every gym and step by the 2.5 kg fallback.
- **Fix:** correct the refs, bump `currentSeedingVersion`, and add a test that every seed ref resolves in `allEquipmentCatalog`.

**`weightPerSide` is applied inconsistently**
- **Where:** `WorkoutSessionModel.swift:230-271`, `WorkoutSetModel.volumeKg`, `MethodInfo+Training.swift:97`
- **Defect:** it is folded into `.weightReps` at runtime. The seed uses it inconsistently: DB bench is `weight` but DB fly is `weightPerSide`. Volume doubles only `side == .both` rows, while MethodInfo says a weight in each hand is counted twice. See open question 1.

**The Bodyweight toggle discards every variation**
- **Where:** `ExerciseEquipmentPresenter.swift:119`
- **Defect:** an assisted pull-up cannot bind its stack, and bodyweight exercises count as performable in every gym.

**Strict decoding on exercises and refs**
- **Where:** `ExerciseModel` (synthesized Codable), `EquipmentRef.kind` (strict enum), `WorkoutExerciseModel.swift:104`
- **Defect:** adding an `EquipmentKind` later would make older builds drop whole sessions and templates. PLAUSIBLE: nothing writes a new kind today.

### Low

**Exercise data**
- A barbell (landmine) T-bar row is loaded with `sleeves: 2` (`WeightStepper.swift:215`), so it steps two plates at a time.
- An empty variation can be saved, and it passes `isPerformable` in every gym (`ExerciseEquipmentPresenter.swift:21`).
- Some seed exercises are missing their load or support. Chest Dip and Weighted Hammer-Grip Pull-Up have a weight metric but no load item. Pull-up, captain's chair and ab-wheel exercises have no variations.

**Equipment and gym edits**
- Deleting a custom machine leaves exercises showing a raw UUID (`GymProfileModel+Machines.swift:48-55`).
- Gym edits made from inside a workout may not reach the keyboard, because they save through `saveGymProfile`, not `saveWorkoutGymProfile`. PLAUSIBLE.
- The equipment sheet's "Variation N" label is not localized (`WorkoutExerciseEquipmentSheetPresenter.swift:103`).

**Tooling**
- `functions/scripts/migrateEquipmentVariations.js:49` still reads a `DialedIn/` path.

---

## 3. Load and rep progression

### 5. A heavier weight that rounds back to the same weight still resets the reps · high ✔

**Where:** `ProgressionEngine.swift:281-305`

**Cause:** `increasedWeight` can return its input. This happens when the equipment is at its maximum, or when twice the step still rounds back. `jumpIsAffordable(w → w)` is then true, so the suggestion is `(same weight, range.min)`. It is counted as "reps instead", yet the reps fall.

**Failures (all replayed):**
- A rack with nothing between 10 kg and 30 kg, 30 × 12 → 30 × 8.
- The top pin, 100 × 12 → 100 × 8.
- An assisted exercise at 0.

**Same path, live:** the in-session adjustment at line 62 does the same.

**Fix:** when `heavier <= weight`, suggest `reps + 1`, or hold.

### 6. No rep range means weight never goes up · high ✔

**Where:** `ProgressionEngine.swift:262-268`

**Cause:** with no range, it is re-derived from last time as `prev…prev+2` on every call, so the top is never reached. New template exercises and swaps default to `SetTarget(setNumber: 1)`, which has no range.

**Failure:** 60 × 10, 11, 12, 13 … forever.

**Fix:** derive the range once, or apply a default range (see open question 4).

**Related:** a target with only a minimum, or a minimum of 0 (`SetTargetView.swift:185-198`), is accepted and stalls the same way.

### 7. Reps-only progression stops at max + 1 · high ✔

**Where:** `ProgressionEngine.swift:108`

**Defect:** it returns `range.max + 1`, not `referenceReps + 1`. The spec's "range shifted by one" is not implemented.

**Failure:** pull-ups at 13 reps stay at 13 forever.

### 8. Live adjustment rewrites every remaining row · high (opt-in)

**Where:** `WorkoutTrackerPresenter+Progression.swift:62-73`, `ProgressionEngine.swift:58,70`

**Cause:** `remaining` includes sub-set pieces and back-off sets, and every row gets the same value. `position` counts sub-set rows, so it points at the wrong target.

**Failures:**
- Logging 100 × 5 turns the 80 kg and 64 kg drops into 95 × 8, and gives a stretch piece weight and reps.
- A missed top set turns 80 kg back-offs into 95 × 4.
- Logging a drop rewrites the working sets.
- A miss on an assisted exercise multiplies a negative weight by 0.95, so the user gets less assistance.

### Medium

**Deload weeks**
- Deload sessions carry no marker, so the next week progresses from the 90 % weight (`ProgressionPlanner.swift:131-148`).
- During the deload week the Auto chip offers the full, un-deloaded weight.
- Deload rounding uses the nearest load, so 15 kg on a 5 kg stack stays 15 (`WorkoutSessionModel.swift:288`).

**AMRAP and failure sets block load increases on compounds**
- **Where:** `ProgressionEngine.swift:200-208`
- **Defect:** these sets are judged against the 1 RIR default. The template UI cannot set `rirTarget`; only the importer does.

**A weight-and-reps set logged without a weight drops to the minimum reps**
- **Where:** `ProgressionEngine.swift:299`
- **Defect:** applies to bodyweight dips and band-only sets.

**Distance rounds to the nearest 50 m**
- **Where:** `ProgressionEngine.swift:235`
- **Defect:** 10 m → 0 m, 24 m → 50 m, and anything under 500 m never grows.

### Low

**Timed and distance sets**
- The engine's "unfinished set holds" branch can never run, because the planner passes only completed sets. Its test feeds a state production cannot produce.
- Holds of 10–20 s never grow under ×1.10 rounded to 5 s.

**AMRAP**
- "Beaten twice" can count a session done at the old, lighter weight (`AMRAPProgression.swift:31`).

**Method consistency**
- The rep-fallback check uses Epley past 10 reps (`ProgressionEngine.swift:314`), which the e1RM rule forbids. Either state it in `ownChoices` or cap it at 10.

**Copy**
- The two-session reset's copy, "A lighter week to recover.", reads like the mesocycle deload (`ActiveWorkoutState.swift:108`).

**History depth**
- History is fetched three sessions deep before sessions that never reached the exercise are dropped (`CoreInteractor+PreviousWorkoutReference.swift:58-68`). PLAUSIBLE.

---

## 4. Session flow and consumers

### 3. Unlogged sets count as done · high ✔

**Where:**
- `WorkoutSessionRowPresenter.swift:62,66`
- `ShareCardContent.swift:49,51`
- `TodaysWorkoutCardPresenter.swift:283`
- `WorkoutSessionDetailPresenter.swift:90-148`
- `WorkoutPresenter.swift:47`
- `WorkoutConsistencyPresenter.swift:47`
- `SocialProfilePresenter.swift:119`
- `AnalyticsPresenter.swift:355,366`
- `LiveActivityManager.swift:122`

**Cause:** finishing keeps the open sets, which carry prefilled figures (the default fill is smart progression). `workingSetCount` and `volumeKg` ignore `completedAt`.

**Failures:**
- Doing 2 of 4 planned sets shows 4 sets and 3,200 kg on the feed, share card, Today, detail, Progress and the social profile.
- Next session's Prev column and prefill treat the sets that were never lifted as "last time".

**Other counting problems:**
- The feed counts raw rows (a left and right pair counts as two, and drops count), while the share card counts pairs once.
- The Live Activity's end summary adds warm-ups.

**Fix:** one "completed working sets" helper (`!isWarmup && completedAt != nil`, with `pairedSetCount`), or drop open sets on finish (open question 2).

### 4. Prefill and warm-ups have no gym · high ✔

**Where:** `CoreInteractor.swift:313`

**Defect:** `plannedSession` builds `WorkoutSessionModel(template:…)` without `gymProfile:`. Prefill and warm-ups therefore use `WeightStepper.fallback`, which rounds to 0.5 kg or 1 lb.

**Failures:**
- A 40 kg working set gets warm-ups at 18, 26 and 33 kg on a 20 kg bar.
- The equipment-exact suggestion 41.25 is shown as 41.5, so the Auto chip and the field disagree and `isEdited` hides the progression note.
- `ActiveWorkoutStateTests.swift:378` says "Prefill still rounds to the plates", which production does not do.

**Fix:** pass `workoutGymProfile`, and do not re-round a suggestion the planner has already rounded. Do this together with fixes 1, 2 and 15.

### Medium

**Assisted and bodyweight warm-ups**
- **Where:** `WorkoutSessionModel+WarmupSets.swift:60,124`
- **Defect:** −30 kg × 50 % gives −15, which is less assistance than the working set. Dips at 0 kg get warm-ups at the working load.

**"kg" is hard-coded on social and summary surfaces**
- **Where:** `WorkoutSessionHighlights.swift:126` (the PR string is also not localized), `WorkoutSessionRowPresenter.swift:70,89,144`, `ShareCardContent.swift:80`, `WeeklyReview.swift:195`

**Strava uploads every piece as a set**
- **Where:** `StravaStrengthFile.swift:63`
- **Defect:** it uploads drops, mini-sets and pieces as separate sets, which inflates the set count and the muscle map. A hold's weight is dropped.
- **Fix:** add `&& !$0.isSubSet`.

**`ExerciseModelDetailStats` disagrees with `volumeKg`**
- **Where:** `ExerciseModelDetailStats.swift:86-103`
- **Defect:** these stats feed History, Records and all PR detection. They ignore the doubling of `.both` rows, count nil reps as 1, and count pairs twice. This type has no tests.

**A logged set can end up with 0 or no reps**
- **Where:** `LiveActivityIntentHandler+App.swift:126` (clamps at 0), the keyboard on logged rows, `ExerciseOneRMAggregator.swift:90`
- **Defect:** `max(1, reps ?? 1)` turns such a set into a single, so a failed 140 kg attempt becomes a 140 kg e1RM and a PR.

### Low

**Counting**
- `BodyweightLoad.swift:44`: a `.both` row adds bodyweight once, while a split left/right pair adds it twice. The current number is pinned by `BodyweightLoadTests:73`.
- `MuscleVolume.swift:80`: `hardSets` can credit a hard right side as 0 when the left was not hard.
- `VolumeRecommendation.swift:197`: deload weeks read as about 50 % adherence.

**Matching and labels**
- `WorkoutSetPairing.swift:211`: warm-up "Last" is matched by raw index, so a different number of warm-ups shifts it onto a working set.
- `ActiveWorkoutState.swift:232`: the bodyweight label drops the bands.

**Unit preference cache**
- **Where:** `ExerciseUnitPreferenceManager.swift:50`
- **Defect:** the cache is never cleared and is not keyed by user, so a global unit change or a second account sees stale units.

**Dead code that only tests call**
- `computeTotalVolumeKg`, `buildPreviousLookup`, and `WorkoutSessionDetailPresenter.addSet`/`deleteSet`.

---

## Checked and sound

**Gym decoding and storage**
- Tolerant decoding works: lossy arrays, `typeId` fallback, sleeves clamped, `isPlates` fallback. The v1 fixture round-trips.
- Firestore merge saves cannot leave stale nested fields.
- Catalogue merge by id keeps duplicates and custom machines.

**Gym loading**
- `loadedBaseWeight`, `chooseBarWeight`, `setPlate`, collars, plate counts and per-sleeve caps all behave correctly.
- Stack loads and `pinPositions` are de-duplicated, add-ons are capped at 6, and removing a stack re-points the default.
- A stack of 7 kg pins with two 2 kg add-ons steps 7, 9, 11, 14, 16, and progression's smallest step there is 2 kg.

**Resolver callers**
- Every caller goes through `WeightStepper`, except the two bypasses above: Convert Values and the Set Plan drops.
- The first active instance of a type is used, so a duplicate stands in for an original that is switched off.

**Units**
- The keypad stores kg and steps from the stored kg value, so I found no case of 45 lb being saved as 20.4 kg and then 20 kg.

**Prebuilt exercise data**
- The app and functions copies of `PrebuiltExercises.json` are byte-identical.
- There are no duplicate exercise, variation or catalogue ids, and every exercise maps to Strava.

**Session data**
- Old sessions decode. `bands` decode tolerantly, round-trip, show as "Red + Blue", and are never counted as kg.
- The 1RM, `hardSets` and `CircleWeek.volumeKg` correctly filter for completed sets. `volumeKg` excludes assistance.

**Progression and its parity with the coach**
- `estimated1RM` matches `functions/coach-maths.js` exactly, and all 1RM calls go through the aggregator.
- These match the spec and MethodInfo: double progression, the RPE gate, the two-session rule without RPE, hold on a single miss, and the 85–95 % e1RM reset rounded down.
- Assisted progression moves the right way at session start.
- No path produces NaN or a division by zero.

## Decisions (10 Oct 2026)

Owner's answers to the open questions below:

1. **Dumbbells:** log the weight of one dumbbell. Volume and Strava count it twice when both hands hold one. 1RM uses the per-dumbbell figure.
2. **Unlogged sets:** drop them when the workout is finished.
3. **History key:** history is keyed by load kind (stack, bar + plates, dumbbells, plate machine). The default variation is the one used last time at this gym; failing that, the first variation the gym can perform; failing that, variation 1.
4. **No rep range:** new template exercises and swaps default to 8–12.
5. **Coarse plates:** suggest only loads the gym can make. When the next load is too big a jump, add a rep at the same weight until the jump is affordable.
6. **After a deload:** stamp deload sessions and leave them out of history. Progression resumes from the last session before the deload.
7. **Social units:** show the author's unit. Stamp the unit the set was logged in onto each workout set.
8. **Assisted and bodyweight exercises:** no smart warm-ups when the working weight is zero or assistance.
9. **Catalogue:** all three changes.
   - Add a 45 lb bar.
   - Switch on a kg stack for kg users.
   - The resolver prefers the active stack in the user's unit over the stored default.
10. **RIR:** two places.
    - The set target screen sets a target RIR for each set. It is always the default RIR on the matching working set.
    - In a workout, a header on the reps keypad records the RIR actually reached, from 0 to 6+, and replaces the default.
    - AMRAP and failure targets default to 0.
11. **Naming:** rename the week-by-week targets (`MicrocycleVariations`) to "Weekly targets". "Variation" keeps meaning equipment.
12. **Unit preference:** option E, follow the equipment.
    - The keypad and step use the unit of the equipment being loaded, as the resolver finds it.
    - If the equipment has both units switched on, or there is no equipment, use the app-wide unit.
    - The per-exercise choice stays as a manual override.
    - Each set stamps the unit it was logged in (decision 7).
    - Charts and totals keep using the app-wide unit. Template weights show in it, since no equipment is known then.

## Open questions for the owner

1. **Dumbbell load.** Is a dumbbell set one dumbbell or the pair? This decides volume, 1RM, the coach maths, Strava, the load-first picker and what replaces `weightPerSide`.
2. **Unlogged sets on finish.** Drop them, or keep them as the plan and filter everywhere?
3. **Variation identity.** Key history by variation id, by load type, or by load kind?
   - Which variations share history (cable with pin stack, plate machine with pin machine)?
   - What is the default variation: last at this gym, then first performable, then first?
   - Can a template pin a variation, and should templates store only the exercise id?
4. **No rep range.** Should such an exercise ever gain weight, and from what default range?
5. **Coarse plates.** Prescribe an unloadable 62.5 kg, or a 10 kg jump? Today's suggestions are unloadable; passing the gym would cause a stall instead.
6. **After a deload week.** Resume from the last session before the deload, or from the planned weight plus a step?
7. **Social units.** Should feeds, share images and PRs use the reader's unit or the author's? The author's unit is not stored on the session.
8. **Assisted and bodyweight warm-ups.** Should these exercises get warm-ups at all?
9. **Catalogue defaults.**
   - Bars are kg only, so lb users load a 44.09 lb bar. Add a 45 lb bar?
   - Pin machines are lb only, so kg users step by 2.27 kg. Intended?
   - The lat pulldown's default stack is its inactive kg stack.
10. **RIR target.** Should it be editable in the template UI?
11. **Naming.** "Variations" also names the week-by-week set targets (`MicrocycleVariations`). Rename one before the new UI ships?
12. **Unit preference.** Per exercise today. Should it be per variation?

## Suggested fix packages

| Package | Contents | Blocked on |
|---|---|---|
| **A. Resolver** | #1, #2 (subset-sum), #10, stack top, capacity clamp, `forProgression` sleeves, tie direction, mirrored assistance. Add a catalogue-wide test of each first variation in the default gym | — |
| **B. Session rounding** | #4 (pass the gym), #15, Set Plan drops and Convert Values through the rule, assisted warm-ups | A; open questions 5 and 8 |
| **C. Progression engine** | #5, #6, #7, #8, dips without a weight, AMRAP and RPE, distance and time, deload marker, AMRAP across weights | open questions 4 and 6 |
| **D. Consumers** | #3 shared helper, `ExerciseModelDetailStats`, Strava sub-sets, 0-rep sets, hard-coded kg | open questions 2 and 7 |
| **E. Seed and creation** | three bad refs and their test, Bodyweight toggle, empty variations, seed gaps, migration script path | — |
| **F. Variation work** (the planned next feature) | #9: carry-over, history keying, re-round on change, template freshness, tolerant decoding of `ExerciseModel` and `EquipmentRef` | open questions 1, 3 and 12 |
| **Low sweep** | the remaining low findings | — |

## Test gaps

Each finding above lacks a test. The ones that would have caught the most:
- a catalogue-wide resolve of each first variation;
- every seed ref resolving in the catalogue;
- `nearest` and `load` with plates in the other unit and with the default lb bumpers;
- production prefill through `plannedSession` with a gym;
- progression over more than one session for: equipment at its top, no rep range, reps only, and the session after a deload;
- live adjustment with pieces and back-offs;
- summaries of a session with unlogged sets;
- `ExerciseModelDetailStats`, which has no tests at all.
