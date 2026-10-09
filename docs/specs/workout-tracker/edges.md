# Live workout tracker: edge-case stress test

Branch `feature/workout-tracker-redesign`, working tree as of 6 Oct 2026. Everything here was read from
the code. Nothing was run in a simulator. Paths are relative to `Compound/` unless stated.

Abbreviations: **AWS** = `Core/Training/Subviews/WorkoutTracker/ActiveWorkoutState.swift`,
**WTV** = `…/WorkoutTracker/WorkoutTrackerView.swift`, **WTP** = `…/WorkoutTracker/WorkoutTrackerPresenter.swift`
(`+AE` = `+ActiveExercise`, `+Rest`, `+Ex` = `+Exercises`, `+SS` = `+Superset`, `+Prog` = `+Progression`),
**STV/STP** = `…/ExerciseTracker/SetTracker/SetTrackerView|Presenter.swift`,
**STRV/STRP** = `…/SetTracker/SetTrackerRow/SetTrackerRowView|Presenter.swift`,
**SKP/SKV** = `…/SetTrackerRow/SetKeyboard/SetKeyboardPresenter|View.swift`,
**RDR** = `Managers/Training/WorkoutSettings/RestDurationRules.swift`,
**LAIH** = `Managers/LiveActivities/LiveActivityIntentHandler+App.swift`,
**LAM** = `Managers/LiveActivities/LiveActivityManager.swift`.

Type: **Bug** = the code does something wrong against its own stated intent; **Gap** = a missing
capability; **Design** = a deliberate choice worth revisiting.

---

## Top 15 by lifter impact

