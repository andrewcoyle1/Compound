# Live Workout Tracker: Usability Audit (OLD vs NEW vs MacroFactor)

Scope: the active-workout screen only. OLD is `HEAD`; NEW is the working tree on
`feature/workout-tracker-redesign`; MacroFactor (MF) comes from the two supplied screenshots.
Method: expert walkthrough (heuristic and task analysis) of the SwiftUI source, with defaults taken
from `WorkoutSettings.swift`: `propagateChanges`, `supersetAutoScroll`, `exerciseAutoNext` and
`useRestTimers` on; `rirTracking` and `smartProgressionApplyInSession` off. Nothing was run on a
device, so heights, sizes and reach are estimates from the layout code. Treat the tap counts as
hypotheses to check in a moderated test (see the end).

Reference devices: a 6.1" phone at 390 x 844 pt and a 6.9" phone at 440 x 956 pt. The persona
throughout is a lifter between sets. The phone is in one hand or flat on a bench about 60 cm away,
their hands are sweaty or chalky, their heart rate is up and they glance for about 2 seconds.

---

## 1. What each design is, in one line

| | Structure | Primary logging affordance | Rest timer |
|---|---|---|---|
| OLD | Overview stat card (6 stats), then every exercise as a `DisclosureGroup`, one expanded | 44 pt circle at the right of each row | Glass pill at the bottom with a `metricLarge` (title) countdown, plus +15s and Skip |
| NEW | Pinned progress bar, then one open exercise card, then Up Next and Completed lists | Full-width bottom CTA that changes meaning; the row circle still works | Inline row under the set it follows, plus "Skip Rest m:ss" taking over the CTA |
| MF | Thumbnail strip with a progress underline, one exercise per horizontal page | Checkbox at the right of each row | Small "0:00" and bar at the top right |

---

## 2. Task walkthroughs

Counts are deliberate touches (taps, long presses, key presses). "S" is a scroll and "K" a keypad
entry. "Find" is the visual search needed before the first touch.

