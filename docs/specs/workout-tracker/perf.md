# Live workout tracker: performance and SwiftUI correctness audit

Scope: working tree of `feature/workout-tracker-redesign`, compared with `HEAD` where it helps.
Read only, nothing run. The millisecond figures are rough estimates for an A15 (iPhone 13) with
8 exercises x 5 sets. Measure them before acting on them. Each finding says whether this branch
introduced it ("new") or it was already in `HEAD` ("pre-existing").

Path prefix used below: `WT/` = `Compound/Core/Training/Subviews/WorkoutTracker/`.

## How a keystroke flows

`SetKeyboardPresenter.type` -> `commit()` writes `set.wrappedValue.weightKg` -> index binding
`exercise.sets[i]` -> the closure binding in `WorkoutTrackerView.currentExerciseSection`
(`WT/WorkoutTrackerView.swift:175-181`) -> `presenter.workoutSession.exercises[index] = updated` ->
`workoutSession.didSet` (`WT/WorkoutTrackerPresenter.swift:28-33`):

1. `saveWorkoutProgress()` -> `WorkoutSessionManager.updateActiveSession` encodes the whole
   session with `JSONEncoder` and calls `data.write(to:)`, synchronously on the main actor
   (`Managers/Training/WorkoutSession/WorkoutSessionManager.swift:81-84`, and
   `FileManager+EXT.swift:12-16` in SwiftfulDataManagers). It then sets `activeSession = session`.
2. `handleWorkoutSessionChange` -> `propagateEdit`. With `propagateChanges` on, which is the
   default (`WorkoutSettings.swift:10`), a typical keystroke also rewrites the sibling sets. That
   is a second `workoutSession` write, so a second didSet, a second full-session encode and a
   second file write.
3. `activeSession` changes, which wakes `startObservingActiveSession` (a Task hop, a deep `!=` of
   the session, then re-arming). It also wakes every view that reads `activeSession`, including
   `TabBarView` underneath the full-screen cover.
4. Because `workoutSession` is a single `@Observable` property, `WorkoutTrackerView.body` runs
   again in full: toolbar, progress header, CTA, card and Up Next. The card's delegate carries
   fresh closures and `Binding(get:set:)` values, which SwiftUI cannot compare, so the bodies of
   `ExerciseTrackerView`, `SetTrackerView` and every `SetTrackerRowView` run again, and each
   `SetKeyboardTextField.updateUIView` runs too.

The Live Activity is **not** pushed per keystroke, and Firestore is **not** written per keystroke
(see "Well done").

---

## Findings, ranked by expected impact

### 1. A SwiftData fetch, JSON decode and sort of the whole exercise library on every keystroke (new, HIGH)

- **Where:** `WT/ExerciseTracker/ExerciseTrackerPresenter.swift:37-39`, called from
  `ExerciseTrackerView.cardHeader` (`WT/ExerciseTracker/ExerciseTrackerView.swift:99`).
- **Mechanism:** `exercise.imageName(in: interactor.allExercises)` evaluates its argument before
  the method gets to check the stored `imageName`. `allExercises` is `systemExercises + userExercises`
  (`Managers/Training/Exercise/ExerciseModelManager.swift:31-45`). `systemExercises` is
  `SwiftDataCollectionPersistence.getCollection`, which runs a `mainContext.fetch` and a
  `JSONDecoder().decode` for **every** entity, then `.sorted(by: name)`. The card header is built
  in every `SetTrackerView` body, so this happens on every keystroke, every stepper tap and every
  set logged. It is wasted work: `fillingMissingImages` has already put the images into the
  session (`WT/WorkoutTrackerPresenter.swift:121, 515-525`). `HEAD` read `exercise.imageName`
  directly.
- **Cost:** about 64 or more decodes of roughly 1.6 KB each, plus a SQLite round trip and a sort.
  Estimated 2-5 ms of main-thread time per keystroke, which is a large share of an 8.3 ms
  ProMotion frame.
