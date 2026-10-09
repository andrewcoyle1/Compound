# Set input on the live workout tracker: the full input-model space, scored

Read-only study of the working tree on `feature/workout-tracker-redesign` (uncommitted), 6 Oct 2026.
No files were edited. HIG pages checked live: `steppers`, `undo-and-redo`. Competitor
behaviour is from memory; confidence is marked on every claim.

---

## 1. What exists today

| Piece | File | What it does |
|---|---|---|
| Keypad | `SetKeyboard/SetKeyboardView.swift` | Custom `UIInputView` (via `SetKeyboardTextField`, a `UITextField` with `inputView`). 4×4 grid, 46 pt scaled keys, input clicks. Weight: chips (Last set / Last time / Target), a −/+ stepper row, a Plates toggle. Reps: chips (Last set / Min / Max) and, when `rirTracking` is on, nine RPE chips 6–10. Next/Prev/Done. |
| Keypad state | `SetKeyboard/SetKeyboardPresenter.swift` | Edits a `Binding<WorkoutSetModel>` live on every key. The first key replaces the value. **`done()` calls `onOfferCompletion`, which logs the set if it is ready** (decision 5d in `docs/reviews/hig-decisions.md`). |
| Steps | `Managers/Training/GymProfile/Loading/WeightStepper.swift` | `WeightStep` per exercise and gym: `.increment` (plate pair, pin, cable), `.list` (dumbbells, fixed bars), `.bands`. Pure and tested. Also what prefill, warm-ups and progression round to (`WeightRoundingRule`). |
| Plates | `Managers/Training/GymProfile/Loading/PlateCalculator.swift` | Per-side load and the nearest loadable totals. |
| Row | `SetTrackerRowView.swift` | Set # menu · Prev (tap fills) or Auto (tap fills) · weight 70 pt · reps 50 pt · Done circle (44 pt). Fields are 35 pt tall. Current row is tinted and shows a plates line, tap to snap to the nearest loadable weight. **Trailing swipe = delete with `allowsFullSwipe: true`, no undo.** Leading swipe = rest picker. Context menu has both. |
| Footer | `WorkoutTrackerView.swift` `.bottomCTA` | One `CallToActionButton`: "Log set 2 · 115 kg × 5" (`ActiveWorkout.logTitle`). **Hidden while the keypad is up** (`!isKeyboardVisible`). **Replaced by Skip Rest / +15s while a rest runs.** |
| Log path | `WorkoutTrackerPresenter+ActiveExercise.swift` `logSet` | The single path for footer, row circle and keypad Done: validate → `completedAt` → `.success` haptic → rest → live progression. |
| Prefill | `WorkoutSessionModel+Prefill.swift` | Smart progression, else last session, per field; weight rounded to equipment. **`rpe` is not prefilled.** |
| Live Activity | `WorkoutSessionActivity/LiveActivityPhaseViews.swift`, `Shared/LiveActivityIntentHandling.swift` | `CompleteSetIntent` logs the target set; during rest a "correction window" shows "Logged 100 kg × 8" with reps −/+ (`AdjustLastSetRepsIntent`). No weight change, no RIR. |
| Undo | — | Tap the green circle again un-logs (and `cancelRestIfUndone` cancels the rest). No `UndoManager`, no shake, nothing for delete. |

Because the rows are prefilled, the common case is already **one tap**. Every model below is
judged mainly on the less common cases and on mistakes, not on that one.

### Current tap counts (measured from the code)

| Case | Taps | Path |
|---|---|---|
| C: numbers right, log | **1** | footer Log, or row circle |
| W: +1 plate pair, log | **3** | weight cell → `+` → Done (logs) |
| R: reps −1, log | **3** (4 for 9→10) | reps cell → digit(s) → Done (logs) |
| Typed weight 100→102.5, log | 7 | cell → `1 0 2 . 5` → Done |
| RIR, log | 4–5 | reps cell → RPE chip → Done (+Next if starting on weight) |
| Log while rest still running | 2 | Skip Rest → Log (or 1 via the small circle) |