| # | Task | OLD | NEW | MF |
|---|---|---|---|---|
| 1 | Log a working set as prefilled | 1 tap on the row circle. Find: no "current" row marker, so the user scans for the first open circle, and may need S if the overview card pushes the table down | **1 tap on the CTA**, which reads "Log set 2 · 115 kg × 5" (`ActiveWorkoutState.swift:168-181`). Find: nothing to search for. **But if a rest is still running it costs 2 (Skip Rest, then Log)**, or 1 on the row circle | 1 tap on the checkbox. Find: no current-row highlight |
| 2 | Change the weight, then log | Field, then stepper or K, then keyboard Done (which logs): 3+ | Same, 3+. The CTA is hidden while the keyboard is up (`WorkoutTrackerView.swift:61,87`), so **Done is the only way to log** (`SetKeyboardPresenter.swift:113-116`) | kg cell, then K, then checkbox: 3+ |
| 3 | Log a warm-up | To add one: "Warmup" chip on the visible chip row, then the sheet. To log: 1 tap | To add one: **"…" then Warmup** (2 taps, hidden, top of card). To log: 1 tap on the CTA ("Log warm-up · 60 kg × 5"). The logged warm-up **disappears** from the table (`SetTrackerView.swift:76`) | To add: visible "Warm Up" chip. To log: 1 tap, and the W row stays visible |
| 4 | Machine taken: do a different exercise now | Tap the other exercise's header, which collapses the current one: 1 tap + maybe S | (a) Card "…" then Do Later: 2 taps, top-right of the card (`SetTrackerView.swift:152-158`). (b) S to Up Next, then tap the row: 1 + S. (c) S, long press, Do Next (`WorkoutTrackerView.swift:256-269`), which **only queues it after the current exercise**, so it still needs (a) or (b) | 1 tap on its thumbnail (top of screen), or swipe the pages |
| 5 | Superset A/B/A/B, 3 rounds | 2 taps per round on circles that **move** (A collapses, B expands). 6 taps | Via the CTA: **3 taps per round (Log A, Skip Rest, Log B)**, because a full rest runs after A (`RestDurationRules.swift` has no superset case). 9 taps. Via the row circle: 2 per round, but the card swaps wholesale between A and B (`WorkoutTrackerPresenter+Superset.swift:33-34`) | Probably 2 per round plus a page change. Not verifiable from the screenshots |
| 6 | How many sets are left in the workout? | 0 taps if the overview card is on screen ("Sets Completed 7/18"), otherwise S up | **0 taps, always visible** in the pinned header ("7 of 18 working sets", `WorkoutTrackerView.swift:126-147`) | Not shown. Only "Set 1 of 3" for the current exercise and per-tile underlines |
| 7 | Fix a typo on a logged set | Current exercise: field, K, Done = 3. Earlier exercise: expand it (+1, maybe S) | Current exercise: 3. Earlier exercise: S to Completed, tap it (the card **and the CTA** switch to it), field, K, Done, then "Next: …" to get back = 5 + S. **A logged warm-up cannot be corrected**: it is filtered out | 3, on the page in view |
| 8 | Add an extra set (back-off or AMRAP) right after the last planned set | Auto-next has already collapsed the exercise: re-expand (S up + 1), then Add Set, then log. About 3 + S | Auto-next has already **moved the card to the next exercise** (`WorkoutTrackerPresenter.swift:442-443,491-503`): S down to Completed, tap the exercise, S to Add Set, Add Set, Log, then "Next:" back. About 4 + 2S | Swipe back one page, "+", then log: about 3 |
| 9 | See last week's numbers | The Prev column **defaulted to Auto**, so 1 tap on the header to switch to Last | **0 taps.** Last is now the default (`SetTrackerPresenter.swift:31`), with RIR under it. Also in Up Next ("Last 100 kg × 5") and the keyboard's "Last time" chip. But it is in caption type in a 78 pt column | 0 taps, at roughly body size, with RIR on a second line |
| 10 | See the program or exercise note | 0 taps, but caption and 2 lines in a collapsed header | 0 taps: the "Your note" box under the title (`ExerciseTrackerView.swift:119-121,134-146`). It pushes the set table down | 0 taps: a "Program Note" card **below** the table, so the rows never move |
| 11a | Start a rest without logging | Not possible | Not possible. The row's "Rest Timer" action only sets that set's duration (`SetTrackerRowView.swift:151-160`) | Unclear |
| 11b | Skip the rest | 1 tap, Skip on the pill | 1 tap on the CTA, in the thumb zone | 1 tap? (top right, hard to reach) |
| 11c | Extend the rest | 1 tap, +15s | 1 tap, +15s beside the CTA (`WorkoutTrackerView.swift:77-85`). No −15s | Unknown |
| 12 | Finish | 1 tap on Finish Workout, which appears when every set is logged, or "…" then Finish (2) | 1 tap on the CTA once every set is logged **and** the rest is over or skipped. **No confirmation** (`WorkoutTrackerPresenter+Finish.swift:64-65`). Finishing early is "…" then Finish (2) | Menu ≡, then Finish (about 2) |

### Net effect

- **The core loop is better in NEW when nothing is resting.** Task 1 is one tap in a fixed, thumb-zone
  position with the numbers read back on the button. That is the single best interaction in any of
  the three designs.
- **The core loop gets worse in NEW whenever a rest is running.** Lifters often start the next set
  before the timer ends, and in a superset they always do. The CTA's rest mode then turns
  "log next set" into two taps (tasks 1 and 5), and it hides what the next set is.
- **Anything off the happy path costs more in NEW.** Adding a set after the last one, fixing an
  earlier exercise, adding warm-ups, swapping an exercise and changing equipment all cost more
  (tasks 3, 7 and 8). The card-plus-CTA model is tuned for the planned linear path; deviations now
  cost a scroll and a context switch.

---

## 3. Glanceability at 60 cm

At 60 cm, 17 pt body text is comfortably readable. 12 pt caption and 11 pt caption2 need the phone
brought closer, especially in secondary grey and with tired eyes.