- **Confirm:** add the launch argument `-com.apple.CoreData.SQLDebug 1` to the Development scheme.
  Each keystroke should print a `SELECT` on the DocumentEntity table. In Time Profiler, filter the
  call tree on `systemExercises`, `ModelContext.fetch` or `JSONDecoder.decode` while typing.
- **Smallest fix (root cause, which also covers every other caller):** make the parameter lazy in
  `Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift:190`:
  ```swift
  func imageName(in library: @autoclosure () -> [ExerciseModel]) -> String? {
      if let imageName, !imageName.isEmpty { return imageName }
      return library().first { $0.id == templateId }.flatMap { Constants.exerciseImageName(for: $0) }
  }
  ```
  Follow-up, not urgent: `systemExercises` decodes on every read app-wide. Caching the sorted array
  in `ExerciseModelManager`, and invalidating it on seed, would remove the cost everywhere.
  `restContext` and `progressionContext` also hit it, though only once per logged set.

### 2. The whole session is encoded and written synchronously, usually twice per keystroke (pre-existing, HIGH)

- **Where:** `WT/WorkoutTrackerPresenter.swift:28-33` (didSet), `:298-306` (save), `:556-584`
  (`propagateEdit`, the nested second write). `WorkoutSessionManager.swift:81-84`.
- **Mechanism:** see steps 1 and 2 of the keystroke flow above. Each write re-encodes about 40 sets
  plus every exercise's `equipmentVariations`, `setTargets` and so on, then does a blocking
  `Data.write` with no `.atomic` option. Assigning `activeSession` then reaches views below the
  cover. `TabBarView.body` reads `presenter.showTabAccessory` (`activeSession != nil`) and
  `presenter.activeSession` (`Core/TabBar/TabBarView.swift:78-85`), so the TabView body, the
  `ForEach(tabs)` Tab content closures (each of which builds a fresh `RouterView { root(router) }`
  with a new closure) and the training accessory all re-evaluate for each digit typed in the
  tracker.
- **Cost:** estimated 0.5-3 ms per write, so roughly 1-6 ms per keystroke, plus the work under the
  cover.
- **Confirm:** run `sudo fs_usage -w -f filesys <pid> | grep document_` while typing; expect two
  writes per digit when the upcoming sets share the weight. Wrap `saveWorkoutProgress` in an
  `os_signpost` and view it in the Points of Interest track. Put `let _ = Self._printChanges()` in
  `TabBarView.body` and `TrainingAccessoryView.body`; they should print once per digit.
- **Smallest fix:** coalesce the save rather than doing it per mutation, so the two nested writes
  become one and a burst of typing becomes one:
  ```swift
  @ObservationIgnored private var pendingSave: Task<Void, Never>?
  func saveWorkoutProgress() {
      guard !isDone else { return }
      pendingSave?.cancel()
      pendingSave = Task { [weak self] in
          try? await Task.sleep(for: .milliseconds(300))
          guard !Task.isCancelled else { return }
          self?.flushSave()            // the current body of saveWorkoutProgress
      }
  }
  ```
  Call `flushSave()` directly from `logSet`, from `onScenePhaseChange` when the new phase is not
  `.active`, from `minimizeSession`, and before finishing or discarding. Also make
  `adoptSavedSessionIfChanged` return early while `pendingSave != nil`, so that an observed write
  cannot overwrite an edit that has not been saved yet. A cheaper partial fix: skip the save inside
  the nested `propagateEdit` write and save once after it, which halves the cost.
  For the fan-out under the cover, give `WorkoutSessionManager` a stored `hasActiveSession: Bool`
  that `TabBarPresenter.showTabAccessory` reads. Then move the `activeSession` read into the
  accessory's own view, so only that view runs again, and not the whole `TabView`.
  Separately, in the package: `data.write(to: url, options: .atomic)`. A crash in the middle of a
  write currently leaves a truncated file, `getDocument` returns nil through `try?`, and the
  active workout is lost on relaunch.

### 3. Every keystroke re-renders the whole screen and the whole card (structural; smaller than HEAD)