### Problems the code shows

1. **Done logs the set before it is lifted.** A lifter loading the bar adjusts weight during the
   rest and taps Done to close the keypad: the set is logged unlifted and the rest timer restarts.
   The only non-logging dismissal is tapping elsewhere (`textFieldDidEndEditing` → `close()`).
2. **Effort is asked before the set exists.** RPE chips live in the reps keypad, so RIR is entered
   pre-log or by re-opening a logged row. Effort is an *outcome*; it can only be known after.
3. **The log button disappears when it is most wanted**, while the keypad is up, and is swapped
   for Skip Rest while resting, so an early start costs two taps.
4. **Full-swipe delete with no undo** on a sweaty-thumb, scrolling list.
5. Fields are 70×35 / 50×35 mid-screen; the stepper is only discoverable after opening a field.
6. Focus lives in a `UITextField` inside a `List` cell; a recycled cell can drop first responder.
   Each row owns its own `SetKeyboardInputHost`.

---

## 2. The model that shapes everything: inputs vs outcomes

A set has two kinds of numbers, and they are known at different times:

| Number | Kind | Known | Best edited |
|---|---|---|---|
| Weight | **input** (you load it) | before the set, during the rest | pre-log, in steps of what the bar/rack allows |
| Reps | **target before, outcome after** | prefilled target; actual after | log the target, correct after |
| RIR / RPE | **outcome** | only after | post-log, optional, one tap |
| Rest | consequence | after | automatic; adjust in the rest row |

So: **change weight before, confirm with one tap, correct reps and add effort after.** That
mirrors the Live Activity, which already logs first and corrects reps in the rest window.

---

## 3. Every option, scored

Scales are 1–5, 5 best. "Cost" 5 = cheapest here. Tap counts include the log tap.
C = numbers right; W = +1 plate step; R = reps ±1.

| # | Model | C | W | R | Errors | Sweaty / 1-hand | Discover | A11y | Cost | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| a | Current custom keypad per cell | 1 | 3 | 3–4 | 3 | 3 | 3 | 4 | 5 | Keep as the *typing* path only |
| b | System `.decimalPad` + keyboard toolbar | 1 | 5–7 | 3–4 | 2 | 2 | 4 | 5 | 3 | Reject: a regression |
| c | −/+ steppers on cells (current row only) | 1 | 2 | 2 | 3 | 3 | 5 | 4 | 4 | Good idea, wrong place |
| d | Wheel / drum picker | 1 | 2 | 2 | 2 | 2 | 4 | 4 | 3 | Reject |
| e | Horizontal scrub on the cell | 1 | 2 | 2 | 2 | 2 | 1 | 2 | 3 | Reject |
| f | Swipe row right to log / left to delete | 1 | — | — | 2 | 3 | 2 | 3 | 5 | Reject as log; fix delete |
| g | Long-press Log for options | 1 | — | — | 4 | 4 | 1 | 4 | 5 | Accelerator, yes |
| h | "Same as last time" chip per row | 1 (2 if blank) | — | — | 4 | 3 | 2 | 4 | 5 | Already exists (Prev tap); restyle |
| i | Docked current-set bar (weight · reps · Log) | 1 | **2** | **2** | **4** | **5** | **5** | 4 | 2–3 | **Core of the recommendation** |
| j | Voice ("100 for 8") | 1 press + speech | same | same | 1 | 4 | 2 | 4 | 1 | Reject; Voice Control is free |
| k1 | Live Activity / Lock Screen (exists) | 1 | open app | 2 (post) | 3 | 4 | 3 | 4 | — | Keep; add RIR, undo |
| k2 | Action Button / Control widget | 1 press | — | — | 3 | **5** | 2 | 4 | 4 | Cheap add-on |
| k3 | Apple Watch app | 1 | 2 (Crown) | 2 | 4 | 5 | 3 | 4 | 1 | Later; no target exists |
| l | Hardware volume buttons | — | — | — | — | — | — | — | — | **Not allowed** |

