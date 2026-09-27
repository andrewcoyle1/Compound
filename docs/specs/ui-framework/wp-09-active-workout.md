# WP-09 · Migrate the active workout and session detail

**Wave 3. Size: large, and the most custom UI in the app.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Training/Subviews/WorkoutTracker/**`, including `ExerciseTracker`, `SetTracker`,
  `SetTrackerRow`, `SetKeyboard`, `WarmupSets` and `WorkoutNotes`
- `Core/Training/Subviews/WorkoutSessionDetail/**`
- `Components/Views/Training/SetDetailRow.swift`, which moves to `Core/Training/Components/`
  (coordinate: WP-10 moves the rest of `Components/Views/Training`)

**Care:** `SetKeyboardView` and `SetTrackerRowView` are the good examples of accessibility in the
app. Do not regress their labels, hints, reduce-motion handling or Dynamic Type caps.

## Specific issues

- **Finish Workout** (README decision 3, default yes). Move Finish out of the `line.3.horizontal`
  menu (`WorkoutTrackerView.swift:221-257`) into a visible `.confirmationAction` button labelled
  "Finish". The menu keeps Minimise and Delete.
  - The Minimise icon becomes `chevron.down` or `Symbol` equivalent; it is not `xmark`.
  - The presenter test covers the finish haptic.
- **Numeric entry.** Time and distance cells use tiny `.roundedBorder` `TextField`s
  (`SetTrackerRowView.swift:~274-305, ~403-455`). Move them onto `SetKeyboardView`, extending it
  with duration and distance modes if needed, so a set row has one input paradigm.
  - If that is too large, do it for distance only and report duration as a follow-up.
- **Stat displays.** The overview grid (`WorkoutTrackerView.swift:57`) and session detail's unused
  `StatCard` `headerSection` (`WorkoutSessionDetailView.swift:233`) both become `Stat`. Delete the
  unused section.
- **Warmup, superset and invalid set** each use their tokens (`warmup`, `superset`, `danger`).
  - The set Done column's "can't complete" state gets a symbol or accessibility value, not colour
    alone (`SetTrackerRowView.swift:285`).
  - The warmup "W" badge in history becomes a `Chip`.
- **"Edit" pills** in session detail (`:151,165,180`) become `Chip` buttons, or trailing
  `ListRow` `.value` + chevron.
- **Session detail wheel pickers and inline sheets** (`:93-125`) move to router sheets with
  presets.
- **The Notes grid cell** uses `.onTapGesture` (`WorkoutTrackerView.swift:104`). Make it a `Button`.
- **The tracker title** uses `.inlineLarge` and `.toolbarRole(.browser)`. Keep them only if they
  are deliberate for the full-screen cover; otherwise use the standard. Say which in the report.
- **Formatting.** Weights through `Format.weight(kg:unit:)` with the exercise's unit, and rep
  ranges through `Format.repRange` (en dash) everywhere.
