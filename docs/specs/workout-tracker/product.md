# Live workout logging: MacroFactor vs Compound's card-plus-lists tracker

Author: Alex (PM) · 6 Oct 2026 · Status: analysis, no code changed

Sources read: the two MacroFactor screenshots (1320×2868, a 6.9" Pro Max), and in Compound:
`WorkoutTrackerView.swift`, `ActiveWorkoutState.swift`, `WorkoutTrackerPresenter+ActiveExercise.swift`,
`+Rest.swift`, `+Progression.swift`, `+Exercises.swift`, `ExerciseTrackerView.swift`,
`SetTrackerView.swift`, `SetTrackerRowView.swift`, `InlineRestTimerRow.swift`, `ProgressionNote.swift`.
Competitor notes are from product knowledge, not a fresh audit. Treat specific competitor details
as "about right", not verified against this month's builds.

---

## 0. MacroFactor's model, as shown

**Fixed chrome (does not move with the page)**
- **Top-left:** a hamburger (the full exercise list, presumably a sheet or drawer) and the
  elapsed clock `0:32:31`, h:mm:ss.
- **Top-right:** the rest timer. A stopwatch glyph, `0:00`, and an empty grey capsule track that
  fills while resting. When idle it still shows `0:00` and the empty track, so it holds that space
  for the whole session.
- **Thumbnail strip:** one square per exercise in session order. Photos where one exists, initials
  (`SA`) where not. It scrolls horizontally and runs off the right edge (7+ exercises). Under each
  thumbnail is a bar: black under the current exercise, light grey under the rest. Nothing has been
  logged in either shot, so from these alone I can't tell whether the bar marks selection or fills
  with sets done. The likely design is both: it fills with progress, and the current one is drawn
  bold. That needs checking against a mid-session screenshot.

**Paged content (one exercise per horizontal page)**
Screenshot 1 is caught mid-swipe. The T-Bar Row page is sliding off to the left and "Wide Grip
Cable R…" is coming in. The title, chips, table and note all move as one page, and the chrome stays
put. So the page is the whole exercise.

Per page, top to bottom:
1. **Name**, wrapping to two lines, then **"Set 1 of 3"**. That counts working sets only: there
   are 2 W rows and 3 working rows (1, 2, F). The next exercise shows "Set 1 of 2".
2. **Chips row**, scrolling horizontally: an unlabelled wand (smart progression / auto-fill), **Info**
   (bar-chart glyph: history and charts), **Warm Up** (generate or edit warm-ups), **Targets**
   (reps, load and RIR prescription), **Swap**. The row overflows the screen edge, so Swap is
   partly clipped. Every exercise action is one tap away.
3. **Table:** `Set | Previous ⇄ | kg | Reps | ☐`.
   - **Set column:** circular badges. **W** = warm-up, **1, 2** = working sets, **F** =
     failure/final set (a set *type*, not a number), and **+** to add a set.
   - **Previous:** the matched set from last time, "50 kg x 11" over "3 RIR". Warm-ups and the F
     set read "No Previous", so sets are matched by type and position, not by row index. Last time
     had two working sets and no F, and the F row doesn't borrow set 2's numbers. The `⇄` toggles
     the reference, most likely previous session against best or target. It's the same idea as
     Compound's Last/Auto chip.
   - **kg and Reps:** large grey filled cells, pre-filled, so today's plan is already entered. The
     next exercise's Previous shows "100 lb", so units are per exercise.
   - **Checkbox per row, plus one in the header.** The header one is almost certainly "complete
     all", which is risky on a live log.
4. **Red badge on the Reps cell, values 1, 1, 0 on sets 1, 2, F.** My reading: this is the
   **target RIR for today's set**. The reasons:
   - The F (failure) set carries **0**, which is exactly what "to failure" means in RIR.
   - Warm-ups carry no badge, and warm-ups have no effort target.
   - A change or notification count would never be drawn as "0". A zero badge only makes sense as a
     *value*.
   - It sits on Reps because RIR qualifies reps ("11, leaving 1 in the tank").
   - It pairs with the Previous column's achieved RIR (3, 2): last time you left 3 and 2, and today
     the target is 1 and 1, then 0.

   The alternative, a "this cell changed" marker, doesn't explain the 0. The **red** is a
   mistake: on iOS red means error or unread count, it competes with the content, and it hides the
   meaning ("1" what?).
5. **Program Note card** with a pin. It's a coach or program instruction ("Flare elbows out at
   roughly 45°…") and sits below the table. The pin suggests the user can pin it to show on every
   session or make it their own.

**What is absent:** there's no bottom call to action, logging happens only through the
checkboxes, nothing shows what's next beyond the strip's photos, nothing marks supersets, and
there's no plate guidance on screen.

---

## 1. What MacroFactor gets right, and why (information architecture)

1. **Clear spatial hierarchy.** Session-level state (clock, rest, where am I) is fixed. Exercise-level
   state (name, actions, sets, note) is one unit that moves together. The user always knows which
   level a control acts on. The rest timer never scrolls away, and the chips never mean another
   exercise.
2. **One exercise owns the screen.** On a Pro Max the whole exercise (5 rows, chips, note) fits
   without scrolling, with room to spare. The focus model matches the physical one: you are at one
   station.
3. **The strip gives a map plus random access in one control.** Photos are faster to recognise
   than names mid-set: you know the T-bar row by its shape. The underline turns the strip into a
   progress indicator. It answers "how far through am I" and "jump to X" without a second screen.
4. **Exercise actions are first-class.** Warm Up, Targets and Swap are one tap. Swap matters most
   in a busy commercial gym. Putting it in a chip rather than a menu is a statement that it's
   expected, not exceptional.
5. **Set *types* are a column, not a property hidden in a menu.** W and F tell you the role of the
   set before you read a number. Matching Previous by type ("No Previous" on the new F set) keeps
   the comparison honest.
6. **Plan, last time and effort target sit on one row.** Previous (what you did, with RIR), the
   pre-filled cells (what to do) and the badge (how hard) all read left to right. It's the most
   decision-dense row in the category, and it answers "what should I lift and how hard" without a tap.
7. **Working-set counting.** "Set 1 of 3" ignores warm-ups, which is the number lifters
   actually track. Compound's header made the same call for the same reason.
8. **The program note stays visible.** Technique cues live with the exercise, not in a sheet.

## 2. Weaknesses and lifter problems it leaves unsolved

1. **Supersets fight the pager.** A superset is A1 → B1 → A2 → B2 across two exercises. With one
   exercise per page that means a swipe between every set, plus remembering which side you're on.
   Nothing in the screenshots marks a superset at all. A design that's elegant for straight sets
   gets worse the moment you pair exercises, and pairing is what time-pressed hypertrophy lifters do.
2. **No session overview beyond pictures.** The strip shows *that* there are 8 exercises, not
   sets left, last time's top set, or what's done. The text list is behind the hamburger: hidden,
   top-left, and a modal context switch. "How much is left, can I finish in 20 minutes?" takes
   several swipes or a menu.
3. **Reach.** On a 6.9" phone held one-handed, the rest timer (top-right), hamburger (top-left),
   strip and chips are all in the hardest zone. The most frequent mid-set actions are skip rest,
   add time and jump exercise, and they're the furthest from the thumb. There's no bottom action
   at all, while the bottom 15% of the screen is empty.
4. **The idle rest timer wastes prime space.** `0:00` plus an empty track sits there for the
   whole session. While resting, the useful content would be the countdown and *what's next*,
   and only the countdown is shown.
5. **Discoverability of the swipe.** Nothing on the page tells you that swiping moves between
   exercises, apart from the strip. Horizontal paging also collides with horizontal gestures inside
   the page: the chips row scrolls horizontally, and any row swipe (delete set) would fight the
   pager. That's probably why MacroFactor has no row swipe, so delete is elsewhere.
6. **Reordering on the fly.** "Squat rack taken, do the next thing" has no visible affordance. With
   a pager, order is spatial, so changing it means a separate edit mode.
7. **Logging is just a checkbox.** Nothing confirms *what* was logged, and nothing asks for RIR at
   the moment it's known. The badge sets the target, but there's no capture of the achieved
   effort, so the progression model is guessing.
8. **Unlabelled controls and an ambiguous badge.** An icon-only wand chip, a `⇄` with unclear
   meaning, and a red number with no unit. A new user can't tell what any of the three does.
9. **No loading help.** It gives the weight but not the plates, and doesn't say "add 2.5 a side
   from your last set". Mental maths is the friction between sets.
10. **Accessibility.** One-page-per-exercise pagers are weak under VoiceOver (page announcements,
    swipe conflicts) and at accessibility text sizes, where a 4-column table on a fixed page has
    nowhere to go.

## 3. Point-by-point: MacroFactor vs Compound's card-plus-lists

| Dimension | MacroFactor | Compound (new) | Edge |
|---|---|---|---|
| Container | Horizontal pager, one exercise per page | Vertical `List`: current-exercise card, then Up Next, Completed, Add Exercise | Compound for overview and reordering; MF for focus |
| Session overview | Photo strip with underline, plus a hidden list | Up Next rows with summaries ("3 sets · 8–12 reps · Last 100 kg × 5") and a Completed section with today's top set | **Compound**, clearly, though it sits below the card's fold on long tables |
| Progress | "Set 1 of 3" per exercise; strip underline | Top bar: one thin bar, "X of Y working sets · Exercise n of m" | Tie. MF's is spatial, Compound's numeric. Neither shows *per-exercise* progress at a glance |
| Moving between exercises | Swipe or tap a thumbnail | Tap an Up Next row; bottom CTA "Next: X" when the card is done | Compound: explicit, thumb-zone |
| Reordering | Not visible | Do Next / Do Later (context menu, card menu), Reorder with drag handles; supersets move as a group | **Compound** |
| Exercise actions | Chips: wand, Info, Warm Up, Targets, Swap | All in the card's `…` menu: Note, Do Later, Equipment, Warmup, Split L/R, Targets, Swap, Superset, Settings, Delete | **MF.** Compound puts Swap and Warm-up behind two taps |
| Set table | Set, Previous⇄, kg, Reps, ☐ | Set, Last/Auto chip, kg menu, Reps, Done. Same shape | Tie. Compound adds the unit menu in the header and stacked rows at accessibility sizes |
| Set types | W, numbers, F; set-type matching for Previous | W (tinted), numbers, 1L/1R for split pairs; side-matched Previous | Compound on L/R; MF on F and drop types |
| Warm-ups | Inline W rows, stay visible | Inline W rows, **hidden once logged** | Compound: less noise as the session moves on |
| Effort | Previous shows achieved RIR; red badge = target RIR | Last shows achieved RIR (from RPE); no visible effort *target* per row | **MF** |
| Plan pre-fill | Cells pre-filled | Cells pre-filled by smart progression; Auto column shows suggestions; live re-suggestion after each set (opt-in) | Compound in capability, but the live rewrite is **silent** |
| Why the numbers | Nothing explains them | `ProgressionNote`: "+2.5 kg today. You hit 5 reps on every working set last time.", tap to dismiss | **Compound**, though the card costs space and a tap |
| Logging | Row checkbox | Row Done **and** a bottom CTA "Log set 2 · 115 kg × 5", one code path | **Compound**: confirms what is being logged, in the thumb zone |
| Rest timer | Fixed top-right, idle `0:00` shown always | Inline row under the set it follows (bar + "Rest: 1:27/1:30" then "Ready"); CTA becomes "Skip Rest 1:23" + "+15s"; Live Activity / Dynamic Island | **Compound**: thumb zone, contextual, gone when idle |
| Elapsed clock | Top-left, large | Nav title subtitle, "Mon 6 Oct · 32:31", paused time excluded | MF more legible; Compound more honest (pauses) |
| Plates | None | Plate summary under the current row, with a "nearest makeable weight" fix | **Compound** |
| Supersets | Not shown | "Superset A" chip on the card; moves as a group; rest anchors to the top after a partner. **But** `ActiveWorkout.primaryAction` stays on the card's exercise until its sets run out, so the CTA does not alternate A→B | Neither solves it. Compound is closer |
| Notes | Program Note card, pin | "Your note" (pinned, neutral fill) plus the session note in the card header; previous note shown as a hint when writing | Compound has more, MF's sits better (below the sets) |
| Reach | Key controls at the top | Key actions at the bottom (CTA, Skip, +15s); exercise actions top of card | **Compound** |
| Accessibility | Pager, fixed columns | Stacked rows at accessibility sizes, 44 pt targets, header traits, contrast notes in code | **Compound** |
| Discoverability | Swipe implicit | Long-press menus (Do Next/Later) and swipe-to-delete set are implicit too, but mirrored in menus | Compound slightly |

**Net:** Compound already beats MacroFactor on overview, reach, logging confidence, rest, plates and
explanation. MacroFactor beats Compound on **one-tap exercise actions**, **visible effort targets**
and the **at-a-glance spatial map**. Neither handles supersets as a first-class flow.

## 4. Ten ideas to make Compound's tracker better than MacroFactor's

Each has: the capability it builds on, the user problem, the interaction, and the risk.

### 1. Superset cards that alternate
- **Capability:** `supersetGroupId`, `movingGroup` (already moves pairs as one),
  `RestAnchor.top` after a partner, `RestDurationRules`.
- **Problem:** in a superset the lifter does A1, B1, rest, A2. Today the CTA keeps offering A's next
  set, so the lifter has to tap B in Up Next each round. MacroFactor makes it worse (a swipe per set).
- **Interaction:** a superset is **one card** with both exercises' rows interleaved (A1, B1, A2,
  B2), each row labelled with its letter in the superset tint. `primaryAction` walks the
  interleaved order. Rest starts only after the last member of a round, and a short transition
  rest (or none) applies between partners, per `RestDurationRules`. The Live Activity says
  "Next: B1 · Cable Fly 20 kg × 12".
