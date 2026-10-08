# Live workout tracker: learnability, progressive disclosure, and a way to decide

Author: Alex (PM) · 6 Oct 2026 · Status: analysis only, no code changed.

Based on the working tree of `feature/workout-tracker-redesign`. Files read:
- Views: `WorkoutTrackerView.swift`, `ExerciseTrackerView.swift`, `SetTrackerView.swift`,
  `SetTrackerRowView.swift`, `ProgressionNote.swift`.
- Presenters: `WorkoutTrackerPresenter` with its `+ActiveExercise`, `+Events`, `+Rest`, `+Finish`,
  `+Exercises`, `+Progression` and `+Superset` files, plus `SetTrackerPresenter`,
  `SetTrackerRowPresenter`, `SetKeyboardPresenter` and `ExerciseTrackerPresenter`.
- Settings and onboarding: `WorkoutSettings.swift`, `WorkoutSettingsView.swift`, `TutorialsView.swift`,
  the `ExerciseFrequency` onboarding step.
- Other: `ABTestManager.swift`, `LiveActivityManager+Events.swift`, `docs/specs/live-activity.md`.
- The five sibling analyses (containers, ux, hig, perf, product).

Nothing in this file has been tested with users. **[unverified]** marks claims I could not
confirm from the code I read.

---

## Part A. Learnability and progressive disclosure

### A1. What the new tracker exposes, and how

Paths below are relative to `Core/Training/Subviews/WorkoutTracker/`.

**Visible with no interaction**
- **Toolbar**
  - Minimize chevron.
  - Workout name, date and running clock (caption).
  - The workout's "…" button.
- **Progress header**
  - Progress bar.
  - "X of Y working sets" and "Exercise n of m".
- **Exercise card**
  - Image and name.
  - The exercise's "…" button.
  - Superset chip.
  - "Your note" (when the exercise has a pinned note) and the session note.
- **Smart Progression note.** A tinted card reading "Tap to dismiss". It shows until you tap it
  or log the first working set.
- **Column headers.** Set, **Last/Auto chip**, **kg unit chip**, Reps, Done.
- **Each set row**
  - Set circle (W, 1, 2, 1L/1R).
  - Last value with RIR.
  - Weight and reps fields.
  - Done circle: dashed when not ready, open when ready, check when logged.
- **The current row** is tinted and outlined. Under it is a **plate line**, shown only for
  barbell exercises in a gym profile that has plates.
- **Inline rest row**, while resting.
- **Add Set** button.
- **Up Next rows** (image, name, plan and last time, chevron), a **Reorder** button, and the
  Completed section.
- **Add Exercise**.
- **Bottom button.** It reads one of:
  - "Log set n · W × R"
  - "Next: X"
  - "Finish Workout"
  - "Skip Rest m:ss" with "+15s" beside it

**Behind a tap on something that does not look tappable**

| Element | What the tap does | Affordance |
|---|---|---|
| Last value | Copies last time's numbers into the set (`SetTrackerRowView.swift:423-432`) | None. Caption text, secondary grey |
| Auto value | Fills the set from the suggestion | None |
| Last/Auto chip | Switches the column. The choice persists in `UserDefaults` | A chip. Moderate, but "Auto" means nothing until it has been seen |
| Set circle | Menu: Warmup Set toggle, "What's a warmup set?" | Looks like a label |
| Plate line, when the weight is not loadable | Sets the nearest weight the plates can make (`:62-81`) | A warning icon. The hint exists only for VoiceOver |
| **Done circle on a logged set** | **Un-logs the set and cancels the rest**, with no confirmation and no undo (`SetTrackerRowPresenter.swift:70-72`) | None. It is found by accident |
| Keyboard Done | **Logs the set if it is ready** (`SetKeyboardPresenter.swift:113-116`) | The key says "Done" |
| Keyboard chips and stepper | Last set, Last time, Target, Min and Max, plates, and RPE (with Effort on) | Visible once the keyboard is open. Good |
| Up Next row | Makes that exercise current, and the bottom button follows it | A chevron, which promises navigation that doesn't happen |

