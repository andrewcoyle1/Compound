# WP-10 · Migrate the Training tab, library, templates and programs

**Wave 3. Size: large.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Training/**` except the WP-09 folders
- `Components/Views/Training/**` except `SetDetailRow.swift`. These move to
  `Core/Training/Components/`: `ExerciseListBuilder`, `WorkoutListBuilder`, `TrainingProgram`,
  `WorkoutTemplate`, `TrainingAccessory`, `TodaysWorkoutCard`, `WorkoutStreakCard`.
- `Components/Views/CalendarHeader/**`, which stays in `Components` because it is generic
  (token-ise only)
- `Components/Views/EnumPicker/`

## Specific issues

- **Training tab empty state.** `TrainingView.swift:70-95` is a hand-built copy of the deleted
  `EmptyState`. Replace it with `ContentUnavailableView` and an action.
- **The "More" rows** on the Training tab are `Label` + `.anyButton` without chevrons. Make them
  `ListRowButton`.
- **Section-header "+" buttons** are styled four ways. Use one: a `.glass` circle button in the
  header, or a toolbar `plus` when it is the screen's main add. Decide the rule and apply it to
  `DefineWorkoutView.swift:167`, `WorkoutTemplateDetailView.swift:~194`,
  `ProgramManagementView.swift:111` and `WorkoutListViewBuilder.swift:52`.
- **"Edit" pills** in `ProgramSettingsView.swift:65,104,129,153` (radius 20) and
  `ExerciseSettingsView.swift:40-81` (`.bordered`) become one style, matching WP-09's choice. Check
  WP-09's merged code if it is available; otherwise use `Chip` buttons.
- **Duplicated code.** `DefineWorkoutView` and `WorkoutTemplateDetailView` contain ~100 lines of
  copy-paste drift: `targetMusclesSection`, `setTarget` and the muscle chips.
  - Extract the shared section into one view in `Core/Training/Components/`, and keep the
    accessible version, which marks primary vs secondary by weight plus a label, not just by fill.
  - Muscle chips become `Chip`.
- **Cards.** `TodaysWorkoutCardLabel` has a fixed `height: 200`, `.cornerRadius(24)` ×3 and
  `backgroundPrimary`. Use `DashboardCard` sizing and `.cardSurface`.
- **Missing titles:** `CreateWorkoutView` and `CreateProgramView` draw a `Text(.title)` in the
  body instead of a title. Also `ExercisesView`, `DefineWorkoutView` and `WorkoutsView`.
- **`PrebuiltProgramDetailView.startButton`** is a hand-rolled async glass button. Make it
  `CallToActionButton(isLoading:)`.
- **Deprecated placement.** `EquipmentPickerView.swift:65` uses `.navigationBarLeading`.
- **Symbols.** Use `Symbol.workout` for workouts everywhere: history, library and cards.