- **Risk:** column widths when partners use different tracking modes or units (row-level units
  fix that). Circuits of 3+ make the card long. The change is to `primaryAction`, which is
  well-tested pure code, so do it there first and render second.

### 2. Make every progression change visible in the cell, not in a banner
- **Capability:** `progressionSuggestions`, `progressionBaseline`, `ProgressionSuggestion.rationale`,
  `applyLiveProgression` (which currently rewrites remaining sets **silently**).
- **Problem:** the `ProgressionNote` card costs ~100 pt and a "Tap to dismiss", and it only
  explains the *first* change. When live progression lowers set 3 after a grinder on set 2, nothing
  says so, and the lifter thinks they mistyped.
- **Interaction:** a small **neutral** delta mark on any cell the engine set differently from last
  time (`+2.5`, `−1`), in the accent or secondary colour, never red. Tapping the mark shows the
  reason in a popover, using the same sentence `ActiveWorkout.progressionReason` already builds.
  When live progression rewrites a set, that cell flashes once and gains the mark, with the reason
  "Adjusted after set 2: 9 reps at RIR 0". Once marks exist, retire the banner or reduce it to one
  line.
- **Risk:** marks become noise on every row of a progressing program. Show them only where today
  differs from last time, and drop them once the lifter has edited the cell (the baseline check
  already detects that).