**In overflow menus**
- **The exercise's "…"** (`SetTrackerView.swift:144-252`):
  - Add Note
  - Do Later
  - Equipment
  - Warmup
  - Split L/R (its on/off state is not visible)
  - Targets
  - Swap
  - Superset
  - Exercise Settings
  - Delete
- **The workout's "…"**:
  - Pause/Resume
  - Finish
  - Workout Notes
  - Workout Settings
  - Gym Settings
  - Discard

**On long press**
- On an Up Next row: **Do Next** and Do Later. The row's hint says only "Opens this exercise".
- On a set row: **Rest Timer** (rest for that set) and Delete.
- On the title: the large content viewer.

**On swipe**
- A set row's trailing swipe is **Delete**, and a full swipe deletes. Its leading swipe is
  **Rest Timer**.

**Not available on this screen**
- Starting a rest without logging a set.
- Taking 15 s off a rest.
- Editing a logged warm-up: it is filtered out of the table (`SetTrackerView.swift:76`).
- Set types beyond warm-up (failure, drop).
- Undo after Delete or un-log.
- Superset-aware rest.
- Exercise history beyond last session. **[unverified]** It may be reachable through Exercise
  Settings.

**Settings that change behaviour.** Workout Settings is reachable two ways: Profile → Settings, and
the tracker's "…". Its defaults:

| Setting | Default |
|---|---|
| Propagate Changes | on |
| Effort (RPE) | off |
| Superset Auto-Scroll | on |
| Exercise Auto-Next | on |
| Smart Progression in-session | off |
| Previous Reference | This workout |

### A2. First week compared with 200 workouts

| | First-week lifter | 200-workout lifter |
|---|---|---|
| **What their screen looks like** | No history, so the Last column is a column of "—". Usually no progression note. Smart warm-ups are on, so W rows appear with no explanation. | Last column full, with RIR. A progression note on most exercises of a progressing program. |
| **What they need** | "What do I do now?" and confidence that a set saved. | Speed, and getting off the planned path quickly when a machine is taken or they want a back-off set. |
| **Served well** | The bottom button reads the set back ("Log set 2 · 60 kg × 8"). The tinted current row. The progress header. | One-tap logging when nothing is resting. Keyboard chips. The plate line. |
| **Will never find** (see A3) | Do Next, rest for one set, Split L/R, the Auto column, the plate fix, copying from Last, the warm-up toggle and its explanation | Mostly found over time. Swap and Warm-up stay two taps away at the top of the card. |
| **Slowed or hurt by** | Unintended actions they cannot see: keyboard Done logging a set, un-logging with a tap | The progression note, the rest-mode button, superset rests, auto-advance, the unit dialog (see A4) |

### A3. Features a novice will not find, and what to do about each

**Do Next**
- *Route today:* long press on an Up Next row only.
- *Why it stays hidden:* long press is never suggested, and the hint says "Opens this exercise".
- *Fix:* add swipe actions on Up Next rows ("Do Now", "Do Later"), correct the accessibility hint,
  and show a one-time tip after the first exercise taken out of order.

**Rest for one set**
- *Route today:* leading swipe or long press on a set row.
- *Why it stays hidden:* there is no visible route, which breaks the HIG rule that context-menu
  items must also be in the main interface (hig.md §1).
- *Fix:* add "Rest Timer…" and "Delete Set" to the set-circle menu. Show a tip when someone skips
  or extends the rest on the same exercise three times in one workout.

**Split L/R**
- *Route today:* the "…" menu, on exercises worked one side at a time.
- *Why it stays hidden:* it is buried, and the menu does not show whether it is on.
- *Fix:* make it a `Toggle` in the menu (hig.md). Show it as a chip only on exercises worked one
  side at a time, so it appears based on the situation, not on experience.

**The Auto column**
- *Route today:* the chip labelled "Last".
- *Why it stays hidden:* the chip names the current mode, not the alternative.
- *Fix:* when the exercise has **no history**, default the column to targets ("8–12") rather than
  "—", so a novice sees the plan. Later, show a tip on the chip the first time a progression
  note appears.