| Element | OLD | NEW | MF |
|---|---|---|---|
| What to do next | Not stated, so the user has to infer it | **CTA label at about body semibold, white on accent, full width.** The best of the three | Not stated |
| Next set's numbers | Row fields at body size, 35 pt tall | Row fields as OLD, plus the CTA label. The current row has a tint and outlined fields (`SetTrackerRowView.swift:97-102,248-252`) | Large grey cells at roughly 22 pt |
| Rest countdown | **`metricLarge` (title, about 28 pt), the most glanceable** | CTA label at body size, plus the inline row at **caption** (`InlineRestTimerRow.swift:44-50`) | Title-ish "0:00", top right |
| Workout progress | `Stat .small` in the card, which scrolls away | **caption** ("7 of 18 working sets", `WorkoutTrackerView.swift:133-137`) over a thin bar | Underline on the thumbnails |
| Elapsed time | `Stat` in the card | **caption** in the nav bar (`WorkoutTrackerView.swift:155-160`) | Large, top left |
| Last time | caption | **caption, 78 pt column** (`SetTrackerRowView.swift:140,318-323`). RIR in **caption2** (`:414-416`) | Roughly body size, its own wide column |

The NEW design makes the action legible and the information small. The things a lifter glances at
between sets (time left resting, last time's numbers, how far through the workout they are) are
all in caption type. OLD's rest countdown was the one element sized for a glance, and NEW
downgraded it.

---

## 4. Thumb reach

On the 6.9" phone, one-handed, the easy zone is roughly the bottom 40% and the centre.

- **NEW, good.** Every frequent action (log, skip, +15s, finish) is the bottom CTA, the easiest
  spot on either phone. This is a real improvement over OLD's row circles, which drift up and down
  the screen as sections expand.
- **NEW, poor.** The card's "…" (Do Later, Swap, Warm-up, Equipment, Notes) sits on the title line
  near the top of the content area, about 200 pt from the top. That is a stretch on 6.1" and needs
  two hands on 6.9". The workout "…" (Pause, Finish early) is in the toolbar, the hardest zone.
  Up Next and Completed sit **below the fold**, so they cost a scroll, not a reach.
- **Row circles**, in all three designs, are on the right edge mid-screen. That suits the right
  hand and is a stretch for the left hand on 6.9".
- **MF.** The thumbnail strip (exercise switching) and the rest timer are both near the top, poor
  one-handed. The chips are about a third of the way down, which is fine. Its main affordance, the
  checkbox column, is mid-right like ours.

**Vertical budget, NEW on 6.1", first open of an exercise (estimated).** Status and nav (about
101) plus the progress header (about 40) take the top 141 pt. The CTA takes the bottom 94 pt.
That leaves about 609 pt of content. It is used by:

| Item | Height (pt) |
|---|---|
| Card header | 64 |
| Pinned note | 60 |
| Progression note (3 lines plus "Tap to dismiss") | 120 |
| Column headers | 44 |
| Five rows (2 warm-ups, 3 working) | 260 |
| Plate line | 44 |
| **Total** | **592** |

So **Add Set is off screen and Up Next is entirely below the fold** on a 6.1" phone, before any
rest row is inserted.

---

## 5. Error-proneness

Ordered by likelihood times cost.

1. **The CTA changes meaning under the thumb.** The label cycles Log, then Skip Rest, then Log
   next or Finish in the same 52 pt slot (`WorkoutTrackerView.swift:60-97`). Three hazards follow:
   - **Double-tap on Log:**
     - With a rest: Log, then Skip Rest. The rest is lost and the user may not notice.
     - Between warm-ups (no rest by rule, `RestDurationRules.swift:73-78`) or with rest timers
       off: **two sets logged**.
     - On the last set with `restBetweenExercises` off: **the workout finishes with no
       confirmation** (`WorkoutTrackerPresenter+Finish.swift:64-65`).
   - **The timer expiring under the thumb.** Reaching for "Skip Rest" at 0:01, the label flips to
     "Log set 3 · …" when `runningRestEnd` turns nil (`WorkoutTrackerPresenter+ActiveExercise.swift:197-199`),
     and **the set is logged before it is lifted.**
   - **Skip Rest then Finish.** After the last set, a double-tap on Skip Rest lands on "Finish
     Workout". Nothing in the screen guards against this.

   OLD had none of these: Finish appeared only once everything was logged, and the rest pill's
   buttons never turned into a log.
2. **Keyboard Done logs the set** (`SetKeyboardPresenter.swift:113-116`, then
   `SetTrackerRowPresenter.swift:304-309`). A lifter who sets the weight *before* lifting presses
   Done to close the keyboard and **logs a set they have not done**, which also starts a rest.
   The behaviour is the same as OLD, but NEW teaches "the button at the bottom logs", which makes
   the keyboard's Done more surprising. Done on an *upcoming* row logs that row out of order.