### 3. Effort target on the row, effort capture on log
- **Capability:** sets carry `rpe`; `EffortScale.rir(fromRPE:)`; the Last column already shows
  achieved RIR; set targets drive the engine.
- **Problem:** MacroFactor shows the target RIR but never captures the achieved one at the moment
  it's known. Compound shows last time's RIR but not today's target. The progression engine is
  only as good as its effort data.
- **Interaction:** the reps cell reads "8 @2" (a quiet suffix, labelled "2 in reserve" for
  VoiceOver) when the program or mesocycle week sets an effort target. After Log, the CTA briefly
  becomes a **one-row RIR picker** (0, 1, 2, 3, 4+) preselected to the target, which commits on
  the next tap or after 3 s. It's a setting, off for users who don't track effort.
- **Risk:** a tap per set is real friction, which is why Juggernaut-style per-set questionnaires
  feel slow. Mitigate with the default plus auto-commit, and measure the opt-out rate. Check that
  `SetTarget` can carry an RIR before promising this; if it can't, that's a model change.

### 4. Loading instructions, not just plate totals
- **Capability:** `PlateCalculator`, gym profiles (bar weight, plates owned), the plate summary on
  the current row, `nearestKg` correction.
- **Problem:** between sets the lifter thinks "I'm at 100, next is 102.5, what do I add?". The
  total plate list for 102.5 makes them re-derive the change.