### (a) Current keypad
- Strengths: real text field, so hardware keyboards, iPad and Mac work; VoiceOver labels;
  locale separator; replace-on-first-key; chips and plates in context; input clicks.
- Weaknesses: see §1. Three taps for the two most common edits; Done = log hazard; footer hidden.
- Keep it as the path for **typing an arbitrary value**, not as the path for small edits.

### (b) System `.decimalPad` / `.numberPad` + `.toolbar(placement: .keyboard)`
- A system field does not replace on first key unless text is selected, so a change is
  select/delete + type. No Next, no stepper unless rebuilt in the toolbar, no plates, no
  chips. The toolbar's targets are small. Locale separators were already a bug once (review #
  "decimal key shows '.' in all locales").
- Only advantage is familiarity and zero custom accessibility work, both of which (a) already has.

### (c) Steppers on each cell
- On every row it does not fit: set 44 + Prev 78 + weight 70 + reps 50 + Done 44 ≈ 286 pt plus
  spacing, against ~360 pt usable on a 402 pt iPhone 17. Four 44 pt buttons add 176 pt.
- On the current row only: fits if Prev collapses, but the controls are mid-screen, scroll with
  the list and sit beside the row's swipe actions, so mis-taps rise. HIG: a stepper must sit next
  to the value it changes and pairs with a field for large changes — satisfied either way.
- The stepper logic is already pure (`WeightStep.next/previous`), so the cost is layout only.

### (d) Wheel picker
- `.list` and bounded `.increment` steps give a finite value list, so it is buildable, but an
  unbounded barbell (`max: nil`) needs a synthetic range. Wheels overshoot under inertia, fight the
  List's vertical scroll, and are poor with wet fingers. Several wheels in a `List` hurt scroll
  performance. Accessible (adjustable) out of the box, which is its only win.

### (e) Horizontal scrub / slider on the cell
- Collides with the row's leading **and** trailing swipe actions and with list scrolling.
  Invisible. Needs detents with `.sensoryFeedback(.selection)` per step and an
  `accessibilityAdjustableAction` fallback, at which point the fallback *is* the stepper.
  Works on the Watch's Crown, not on glass.

### (f) Swipe-to-log
- The row already swipes both ways: trailing = delete (full swipe on), leading = rest picker.
  Making leading = log invites the mirror error (log vs delete) on a slippery thumb, and swiping
  logs whichever row is under the thumb, not the current set. Swipe actions do appear in
  VoiceOver's Actions rotor, so accessibility is acceptable, but as a primary path it is worse
  than a 1-tap button in the thumb zone.
- **Independent fix:** `allowsFullSwipe: false` on delete, or register delete with `UndoManager`.

### (g) Long-press Log for options
- `Menu { … } label: { … } primaryAction: { log() }` on the footer. Options: Log as failed /
  short (opens reps), Log and skip rest, Log with custom rest, Log all remaining at these numbers
  (straight sets). HIG: a hidden menu must not be the only way to do something — all of these
  exist elsewhere. Pure accelerator, ~30 lines.

### (h) "Same as last time" chip
- Prefill already did it, so C is 1 without the chip. It is useful only to *revert* after an
  edit, and that already exists: Prev and Auto columns fill on tap (`fillFromPrevious`). Its
  problem is discoverability: it looks like caption text. Give it a `Chip` look on the current
  row only. No new mechanism.

### (i) Docked current-set bar
- One bar in the bottom safe area, above the Log button:
  `Set 2 of 4 · [−] 100 kg [+] · [−] 8 reps [+]`, plate line under it, Log below.
- Tapping a value focuses the existing `SetKeyboardTextField` in the bar, so the existing keypad
  slides up as the input view and `safeAreaInset` content rides above it: the bar and the Log
  button stay visible while typing. Hardware keyboards keep working.
- Edits only the current set (the one `ActiveWorkout.primaryAction` points at). Tapping another
  row's value still opens the keypad on that row, as today, so corrections to old sets need no
  new path.
