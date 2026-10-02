# Training library: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`. Pages read:
`designing-for-ios`, `lists-and-tables`, `collections`, `searching`, `search-fields`, `buttons`,
`menus`, `context-menus`, `pull-down-buttons`, `pop-up-buttons`, `sheets`, `modality`, `alerts`,
`entering-data`, `text-fields`, `pickers`, `segmented-controls`, `toggles`, `disclosure-controls`,
`loading`, `undo-and-redo`, `drag-and-drop`, `accessibility`, `writing`, plus `action-sheets`,
`toolbars`, `layout`, `materials`, `voiceover` and `activity-views` where the code needed them.

**Scope.** Code read: `Core/Training/TrainingView.swift` with its presenter and router, all of
`Core/Training/Components/`, and `Core/Training/Subviews/` folders `ActiveTrainingProgram`,
`AddTraining` (Create Exercise, Create Program, Create Workout), `ExerciseSettings`,
`TrainingProgramLibrary`, `WorkoutHistory`, `Workouts`, `WorkoutSessionDetailView` and
`WorkoutTemplateDetail`. About 11,800 lines. Also read, because the code above calls them:
`Root/RIBs/GlobalRouter.swift`, `Components/DesignSystem/Chip.swift` and `ListRow.swift`,
`Components/Views/EnumPicker/EnumPickerView.swift`.

**Not reviewed.** `Subviews/WorkoutTracker/` (another reviewer), the shared `CalendarHeader`,
`WorkoutSessionRow`, `ExerciseModelDetail`, `ShareToFollower` and the rest modal. The assignment
also names `Components/Views/Training/`; that folder does not exist in this tree.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Sizes given in points are read off the
code, not measured. Other people were editing this tree while it was read, so line numbers are as
of 2026-09-28 and may have moved.

Paths are relative to `DialedIn/`. `T/` stands for `Core/Training/`, `S/` for
`Core/Training/Subviews/`, `CP/` for `Core/Training/Subviews/AddTraining/CreateProgram/`,
`CW/` for `…/AddTraining/CreateWorkout/` and `CE/` for `…/AddTraining/CreateExercise/`.
Findings are most serious first.

## Decisions built (2026-09-29, branch hig/training)

| Decision | Status | What changed |
|---|---|---|
| 6 (Training) | built | Programs, Workout Library and Workout History push on the Training tab with no Close; a finished workout pushes from the calendar, active program and History (`WorkoutSessionDetailDelegate.isPushed`) and stays a sheet with Close from Dashboard, Notifications and the tracker; the Workout Library stays a sheet from Analytics (`WorkoutsDelegate.isPushed`); Program Settings pushes inside the editor. Editing notes on a pushed workout hides Back and the close button ends the edit, asking when notes changed. |
| 11a (now) | built | "Edit Notes" row with no chevron; Save is a `Button(role: .confirm)` in `.confirmationAction` while editing; set and exercise editing code kept with a TODO. |
| 13d | built | The + is a menu (New Program, New Workout, New Exercise); the Add Training module is deleted. `showAddTrainingViewZoom` had no callers. |
| 13e | built | "Primary"/"Secondary" badge on each chosen tile, heavier ring for Primary, one line explaining the taps, 2 then 1 columns at accessibility sizes, placeholder marked TODO; Type, Laterality and both metrics are in-row menu pickers. |

## Resolution (2026-09-28, branch hig/training)