- **Interaction:** on the current row, when the previous set's weight differs, the plates line
  reads as the **change**: "Add 1.25 each side" or "Strip to 20 + 10". Otherwise it reads as the
  full load. The same line goes on the Live Activity during rest, so you load the bar without
  unlocking the phone.
- **Risk:** wrong for machines, dumbbells and stacks. Gate it on the exercise's equipment type and
  show it only for barbell and plate-loaded exercises. Fractional plates the gym lacks are already
  handled by `nearestKg`.

### 5. Rest is a preview of the next set
- **Capability:** inline rest row, Skip Rest / +15s CTA, Live Activity with lock-screen logging,
  `logTitle`.
- **Problem:** during rest, the useful question is "what's next, and do I need to change it?".
  MacroFactor shows a bare countdown top-right. Compound's CTA shows "Skip Rest 1:23", which hides
  the next set.
- **Interaction:** while resting, the CTA reads "Skip Rest · 1:23" with a second line, "Next: set 3
  · 100 kg × 8 @1". When rest ends, it flips to "Log set 3 · 100 kg × 8" with the rest-over haptic
  (already distinct: `.warning` against `.success`). The Live Activity carries the same two lines
  plus the plates line from idea 4.
- **Risk:** a two-line CTA at large type sizes. It already allows `lineLimit(2)`; test at AX sizes.
  Live Activity update budgets are fine because it updates on events, not every tick.