**The plate fix**
- *Route today:* tapping the warning line.
- *Why it stays hidden:* it reads as a warning, not a button.
- *Fix:* change the design, not add a tip. Make "Use 112.5 kg" a small bordered button on that
  line.

**Un-logging by tapping the check**
- *Route today:* tapping the Done circle on a logged set.
- *Why it stays hidden:* it is found by accident, which is the worst way to find it.
- *Fix:* change the design. On a logged set, the check opens a menu (Unlog, Edit). Every log
  gets an Undo toast for about 5 s.

**Copying from Last**
- *Route today:* tapping the Last value.
- *Why it stays hidden:* nothing signals it.
- *Fix:* the keyboard's "Last time" chip already does this visibly. Leave the tap as a shortcut
  and teach it with a tip only if data shows people typing last time's figure by hand.

**Warm-up meaning and toggle**
- *Route today:* tapping the set circle.
- *Why it stays hidden:* the circle looks like a label.
- *Fix:* the first workout that has W rows shows a one-time tip: "W = warm-up. Tap a set number to
  change it."

**Keyboard Done logs the set**
- *Route today:* this is the default behaviour.
- *Why it is a problem:* it causes errors, not just low discovery.
- *Fix:* change the design, as ux.md #4 proposes. Label the key "Log" while the row is ready, and
  add a plain button that only closes the keyboard. Decision 5d in hig-decisions ("Done logs")
  has to be revisited by the owner, not overridden here.

### A4. Features that slow an expert

1. **The Smart Progression note**
   - The acknowledgements live in `acknowledgedProgressionNotes`, an in-memory set on the
     presenter, keyed by the exercise's id in that session.
   - So a long-time lifter on a progressing program sees the card on **almost every exercise of
     every workout**.
   - It comes back if they minimize and reopen the tracker, because that builds a new presenter.
   - It costs no tap, since it clears on the first working set. Its cost is roughly 120 pt above
     the table at the moment the lifter is reading the numbers, and it pushes Add Set and Up Next
     below the fold (ux.md §4).
2. **The rest-mode button.** Lifting before the timer ends takes Skip, then Log: 2 taps where 1
   should do. In a superset there is a full rest between partners, so it is 3 taps per round
   (ux.md §2).
3. **Auto-advance on the last set.** A back-off set now costs about 4 taps and 2 scrolls.
4. **Swap and Warm-up** are in the "…" at the top of the card: two taps, the second a reach.
5. **Changing the unit** asks "Display Only / Convert Values" every time. That is fine once,
   tiresome per exercise.
6. **Confirmations that are fine** (rare and destructive): Delete Exercise, Discard, Swap that
   would drop logged sets, No Sets Logged.
7. **The missing confirmation, which hurts experts most.** Finish from the bottom button has none.
   Experts tap fastest, so a double tap that lands on Finish happens to them first (ux.md §5.1).

### A5. Disclosure strategy

Four rules decide each tier.

1. **The core loop is the same for everyone.** Read the numbers, lift, log, rest, move on.
   Nothing in that loop depends on experience. A 200-workout lifter and a first-timer press the
   same button in the same place.
2. **Every hidden action has one visible route.** Gestures and long presses are shortcuts, never
   the only way (HIG context-menus and gestures; hig.md §2h).
3. **Explanations adapt to use. Controls never move.** Hints and explanatory cards fade as the
   user gains experience. Buttons do not appear, disappear or move with usage counts. This avoids
   "where did that button go?", and keeps support docs, screenshots and UI tests stable.
   Visibility *may* depend on the **situation**: per-side chips only on exercises worked one side
   at a time, plates only on a barbell, Do Later only when something else is left.
4. **One hint per workout at most. None during the first workout. None in the last 10 s of a
   rest.** The first workout is for learning the loop.