| # | Status | What changed |
|---|---|---|
| 1 | skipped: decision | Libraries still open as sheets. |
| 2 | skipped: decision | "Edit Workout" still toggles the notes field only. |
| 3 | fixed | Session detail, set targets and exercise picker block the swipe and ask through `showDiscardChangesDialog` only when something changed; Create Exercise's close asks; the workout builder's exercises survive going back (held by the name step); the program editor asks only when the program differs. |
| 4 | fixed | Session picker and program activation are action sheets; activation answers Save Templates / Don't Save / Cancel; both private in-progress prompts use `showActiveWorkoutAlert`; weight and distance units are in-row menu pickers. |
| 5 | fixed | Start Time holds the date, has close and Done, and saves once on Done. |
| 6 | fixed | Create flow keeps the system Back button; the edit sheet has `role: .close` in `.cancellationAction`, titled Edit Program. |
| 7 | fixed | Program editor More menu (Share with Friends, Delete Program); Delete in the library row's menu; exercises get Edit (reorder, delete) and `.rowActions`; set targets and the active program use `.rowActions`. |
| 8 | fixed | Set fields labelled by set and column; contribution field named; swatches named. |
| 9 | fixed | `RowChipButton` deleted, rows are `ListRowButton`; filter chips and reset 44 pt; variation delete `.tapTarget()`; swatches `ControlSize.row`. |
| 10 | fixed | Active chips filled with the accent, count from 1, `.isSelected`; multi-select are `Toggle`s with `.menuActionDismissBehavior(.disabled)`; regular glass. |
| 11 | fixed, partly | History branches on no sessions; No Programs offers Create Program; No Custom Exercises offers Create Exercise; equipment search has `ContentUnavailableView.search`. History's "Start Workout" action not added: starting and presenting the tracker from inside the History sheet depends on finding 1. |
| 12 | fixed | `.onMove` plus `EditButton` on the workout's exercises. |
| 13 | fixed | Review names equipment; colour/icon subtitle dropped; day order by name. |
| 14 | fixed | Inline error under the contribution; alternate names capped at 300; min above max swapped on save; picker confirm disabled at zero and existing exercises shown ticked and locked. |
| 15 | skipped: decision | Add Training sheet unchanged. |
| 16 | skipped: decision | Type/Laterality sheets and muscle grid unchanged. |
| 17 | fixed | Spinners on Create, Save (workout), Save/Activate Program, Program Settings Activate, Start Workout; Activate and Start Workout guarded against a second tap. |
| 18 | fixed | Titled `showAlert(title:error:)` in program design, settings and prebuilt detail; fragment titles title-cased. |
| 19 | fixed | Programs; icon prompt; no "Choose One"; rows replace Add/Edit chips; Start Program; title-case headers; "Final" dropped; "Custom Exercises" filter. |
| 20 | fixed | `.background(.bar)` removed. |
| 21 | fixed | Opacity dropped. |
| Smaller | fixed | "1 Exercise" via `inflect`; Periodization; listed strings localized; share menu without mixed icons; microcycle chevron; Remove Day destructive; distance unit picker; today card circle shrinks and text wraps. Program Settings' own Activate button kept (the review's own judgment call), now guarded and with a spinner. |
| Hand-offs | fixed | All Core/Training sites outside WorkoutTracker. `WorkoutSessionDetailPresenter:471` not a problem: the modal covers rendering the share image, not a read. `CreateWorkoutView`/`CreateProgramView` images left decorative (the default). |

## Findings

### 1. Libraries open as sheets, and sheets then stack three and four deep
Severity: hurts usability
Where: rows with a chevron at `T/TrainingView.swift:85`, `:88`, `:94`; presented as sheets at
`S/TrainingProgramLibrary/ProgramManagementView.swift:139`, `S/Workouts/WorkoutsView.swift:52`,
`S/WorkoutHistory/WorkoutHistoryView.swift:110`. Further sheets on top:
`CP/ProgramDesign/ProgramDesignView.swift:275` (edit program),
`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:139`,
`CP/ProgramDesign/ProgramSettings/ProgramSettingsRouter.swift:13`, `:19`, `:25`, `:31`,
`S/WorkoutSessionDetailView/WorkoutSessionDetailView.swift:241`,
`S/WorkoutSessionDetailView/WorkoutSessionTimingSheets.swift:72`, `:78`
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are in your app." —
https://developer.apple.com/design/human-interface-guidelines/sheets. "Present content modally
only when there's a clear benefit." —
https://developer.apple.com/design/human-interface-guidelines/modality. "If you need to let
people drill into a list or table row's subviews, use a disclosure indicator accessory control."
— https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
What happens: Training Program Library, Workout Library and Workout History are rows with a
disclosure chevron, but each opens a sheet with a close button. Everything inside then presents
again: Library → Edit Program → Program Settings → Rename is four sheets; History → session →
Start Time is three. Closing one lands on another sheet.
Fix: push the three libraries from the tab (`.push`), which removes one layer everywhere. Push
Program Settings and its four editors inside the editor's own navigation stack. Keep a sheet only
for the leaf task (rename, pick a date).
Size: L
Decision needed: yes — were the libraries made sheets on purpose (for example to keep the tab
bar accessory out of the way)?