- **Where:** `WT/WorkoutTrackerView.swift:25-121` (body reads `workoutSession`, `progress`,
  `primaryAction`, `primaryActionTitle`, `canQuickFinish`, `runningRestEnd`, `currentExercise`,
  `upNextExercises`, `completedExercises` and `upNextSummary` for each row). `:175-181` builds a
  new closure `Binding` on each pass, and `:292-331` builds a delegate full of fresh closures.
  `WT/ExerciseTracker/SetTracker/SetTrackerView.swift:76-101` and the `CoreBuilder` builders that
  allocate a new presenter on each call: `SetTrackerView.swift:423`, `SetTrackerRowView.swift:473`,
  `ExerciseTrackerView.swift:249`.
- **Mechanism:** `@Observable` tracks the `workoutSession` property as one unit. Every view that
  reads any part of it is invalidated by any change to it, and a digit typed into the weight field
  is such a change. Some of that is intended: the CTA title "Log set 2 · 115 kg × 5" is meant to
  follow keystrokes (`WT/WorkoutTrackerPresenter+ActiveExercise.swift:205-221`). The children are
  a different matter. They are handed closure bindings and closure-bearing delegates, so SwiftUI's
  field comparison cannot prove them unchanged and runs every body again:
  - every set row in the card, not only the edited one;
  - each row's two `UIViewRepresentable.updateUIView` calls, which set `textColor` and
    `accessibilityLabel` and compare `text`;
  - the Up Next rows, whose subtitles only change when a set is logged;
  - the toolbar `Menu`, the title and the progress header.

  Every builder call also allocates a throwaway `ExerciseTrackerPresenter`, a `SetTrackerPresenter`
  (which reads `UserDefaults` in its `init`), and for each row a `SetTrackerRowPresenter`, a
  `SetKeyboardPresenter` and a `SetKeyboardInputHost`. `@State` keeps the first one, so these are
  pure garbage.
- **Context:** this is much better than `HEAD`, which used `ForEach($presenter.workoutSession.exercises)`
  with every exercise's table expanded (about 40 set rows). The redesign renders around 7 set rows
  and 7 one-line rows. Presenter-side compute is in microseconds; the cost is SwiftUI graph and
  `UICollectionView` cell updates. Estimate 1-3 ms per keystroke.
- **Confirm:** add `let _ = Self._printChanges()` to `WorkoutTrackerView`, `SetTrackerView` and
  `SetTrackerRowView`, then type one digit. Expect every row to print `@self changed`. In the
  Instruments **SwiftUI** template, check that the View Body count per row grows by one per
  keystroke.
- **Smallest fix (only if measurement shows it matters after 1 and 2):** move the Up Next row into
  its own `struct UpNextRow: View`. Give it only comparable inputs (`presenter` as a reference,
  `exerciseId`, `title`, `subtitle`, `isDone`) and build its button actions inside its body, so
  SwiftUI skips it when nothing changed. Do the same for `ProgressHeader(progress:)`. Do not
  attempt per-set observation now; that is a model refactor. The allocations can be left alone,
  since their CPU cost is negligible.

### 4. Each row builds its own keyboard `UIHostingController` the first time it gains focus (pre-existing, MEDIUM: a hitch per set)

- **Where:** `SetTrackerRowView.swift:32` (`@State private var keyboardHost = SetKeyboardInputHost()`
  per row), `SetKeyboard/SetKeyboardTextField.swift:22-51, 81`.
- **Mechanism:** one host per row, created lazily, so tapping the weight field of each new set
  builds a fresh `UIHostingController<SetKeyboardView>` inside a `UIInputView`. UIKit then swaps
  input views, which is a re-present animation, rather than keeping one docked. The redesign has
  the user move row to row for every set, so this happens about once per set.
- **Cost:** estimated 5-15 ms on first focus, which is a visible stutter as the keyboard comes up.
- **Confirm:** use the Instruments **Animation Hitches** template while tapping set 2's and then
  set 3's weight field, and look for `UIHostingController.init` and `SetKeyboardView.body` on the
  main thread.