- Risks: vertical space on small phones (~150 pt with Log); must stack at accessibility sizes;
  duplicates the row's figures (acceptable: the row is the record, the bar is the editor, and
  the Log title already repeats them).

### (j) Voice
- iOS 26 `SpeechAnalyzer` / `SpeechTranscriber` can run on-device, but gyms are loud, many
  lifters wear headphones with music, "fifteen/fifty" and kg/lb are ambiguous, the parser needs
  Spanish too, and talking to a phone between sets is socially costly. App Shortcuts cannot put a
  free number in the spoken phrase; Siri asks a follow-up. Error cost is highest of all options.
- Motor-impaired users already get "Tap Log set", "Tap Increase weight" from **Voice Control**
  for free if every control is labelled. Invest in labels, not a speech parser.

### (k) Off-screen logging and what the phone must then show
- **Live Activity / Lock Screen / Dynamic Island (exists).** Complete logs without unlocking;
  rest starts; reps −/+ during rest. Missing: RIR (add 3–5 chips to the correction row,
  same intent pattern) and Undo (an intent that clears `completedAt` within the rest window).
  Weight changes belong in the app; the Lock Screen is for confirming.
- **Action Button and Control Center / Lock Screen control.** Expose the same completion as an
  `AppIntent` in an `AppShortcutsProvider` ("Log set in Compound") and a `ControlWidgetButton` in
  the widget extension. Pressing a physical button with chalked hands, phone in pocket or on the
  floor, is the best "sweaty" input there is. It logs blind, so the Live Activity's correction
  window is what makes it safe. Cost is low because `LiveActivityIntentHandling.completeSet`
  already does the work.
- **Apple Watch.** No watchOS target exists. The Crown is the ideal detented stepper with
  haptics, and Strong, Hevy and Fitbod all ship watch apps (medium confidence). It is a new
  target plus sync, so it is a separate project.