### 6. "Machine's taken": Do Later or Swap, from the gym profile
- **Capability:** Do Later / Do Next, gym profiles (equipment available), `equipmentVariations`,
  Swap, previous sessions per exercise template.
- **Problem:** the most common unplanned event in a commercial gym. MacroFactor has Swap in a chip
  but no "do it later". Compound has Do Later, but Swap is two taps deep in a menu.
- **Interaction:** promote **one** chip under the card header, "Busy?", which opens a compact
  sheet. Its top choice is "Do later" (keeps the plan). Below that come 2–3 swaps filtered to the
  **current gym profile's equipment** and the same movement pattern, each with *its own* last
  session ("Last: 32 kg × 10") so the weight isn't a guess.
- **Risk:** poor substitutions erode trust. Start with curated equivalence (equipment variations
  and same primary muscle), not ML. A swap also breaks the progression history for that slot, so
  say so in the sheet.

### 7. More depth on "last time", and how close you are to a PR
- **Capability:** `previousSessions(limit:)`, Epley e1RM (Swift, mirrored in `coach-maths.js`),
  `personalRecord` palette colour.
- **Problem:** "Last" is one session. A bad day last week makes it misleading, and lifters chase
  PRs, not last Tuesday.
- **Interaction:** long-press (and an accessibility action) on a Last cell shows the last 3
  sessions for that set and the best e1RM. When the row's current figures would set a rep PR or
  e1RM PR, a small trophy appears in the `personalRecord` tint *before* logging: "1 more rep is a
  PR". Logging it plays the PR haptic.
- **Risk:** pressure to grind reps against the RIR target. Show "PR at target RIR" only, not "PR
  if you go to failure", and make the indicator a setting.

### 8. One warm-up row, regenerated from the working weight
- **Capability:** smart warm-up generation, gym plates, logged warm-ups already hidden.
- **Problem:** MacroFactor shows two W rows per exercise. Across a session that's 15+ rows of
  low-value logging, and editing the working weight doesn't update them.
- **Interaction:** unlogged warm-ups collapse into **one row**, "Warm-up · 3 sets · 20 → 40 → 60
  kg", which expands on tap. Logging it logs them all, or the user expands to log each. Changing
  the first working set's weight regenerates any unlogged warm-ups, with plates from the gym
  profile.
- **Risk:** lifters who log each warm-up lose a step (expand). Regeneration must never touch a
  warm-up that has been logged or edited by hand, the same baseline rule progression uses.

### 9. Program context in one line
- **Capability:** `MesocycleManager`, `MacrocycleManager`, `MesocycleSchedule` (microcycle
  progress), deload rationale in progression.
- **Problem:** a lifter on a program can't see why today is RIR 1 rather than 3, or that next week
  is a deload. MacroFactor's Program Note is a free-text cue, not a plan.