- **Fix:** one `SetKeyboardInputHost` per card, owned by `SetTrackerView` with `@State` and passed
  to the rows. In `view(for:)`, when the presenter differs, swap
  `hostingController.rootView = SetKeyboardView(presenter: presenter)`. Every field then shares
  the same `inputView` instance, and UIKit does not re-animate between responders that share an
  input view.

### 5. `plateSummary` runs the plate grid scan up to four times per keystroke (new, MEDIUM-LOW)

- **Where:** `SetTrackerRowPresenter.swift:281-299`, called on each render of the current row
  (`SetTrackerRowView.swift:60`). `PlateCalculator.swift:20-26, 30-39, 48-77`.
- **Mechanism:** most intermediate values while typing ("1", "12", "122") cannot be loaded. For
  those, `load` runs `nearest` twice (below and above), each up to `heaviest*2/0.25` steps: 200 for
  25 kg plates, 360 for 45 lb. Every step calls `perSide`, which re-filters and re-sorts the plate
  list. `nearestLoadable` then calls `load` again, so there are four scans. On top of that,
  `WeightStepper.steps` re-derives the gym's plates on every render.
- **Cost:** estimated 0.3-1.5 ms per keystroke, worst in pounds.
- **Confirm:** Time Profiler while typing an unloadable weight such as 122 kg; look for
  `PlateCalculator.perSide`.
- **Fix (two small edits):** in `plateSummary`, use the `.notLoadable(below:above:)` that `load`
  already returned (pick the closer one) rather than calling `nearestLoadable`, which halves the
  work. In `nearest`, compute `plates.filter { $0 > 0 }.sorted(by: >)` once and hand it to a
  `perSide` overload that does not sort.

### 6. Hiding the CTA from keyboard notifications (new, LOW-MEDIUM; not a per-keystroke cost)

- **Where:** `WT/WorkoutTrackerView.swift:21, 61, 87, 101-106`.
- **Mechanism:** `keyboardWillShow` and `keyboardWillHide` flip `isKeyboardVisible` outside any
  animation. When it flips, the `safeAreaInset` content collapses and the List's bottom inset jumps
  in one transaction, while keyboard avoidance changes the inset again in a second, animated one.
  That is two layout passes, and the CTA's `.transition` never animates because the state change
  carries no animation. These notifications fire on show and hide, **not per keystroke**, so the
  view does not thrash while typing. Three side effects:
  - moving focus between rows with different input views (finding 4) can post hide and then show,
    which flashes the CTA back for a frame;
  - any keyboard on screen hides the CTA, including the Notes sheet presented over the tracker;
  - an iPad floating or undocked keyboard posts neither notification.
- **Confirm:** add a `print` in both `onReceive` closures, then tap set 1's weight, set 2's weight,
  and then Next. Watch the List's content inset in the View Debugger.
- **Fix:** derive the flag from the tracker's own state instead. Have the rows report keyboard
  open and close through the existing `onBegin` and `close` hooks into a presenter flag, for
  example `WorkoutTrackerPresenter.isEditingSet`. If the notifications stay, at least wrap the
  write: `withReducedMotionAnimation(.quick) { isKeyboardVisible = true }`.

### 7. Animation modifiers applied to the whole List (new or broadened, LOW)

- **Where:** `WT/WorkoutTrackerView.swift:99-100`, plus `SetTrackerRowView.swift:94, 97-102`.
- **Mechanism:** `.reducedMotionAnimation(.standard, value: runningRestEnd == nil)` and
  `.reducedMotionAnimation(.emphasis, value: canQuickFinish)` sit on the `List`. When a set is
  logged and a rest starts, every change in that transaction animates with the custom curve: row
  done state, highlight move, rest row insert, warm-up row removal, progress bar and section moves.
  That turns a plain `UICollectionView` batch update into a custom-animated one. On the row,
  `.reducedMotionAnimation(value: isCurrent)` also animates the plate line's insertion, which
  changes the row's height inside a self-sizing cell; these can clip or overlap for a frame.