3. **One tap on a done check un-logs the set** (`SetTrackerRowPresenter.swift:71`), with no
   confirmation and no undo. It also cancels the running rest (`cancelRestIfUndone`,
   `WorkoutTrackerPresenter+ActiveExercise.swift:185-191`). The check is the 44 pt cell beside the
   50 pt reps field, which is exactly where a typo correction aims. The un-logged set becomes
   current again and the CTA rewinds.
4. **Full trailing swipe deletes a set** (`SetTrackerRowView.swift:103-105`, `allowsFullSwipe:
   true`), with no undo. It is the same as OLD, but more exposed in NEW because rows now carry a
   row background and a thumb scrolling the card can catch a diagonal swipe.
5. **One tap on an Up Next row hijacks the card and the CTA** (`WorkoutTrackerView.swift:239-240`,
   then `WorkoutTrackerPresenter+ActiveExercise.swift:33-40`). A stray tap while scrolling switches
   the current exercise. The next CTA tap then logs **set 1 of the wrong exercise**. The only cues
   are the card title and "Exercise n of m" in caption.
6. **Layout shifts above the current row.** Several things move the rows by 40 to 120 pt:
   - The progression note vanishes after the first working set (`ProgressionNote.swift`, gated at
     `WorkoutTrackerPresenter+ActiveExercise.swift:143-148`).
   - Logged warm-ups disappear (`SetTrackerView.swift:76`).
   - The rest row is inserted under the set (`SetTrackerView.swift:73-75,98-100`).
   - The plate line jumps to the next row (`SetTrackerRowView.swift:60-90`).

   CTA users are unaffected. Row-circle users (task 5, early log during rest) hit moving targets.
7. **MF's own risk** is accidental horizontal page swipes while working a row. The first screenshot
   shows a half-swiped page. NEW and OLD avoid this entirely, a point in their favour.

---

## 6. Discoverability of hidden actions

| Action | OLD | NEW | MF |
|---|---|---|---|
| Swap exercise | Visible chip | **"…" menu** (`SetTrackerView.swift:215-220`) | Visible chip |
| Warm-ups | Visible chip | **"…" menu** | Visible chip |
| Targets, Equipment, Split L/R, Superset | Visible chips (scrolling) | **"…" menu** | Visible chips (Targets) |
| Do Later | n/a | Card "…" **and** long-press on Up Next | n/a |
| Do Next | n/a | **Long-press only**. The row's hint says "Opens this exercise" and does not mention it (`WorkoutTrackerView.swift:254`) | n/a |
| Reorder | Drag (`onMove`) | Visible "Reorder" button (`WorkoutTrackerView.swift:203-214`). Good | Unknown |
| Mark a set as warm-up | Tap set number, then menu | Same (`SetTrackerRowView.swift:162-193`), unlabelled | Set-type letters W/F suggest a menu |
| Fill from last time | Tap the Prev value | Same (`SetTrackerRowView.swift:423-432`). Nothing signals that it is tappable | Unknown |
| Per-set rest | Swipe or long-press | Same | Unknown |
| Workout notes | Visible "Notes" stat | **Toolbar "…"** | ≡ menu |
| Pause | Toolbar "…" | Toolbar "…" | ≡ |

The redesign moved **six visible verbs into one overflow menu**. For Swap and Warm-up in particular
this is a regression against both OLD and MF. "Machine taken, swap to the cable version" is one of
the most common mid-workout deviations, and its natural home is a visible chip, as MF shows.

---

## 7. With the keyboard up

- **NEW hides the CTA and the rest CTA** while the keyboard is up (`WorkoutTrackerView.swift:61,87,101-106`).
  That is correct: OLD's pill and Finish button rode the `safeAreaInset` up over the row being
  edited. But NEW then shows **no rest countdown at all** unless the inline rest row (caption) is
  within the shrunken viewport.
- **Logging** is only through Done, and Done does not say it logs (see error 2). The keyboard's
  chips ("Last set", "Last time", "Target", `SetKeyboardPresenter.swift:255-269`) and stepper are
  good. They are the fastest correct way to change weight in any of the three designs.
- **Space.** The nav bar (54), progress header (40) and keyboard (keys plus chip row plus stepper
  plus plate strip, roughly 330 to 380) leave about 300 to 350 pt on 6.1". That is enough for the
  edited row plus about 3 others. The progress header earns its pinned space less here; it could
  collapse while editing.