- **Interaction:** under the card's title, one secondary line: "Week 3 of 5 · Target RIR 1 ·
  Deload next week". Tapping it opens the mesocycle. Ad-hoc workouts don't show the line.
- **Risk:** header height. It's one line, and it replaces rather than adds if the progression
  banner goes (idea 2).

### 10. Log the next set without the screen
- **Capability:** Live Activity already logs sets from the Lock Screen (the rest code handles "a
  rest started from the Lock Screen"); App Intents back it.
- **Problem:** chalky hands, the phone on the floor, gloves. Every competitor makes you look and
  tap.
- **Interaction:** expose "Log next set" as an App Intent bound to the **Action Button** and
  Control Center, plus the Live Activity. It logs exactly what the CTA would (`primaryAction`), at
  the planned figures, with the success haptic and a spoken confirmation if VoiceOver or Siri is
  active ("Set 3 logged, 100 by 8, rest 2 minutes").
- **Risk:** logging planned numbers that weren't actually hit. Mitigate with an undo in the Live
  Activity for 10 s and an "edited after Action Button" analytics flag to see how often it's wrong.
  Mac Catalyst has no Action Button, so exclude it like ActivityKit already is.

*Not on the list:* Strava. It's post-workout and already handled by the finish flow. Putting it on
the tracker would be scope creep.

## 5. Recommendation: the container model

**Keep card-plus-lists as the container. Do not adopt horizontal paging. Steal MacroFactor's map,
not its pager.** Confidence about 75%.

Reasoning:
1. **Paging breaks the things Compound already does well.**
   - Set rows swipe on both edges (delete, rest timer), which collides with a page swipe.
   - Up Next with Do Next / Do Later is the best answer in the category to a busy gym. A pager
     makes order spatial and reordering modal.
   - Supersets get worse, not better.
2. **The bottom-anchored flow beats MacroFactor on reach.** CTA, Skip Rest and +15s are already in
   the thumb zone. A pager would push navigation back into gestures and the top strip.
3. **Accessibility.** The List's stacked rows at accessibility sizes, section headers and menus are
   solid under VoiceOver. A pager gives that up for little gain.
4. **What paging really offers is a spatial map and focus, and both can be had cheaply:**
   - **Map:** replace the single `ProgressView` in `progressHeader` with a **segmented bar, one
     segment per exercise**, width ∝ working sets, fill = sets done, current one outlined, superset
     members joined. Tapping it opens a compact exercise menu (jump to). This is MacroFactor's strip
     without the photos or the top-of-screen tax, and it reuses the existing `Progress` model plus
     one more array. It's a small change.
   - **Focus:** the card already owns the top of the list. Make sure it's scrolled to the current
     row after each log so the table never pushes the active row below the CTA.
5. **The hybrid worth building is "card per *station*".** A straight set is one exercise and a
   superset is one card holding both (idea 1). That's the unit lifters think in, and neither
   MacroFactor's pager nor a pure list models it.

**What would change my mind:** if analytics show most exercise switches happen through Up Next
taps in strict order (not Do Later or out of order), and session-length interviews say lifters
find the Up Next list unused, a pager becomes cheaper to justify. Check `Event.exerciseSelected`
and `exerciseMoved` against `setCompleted` (source `row` vs `log_button`) before anyone builds one.

**Suggested sequence** (each is independently shippable, smallest first):
1. Segmented progress map (section 5, item 4).
2. Promote Swap and Warm-up to visible chips, or the single "Busy?" chip (idea 6). One-tap
   exercise actions are MacroFactor's clearest win over Compound today.
3. Superset alternation in `primaryAction` (idea 1, logic first).
4. Visible progression deltas, and retire the dismiss-to-read banner (idea 2).
5. Rest as a preview, plus a loading-change line (ideas 4 and 5).
6. Effort capture (idea 3), behind a setting, after checking `SetTarget` can carry an RIR target.

**Metrics to watch:**
- Median seconds from rest-over to set logged.
- Share of sets logged via the CTA, the row, or the Live Activity.
- Rate of edits to progression-filled cells (acceptance of suggestions).
- Do Later and Swap usage per session.
- Superset sessions: taps per round before and after idea 1.