### 2. "Edit Workout" on a finished session opens no editor, and Save hides in the More menu
Severity: hurts usability
Where: `S/WorkoutSessionDetailView/WorkoutSessionDetailView.swift:93-99`, `:179-203`,
`:207-224`; unused editing code at `WorkoutSessionDetailPresenter.swift:257`, `:300`, `:320`,
`:446`
Guideline: "Avoid putting all of a view's actions in one pull-down button. A view's primary
actions need to be easily discoverable" and "listing a minimum of three items can help the
interaction feel worthwhile." —
https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons. "The Done button
dismisses a sheet after completing a task or explicitly saving changes… the Done button belongs on
the trailing edge." — https://developer.apple.com/design/human-interface-guidelines/sheets
What happens: the row reads "Edit Workout / Go to the workout editor" with a chevron. Tapping it
only sets `isEditMode`, which turns the notes line further down into a text field; sets and
exercises cannot be changed, although the presenter has `addSet`, `deleteSet`, `deleteExercise`
and `onAddExercisePressed` that no view calls. Save then exists only as the first item of a
two-item More menu.
Fix: move Save to `ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) }`, shown
while editing (this is also the contract's Confirm pattern). Rename the row to what it does
("Edit Notes", no chevron), or wire the set and exercise editing the presenter already has.
Size: S for the toolbar and wording, L for real set editing
Decision needed: yes — should a finished workout's sets be editable here?

### 3. Unsaved work is thrown away by a swipe, a close or a back, with no question asked
Severity: hurts usability
Where: `S/WorkoutSessionDetailView/WorkoutSessionDetailView.swift:150-158` (the close button
asks, the swipe does not); `CW/SetTarget/SetTargetView.swift:100-104`, `:179`;
`CW/ExercisesPicker/ExercisesPickerView.swift:31-35`, `:65`;
`CE/CreateExercisePresenter.swift:92-94`; `CW/DefineWorkoutWrapper/DefineWorkoutWrapperView.swift`
(back from the exercise list); the opposite at `CP/ProgramDesign/ProgramDesignPresenter.swift:207`
Guideline: "Support swiping to dismiss a sheet… If people have unsaved changes in the sheet when
they begin swiping to dismiss it, use an action sheet to let them confirm their action." —
https://developer.apple.com/design/human-interface-guidelines/sheets. "When necessary, help
people avoid data loss by getting confirmation before closing a modal view. Regardless of whether
people use a dismiss gesture or a button…" —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: no `interactiveDismissDisabled` exists anywhere in this area, so swiping down the
session sheet, the set-target sheet or the exercise picker drops the edits silently. Backing out
of the workout builder drops its exercise list the same way. The program editor does the reverse
and asks "discard your changes?" even when nothing was changed. Caveat: I did not read the routing
package, so a package-level block on the swipe is possible but I found none.
Fix: one rule for every editor: if the working copy differs from what it opened with, block the
swipe (`.interactiveDismissDisabled(hasChanges)`) and confirm through
`router.showConfirmationDialog`; if it does not differ, close at once.
Size: M
Decision needed: no

### 4. Alerts are used as menus, and one asks "Yes / No"
Severity: hurts usability
Where: `T/TrainingPresenter.swift:174-192` (one button per workout on that day);
`S/ExerciseSettings/ExerciseSettingsPresenter.swift:80-97` (weight unit);
`S/ActiveTrainingProgram/ActiveTrainingProgramPresenter.swift:214-231`,
`S/WorkoutTemplateDetail/WorkoutTemplateDetailPresenter.swift:98-115` and
`Root/RIBs/GlobalRouter.swift:60-72` called from `T/TrainingPresenter.swift:109` ("Workout In
Progress"); `CP/ProgramDesign/ProgramDesignPresenter.swift:139-155`
Guideline: "Use an action sheet — not an alert — to offer choices related to an intentional
action." and "alerts display a title, optional informative text, and up to three buttons." and
"In informational alerts only, you can use 'OK' for acceptance, avoiding 'Yes' and 'No.' Always
use 'Cancel' to title a button that cancels the alert's action." —
https://developer.apple.com/design/human-interface-guidelines/alerts. "Use a pop-up button to
present a flat list of mutually exclusive options or states." —
https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons
What happens: every choice goes through `router.showAlert`, which is always `.alert`. A day with
four workouts makes a five-button alert. Activate Program interrupts with "Would you like to save
the workout templates…?" answered "Yes", "No" and a `role: .close` button. The two copies of
"Workout In Progress" carry different button titles from the shared one in `GlobalRouter`.
Fix: `router.showConfirmationDialog` already exists (`GlobalRouter.swift:74`); use it for the
session picker, the in-progress prompt and the template question, with verb titles ("Save
Templates", "Don't Save", "Cancel"). Replace both private in-progress prompts with
`showActiveWorkoutAlert`. Make the weight unit a `Picker` with `.pickerStyle(.menu)` in the row.
Size: M
Decision needed: no

### 5. The Start Time sheet has Done and nothing else, and has already saved
Severity: hurts usability
Where: `S/WorkoutSessionDetailView/WorkoutSessionTimingSheets.swift:27-31`;
`WorkoutSessionDetailPresenter.swift:183-186`, `:195-208`
Guideline: "Provide an alternative to the Done button. If you provide a Done button, always pair
it with a Cancel button to give people a clear way to dismiss the sheet without confirming or
saving their changes… Relying solely on the Done button implies that completing the task is the
only way to exit the sheet." — https://developer.apple.com/design/human-interface-guidelines/sheets
What happens: every movement of the date picker writes the session to the backend and plays the
success haptic. There is no cancel and no way back to the original time. The Duration sheet beside
it (`:60-65`) does it correctly with close and confirm.
Fix: hold the date in the sheet, add `Button(role: .close)` in `.cancellationAction`, and save
once from the confirm button, as `WorkoutSessionDurationSheet` does.
Size: S
Decision needed: no

### 6. The program editor replaces Back with a chevron that discards everything
Severity: hurts usability
Where: `CP/ProgramDesign/ProgramDesignView.swift:55`, `:203-211`;
`CP/ProgramDesign/ProgramDesignPresenter.swift:207-226`
Guideline: "The Back button lets people navigate to a previous step in a multi-step flow… It
isn't intended to dismiss a sheet." —
https://developer.apple.com/design/human-interface-guidelines/sheets. "Use the standard Back and
Close buttons… If you create a custom version of either, make sure it still looks the same,
behaves as people expect" — https://developer.apple.com/design/human-interface-guidelines/toolbars.
"it's especially important let people swipe to navigate back" —
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
What happens: the system back button is hidden and a hand-drawn `chevron.left` takes its place.
In the create flow it does not go back to the icon step; it offers to discard the program and
close the cover. When editing, the same chevron is the only way to close a sheet. Hiding the back
button also removes the back swipe (my understanding of SwiftUI, not run).
Fix: keep the system back button in the create flow. For the edit sheet and the cover use
`Button(role: .close)` in `.cancellationAction`, confirming only when there are changes
(finding 3).
Size: S
Decision needed: no

### 7. Delete is reachable only by swipe, and Share only by touch and hold
Severity: hurts usability
Where: delete — `S/TrainingProgramLibrary/InactiveTrainingProgram/InactiveTrainingProgramView.swift:30-38`,
`S/ActiveTrainingProgram/ActiveTrainingProgramView.swift:33-37`,
`CW/DefineWorkout/DefineWorkoutView.swift:83-87`, `CW/SetTarget/SetTargetView.swift:57-63`;
share — `S/TrainingProgramLibrary/TrainingProgramDisclosureGroup/TrainingProgramDisclosureGroupView.swift:28-32`
Guideline: "Always make context menu items available in the main interface, too." and "Support
context menus consistently throughout your app." —
https://developer.apple.com/design/human-interface-guidelines/context-menus. "Offer alternatives
to gestures. Make sure your UI's core functionality is accessible through more than one type of
physical interaction." — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: a saved program can be deleted only by swiping its row, and shared only from a
context menu that exists on this one row in the whole area. The program editor has neither
action. Workout templates do it properly, in a More menu
(`S/WorkoutTemplateDetail/WorkoutTemplateDetailView.swift:58-79`).
Fix: give the program editor the same More menu (Share with Friends, Delete Program last, with
`role: .destructive`), and add Delete to the row's context menu beside Share. For exercises and
set targets an Edit mode with `.onDelete` covers it (see finding 12).
Size: M
Decision needed: no

### 8. Fields and swatches that VoiceOver cannot name
Severity: hurts usability (VoiceOver) — not run
Where: `CW/SetTarget/SetTargetView.swift:46-52`;
`CE/FinalExerciseDetails/FinalExerciseDetailsView.swift:81`;
`T/Components/ProgramColourIconGrid.swift:31`, `:45`
Guideline: "Provide alternative labels for all key interface elements." —
https://developer.apple.com/design/human-interface-guidelines/voiceover. "Because placeholder
text disappears when people start typing, it can also be useful to include a separate label
describing the field" — https://developer.apple.com/design/human-interface-guidelines/text-fields
What happens: both rep fields in every set row are `TextField("Optional", …)`; the column
headings above are separate text, so each field is announced as "Optional". The body-weight
contribution field has an empty label. Program icons are labelled with their symbol name
("gauge.with.dots.needle.bottom.100percent") and colours with `Color.description`.
Fix: `.accessibilityLabel("Set \(n), minimum reps")` and the maximum equivalent; label the
contribution field "Body weight contribution, percent"; give the icon and colour lists a
localized name each instead of the raw value.
Size: S
Decision needed: no

### 9. Tap targets under 44 pt
Severity: hurts usability
Where: `T/Components/RowChipButton.swift:24-28`, used at
`S/ExerciseSettings/ExerciseSettingsView.swift:71`,
`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:48`,
`CE/ExerciseEquipment/ExerciseEquipmentView.swift:100`;
`T/Components/ExerciseListBuilder/ExerciseListBuilderView.swift:129-135`, `:246-259`;
`CE/ExerciseEquipment/ExerciseEquipmentView.swift:52-59`;
`T/Components/ProgramColourIconGrid.swift:21`
Guideline: "As a general rule, a button needs a hit region of at least 44x44 pt" —
https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: `RowChipButton` wraps a `Chip` (about 20 pt tall by `Chip.swift`'s own comment) in
a plain button without `.chipTapTarget()`, and it is the only tappable part of eleven settings
rows; the row itself does nothing. The filter chips are body text plus 8 pt padding, about 38 pt.
The delete-variation button is a bare glyph in a section header. Colour and icon swatches are
40 pt.
Fix: make each "Edit" row a `ListRowButton` (whole row tappable, chevron) and delete
`RowChipButton`; the contract already says `ListRowButton` for rows in a List. Give the filter
chips and the header button `frame(minHeight: ControlSize.row)` with a `contentShape`, and the
swatches `ControlSize.row`.
Size: M
Decision needed: no

### 10. Exercise filter chips: the active state cannot be seen, and each pick closes the menu
Severity: hurts usability
Where: `T/Components/ExerciseListBuilder/ExerciseListBuilderView.swift:249`, `:258`,
`:187-203`, `:131`, `:259`
Guideline: "Convey information with more than color alone." —
https://developer.apple.com/design/human-interface-guidelines/accessibility. "Only use clear
Liquid Glass for components that appear over visually rich backgrounds." —
https://developer.apple.com/design/human-interface-guidelines/materials
What happens: an active chip is drawn in `.tint`, an inactive one in `.primary`. The accent is
`labelColor` today, so they are the same colour. The count badge appears only above one
selection, so choosing a single Type, Laterality, Resistance or Support changes nothing on the
chip; if the accent becomes a colour, colour will be the only sign. The multi-select menus are
plain `Button`s, so the menu closes after each pick, against the code comment that says it stays
put. All chips use `.clear` glass over a text list.
Fix: show a selected chip with a filled background or a leading checkmark, and show the count
from 1. Build the options as `Toggle(isOn:)` inside the `Menu` with
`.menuActionDismissBehavior(.disabled)`. Use regular glass.
Size: S
Decision needed: no

### 11. Blank and dead-end empty states
Severity: hurts usability
Where: `S/WorkoutHistory/WorkoutHistoryView.swift:24-30`, `:58-72`;
`S/TrainingProgramLibrary/ProgramManagementView.swift:90-96`;
`T/Components/ExerciseListBuilder/ExerciseListBuilderView.swift:269-273`;
`CE/EquipmentPicker/EquipmentPickerView.swift:33-35`
Guideline: "Provide clear next steps on any blank screens… guide people on actions they can take,
and give them a button or link to do so if possible." —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: Workout History shows its empty state only when there is no signed-in user. A
signed-in user with no workouts gets the header "Completed Workouts 0" over an empty list. The
state that does exist offers "Reload", which only posts a notification. "No Programs" and "No
Custom Exercises" name the problem but carry no button. Equipment search with no match shows
nothing.
Fix: in History branch on `workoutSessions.isEmpty`, with a "Start Workout" action. Add "Create
Program" and "Create Exercise" actions to the other two. Add
`ContentUnavailableView.search(text:)` to the equipment picker.
Size: S
Decision needed: no

### 12. Exercises in a workout cannot be reordered
Severity: hurts usability
Where: `CW/DefineWorkout/DefineWorkoutView.swift:78-88`
Guideline: "Let people edit a table when it makes sense. People appreciate being able to reorder
a list, even if they can't add or remove items." —
https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
What happens: the order of exercises is the order they were picked in. To move one up, it has to
be removed and everything after it added again. Program days can be reordered
(`EditDayOrderView`), so the pattern is already in the codebase.
Fix: `.onMove { presenter.moveExercise(from: $0, to: $1) }` on the `ForEach`, with an `EditButton`
in the toolbar; that also gives delete a visible path (finding 7).
Size: S
Decision needed: no

### 13. Internal identifiers shown as text
Severity: polish
Where: `CE/ExerciseSave/ExerciseSaveView.swift:134`, `:137`;
`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:71`, `:109-119`
Guideline: "Be clear. Choose words that are easily understood" and "avoiding jargon" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: the exercise review screen prints `equipment.equipmentId` where the step before
printed the equipment's name. Program Settings prints the colour's hex string and the SF Symbol
name as the row subtitle ("#FF3B30, Flag.Pattern.Checkered"), and the day order as "R W W ".
Fix: resolve the id through the same lookup `ExerciseEquipmentPresenter.name(for:)` uses. Drop
the colour and icon subtitle (the row's own glyph already shows both). Write the day order in
words ("Rest, Workout A, Workout B") or as a count.
Size: S
Decision needed: no

### 14. Invalid input is refused without saying why
Severity: polish
Where: `CE/FinalExerciseDetails/FinalExerciseDetailsView.swift:53`, `:108`,
`FinalExerciseDetailsPresenter.swift:24-26`; `CW/SetTarget/SetTargetView.swift:144-158`;
`CW/ExercisesPicker/ExercisesPickerView.swift:27`, `:37-41`,
`ExercisesPickerPresenter.swift:35-39`
Guideline: "Dynamically validate field values… provide feedback as soon as you detect a problem"
and "make the button available only after people enter the data you require." —
https://developer.apple.com/design/human-interface-guidelines/entering-data. "Show errors right
next to the field, and instruct people how to enter the information correctly" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: a contribution over 100 disables Next with no message. The alternate-names counter
reads "n/300" but nothing stops at 300. A set target accepts a minimum above its maximum and
saves "12–8 reps". The exercise picker's title says "Select at least one exercise" while its
confirm button stays enabled, and ticking an exercise already in the workout counts as selected
but adds nothing.
Fix: an `InlineMessage(.error, …)` under the contribution field ("Enter a number from 0 to
100"); enforce or remove the 300 counter; refuse or swap min and max on save; disable confirm at
zero and show exercises already in the workout as checked and locked.
Size: M
Decision needed: no

### 15. A sheet to choose between three commands
Severity: polish
Where: `S/AddTraining/AddTrainingView.swift:15-27`, `:70`; `AddTrainingPresenter.swift:25-38`;
entry at `T/TrainingView.swift:123-130`
Guideline: "An Add button could present a menu that lets people specify the item they want to
add." — https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons. "Present
content modally only when there's a clear benefit." —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: the + button opens a sheet holding New Program, New Workout and New Exercise. Each
row dismisses the sheet and then opens a full-screen cover, so every create costs a sheet up, a
sheet down and a cover up.
Fix: make the toolbar + a `Menu` with the three items and delete the module.
Size: S
Decision needed: yes — `showAddTrainingViewZoom` suggests other callers; confirm they can take a
menu too.

### 16. Short option lists open a sheet, and the muscle picker is a grid of one image
Severity: polish
Where: `CE/CreateExerciseView.swift:102-136`, `:209-229`, `CE/CreateExercisePresenter.swift:48-58`;
`CE/MuscleGroupPicker/MuscleGroupPickerView.swift:52`, `:66`, `:83`, `:103`,
`MuscleGroupPickerPresenter.swift:41-48`
Guideline: "When possible, offer choices instead of requiring text entry… consider using a
picker, menu, or other selection component" —
https://developer.apple.com/design/human-interface-guidelines/entering-data. "Avoid switching
views to show a picker." — https://developer.apple.com/design/human-interface-guidelines/pickers.
"Consider using a table instead of a collection for text." —
https://developer.apple.com/design/human-interface-guidelines/collections
What happens: Type and Laterality are rows with a downward chevron, which reads as a menu, but
each opens a sheet listing a handful of options. The muscle picker is a three-column grid where
every tile draws the same placeholder (`ImageLoaderView()` defaults to the splash image) over a
one-line name that will truncate at large text. One tap means primary, a second secondary, a
third none, and nothing on screen says so (the cycling is my judgment, not a quoted rule).
Fix: `Picker` with `.pickerStyle(.menu)` for Type, Laterality and the two metrics. Until muscle
artwork exists, list muscles as rows with a Primary / Secondary / Off menu or segmented control
per row.
Size: M
Decision needed: yes — is muscle artwork planned?

### 17. Saves give no sign of progress
Severity: polish
Where: `CE/ExerciseSave/ExerciseSaveView.swift:77-83`;
`CW/DefineWorkoutWrapper/DefineWorkoutWrapperView.swift:35-41`;
`CP/ProgramDesign/ProgramDesignView.swift:153-170`;
`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:34-38`;
`S/WorkoutTemplateDetail/WorkoutTemplateDetailView.swift:41-50`
Guideline: "Configure a button to display an activity indicator when you need to provide
feedback about an action that doesn't instantly complete." —
https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: these buttons write to the backend and at most go dim. `CallToActionButton` has
`isLoading`, and only `PrebuiltProgramDetailView.swift:25` passes it. Program Settings' Activate
and Start Workout have no guard at all, so a second tap runs the write twice.
Fix: pass `isLoading: presenter.isSaving` at each site and add the flag where it is missing.
Size: S
Decision needed: no

### 18. Alert titles: "Error", and two capitalisation styles
Severity: polish
Where: "Error" through `router.showAlert(error:)` at
`CP/ProgramDesign/ProgramDesignPresenter.swift:173`, `:200`, `:239`,
`CP/ProgramDesign/ProgramSettings/ProgramSettingsPresenter.swift:68`,
`S/TrainingProgramLibrary/PrebuiltProgramDetail/PrebuiltProgramDetailPresenter.swift:49`;
sentence case at `S/TrainingProgramLibrary/ProgramManagementPresenter.swift:84`,
`S/WorkoutTemplateDetail/WorkoutTemplateDetailPresenter.swift:68`, `:138`,
`S/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:128`
Guideline: "Avoid writing a title that doesn't convey useful information — like 'Error'… If the
title is a sentence fragment, use title-style capitalization, and don't add ending punctuation."
— https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: five failures show the title "Error" over a raw `localizedDescription`. The same
kind of failure is "Unable to Delete Program" on one screen and "Unable to delete program" on
the next.
Fix: replace the five with `showSimpleAlert(title: "Unable to Save Program", …)` style titles,
and put every fragment title in title case.
Size: S
Decision needed: no

### 19. Wording
Severity: polish
Where and what:
- `S/TrainingProgramLibrary/ProgramManagementView.swift:32` is titled "My Programs"; the row that
  opens it (`T/TrainingView.swift:85`) says "Training Program Library".
  `T/Components/ExerciseListBuilder/ExerciseFilters.swift:27` has "My Exercises".
- `CP/ProgramIcon/ProgramIconView.swift:20`: "What icon should we use to display this program?"
- `CE/EquipmentPicker/EquipmentPickerView.swift:37`: subtitle "Choose One" on a list that
  accepts several. `CE/ExerciseEquipment/ExerciseEquipmentView.swift:100`: the button stays
  "Add" after equipment has been added.
- `S/TrainingProgramLibrary/PrebuiltProgramDetail/PrebuiltProgramDetailView.swift:28`: "Start
  this program".
- Headers in two styles: "Program name" (`CP/NameProgram/NameProgramView.swift:22`), "Workout
  name" (`CW/NameWorkout/NameWorkoutView.swift:27`), "Number of cycles"
  (`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:61`) beside "Exercise Name" and
  "Day Order".
- `CE/ExerciseSave/ExerciseSaveView.swift:159`: sections marked "Final".
Guideline: "Use possessive pronouns sparingly… Avoid using *we* altogether" and "Adopt
capitalization rules that align with your app's style, then apply them consistently." —
https://developer.apple.com/design/human-interface-guidelines/writing. "Using title-style
capitalization, consider starting the label with a verb" —
https://developer.apple.com/design/human-interface-guidelines/buttons
Fix: "Programs" (and name the row the same); "Choose an icon for this program"; "Choose Any" or
no subtitle; "Edit" once something is chosen; "Start Program"; title case for every header; drop
"Final".
Size: S
Decision needed: no

### 20. Opaque bar material behind the calendar header
Severity: polish
Where: `T/TrainingView.swift:61`
Guideline: "Instead of applying a solid or semi-opaque background color beneath controls, use a
scroll edge effect to visually elevate controls above content." —
https://developer.apple.com/design/human-interface-guidelines/layout
What happens: the header in the top safe-area inset sits on `.background(.bar)`, the same pattern
the onboarding review reported (its finding 9).
Fix: remove the background and let the scroll edge effect separate the header from the list.
Size: S
Decision needed: no

### 21. Completed days are dimmed to 30%
Severity: polish
Where: `S/ActiveTrainingProgram/Subviews/MicrocycleItemRow.swift:17`
Guideline: "Strive to meet color contrast minimum standards… Up to 17 pts — 4.5:1" —
https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: a finished day's name, exercise list and muscle chips are drawn at 0.3 opacity.
Secondary text at 30% will not reach 4.5:1 (not measured), and the row looks disabled although
tapping it opens the finished session. The checkmark already says it is done.
Fix: drop the opacity, or use `.foregroundStyle(.secondary)` for the title only.
Size: S
Decision needed: no

## Smaller items

- `S/WorkoutTemplateDetail/WorkoutTemplateDetailView.swift:109` reads "1 Exercises" in English:
  the catalog key `%lld Exercises` has Spanish plural variations and no English ones.
  `DefineWorkoutView.swift:90` does it right with `inflect`.
- UK spelling, against README follow-up decision 8: "Periodisation" at
  `CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:93` and
  `S/TrainingProgramLibrary/PrebuiltProgramDetail/PrebuiltProgramDetailView.swift:43`.
- Strings that never reach the catalog because they are passed as `String`: "None"
  (`CE/CreateExerciseView.swift:69`, `:81`, `:105`, `:123`), "Trackable Metric 1" and the other
  picker titles (`:73`, `:85`, `:109`, `:127`), "Resistance Equipment" / "Support Equipment"
  (`CE/ExerciseEquipment/ExerciseEquipmentPresenter.swift:66`, `:85`), "Off" and "None"
  (`S/ExerciseSettings/ExerciseSettingsPresenter.swift:53`, `:60`), both delete messages
  (`S/TrainingProgramLibrary/ProgramManagementPresenter.swift:54-55`), both save-failed messages
  (`S/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:204`, `:238`), and the default
  day names "Rest", "Rest Day", "Workout A" (`CP/ProgramDesign/ProgramDesignPresenter.swift:73`,
  `:93`, `:251-253`).
- The share menu mixes items with and without icons, and "Copy Link" uses the share symbol
  (`S/WorkoutSessionDetailView/WorkoutSessionDetailView.swift:161-174`). "Provide icons for all
  menu items in a group, or none of them." —
  https://developer.apple.com/design/human-interface-guidelines/menus
- Program Settings has its own "Activate Program" button
  (`CP/ProgramDesign/ProgramSettings/ProgramSettingsView.swift:33-39`) that saves and activates
  from inside a settings sheet, then returns to an editor showing the same button. My judgment:
  remove it.
- The microcycle row ends in an empty `circle`, the glyph `ListRow` uses for an unchecked option,
  but tapping opens the workout (`MicrocycleItemRow.swift:20`). My judgment: a chevron for days
  not yet done.
- "Remove" in the program editor deletes the selected day and its exercises at once, with no
  role, confirmation or undo (`CP/ProgramDesign/ProgramDesignView.swift:177-184`,
  `ProgramDesignPresenter.swift:108-116`). The whole edit can still be discarded.
- The Exercise Settings row "Weights" shows "Kilograms · Meters" but only the weight unit can be
  changed; `onSelectDistanceUnit` has no caller
  (`S/ExerciseSettings/ExerciseSettingsPresenter.swift:108`).
- `T/Components/TodaysWorkoutCard/Components/TodaysWorkoutCardLabel.swift:45`, `:110`: a fixed
  100 pt circle and one-line title and subtitle inside a fixed-height card. "Recovery is part of
  the process." will truncate at large text (not run).

## Contract conflicts

- **Close on a sheet that has already saved.** `CONTRACT.md` § Patterns makes
  `Button(role: .close)` the one dismiss control. The HIG says "The Cancel (or Close) button
  dismisses a sheet without saving any changes" and "The Done button dismisses a sheet after
  completing a task or explicitly saving changes" —
  https://developer.apple.com/design/human-interface-guidelines/sheets. Program Settings
  (`ProgramSettingsView.swift:102-106`), the equipment picker (`EquipmentPickerView.swift:65-69`)
  and the shared enum picker write through a binding as you tap, so their close button keeps the
  changes. The contract's own Confirm pattern (`role: .confirm`) would fit these; which one
  applies to a live-saving sheet is not stated.

## Done well — keep

- Create flows disable Continue / Next / Save until the required data is there, and mark
  required sections "Required" in the header.
- Rename, Day Order, Deload, Color & Icon and Duration all pair close with confirm, and hold a
  working copy until confirm.
- Every destructive delete that reaches the backend confirms with a Cancel, and workout
  templates list Delete last in the menu with the destructive role.
- Selection never rests on colour alone: muscle tiles carry P / S, `MuscleChip` changes weight
  and spoken label, selected rows add `.isSelected`.
- Search filters as you type, has a scoped prompt ("Search exercises", "Search workouts"), and
  uses `ContentUnavailableView.search` when nothing matches. Exercise search also matches muscle
  names and alternate names.
- Rows move their image or accessory under the title at accessibility sizes
  (`TemplateExerciseRow`, `ListRow`), and sheet presets always include `.large`.
- Haptics follow the contract: `.selection` on pickers, `.success` / `.error` on saves.