| Tier | What | Mechanism |
|---|---|---|
| **Always visible** | The bottom button, current-row highlight, progress, Last/targets column, set table, rest row, Add Set, Up Next with summaries, Add Exercise. **Promoted:** a chip row with **Swap, Warm-up and "Do later"**, each shown only where it applies (ux.md #6, product.md idea 6). **Visible routes:** "Rest Timer…" and "Delete Set" in the set-circle menu, and a bordered "Use X kg" button on the plate line | Layout |
| **One-time tip at first relevant use** | Warm-up meaning (first W rows). Do Next and Do Later (first exercise taken out of order). Rest for one set (third skip or extend on the same exercise). Auto column (first progression note). Split L/R (first exercise worked one side at a time, if it stays in the menu). Undo (first log, as a toast rather than a tip) | **TipKit**, which is built in, with `MaxDisplayCount(1)` and an event-based rule per tip, invalidated once the action is used. No new dependency |
| **Stays in menus** | Equipment, Targets, Superset, Exercise Settings, Delete Exercise, note, unit change, Pause, Finish early, Workout Notes, Workout Settings, Gym Settings, Discard | Menus, grouped with dividers (hig.md) |
| **Adapts with use** (explanation only) | Progression note: a full card until the user has acknowledged 3 notes, **then one line in the header** ("+2.5 kg · Why?") that expands on tap. Acknowledgements kept per exercise template for the workout, not per presenter, so minimizing doesn't bring them back. Tips retire as their action is used | A counter in `UserDefaults` beside `SetTracker.showsSuggestions` |

**Where this connects to what the app already has**
- **Onboarding** has no training steps. The folders are account, body, goal and diet. CLAUDE.md
  says notifications, Health and Strava are "offered where first used", and this tracker should
  follow that: **no tracker tour in onboarding.**
- The `ExerciseFrequency` answer exists for the calorie estimate. Do not use it to change the UI.
  Do send it to Mixpanel as a user property so analyses can split novices from regulars
  **[unverified that it is stored on `UserModel`]**.
- **Profile → Tutorials** is a placeholder whose own copy promises: "When the app starts showing
  first-run guidance, this is where you will be able to see it again." TipKit gives it that job:
  a "Show tips again" row that calls `Tips.resetDatastore()`. That has to run before
  `Tips.configure()`, so set a flag and reset on the next launch.
- **Training Settings → Workout Settings** keeps the behaviour switches. Effort (RPE) is off by
  default. Offer it once, in context, after the fifth finished workout on the summary screen, the
  same pattern as the Strava offer (`offerStravaIfFirstWorkout`). Do not leave it buried in a
  list most users never open.

### A6. Should there be a "Simple" and a "Full" density setting?

**Recommendation: not now.** Confidence about 65%.

- **The personas differ mainly in explanation, not controls.** The rules above deal with that
  without a mode.
- **A mode doubles the surface.** Two layouts means twice the screenshots, UI tests, help copy
  and bugs, in a screen already 2,800 lines across the tracker module.
- **People can't choose a density before they have used the screen.** A setting in a list most
  users never open does nothing for them.
- **Accessibility sizes already change the density.** The rows stack at accessibility text
  sizes, which covers the most important reason to reduce it.

**What would change my mind:** if the experiment in Part B shows that **30% or more** of the
strip arm turns the strip off, or if interviews show novices overwhelmed by the table. Then add
**one** Workout Settings toggle, "Compact tracker", that controls exactly three things: the chip
row, the Up Next summaries and the plate line. Nothing else.

---

## Part B. A way to decide

Six analyses, six opinions, and no data. The aim is that the next design argument gets settled
by numbers agreed in advance, rather than by whoever writes the longest document.

### B1. The criteria

Seven measures. Each says which of the existing opinions it settles.

| # | Criterion | Definition | Settles |
|---|---|---|---|
| C1 | **One-tap log rate** | Share of in-app logs with no keyboard session for that set and no Skip Rest in the 5 s before. The proxy for taps per set | ux.md's "1 tap vs 2 when resting", and the cost of the rest-mode button |
| C2 | **Rest-end to next-log latency** | Next log time minus the planned rest end, from `rest_end_time` plus 15 s per extension. A negative value means the set started early. Report the median, and the **share of sets logged before the rest ended** | The rest-mode button (ux #2) and supersets (ux #3, product idea 1) |
| C3 | **Accidental-action rate per 100 sets** | Any of: an un-log within 10 s of a log; Skip Rest within 1 s of a log; two button logs less than 600 ms apart; Finish within 2 s of Skip Rest; a set deleted and another added within 30 s | ux.md §5 errors 1–4. The guardrail for every change |
| C4 | **Cost of going off plan** | Per workout: exercises taken out of order, Do Next/Later, Swap, sets added after auto-advance. Plus time from one exercise's last set to the first set logged on the exercise opened next | Chips vs "…" (ux #6, product #6). Auto-advance (ux #5). **Strip vs card** |
| C5 | **Logging surface mix** | Share of sets logged from the bottom button, a row's circle, the keyboard and the **Lock Screen**. If 40% come from the Lock Screen, the phone layout matters less than the Live Activity | product idea 10. How much effort the container deserves |
| C6 | **Completion** | Finished ÷ started. Discarded after at least one set. Abandoned (neither, after 24 h). At finish, working sets logged ÷ planned | Whether any change makes people quit mid-workout |
| C7 | **Navigation behaviour** | Exercise selections per workout split by where they came from (Up Next, Completed, the "Next:" button, the strip). Reorder by drag. Share taken in order | containers.md and product.md's "what would change my mind" about a pager |

Two guardrails that Mixpanel cannot see:
- **Keystroke hitches.** Instruments and MetricKit hitch rate (perf.md findings 1–2).
- **Glanceability at 60 cm.** This needs the gym test in B5, not analytics (hig.md text sizes).

### B2. What the existing events already cover

These are the events actually emitted today, with their parameters, read from the code.

**`WorkoutTrackerPresenter.Event`** (`WorkoutTrackerPresenter+Events.swift`)

| Event name | Parameters | Fired from |
|---|---|---|
| `WorkoutTrackerView_Appear` (screen event) | none | `onViewAppear` |
| `WorkoutTrackerView_Disappear` | none | `onViewDisappear` |
| `WorkoutTrackerView_DiscardWorkout_Start` / `_Success` / `_Fail` | `_Fail`: the error's parameters | `discardWorkout` |
| `WorkoutTrackerView_SaveProgress_Fail` (severe) | the error's parameters | `saveWorkoutProgress` |
| `WorkoutTrackerView_FinishWorkout_Start` / `_Success` | none | `completeFinish` / `retrySave` |
| `WorkoutTrackerView_FinishWorkout_Fail` | `reason`: permanent, retries_exhausted, signed_out or cancelled | same |
| `WorkoutTracker_StartRestTimer_Called` | `input_duration`, `resolved_duration` | `startRestTimer` |
| `WorkoutTracker_StartRestTimer_AfterCall` | `rest_end_time` (epoch seconds), `rest_end_time_is_nil` | `startRestTimer`. **This gives the planned rest end for C2** |
| `WorkoutTracker_Rest_Extended` | `seconds` (15) | `onAddRestTimePressed` |
| `WorkoutTracker_Rest_Skipped` | none | `onSkipRestPressed` |
| `WorkoutTracker_Workout_Paused` / `_Resumed` | none | `onPauseResumePressed` |
| `WorkoutTracker_Exercise_Selected` | **none** | `onExerciseSelected`. This is an Up Next or Completed tap **and also the bottom button's "Next:"**, so the two are mixed together. Auto-advance and superset round-robin do **not** fire it |
| `WorkoutTracker_Exercise_Moved` | `to`: later or next | Do Later (card menu or long press), Do Next. **Not** drag-to-reorder |
| `WorkoutTracker_Progression_Adjusted` | `exercise_id`, `sets_changed` | Live re-suggestion. Only with in-session Smart Progression on |
| `WorkoutTracker_ProgressionNote_Acknowledged` | none | Tapping the note |
| `WorkoutTrackerView_LoadGymProfile_Fail`, `_HealthKitAuthorisation_Fail` | the error's parameters | Operational |

Also at finish (`+Finish.swift`):
- `finish_workout_debug` (info level) with `session_id`, `template_id` and `plan_id`.
- `WorkoutSessionModel.finishedEventName` with `finishedEventParameters`. **[contents unread]**
- `finish_workout_save_error` with `error` and `is_transient`.

**`SetTrackerRowPresenter.Event`**

| Event name | Parameters | Notes |
|---|---|---|
| `SetTrackerRow_SetCompleted` | `source`, `set_id`, `exercise_id`, `use_rest_timers`, `rest_duration_seconds`, `on_start_rest_is_nil` | `source` is `log_button` (the bottom button) or `row`. **Keyboard Done also reports `row`.** It can only be told apart by a `SetTrackerRow_Keyboard_OfferedCompletion` immediately before it. The tracker always sends `on_start_rest_is_nil: false`. The warm-up sheet and the finished-workout editor send `true`, so **filter on `false`** to count live logging only |
| `SetTrackerRow_Keyboard_OfferedCompletion` | none | Fired when keyboard Done logs a ready set |

**Others**
- `LiveActivityMan_*`: Start, Update and End, each with Success and Fail. Operational only; they
  say nothing about which set was logged.
- `ABTestManager` adds every active test to the **user properties** (`addUserProperties`). An
  experiment flag in `ActiveABTests` therefore reaches Mixpanel with no extra work, with the
  caveat in B4.

**Coverage per criterion**

| Criterion | Covered today | Gap |
|---|---|---|
| C1 | `SetCompleted.source`, `Rest_Skipped`, `Keyboard_OfferedCompletion` | Keyboard opens are not tracked, so a set edited in the keyboard and then logged with the button looks like a one-tap log |
| C2 | `StartRestTimer_AfterCall.rest_end_time`, `Rest_Extended`, `SetCompleted` timestamps | No event when a rest runs out on its own |
| C3 | Skip within 1 s, double log, Finish after Skip: yes, all from existing events | **Un-log has no event** (`SetTrackerRowPresenter.swift:70-72`). **Set delete has no event** |
| C4 | `Exercise_Moved` | Swap, Warm-up, Targets, Add Set, Delete Set, the unit change and the plate fix are **all untracked**. `SetTrackerPresenter` and `ExerciseTrackerPresenter` have no `Event` enum at all. `Exercise_Selected` has no source and no in-order flag |
| C5 | In-app sources only | **[unverified]** whether the Live Activity handler (`AppLiveActivityIntentHandler`, which is given a `logManager`) emits a per-set event. I could not locate the file without search. Sets logged on the Lock Screen while the tracker is open reach the screen by adopting the saved session, which emits nothing |
| C6 | Appear, Finish and Discard events | No "workout started" event on this screen **[may exist where the workout is started; unverified]**. Finish carries no planned-vs-logged counts **[unless `finishedEventParameters` has them]**. Minimize is not tracked |
| C7 | `Exercise_Selected`, `Exercise_Moved` | No source. Drag reorder (`moveExercises`) and the Reorder button are untracked |

### B3. The instrumentation to add

The smallest set that closes the gaps. Ship it in the same build as the experiment.

1. **`source: "keyboard"`.** `offerCompletion` passes it rather than the default "row" (one
   argument through `onSetComplete` and `onLogSet`). **`source: "live_activity"`** goes in the
   intent handler's `completeSet`, if it is not there already.
2. **`SetTrackerRow_SetUncompleted`** with `set_id`, `exercise_id` and `seconds_since_logged`, in
   the un-log branch.
3. **`WorkoutTracker_Exercise_Selected`** gains:
   - `source`: up_next, completed, cta_next or strip;
   - `in_order`: whether it was the first exercise with sets left;
   - `left_set_in_progress`: whether the exercise left behind had some sets logged and some open.
4. **`WorkoutTracker_Rest_Completed`** with `planned_seconds`, in `announceRestCompletion`.
5. **One event for exercise actions**, not fifteen. `WorkoutTracker_ExerciseAction` with:
   - `action`: swap, warmup, targets, equipment, split, superset, note, add_set, delete_set,
     unit_change, fill_last, fill_auto, plate_fix, auto_toggle, set_rest, reorder_drag;
   - `via`: menu, chip, swipe, context_menu or tap.
6. **Finish parameters** (only those that `finishedEventParameters` lacks): `working_sets_planned`,
   `working_sets_logged`, `exercises_untouched`, `active_minutes`.
7. **`WorkoutTracker_ProgressionNote_Shown`**, as the denominator for the acknowledgements.
8. **`layout` as an event property** on `SetCompleted`, `Exercise_Selected`, `ExerciseAction` and
   finish. The reason is in B4.

Skipped: per-keystroke and per-menu-open events. They add noise and nothing a decision needs.

### B4. Experiment: the card alone vs the card with an optional strip

**What is compared**
- **Arm A** is today's screen, the card plus lists (containers.md A1).
- **Arm B** is the same screen plus the thumbnail strip in the `safeAreaBar` (containers.md D1),
  with a "Show exercise strip" switch in Workout Settings so people can turn it off.
- **Nothing else differs.** Ship the rest-button, superset and keyboard changes in a separate
  build. Bundling them would make every result impossible to attribute.

**Why the main metrics are not the deciders.** The strip does not touch the log loop, so C1–C3
are **guardrails** for this test. It should be judged on C4 and C7, plus the opt-out rate. If
taps per set is used to judge the strip, the test will come out "no difference" and settle
nothing.

**Design: a 2-week crossover on TestFlight.**
- The flag is `trackerNavigator: card | strip` in `ActiveABTests`, served by Remote Config.
  TestFlight builds use the prod configuration.
- Assign by a random percentile condition: half start on the card, half on the strip. **Swap the
  conditions in the console on day 8.**
- **Why within-subject.** A TestFlight group is small, realistically 15–30 active lifters
  **[unverified count]**. Each lifter compared with themselves removes the large differences
  between programs and gyms.
- **Caveat.** `ABTestManager` writes the arm as a *user property*, and Mixpanel breaks down by
  a profile's **current** value. After the swap, every week-1 event would be relabelled.
  Hence item 8 in B3: stamp `layout` on each event.
- **Power, stated plainly.** About 20 lifters × 3 workouts a week × 2 weeks is about 120
  workouts and 2,000+ sets. But the unit of analysis is the lifter, and 20 paired lifters can
  only detect large effects (roughly 0.65 SD at 80% power). The rule below is written for
  that: big wins, clear harm, or keep what we have.

**What to look at in Mixpanel.** Filter everywhere on `on_start_rest_is_nil = false` and on
release version. Break down by `layout`, using each user's median.

| Report | Type | Measures |
|---|---|---|
| Strip use | Insights: `Exercise_Selected` where `source = strip`, per workout, for workouts with 4+ exercises | Is it used at all |
| Opt-out | Insights: `ExerciseAction` with the strip switched off, or a settings event | Is it wanted |
| Navigation cost | Funnel: last `SetCompleted` of an exercise → next `SetCompleted` with a different `exercise_id`. Median time to convert | C4 |
| Out of order | Insights: share of `Exercise_Selected` with `in_order = false`, and `Exercise_Moved` per workout | C4 and C7 |
| Accidental actions | Funnel: `SetCompleted` → `SetUncompleted` within 10 s, holding `set_id` constant. Plus Skip within 1 s, via a funnel window | C3 guardrail |
| Completion | Funnel: `WorkoutTrackerView_Appear` (first per session) → `FinishWorkout_Success`, and `DiscardWorkout_Success` | C6 guardrail |
| Logging surfaces | Insights: `SetCompleted` by `source` | C5, for context |

**Decision rule.** Written down and dated **before** day 1. The owner decides on day 15, and the
rule is not changed after the data arrives.

- **Make the strip the default** only if all four hold:
  1. **It is used.** At least one strip tap in at least 50% of strip workouts that have 4 or
     more exercises.
  2. **It is wanted.** Fewer than 20% of the strip arm turn it off, and at least 60% prefer it
     in a 3-question exit survey.
  3. **It helps.** Median navigation time (exercise to exercise) is at least 20% lower, **or**
     out-of-order selections cost no more taps with fewer scrolls, measured in the gym test.
  4. **Nothing gets worse.** The accidental-action rate does not rise by more than 1 point per
     100 sets. Completion does not fall. No new crash.
- **Drop the strip** if fewer than 25% of workouts use it, or 30% or more turn it off, or a
  guardrail gets worse.
- **Anything in between counts as inconclusive. Keep the card**, because no change is the cheaper
  default. Re-run later as a production A/B test at 50/50 once there are enough users.
- **The pager comes back on the table only** if the strip is heavily used **and** testers ask for
  swiping without being prompted (the gym and Wizard-of-Oz tests below). That is the condition
  containers.md and product.md already set.

### B5. Three cheap tests that need no code

**1. A Figma or paper tap-through with 5 lifters** (about 2 days including analysis)
- **Who:** 2 lifters under 3 months of training, 3 with over 2 years, including one who
  supersets and one left-hander.
- **Variants:** three, counterbalanced: today's card, the card with the strip, a paged layout.
- **Tasks:**
  1. The squat rack is taken, so do lunges now (Do Next).
  2. Add a back-off set after the last set.
  3. Fix last exercise's reps.
  4. Do one superset round.
  5. Set a 3-minute rest for this set only.
  6. Undo a set you just logged.
- **Measures:** first-click success (pass at 4 of 5), time on task, and what they expected to
  happen.
- **What it settles:** which hidden features (A3) are truly undiscoverable, and whether the strip
  helps first clicks.

**2. A real session with the existing TestFlight build** (3–5 lifters, a morning each)
- **Setup:** an observer stands beside the lifter with a tally sheet for taps, scrolls,
  two-handed moments, glances, and how often the set starts before the rest ends. Lock Screen and
  phone use are recorded separately.
- **Video:** iOS screen recordings don't show touches, so if filming, use a second phone over the
  shoulder, with consent and gym permission.
- **After:** a 5-minute debrief.
- **Measures:** C1, C2 and C5 by hand, before the instrumentation ships. Plus the 60 cm glance
  check: can they read the rest time and last time's numbers from the bench?
- **What it settles:** whether the rest-mode button and the caption-sized text really cost what
  ux.md and hig.md claim.

**3. A Wizard-of-Oz test of the paged layout** (half a day)
- **Setup:** one screenshot per exercise of a real workout, taken with the Mock scheme or the
  screenshot script in `scripts/`, in a Photos album. Swiping through Photos *is* the pager.
  The lifter logs on a paper card, or tells the facilitator, who notes it down.
- **Variants:** run it once with a page per exercise and once with a page per superset block.
- **Measures:**
  - unprompted swipes;
  - attempted row swipes (the gesture clash in containers.md);
  - superset mistakes (logging the wrong partner);
  - stated preference against today's TestFlight build.
- **What it settles:** whether "I want to swipe" is a real need before anyone builds the
  hardest-to-get-right container.

### B6. Sequence

| Week | Work | Owner |
|---|---|---|
| 0 | Tests 1 and 3. Write the decision rule down and date it | PM |
| 0–1 | Instrumentation (B3) plus the strip behind its flag in one build. Test 2 on the current build as a baseline | Eng / PM |
| 1–2 | Crossover on TestFlight | — |
| 3 | Read against the written rule. Write the decision with its numbers | PM |

The same seven criteria then judge the next proposals: the rest button (C1, C2), supersets (C2,
C4), keyboard "Log" (C3), and chips vs menu (C4). Each is its own flag and its own two-week
window.