- **What the phone shows on return** (for any of the above): the set ticked with its time; the
  rest row counting from `completedAt` (already handled: "A rest started from the Lock Screen
  began when its set was logged there"); the correction row for that set (reps −/+, RIR, Undo);
  the bar already on the next set; and a one-line source note ("Logged from Lock Screen") so a
  set the user does not remember logging is explicable. The phone stays the single source of
  truth, per `docs/specs/live-activity.md`.

### (l) Hardware volume buttons: not allowed
- App Review Guideline 2.5.9: apps that "alter or disable the functions of standard switches,
  such as the Volume Up/Down and Ring/Silent switches" are rejected.
- There is no public API to intercept them. The known hack (KVO on
  `AVAudioSession.outputVolume` with a hidden `MPVolumeView`) actually changes the volume of the
  user's music on every log and is the pattern 2.5.9 targets.
- `AVCaptureEventInteraction` (iOS 17.2+) is the one sanctioned use, and only for camera capture
  with a running capture session; running a dummy session to log sets misuses it and lights the
  camera indicator. The sanctioned physical button is the **Action Button** (k2).

### (m) Haptic and sound choreography

Uses the existing `interactor.playHaptic(option:)` and `SoundEffectManager`; SwiftUI views can use
`.sensoryFeedback`.

| Event | Haptic | Sound | Notes |
|---|---|---|---|
| Stepper step (weight or reps) | `.selection` | input click | One per step; long-press repeat at ~8/s with a selection tick each |
| Stepper hits min/max or list end | `.warning`-light (rigid impact) | none | Tells the user the press did nothing |
| Weight becomes not-loadable | none on step; plate line turns warning | none | Avoid nagging mid-adjust |
| Keypad key | none | input click (exists) | System behaviour |
| Log set | `.success` (exists) | optional short tick via `SoundEffectManager`, off by default | One event, one haptic |
| Log a PR | `.success` then a second light impact | optional | Distinct, rare, earned |
| Validation refusal | `.error` (exists) + alert | none | |
| RIR chip | `.selection` | none | Post-log, non-blocking |
| Undo | `.warning` | none | Different from log so it is felt as a reversal |
| Rest over | `.warning` (exists) | existing | |
| Scrub detent (if e) | `.selection` per detent | none | |
| Swipe past full-swipe threshold (f) | medium impact (system) | none | |
| Action Button / Control | system press haptic | none | Live Activity updates as the confirmation |
| Voice (if j) | `.success` | spoken "Logged 100 for 8" | Only feedback that works with phone in pocket |

### (n) Undo model
- **Keep** the circle re-tap (it is the row's toggle and already cancels the rest).
- **Add** `UndoManager` registration for log, delete and edits from the bar, with action names
  ("Undo Log Set 2", "Undo Delete Set"). This brings shake, three-finger swipe and iPad/Mac ⌘Z
  free, and HIG says to describe the result in the shake alert. SwiftUI:
  `@Environment(\.undoManager)` in the view, passed to the presenter.
- **Add** an Undo in the post-log correction row for the duration of the rest. HIG prefers
  system undo gestures and says dedicated buttons belong in a toolbar; this is a deliberate,
  narrow departure (shake is unreliable mid-workout: it fires while walking with the phone and is
  undiscoverable), and it matches the Live Activity's correction window. Owner decision.
- **Do not** use swipe-to-undo; HIG: "avoid redefining standard gestures for undo and redo."
- **Fix** delete: `allowsFullSwipe: false` or undoable.

---

## 4. Effort (RIR) capture: in the row or after logging?

**After.** RIR is an outcome. Today it is in the reps keypad, which forces it to be entered
before the set exists or by re-opening a logged row.

Post-log flow: the inline rest row (`InlineRestTimerRow`) becomes the correction row while the
rest runs:

```
✓ Set 2 · 100 kg × 8         [−] [+]   Undo
  Reps in reserve   0   1   2   3   4+          Rest 1:12 / 2:00
```

- Shown only when `rirTracking` is on; optional; never blocks the next set. Five RIR chips map to
  RPE 10/9/8/7/6 via `EffortScale` (stored as `rpe`, as now). The nine half-step RPE chips stay in
  the keypad for anyone who wants them on a logged row.
- Disappears when the next set is logged or the rest ends and the user scrolls on.
- Same row on the Live Activity's resting phase (reps −/+ exists; add the chips as intents).
- Precedent: Juggernaut AI asks for RPE after each set to auto-regulate the next (medium
  confidence); RP Hypertrophy asks pump/soreness/joint/workload questions after each exercise, not
  per set (medium-high); Hevy keeps RPE as an optional per-set column opening a picker (medium).

---

## 5. How other apps do it (from memory; verify before quoting)

| App | Input model | Effort | Confidence |
|---|---|---|---|
| Strong | Table rows (Set · Previous · kg · Reps · ✓); custom keypad with −/+ step keys and Next; tap Previous to fill; auto rest timer; plate calculator; Watch app | RPE key on the keypad, per set, pre- or post-log | High on table/checkmark/Previous; medium on keypad details and plate calculator |
| Hevy | Same table; Previous fills; swipe to delete a set; Live Activity; Watch app with Crown adjust | Optional RPE column opening a picker sheet | Medium; unsure whether its keypad is custom or system |
| RP Hypertrophy | App prescribes load and rep target; you enter actual weight and reps per set, tick to log | Per-exercise feedback questionnaires (soreness before, pump/joint pain/workload after); RIR is prescribed per week, not logged per set | Medium-high |
| Juggernaut AI | Prescribed sets; after each set you confirm reps and rate RPE; next set's load auto-adjusts | Post-set RPE, central to the model | Medium |
| Alpha Progression | Prefilled from progression; custom input with steps; plate calculator | Per-set RIR, optional | Low |
| Fitbod | Prefilled sets; edit weight/reps per set; tick to log; Watch app | Mostly none per set | Low on the editor style; medium on the Watch app |
| Boostcamp | Program-prefilled rows, tick to log, fields edited by keypad | RPE/RIR column for programs that prescribe it | Low-medium |
| MacroFactor Workouts | Auto-progressed targets prefilled; one-tap log; equipment-aware increments | Post-set effort capture | **Low — unverified; check the app before citing** |

Common ground across the field: prefilled rows, a per-row tick, and "Previous" as a fill. Nobody
(to my knowledge) docks a single current-set editor in the thumb zone, which is the differentiator
the recommendation below adds without removing the table.

---

## 6. Ranked recommendation

1. **(i) Docked current-set bar** with **(c)** steppers inside it, paired with the keypad for typing.
2. **Post-log correction row**: reps −/+, RIR chips, Undo (fixes §1.2, makes blind logging safe).
3. **Done closes, Log logs**: the keypad never logs; the Log button is never hidden.
4. **(k2) Action Button / Control** + RIR and Undo on the **(k1) Live Activity**.
5. **(n)** `UndoManager` + non-full-swipe delete.
6. **(g)** Long-press Log menu; **(h)** restyle Prev/Auto fill as a chip on the current row.
7. Later: **(k3)** Watch app.
8. Reject: **(b)**, **(d)**, **(e)**, **(f)** as a log gesture, **(j)**, **(l)**.

### The combined model

```
┌ List ─────────────────────────────────────────────┐
│ Bench Press                                       │
│  ✓ 1   97.5 × 8                                   │
│  ✓ 2   100 × 8      [−][+] reps   Undo            │  ← correction row, during rest
│        RIR  0  1  2  3  4+        Rest 1:12/2:00  │
│ ▸ 3   100 × 8   (tinted current row)              │
│   4   100 × 8                                     │
└───────────────────────────────────────────────────┘
┌ bottom safe area ─────────────────────────────────┐
│ Set 3 of 4   [ − ]  100 kg  [ + ]   [ − ] 8 [ + ] │  ← tap a value to type (keypad slides up)
│ Per side: 20 + 15 kg                              │
│ [        Log set 3 · 100 kg × 8          ]  ⋯hold │
└───────────────────────────────────────────────────┘
```

### Exact tap counts

| Case | Today | Recommended |
|---|---|---|
| Numbers right, log | 1 | **1** |
| +1 plate step, log | 3 | **2** (`+`, Log) |
| +2 plate steps, log | 4 | 3 |
| Reps −1 (missed a rep) | 3 | **2** (Log, then `−` in correction row) — or `−`, Log |
| Reps +1 | 3–4 | **2** |
| RIR after the set | 4–5, pre-log | **+1**, post-log, optional |
| Typed weight 100 → 102.5 | 7 | 7 (tap value, 5 keys, Log) |
| Log while rest still running | 2 | **1** (Log ends the rest) |
| Undo a log | 1 (find the circle) | 1 (Undo in correction row, circle, or shake) |
| From pocket | Lock Screen Complete: 1 | 1 (Lock Screen or Action Button) |

### Behaviour changes this implies (owner decisions)

- **Reverses decision 5d** ("Done on the set keyboard logs the set"). With the Log button always
  visible above the keypad, Done only closes. This removes the premature-log hazard.
- **Log replaces Skip Rest as the footer's primary during rest.** Logging the next set ends the
  rest by definition. Skip and +15s move to the rest row (they are already in the Live Activity).
- **RPE chips leave the reps keypad's default view** in favour of post-log RIR chips. Keep them
  reachable when editing a logged row.

---

## 7. SwiftUI feasibility against this codebase

**Bar placement.** `bottomCTA` is `safeAreaInset(edge: .bottom)`; put the bar in the same inset
above `CallToActionButton`. Inset content rises above the keyboard (including a custom
`inputView`), so the bar and Log stay visible while the keypad is up. Delete the
`!isKeyboardVisible` conditions and the two `keyboardWill{Show,Hide}` observers.

**Binding the bar to the current set.** `primaryAction` already resolves `(exerciseId, setId)`.
Expose a `Binding<WorkoutSetModel>` on the tracker presenter whose setter calls the existing
`updateSet(_:in:)`. Same pattern as the rows' delegate binding; see the memory note on stale
bindings in routed sheets: use getter closures, not captured values.

**Steppers.** Reuse `WeightStepper.steps(for:profile:unit:)` and `WeightStep.next/previous`
unchanged. Bands cycle names (`band(after:forward:)`). Reps step by 1, floor 1. Long-press
auto-repeat: `Button` with `.buttonRepeatBehavior(.enabled)` (iOS 17+). Each value is one
accessibility element with `.accessibilityAdjustableAction` (VoiceOver swipe up/down = one plate)
and an `.accessibilityValue` like "100 kilograms, per side 20 plus 15".

**Typing.** Reuse `SetKeyboardTextField` + `SetKeyboardPresenter` + `SetKeyboardInputHost` in the
bar. One host for the bar instead of one per row is simpler and avoids first responder living in a
recycled `List` cell. Drop the keypad's own stepper row and Plates toggle when it is opened from
the bar (the bar shows both); keep them when it is opened from a row. `SetKeyboardPresenter.done()`
loses its `onOfferCompletion` call, and `offerCompletion` / `Event.keyboardOfferedCompletion` go
(update the funnel that reads that event).

**SwiftUI `@FocusState`** is not needed: focus is driven by the presenter's `activeField` through
`updateUIView`, which already works with Next/Prev. No change.

**Correction row.** Extend `InlineRestTimerRow` (it already sits under the set it follows, and
the presenter already has `ActiveWorkout.latestCompletedSet`). Reps −/+ write through `updateSet`
and should re-run `applyLiveProgression` so the remaining sets re-suggest; RIR writes `rpe` via
`EffortScale`. Undo calls the existing un-log path, which already cancels the rest.

**Undo.** `@Environment(\.undoManager)` in `WorkoutTrackerView`, handed to the presenter on
appear; register in `logSet`, delete and bar edits with `setActionName`. Coalesce consecutive
stepper presses on one value into one undo group (HIG: batch incremental adjustments).

**Long-press menu.** `Menu(primaryAction:)` around the footer label; check that
`CallToActionButton` styling survives inside a `Menu` label, or attach `.contextMenu` instead.

**Action Button / Control.** New `AppIntent` (not a `LiveActivityIntent`, so it can be run by
Shortcuts) whose `perform()` calls `LiveActivityIntentHandler.current?.completeSet(id:)` with the
current target; `AppShortcutsProvider` for Siri/Action Button; `ControlWidgetButton` in the
`WorkoutSessionActivity` extension. When the app is not running, the existing intent fallback
applies.

**Layout.** At accessibility sizes stack the bar (weight line, reps line, Log), matching how
`SetTrackerRowView` stacks. Tokens only: `ControlSize.row` (44 pt) minimum for −/+, `Spacing`,
`Radius`, `.monospacedDigit()`; the SwiftLint custom rules apply. Strings into
`Localizable.xcstrings` with Spanish.

**iPad / hardware keyboard.** `.keyboardShortcut(.return, modifiers: .command)` on Log, and
`.onKeyPress` (or the text field) for ↑/↓ = step weight. The decisions list already commits to
iPad shortcuts.

**Tests.** `SetKeyboardPresenterTests` cover Done → completion and will need updating; add
presenter tests for the bar binding, correction-row reps re-suggesting, and undo grouping. Run
`-only-testing:CompoundUnitTests/SetKeyboardPresenterTests` and `WorkoutTrackerPresenterTests`.

### Lazy order (smallest diff first)

1. `allowsFullSwipe: false` on delete. One line.
2. Keypad Done closes; footer stays visible above the keypad; Log ends a running rest. Small.
3. Correction row with reps −/+, RIR chips, Undo. Medium; biggest behavioural win.
4. The docked bar. Largest; do it once 1–3 have shown whether the keypad's 3-tap edits still hurt.
5. Action Button / Control, Live Activity RIR + Undo, `UndoManager`, long-press menu.

Skipped: Watch app, voice, wheels, scrub. Add the Watch app when off-phone logging proves popular
through the Action Button and Live Activity analytics (`source` on `SetTrackerRow_SetCompleted`
already distinguishes them).