---

## 8. Where NEW is less intuitive than OLD or MF

1. **Rest mode hijacks the CTA**, so the next set is no longer shown on the button and "log now"
   costs 2 taps (OLD: 1 on the row; MF: 1).
2. **Supersets.** The card swaps wholesale A to B to A, and the header's "Exercise 3 of 6" flips
   back and forth. Neither partner's next numbers are visible while doing the other. A full rest is
   injected between partners, so every round needs a Skip. OLD at least showed both headers, and
   MF's "SA" tile signals the grouping. Up Next rows carry no superset marker
   (`WorkoutTrackerView.swift:238-252`).
3. **Auto-advance on the last set** takes the exercise away exactly when a lifter decides "one
   more" or wants to check what they just did. Its rows are now in Completed below Up Next.
4. **Logged warm-ups vanish.** MF keeps the W rows, which reassures the lifter and lets them
   correct. NEW makes warm-up typos uncorrectable on this screen.
5. **Verbs are buried** (Swap, Warm-up, Targets, Equipment) in an overflow at the top of the card.
6. **Ambiguous CTA semantics.** One button with four meanings is a mode design, and mode errors
   follow (section 5, item 1). OLD and MF have one meaning per control.
7. **Rest is less glanceable** (caption and body against OLD's title-size countdown).
8. **Opening a completed exercise to fix it re-targets the CTA** to "Next: X", where X is the next
   exercise after *that* one with sets left (`ActiveWorkoutState.swift:154-165`). That is not
   necessarily the exercise the user was on.
9. **The Smart Progression note** is a large tinted card with "Tap to dismiss" (`ProgressionNote.swift:18-44`)
   placed *above* the sets. It is explanatory content in the most valuable space at the moment the
   lifter wants the numbers. At accessibility text sizes it can push the whole table below the fold.

## 9. Where NEW is better

1. **One-tap logging in a fixed, reachable place, with the numbers read back** ("Log set 2 · 115 kg
   × 5"). This removes visual search and confirms intent. It is better than both OLD and MF.
2. **A clear "you are here".** The tinted current row, its outlined fields, muted upcoming rows
   (`SetTrackerRowView.swift:97-102,242,248-252`) and "Next to log" for VoiceOver (`:192`). Neither
   OLD nor MF marks the current set.
3. **Whole-workout progress is always visible** and counts working sets only
   (`ActiveWorkoutState.swift:67-75`). MF has no equivalent.
4. **Up Next rows with the plan and last time** ("3 sets · 8–12 reps · Last 100 kg × 5",
   `ActiveWorkoutState.swift:219-239`) are far more informative than MF's image-only strip, which
   falls back to initials ("SA") for exercises without an image.
5. **Last is the default** with RIR. That fixes OLD's Auto default, which hid the most-asked
   question ("what did I do last time?").
6. **The plate line** under the current set, with a one-tap "Use 112.5 kg" fix
   (`SetTrackerRowView.swift:60-90`). Neither OLD nor MF has this inline.
7. **Explicit Reorder and Do Later**, a reasonable model for gym congestion that also moves
   superset groups together (`WorkoutTrackerPresenter+ActiveExercise.swift:52-97`).
8. **Keyboard handling.** The CTA steps aside instead of covering the row, and the "Finish
   Workout" CTA appears only when everything is logged.
9. **No horizontal paging**, so no accidental page swipes (MF's main error source).
10. **Less noise than OLD.** Volume, an exercise count and a notes stat no longer compete with the
    set table.

---

## 10. Ten highest-impact changes, ranked

Ranked by (frequency × severity) ÷ effort. Each entry gives the user problem, the change and the
trade-off.

**1. Make the CTA safe against morphing (double-tap, timer expiry, Finish).**
- *Problem.* The 52 pt slot cycles Log, Skip Rest, Log or Finish. A double-tap or a tap at 0:01
  logs an unlifted set, kills a rest or ends the workout, and Finish has no confirmation
  (`WorkoutTrackerView.swift:60-97`, `WorkoutTrackerPresenter+Finish.swift:64-65`).
- *Change.*
  - Ignore CTA taps for about 500 ms after its action changes, and cross-fade the label.
  - When a rest ends naturally, keep the expired state ("Rest done · Log set 3 · …") for about
    1 s before it becomes tappable.
  - Never let the CTA *become* Finish directly after another tap. Show "Review & Finish" with a
    confirmation sheet (time, sets, volume, notes field). That puts back the notes moment that
    menu-Finish has.
  - Add an "Undo log" toast for about 5 s after every log.
- *Trade-off.* Fast loggers feel a slight hitch. The toast briefly covers part of the table.

**2. While resting, make the CTA "Log next set" and demote Skip and +15s.**
- *Problem.* Most lifters start before the timer ends. In rest mode the CTA hides the next set and
  costs 2 taps (Skip, then Log) per set, and 3 per superset round.
- *Change.*
  - Keep the primary CTA as "Log set 3 · 115 kg × 5" throughout the rest. Logging early simply
    restarts the rest.
  - Put the countdown in a large `metric` / `metricLarge` strip directly above the CTA, with +15s,
    −15s and Skip as glass buttons on that strip. This is OLD's pill plus NEW's CTA.
- *Trade-off.* About 56 pt of extra bottom chrome while resting. "Skip" becomes a secondary tap
  rather than the primary one, so users who skip without logging (to change weight first) need one
  more glance.

**3. Make supersets superset-aware.**
- *Problem.* A full rest runs after A before B (`RestDurationRules.swift` has no superset rule). The
  card swaps wholesale, so the lifter loses sight of the partner. Up Next shows no grouping.
- *Change.*
  - No rest (or a configurable short transition) between partners, and the full rest after the
    last partner of the round.
  - Render the group as one card with A and B tables stacked, or an A|B segmented switcher, with
    the CTA alternating "Log A2 · …" and "Log B2 · …".
  - Tag partners in Up Next with the existing `Chip(..., tint: .superset)`.
- *Trade-off.* New rest-rule setting and test surface. A two-table card is taller, so on 6.1" it
  will scroll.

**4. Separate "close keyboard" from "log set".**
- *Problem.* Done silently logs the set and starts the rest (`SetKeyboardPresenter.swift:113-116`),
  so pre-set weight changes are logged as completed sets.
- *Change.* While the row is ready, label the prominent key "Log" ("Log ✓"), and add a plain
  keyboard-dismiss key (chevron down) that only closes. Never log an *upcoming* row from the
  keyboard: close only, or ask.
- *Trade-off.* One more key on a dense keypad. Existing users' muscle memory for Done changes, so
  ship it with a one-time tip.

**5. Don't yank the exercise away on its last set.**
- *Problem.* Auto-next moves the card the moment the last set is logged
  (`WorkoutTrackerPresenter.swift:442-443,491-503`). Adding a back-off or AMRAP set, or reviewing
  the set just done, now costs about 4 taps and 2 scrolls.
- *Change.* Stay on the finished exercise during its rest. Show a compact done summary with a
  visible "Add set" button, and set the CTA to "Next: Lunge · 60 kg × 10". Advance when the user
  taps it or when the rest ends.
- *Trade-off.* One more tap for users who want instant advance, unless the advance on rest end
  covers them. It conflicts with `exerciseAutoNext` as specified, so that setting's meaning
  changes.

**6. Bring the top two or three verbs back as visible chips.**
- *Problem.* Swap, Warm-up, Targets and Equipment moved into the card's "…"
  (`SetTrackerView.swift:144-237`), which is hidden and top-of-screen. MF and OLD both show them.
- *Change.* Add one chip row under the card title with **Swap, Warm-up and "Busy? Do later"**, and
  keep the rest in "…". Hide chips that do not apply (no Warm-up once warm-ups exist; Do Later
  only when `canDoLater`).
- *Trade-off.* About 44 pt of vertical space per card. Pair it with change 8 so the net height does
  not grow.

**7. Size what lifters glance at for 60 cm.**
- *Problem.* Rest time, last time, RIR, workout progress and elapsed time are caption or caption2
  (`InlineRestTimerRow.swift:44-50`, `SetTrackerRowView.swift:318-323,414-416`,
  `WorkoutTrackerView.swift:133-137,157-158`).
- *Change.*
  - The inline rest time and header counts at `metricSmall`.
  - The current row's weight and reps at `metric`.
  - "Last" at `rowDetail`, with the column widened from 78 pt by narrowing the 44 pt set column's
    padding.
  - Elapsed time out of the nav-bar caption and into the progress header at `metricSmall`.
- *Trade-off.* Rows get taller, so fewer are visible, and accessibility-size stacking has to be
  re-tuned. There is a risk of clipping in the 70/50 pt fields; test with 3-digit lb weights.

**8. Stop the table moving above the current set.**
- *Problem.* The progression note (120 pt) vanishes, logged warm-ups disappear, the rest row and
  the plate line move between rows, and the pinned note sits above the sets. Targets shift
  40–120 pt under the thumb. Warm-ups cannot be corrected.
- *Change.*
  - Keep logged warm-ups as compact done rows (still editable).
  - Shrink the progression note to one line ("+2.5 kg · hit 5×5 last time ⓘ") in the column
    header area, expandable on tap.
  - Move the pinned and session notes **below** the table, as MF does.
  - Reserve the rest-row slot so its appearance does not reflow the table.
- *Trade-off.* Rows get slightly longer. The progression explanation is less prominent, which
  matters if the team needs users to notice smart progression.

**9. Make destructive and undo gestures deliberate.**
- *Problem.* One tap on a done check un-logs and cancels the rest (`SetTrackerRowPresenter.swift:71`).
  A full trailing swipe deletes a set with no undo (`SetTrackerRowView.swift:103-105`). A stray tap
  on an Up Next row retargets the CTA (`WorkoutTrackerView.swift:239-240`).
- *Change.*
  - On a done set, the check opens a small menu (Unlog, Edit) or needs a long press.
  - Set `allowsFullSwipe: false` for logged sets and add an undo toast for delete.
  - When an Up Next tap switches away from an exercise with a set in progress, show a brief
    banner "Switched to Lunge · Back to Bench" with one-tap return.
- *Trade-off.* Intentional un-logs get slower. A banner adds transient chrome.

**10. One-handed, discoverable exercise switching, and correct "return to where I was".**
- *Problem.*
  - Up Next is below the fold on 6.1".
  - Do Next is long-press only and does not open the exercise anyway.
  - Opening a completed exercise sends "Next:" to the wrong place (`ActiveWorkoutState.swift:154-165`).
- *Change.*
  - Add leading and trailing **swipe actions** on Up Next rows ("Do now", "Do later") alongside
    the context menu, with "Do now" = move it next **and** open it.
  - Make the progress header tappable to open a compact exercise-jump sheet, a bottom sheet in the
    thumb zone rather than MF's top strip.
  - Track the exercise the user was on, and make "Next:" after a correction return to it.
- *Trade-off.* Swipe actions on Up Next conflict with nothing today but add gesture surface. The
  jump sheet duplicates the list, so keep it as an accelerator rather than a second navigation
  model.

**Considered and left out of the top 10:**
- A manual "Start rest" without logging (low frequency).
- −15s (folded into change 2).
- Collapsing the progress header while the keyboard is up (minor gain).
- Restoring workout volume on the live screen (low decision value mid-set).

---

## 11. Validating this (suggested study)

- **Method.** In-gym moderated usability test, 8 lifters (mixed: 4 intermediate, 2 novice, 2
  advanced who superset; at least 2 left-handed; one 6.1" and one 6.9" device). Each runs a
  scripted 5-exercise session on OLD and NEW, counterbalanced, plus think-aloud between sets.
- **Measures.**
  - Taps per logged set, from Mixpanel `setCompleted.source` (row, keyboard or log_button,
    already instrumented).
  - Unintended actions: un-logs within 10 s, rest skipped within 1 s of a log, finish within 2 s
    of Skip Rest, set deleted then re-added.
  - Time to complete the deviations: machine-busy switch, extra set, earlier-set typo.
  - SEQ after each task, SUS at the end.
- **Analytics to add before the test.**
  - Time from log to the next CTA tap (under 600 ms suggests a double-tap).
  - Keyboard-Done logs followed by an un-log within 60 s (premature log).
  - Exercise-switch taps followed within 5 s by a log on the new exercise and then an un-log
    (wrong-exercise log).
- **Accessibility pass.**
  - VoiceOver: confirm that the CTA's label changes are announced, not just updated silently.
  - AX5 text size: verify the progression note and pinned note do not push the first set row off
    screen.
  - Reduce Motion with layout shifts.
  - Left-handed reach on the 6.9" phone.