- **Confirm:** use Debug > Slow Animations in the Simulator and log a set.
- **Fix:** move both modifiers from the `List` onto the CTA content inside `.bottomCTA { … }`, and
  let the List keep its default row animations. Drop the row-level animation and keep only the
  one on the `listRowBackground` opacity.

### 8. Set bindings are index-based and can crash on delete while the keyboard is open (pre-existing correctness, MEDIUM)

- **Where:** `SetTrackerView.swift:76`. `delegate.exercise.sets.filter { … }` yields `Binding`s
  keyed by the keypath `\.[i]`. `SetKeyboardPresenter.swift:69, 82-87, 298` keeps
  `editingSet` and reads it in `displayText`, `plateLoad` and `selectedRPE`.
- **Mechanism:** `ForEach` identity is fine, because `Binding<Identifiable>` gives the set's id.
  The binding itself, though, reads `sets[i]`. Say the keyboard is open on the last set and the
  user swipe-deletes an earlier one (a split L/R pair removes two). The open row's next render
  then reads `editingSet.wrappedValue`, `sets[4]` of a 4-element array, and the app traps with
  "Index out of range". The comment at `WorkoutTrackerView.swift:173` already fixed this exact
  problem for exercises, but the fix stops at the set level.
- **Confirm:** open the weight keyboard on the last set, then swipe-delete set 1 from the context
  menu.
- **Fix:** build id-based set bindings in `SetTrackerView`, as the exercise binding does. The
  minimum is to close every row's keyboard on delete. Also set `editingSet = nil` in
  `SetKeyboardPresenter.close()`.

### 9. The Skip Rest label can build an inverted range (new, LOW; theoretical crash)

- **Where:** `WT/WorkoutTrackerView.swift:61, 70`.
- **Mechanism:** `runningRestEnd` checks `restEnd > Date()`, and then `Text(timerInterval: Date()...restEnd)`
  takes a later `Date()`. If the rest ends between the two calls, `ClosedRange` traps. The window
  is microseconds wide, but the fix is free.
- **Fix:** `Text(timerInterval: min(.now, restEnd)...restEnd)`, or `Text(restEnd, style: .timer)`.
  `InlineRestTimerRow` is already safe, because it uses `context.date` for both bounds.

### 10. Per-row lookups: real but negligible (answers questions 1 and 2)

- `ActiveWorkout.rowState`, called per row (`SetTrackerView.swift:91`, `ActiveWorkoutState.swift:47-50`),
  is O(S) per row, so O(S²) per card: about 25-100 comparisons, only for the current exercise.
  Optional: compute `ActiveWorkout.currentSet(in:)?.id` once before the `ForEach`.
- The previous-set lookup `lastExercise.matchingSet(for:in:)` (`SetTrackerView.swift:79`,
  `WorkoutSetPairing.swift:204-219`) calls `workingSetNumber` for each candidate, and each call
  allocates a new `workingSets` array. That is O(S²) per row and O(S³) per card: around 1,000
  element operations for a split 5x2, under 0.1 ms. If it ever matters, memoise it per `templateId`
  in the presenter; `previousExercises` is fixed after load.
- `upNextSummary` calling `interactor.getPreference`: **cheap**. It is an `@ObservationIgnored`
  dictionary cache, with `revision` as the only observed dependency
  (`ExerciseUnitPreferenceManager.swift:21-50`).
- `currentExercise` is a computed O(E) property, re-evaluated inside the `filter` closures of
  `upNextExercises` and `completedExercises`. That is O(E²), 64 comparisons. Hoisting it into a
  `let` is tidier but not a performance concern.
- `primaryActionTitle` re-runs `primaryAction`, and `primaryAction` is evaluated twice per body
  (`:87, :91`). Microseconds.

### 11. TimelineViews: two, each isolated (answers question 3)