| # | Issue | Where | Type |
|---|---|---|---|
| 1 | **Supersets and circuits rest in full after every partner set.** `RDR` knows nothing of `supersetGroupId`, so A1 starts the full 90 s rest, the card flips to B, and the log button is replaced by Skip Rest. Every superset round costs a Skip Rest tap, and the rest after A's last set is a between-exercises rest. | RDR:60-94, WTV:61-86, WTP+SS:23-35 | Gap |
| 2 | **Keyboard Done logs whichever row is being edited, upcoming rows included.** A lifter who pre-fills set 3 while on set 1 and taps Done logs set 3 out of order and starts a rest (the between-exercises one if it is the last set). Hardware Return on reps does the same. | STRP:304-309 → STRP:44-46 → WTP+AE:239-272; SetKeyboardTextField:127-131 | Bug |
| 3 | **A rest starts after the final set of the workout**, so Finish Workout is hidden behind Skip Rest for the rest's length, and a "rest complete" alert can fire after the lifter has put the phone away. | RDR:88-91 (`isLastWorkingSet`), WTV:61 (rest branch wins over finish) | Bug |
| 4 | **Drop sets, AMRAP, myo-reps, rest-pause and cluster sets are not represented in the log.** `SetTarget.setType` (standard/drop/myo/failure) exists on templates but the set model has no type and the tracker never reads it. Mini-sets count as full working sets in progress, volume and weekly sets per muscle, and each one triggers a full rest. | WorkoutSetModel.swift:10-33; SetTarget.swift:16; only reader ProgressionEngine.swift:220-222 | Gap |
| 5 | **Per-keystroke propagation overwrites sets that happen to match an intermediate value.** Sets 1–2 at 100 kg, back-off set 3 at 80 kg. Type 82.5 into set 1: on "80" nothing matches set 3, but on the next key the original is 80 and set 3 (80) is rewritten to 82.5. The default is on. | WTP:556-584 (`propagateEdit` on every `didSet`), WTP:464-486 | Bug |
| 6 | **Assisted machines cannot be logged correctly.** There is no minus key and every step clamps at 0, and `problem(with:)` refuses negative weight. `.weightPerSideAssistance` maps to plain `weightReps`, so 30 kg of assistance is stored as 30 kg of load. Volume and PRs are then wrong, and smart progression *adds* assistance, which makes the lift easier, not harder. | SKP:135-152, WeightStepper:39-40, STRP:167, WorkoutSessionModel.swift:201-213 | Gap |
| 7 | **Timed holds have no timer.** For a 30 s plank the lifter types "30". There is no start or stop, and no countdown. New sets default to 1:00 (timeOnly) or 400 m · 2:00 (distanceTime), so the log button reads "Log set 1 · 1:00" before anything is entered, and one tap records invented data. | SKP:192-195, WorkoutSessionModel.swift:492-501, AWS:197-201 | Gap + Bug |
| 8 | **The workout's own gym is ignored; plates and steps always come from the favourite gym.** `onTask()` is never called and `workoutTemplate` is never assigned, so `gymProfile` is always nil. The row's keyboard and plate line read `favouriteGymProfile` rather than `workoutGymProfile`. Training at a second gym gives wrong plates, increments and "Not loadable" advice. With no favourite set, the "Gym Settings" menu item does nothing. | WTP:148-159, WTP:603-607, STRP:266, STRP:284 | Bug |
| 9 | **App killed mid-workout: the rest, the pause and Apple Health are lost.** The tracker reads `hkWorkoutManager.restEndTime`, which is nil in a fresh process, so there is no Skip Rest and no inline timer while the Live Activity is still counting. `hkStartedSessionId` survives the kill, so `onAppear` returns early and the HealthKit session is never restarted or recovered. `pausedAt` and `pausedDuration` live in memory only. | WorkoutSessionManager.swift:281-286, WTP:194, HKWorkoutManager.swift:40-46 | Bug |
| 10 | **The inline rest timer disappears after a set is logged from the Lock Screen.** `restStartedAt` is kept after a rest runs out ("so it can read Ready") and is cleared only by Skip. A later Lock Screen log has `completedAt > restStartedAt`, so `restAnchor` returns nil and the new rest has no row on the card. The footer still shows Skip Rest. | WTP:61, WTP+Rest:89-95, AWS:145, WTP+AE:174-182 | Bug |
| 11 | **Exercises added mid-workout are second-class.** You get 1 set (the picker's default single target), no per-side rows (so no Split L/R for a unilateral lift), no Last column (`previousExercises` loads only on appear), no suggestion, and the card jumps to the first incomplete exercise rather than staying put. | WTP+Ex:13-54 (`defaultSets` without `perSide`), ExercisesPickerPresenter:70, WTP+Rest:36-68 | Bug |
| 12 | **Live Activity disagrees with the screen.** It does not name the side, so 1L and 1R both read "20 kg × 10". It counts warm-ups in its totals while the header excludes them. It ignores the superset round-robin and a rest set by hand on the row. Its Complete button logs a set with no reps, because there is no validation. | LAM:395-405, LAIH:77-98, LAIH:211-216, LiveActivityPhaseViews:209 | Bug |
| 13 | **Bodyweight lifts read badly.** The Last column is blank for any previous set with no weight (weightReps requires both weight and reps), and weighted pull-ups read "10 kg × 8" with no BW or +. Smart warm-ups give bodyweight pull-ups two warm-up sets at full working reps (repsOnly, or nil weight). | STRV:373, AWS:191-194, WarmupSets:28-34, :54-69 | Bug |
| 14 | **A single tap un-logs and a full swipe deletes, with no undo.** The green check sets `completedAt = nil` on one tap, which also cancels the rest. A trailing full swipe deletes a logged set (and its pair) at once. Mid-set with sweaty hands, both are easy to hit. | STRP:70-72, STRV:103-105 | Design |
| 15 | **Swap moves logged sets onto the new exercise and goes blind.** Two logged sets of barbell bench become dumbbell bench in history. The Last column and the suggestion vanish because both are keyed by the old `templateId`. Set targets reset to one standard set. One logged warm-up plus three open working sets gives four fresh working sets, because `openCount` includes warm-ups. | STP:78-131 (109, 129), WTV:301-305 | Bug + Design |

Close behind: unit "Convert Values" rewrites already-logged sets (STP:245-277); the tracker never
scrolls the current row into view on 12-set exercises; the 400-character note has no line limit on
the card; deleting one exercise of a superset leaves its partner labelled "Superset A".

---

## 1. Tracking-mode matrix

Common path: the row inputs come from `STRV.inputFields` (STRV:208-230), the Last column from
`previousValueContent` (STRV:366-407), the log title from `ActiveWorkout.logTitle/figures`
(AWS:168-203), the keyboard fields from `SetKeyboardField.fields` (SKP:22-29), and the plate line
from `plateSummary` (STRP:281-299, shown only on the current row, STRV:60-90).

| | Bench 100 kg × 5 (weightReps, barbell) | Bodyweight pull-ups | 30 s plank (timeOnly) | 400 m row (distanceTime) |
|---|---|---|---|---|
| **Columns** | Set · Last · [kg▾] · Reps · Done | weightReps if the exercise has any weight metric, otherwise Reps only | Set · Last · Time (90 pt) · Done | Set · Last · [m▾] · Time (70 + 70 pt) · Done |
| **Log button** | "Log set 2 · 100 kg × 5"; "Log warm-up · 60 kg × 5" | weight nil or 0 → "Log set 1 · 8 reps" (AWS:193); weighted → "Log set 1 · 10 kg × 8" (no BW/+) | "Log set 1 · 1:00" *before typing anything* (default 60 s, WorkoutSessionModel:495); after typing "30" → "Log set 1 · 0:30" | "Log set 1 · 400 m · 2:00" from defaults (:496, :501) |
| **Plate line** | "Per side: 20 + 10 kg"; when not loadable → tappable "Not loadable. Use 102.5 kg". Uses the **favourite** gym, not the workout's (#8) | none (weight 0 or nil; `.bodyWeight` is not plate-loaded) | none | none |
| **Last column** | "100 kg × 5" plus "RIR 2" when an RPE was logged; tap fills | **"—" when the previous set had no weight** (STRV:373 needs both) | "0:45"; tap fills | "400 m 1:32" in caption2, two lines in 78 pt, no separator |
| **Keyboard** | chips Last set / Last time / Target; ± stepper with bar chip; Plates strip; reps chips Min/Max; RPE row if `rirTracking` | stepper chip "BW", ± 1.25 kg from 0; **no minus key**, so assisted is impossible | digits only, microwave entry ("130" = 1:30), max "9999" = 100:39; **no start/stop timer** | distance keypad (5 whole digits), then duration; no pace shown |
| **Warm-ups** | 1–3 at 50/70/90 % | **2 warm-ups at full working reps** (WarmupSets:28, :66) | none (correct) | none (correct) |
| **Rest** | base rest; last set → between-exercises | same | same, which is long for a series of short holds | same, even after a 20-minute erg piece |
| **Progression note** | yes | addReps only | never (`progressionReason` speaks only of weight and reps) | never |

**Should:** treat the duration and distance defaults as placeholders (grey hint text) rather than
values, and keep the button title without figures until something is entered. Add a start/stop
stopwatch to the timeOnly row (counting up for holds, with an optional countdown to the target) and
show pace on distanceTime. Show "BW", "BW + 10 kg" and "BW − 20 kg". Make the Last column show
"8 reps" for a weightless set, as `figures` already does. Generate no warm-ups for bodyweight or
repsOnly lifts by default.

### Unilateral L/R

- **currentSet**: `sets.first { completedAt == nil }` (AWS:43-45) picks the left, because pairs are
  stored left first. If the right is ticked first the left stays current, which is acceptable.
- **Rest between sides**: `hasFollowingSidePartner` → `restBetweenSideSets` (default **off**), scaled
  0.5 (RDR:83-86). After 1L the button reads "Log set 1R · 20 kg × 10" with no rest. Correct.
- **Rest after 1R**: the full base rest. After the last R, the between-exercises rest. Correct.
- **Live Activity**: `targetSet` is the first incomplete set (LAM ~471). ContentState has **no side**
  field, so the banner shows "Set 1 of 3 · 20 kg × 10" for both L and R (#12). **Should** carry the
  side and render "1L / 1R".
- **Smart progression** reads the left as the set (WTP+Prog:65 `position / 2`). Fine.
- **Adding a unilateral exercise mid-workout** creates `side: nil` rows (WTP+Ex:23-27 does not pass
  `perSide`), so the Split chip never shows (STV:194) (#11).

---

## 2. Set types

| Type | Model today | What a lifter does today | Failure | Should |
|---|---|---|---|---|
| Warm-up | `isWarmup` (WorkoutSetModel:31). Smart warm-ups are prepended (WorkoutSessionModel:151-163); logged ones are hidden (STV:76) and drawn "W" | Logs them in order with no rest between; the last earns 0.75× rest (RDR:73-79), anchored `.top` (AWS:147) | Generated for **every** weightReps/repsOnly exercise, lateral raises and the fifth isolation lift included: 15 exercises can mean ~30–45 extra rows. The "Warmup" action (STV:187-192) opens a sheet of *logged* warm-ups only (WarmupSetsView filter), so with smart warm-ups off there is no way to add one at the top: Add Set appends at the bottom and "Warmup Set" toggles it there. Toggling a logged working set into a warm-up makes it vanish from the card. | Warm-ups for the first lift of each muscle, or compounds only. An "Add warm-up" that inserts above the working sets. Show logged warm-ups collapsed ("2 warm-ups ✓") rather than gone. |
| Drop set | `SetTarget.setType = .drop` on the template only | Add Set, lower the weight, log; then Skip Rest | Counted as a full working set (header, volume, weekly muscle sets); the full rest fires; history cannot tell a drop from a straight set | `WorkoutSetModel.kind` (`standard/drop/myo/restPause/cluster/amrap`) plus `parentSetId`; sub-sets drawn indented under their parent, with no rest after a sub-set and counted once |
| AMRAP / to failure | `.failure` target type, unread by the tracker | Nothing marks it; the Auto column may show "8+" (STRV:337) | No cue to go to failure; nothing records that reps are open-ended | An "AMRAP" chip on the row; the log title says "Log AMRAP set" |
| Myo-reps / rest-pause | `.myo` target type | Logs the activation set, then each mini-set as a new set with a full rest each | The rest timer fights the protocol (15 s mini-rests); the set count inflates five-fold | A row type with a mini-rest that defaults to 15–20 s and "+1 mini-set" inside the row |
| Cluster | none | As rest-pause | As above | As myo, with intra-set rest |

---

## 3. Supersets and circuits

| Aspect | Code | Today | Problem | Should | Type |
|---|---|---|---|---|---|
| Card shows one exercise | WTV:171-189 | Card A; after a set the card flips to the partner (`supersetAutoScroll`, WTP+SS:23-35) | Partner's numbers are invisible until the flip; B appears only as an Up Next row | Two stacked mini-tables on one card for a group (A1/B1 rows interleaved), or at least a "Next in superset: B · 40 kg × 10" line | Design |
| Rest between partners | RDR:60-94 | Full base rest after A1 | #1. And A's last set is `isLastWorkingSet` → between-exercises rest even though B's last set is still to come | No rest (or a "transition" setting, default 0–15 s) after a set whose partner has sets left; rest after the round | Gap |
| Label | WTV:283-290 | "Superset A"/"Superset B" = the member's letter *within* its group | Two supersets in one workout are both "A/B"; deleting one partner leaves a lone "Superset A" (WTP+Ex:56-66 does not clear the partner's `supersetGroupId`) | Letter per group, number per member (A1, A2, B1, B2); dissolve on delete | Bug (delete) / Design (label) |
| Completion of one partner | WTP:491-500 | Jumps to the next incomplete exercise **after** it in order | Partners need not be adjacent (STP:155-174 does not move them together). With B before A, finishing A skips B's remaining sets | Prefer an incomplete partner first; move the joined exercise next to its partner when grouping | Bug |
| Do Later / Do Next | WTP+AE:52-77 | Moves the whole group | Correct | — | — |
| Progress counter | WTP+AE:116-119 | "Exercise 3 of 6" flips 3↔4 each set | Reads as jumping around | "Superset 2 of 5" for a group | Design |
| Live Activity | LAIH:95 | Logging A1 keeps the banner on A2 | Ignores the round-robin. Only corrected if the tracker presenter is alive to re-push (WTP:527-547). Minimized, it stays on A | Apply the same superset advance inside `completeSet` | Bug |
| Circuits of 3–4 | WTP+SS:28 wraps | Round-robin in group order, skipping finished members | Good; the rest problem multiplies (3 needless rests per round) | As above | — |

---

## 4. Edge states

| State | Governing code | Today | Failure / awkwardness | Proposed | Type |
|---|---|---|---|---|---|
| **0 exercises** | WTV:27-33, AWS:154-165, WTV:126-147 | "No Exercises" placeholder, Add Exercise row, no CTA | The progress bar still reads "0 of 0 working sets · Exercise 0 of 0"; Finish only via the ⋯ menu → "No Sets Logged" dialog | Hide the header; make Add Exercise the bottom CTA | Gap |
| **1 exercise** | — | Fine; Up Next and Completed are empty | — | — | — |
| **15 × 6 sets** | WTV:191-220, AWS:67-75 | Card plus 14 Up Next rows; "0 of 90 working sets"; plus up to 45 smart warm-ups | Every keystroke saves the whole session (WTP:28-33 `didSet` → local write) and diffs 90+ sets (WTP:556-601): cheap but constant. Warm-up noise (§2) | Fewer warm-ups; debounce saves | Design |
| **1 set** | RDR:88 | Its rest is the between-exercises rest; "Set 1/1" | Fine | — | — |
| **12 sets** | STV:76-101 | 12 rows plus Add Set | The list never scrolls to the current row. After set 8 the highlighted row is below the fold; the CTA still works, but the row and its plate line are not visible | `ScrollViewReader.scrollTo(currentSetId)` after each log | Gap |
| **Exercise with no sets** | AWS:154-165, WTP:454-456 | The card shows only headers and Add Set; the CTA says "Next: …"; `isComplete` is false, so it stays in Up Next for good; "Set 0/0" (ExerciseTrackerView:203) | Saved as an empty exercise in history; if it is the only exercise there is **no CTA at all** | On finish, offer to drop empty exercises; when it is the only one, make the CTA "Add Set" | Gap |
| **40-char Spanish name** ("Press de banca inclinado con mancuernas") | ExerciseTrackerView:106, WTP+AE:214-215, WTV:89-94 | Card title wraps (no limit); CTA "Siguiente: Press de banca inclinado con mancuernas" at `lineLimit(2)` | Fine at default sizes; truncates at AX sizes; Live Activity truncates | — | — |
| **400-char note** | ExerciseTrackerView:119-126 | The session note `Label` and the pinned exercise note have **no line limit** | 8–10 lines above the set table on every set; the table is pushed off screen at large sizes | `lineLimit(3)` with "More" | Bug (layout) |
| **No previous session** | WTP+Rest:36-68, STRV:270-273 | Last column "—"; no progression note | Fine. Time/distance defaults masquerade as data (§1) | — | — |
| **Previous session in a different unit** | STRV:374, Format.swift:38-40 | Converted on display: "220.5 lb × 5" | Tap-to-fill writes 100 kg exactly, which the field shows as "220.46"; the plate line then says "Not loadable. Use 220 lb" | Round fills to the gym's increment in the current unit | Design |
| **Gym profile missing** | WeightStepper:91, :100-102; WTP:603-607 | Fallback ± 2.5 kg / 5 lb from 0, no bar chip, no plates; "Gym Settings" silently does nothing | Silent dead menu item; no plate maths | Hide or disable Gym Settings when there is no gym, or route it to "Choose a gym" | Bug (minor) |
| **Plates with lb unit** | PlateCalculator:20-59, WeightStepper:165-172, :207-211 | An lb gym (45 bar; 45/35/25/10/5/2.5) works: 225 → "45 + 45". A kg-plate gym used in lb converts plates to 44.092 lb… so 225 lb is "Not loadable. Use 224.9 lb" | Greedy loading fails non-canonical sets (15 lb bumpers: 30/side = 15+15, but greedy tries 25 first) | Subset search (the `ponytail:` note at :64 already names it); keep plate maths in the plates' own unit | Bug (minor) |
| **Dynamic Type AX5** | STRV:41-47, STV:53, WTV:126-147, InlineRestTimerRow:44-46, SKV:36 | Rows stack into two lines; keyboard capped at xxLarge (deliberate) | The progress header is one `HStack` of two texts and wraps into a tall pinned bar; the rest row's `.fixedSize()` text can push the bar to zero width or overflow at 375 pt; the CTA truncates at 2 lines | `ViewThatFits` or a VStack for the header at AX sizes; drop `fixedSize` and let the bar go under the text | Bug (layout) |
| **Landscape (iPhone)** | WTV whole body | Nav bar, pinned header, bottom CTA and the ~300 pt custom keyboard on a ~390 pt-tall screen | While typing, about one row is visible | Hide the progress header while the keyboard is up | Design |
| **iPad regular width** | `readableContentWidth` 700 pt; SetKeyboardTextField:29-50 | The table keeps fixed columns (fine). The custom `inputView` spans the full screen width with `maxWidth: .infinity` keys | A 1,000-pt-wide keypad; with a hardware keyboard the custom keyboard and its chips may still occupy the bottom | Cap the keypad width and centre it; consider a popover keypad on iPad | Design |
| **Reduce Motion** | WTV:96-100, STRV:94-100 | Opacity transitions; highlight cross-fades | Pass | — | — |
| **Dark Mode, dim gym** | STRV:318-323 (`.caption` secondary), STRP:230 (`notReady` at 0.5 opacity), STV:280 (`.caption2`) | Small secondary text for Last and headers; the dashed "not ready" circle at 50 % secondary | Hard to read at arm's length in low light; the "not ready" state is nearly invisible in dark | Body-size Last column on the current row; full-opacity dashed circle | Design |
| **Offline** | WorkoutSessionManager:81-84 (local document), WTP+Finish:152-194 | Every edit is saved locally; finish retries with toasts; the session stays resumable | Pass. The active session is on-device only, so losing the phone loses it (acceptable) | — | — |
| **App killed mid-set, resumed** | WTP:108-146, WTP:194, WorkoutSessionManager:281-286 | Sets are intact (saved per keystroke) | Rest lost on screen (#9); HealthKit not restarted (#9); pause lost; `restStartedAt`, `customRestSeconds`, `acknowledgedProgressionNotes` reset; `progressionBaseline` is recaptured from **edited** values (WTP:123), so with in-session progression on the engine may overwrite the user's edits | Read `SharedWorkoutStorage.restEndTime` as a fallback, as LAIH:259-263 already does; implement HealthKit workout recovery; persist pause and the baseline with the session | Bug |
| **Phone call during rest** | HKWorkoutManager:355-391 | A wall-clock end time plus a scheduled backstop notification | Pass; the rest-complete sound may be swallowed by the call audio | — | — |
| **Rest ends while locked or backgrounded** | HKWorkoutManager:441-470, RestOverNotifying | Live Activity alert or backstop notification; on return the inline row reads Ready | Pass | — | — |
| **Set logged from the Lock Screen while the card shows another exercise** | LAIH:77-98, WTP:403-418, :527-547 | The handler logs, saves and rests; on foreground the tracker adopts it; if that exercise is now complete, `advanceAfterExerciseCompletion` **moves the card away** from the exercise the user had open | Card jumps; the inline timer may be missing (#10); no validation (#12); a minimized tracker reopens on the first incomplete exercise and re-points the Live Activity there (WTP:127-144) | Do not move an open card for a remote log unless it was showing the logged exercise; fix `restStartedAt`; validate in `completeSet` | Bug |
| **Editing a logged set** | SetTrackerRowView:253-254 comment; WTP:470 | Fields stay editable; Done on a logged row does nothing; no propagation | Pass | — | — |
| **Un-logging the set a rest follows** | STRP:70-72 → WTP+AE:185-191 | The rest is cancelled; the row becomes current again; the button reads "Log set N" | One tap with no confirmation (#14); the original `completedAt` is lost, so re-logging re-orders "latest set" | Undo toast ("Set 2 un-logged · Undo") | Design |
| **Deleting the current exercise** | WTP+Ex:56-66 | Card jumps to the **first** incomplete exercise, possibly one put off earlier, not the next one | Unexpected jump; a running rest re-anchors `.top` on the new card | Go to the next exercise in order | Design |
| **Deleting the only exercise** | WTP+Ex:56-66, WTV:27 | Empty state; a running rest keeps going (footer Skip Rest over the empty screen) | Rest for nothing | Cancel the rest when its set's exercise is deleted | Bug (minor) |
| **Deleting the set a rest follows** | STRV:103-105, AWS:131-148 | Rest continues; the row re-anchors under the previous logged set | Wrong place | Cancel or re-anchor `.top` | Bug (minor) |
| **Reordering during rest** | WTP+AE:86-112 | The card stays; the rest stays anchored by set id | Pass | — | — |
| **Swapping mid-way** | STP:78-131 | See #15 | — | Keep the old exercise (logged sets only, marked done) and insert the new one after it with the open sets; reload Last and suggestions for the new `templateId` | Bug + Design |
| **Changing units mid-workout** | STV:346-368, STP:245-277 | "Display Only" relabels; "Convert Values" converts **every** set, logged ones included, rounding lb to whole pounds | Already-logged history is rewritten (100 kg → 220 lb = 99.79 kg); the preference is global per exercise, so it changes future sessions silently | Convert only open sets; round to the gym's increment; say "for this exercise everywhere" in the dialog | Bug |
| **Timezone / midnight crossing** | WTP+AE:121-123, WTP:165-171 | Date label from `dateCreated` in the current zone; the clock is wall-clock | A 23:30 start counts towards the start day. Acceptable | — | — |
| **4-hour workout / forgotten finish** | WTV:150-166, WTP:190 | The clock goes to h:mm:ss; the idle timer stays disabled (`keepAlive`) for the whole time | No "still training?" prompt, so a forgotten session pollutes duration, Apple Health calories and the battery; Live Activities end at about 8 h | After 45–60 min with no set logged, a notification "Still training? Finish / Keep going"; propose the last set's time as the end time | Gap |
| **Cardio in a lifting session** | WTP:209 (`.traditionalStrengthTraining` for the whole session), RDR | A run or row is a distanceTime exercise; full rest after it; counted as a working set | Apple Health gets no distance or route for it; a "working set" for a 20-minute run | Optionally no rest after timed or distance work; a per-exercise Health activity segment later | Gap |
| **Mac Catalyst rest** | WTP+Rest:128-131, WorkoutSessionManager:281-286 | `startRest` is compiled out; `restStartedAt` is set; `endsAt` is nil | The inline row reads "Ready" the instant a set is logged; no rest on Mac | A plain in-process timer on Catalyst | Gap |
| **Paused workout** | HKWorkoutManager:146-161 | The clock stops; a running rest keeps counting and alerts | Minor | Pause the rest with the workout | Design |

---

## 5. Smaller findings worth a line each

- `completedSummary` / `upNextSummary` pick "Top" with `max` on (weight, reps). For timeOnly and
  distanceTime every key is (0, 0), so the *first* set wins rather than the longest or farthest
  (AWS:211, :234). **Bug.**
- `onTask()` (WTP:148-159) is dead code, and so is `workoutTemplate` (WTP:35). Delete them, or wire
  them up for #8.
- Set bindings are by index (`delegate.exercise.sets.filter{…}` → `Binding` subscripts, STV:76),
  which the exercise level explicitly avoided (WTV:173-175). Deleting a set, or adopting a remote
  save, while a row redraws risks an out-of-range read. **Risk, unconfirmed.**
- The `onAddRestTimePressed` and `startRestTimer` calls pass `currentExerciseIndex`, not the
  expanded card's index (WTP+Rest:79, :130), so the Live Activity can point at a different exercise
  from the card when `exerciseAutoNext` is off.
- The Live Activity rest ignores a rest set by hand on the row (LAIH:211-216 passes no
  `customRestSeconds`).
- In `swap`, `openCount` counts open warm-ups as working sets (STP:109).
- The Warm-up sheet copies the exercise into its own presenter state (WarmupSetsPresenter:10), so it
  shows a snapshot that does not follow edits made elsewhere while it is open.