- The title clock (`WT/WorkoutTrackerView.swift:155-160`) uses `.periodic(by: 1)`, and only its
  content closure runs each second; it does not invalidate the screen. The closure does read
  `workoutDateText`, which goes through `workoutSession`, so it is also re-run on each keystroke
  and re-formats the date with a `FormatStyle` every second. Fix: compute the date text once,
  outside the closure. Optional: with the paused-adjusted start, use
  `Text(timerInterval: adjustedStart...Date.distantFuture, countsDown: false)` while running, and
  drop the TimelineView entirely.
- `InlineRestTimerRow` (`InlineRestTimerRow.swift:20`) uses `.explicit([now, end])`. It renders
  twice per rest, and the countdown and bar are system-driven through `Text(timerInterval:)` and
  `ProgressView(timerInterval:)`, so no per-second bodies run. The schedule is rebuilt with a new
  `Date()` whenever the card re-renders; that is harmless.
- The CTA countdown uses `Text(timerInterval:)` with no TimelineView. Good.

### 12. Live Activity refresh rate (answers question 6): fine

- `refreshLiveActivity` runs on `updateSet` (a log), on selecting, Do Next, Do Later, add, delete
  and move, and from `handleWorkoutSessionChange` only when a set has **newly** completed. Typing
  never reaches it. `LiveActivityManager.updateLiveActivity` drops states equal to the last one
  (`LiveActivityManager.swift:195-239`).
- A log pushes twice: `updateSet` -> `refresh`, then `startRest` -> `updateRestAndActive`. The
  states differ in `restEndsAt`, so both go out. That is acceptable. If you want one push, start
  the rest before the refresh.
- The Firestore sync engine is written only at finish (`saveWorkoutSession`). Per-keystroke
  persistence is the local file in finding 2.

### 13. List identity (answers question 5): sound

- `ForEach(upNext)` and `ForEach(completed)` are keyed by exercise id, and `.onMove` maps the
  filtered positions back to the session correctly.
- Set rows are keyed by set id. A logged warm-up leaves the filter cleanly.
- The rest row sits inside the `ForEach` element, so moving its anchor removes it from one place
  and inserts it in another. That is fine, though it does not animate as a move.
- The card's `Section` has no `.id`. When the card switches exercise, the `@State` presenters of
  `ExerciseTrackerView` and `SetTrackerView` are reused. They hold only `draftNote` and the global
  `showAutoRanges`, so this is harmless. The rows are rebuilt, because the set ids differ.
- `exerciseRow` wraps its accessory in `AnyView` (`:249`), which is minor.

---

## Well done

- Only the current exercise draws a set table. That cuts the row count from about 40 to about 15
  compared with `HEAD`, and it is the biggest performance gain in the redesign.
- The exercise binding is looked up by id rather than index (`WorkoutTrackerView.swift:173-181`).
- Rest UI uses system-driven `Text(timerInterval:)` and `ProgressView(timerInterval:)`, plus a
  two-entry `.explicit` timeline. Nothing ticks a view body during a rest.
- The 1 s clock is confined to the toolbar's principal item.
- `getPreference` is cached with `@ObservationIgnored` and a `revision` counter, so calling it per
  row is free.
- Live Activity pushes are de-duplicated by `ContentState` equality, and keystrokes never push.
- `previousExercises` and `progressionSuggestions` load once on appear, each in a single
  assignment, so one invalidation.
- `ActiveWorkout` holds the rules as pure functions over values, so they can be tested and
  benchmarked without a screen.
- The rest-completion loop lives in `.task`, so it is cancelled with the screen. The
  `withObservationTracking` re-arm is weak-self and main-actor.

## Suggested order

1. The `@autoclosure` fix to `imageName(in:)`. One line; removes the largest per-keystroke cost.
2. Coalesce `saveWorkoutProgress` (and add `.atomic` in the package).
3. Measure with `_printChanges` and the SwiftUI instrument before touching finding 3.
4. Share one keyboard host per card (finding 4) and fix the plate scan (finding 5).
5. Fix the correctness items 8 and 9, which are cheap.
