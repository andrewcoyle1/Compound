# Workout tracker: container options

Analysis only. Nothing in the repo was edited. Based on the working-tree `WorkoutTracker/`
(current-exercise card, Up Next, Completed, `safeAreaBar` progress header, `bottomCTA`),
`git show HEAD:` (a List of `DisclosureGroup`s), the two MacroFactor screenshots, and the live HIG
pages `page-controls` and `scroll-views` (fetched 6 Oct 2026 with the `apple-hig` skill).

Confidence markers: **[verified]** means read in this repo's code or the HIG. **[known]** means
well-established SwiftUI behaviour. **[uncertain]** means it needs a prototype on iOS 26 before
anyone relies on it.

---

## 0. Constraints in this codebase that decide the outcome

1. **`SetTrackerView` returns List rows, not a self-contained view.** [verified] Its body is a
   run of sibling rows (card header, progression note, column headers, rest row, `ForEach` of set
   rows, Add Set). Each one carries `.listRowInsets`, `.listRowSeparator` and `.listSectionMargins`.
   `SetTrackerRowView` uses `.listRowBackground` for the current-set highlight,
   `.swipeActions` on both edges (trailing: Delete with full swipe; leading: Rest Timer) and
   `.moveDisabled(true)`. **Whatever holds a set table has to be a `List`.** Under a
   `LazyVStack` or `VStack`, every one of those modifiers does nothing. You would lose the
   highlight, the separators, the inset layout and both swipe actions without any error. This is
   the biggest single cost driver in the table below.
2. **The custom keyboard is per row.** [verified] `SetKeyboardInputHost` is `@State` on each
   `SetTrackerRowView`. The `UITextField.inputView` is a `UIHostingController` wrapped in a
   `UIInputView`. Focus follows `SetKeyboardPresenter.activeField`, one presenter per row. It is
   applied in `updateUIView` with a `DispatchQueue.main.async` `becomeFirstResponder`.
   `textFieldDidEndEditing` calls `close()` when focus goes somewhere the keyboard did not send
   it. As a result:
   - If a row's view is torn down (a lazy page dropped, a List cell reused, a card swapped), the
     field resigns, the presenter closes and the keyboard goes away. That is safe, but any
     container that rebuilds rows while you type will kill the keyboard.
   - Nothing at screen level can tell a row to close. The only global lever is
     `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)`.
     That runs `textFieldDidEndEditing`, which then runs `close()`.
   - `WorkoutTrackerView.isKeyboardVisible` already exists (from keyboard notifications) and
     already hides the CTA. Any pager can reuse it to lock paging.
3. **One "current exercise" drives three things.** [verified] `expandedExerciseId` and
   `currentExerciseIndex` feed the card, `primaryAction` (the CTA) and
   `liveActivityExerciseIndex` (the Live Activity). `onExerciseSelected` also plays a selection
   haptic, tracks `exerciseSelected` and calls `refreshLiveActivity()`. Several things move it
   programmatically: `advanceWithinSuperset` (round-robin, gated on `supersetAutoScroll`),
   `advanceAfterExerciseCompletion`, `onDoLaterPressed`, the CTA's `.next`, and a set logged from
   the Live Activity. **Any pager needs a two-way binding.** It must follow programmatic moves,
   and a swipe should not trigger the haptic, the analytics event and a Live Activity push on
   every page it passes.
4. **`restTimer(for:)` shows a rest row on every exercise asked.** [verified]
   `ActiveWorkout.restAnchor` returns `.top` for any exercise that does not hold the rested set.
   Today only the card asks. In a pager every page that gets built would show a rest row and
   start its own `TimelineView`. Pass `restTimer` only to the selected page.
5. **Every keystroke invalidates `workoutSession`.** [verified] The comment on
   `primaryActionTitle` says so. Every view that reads `presenter.workoutSession` re-evaluates,
   so an eager `HStack` of N Lists does N times the work per digit.
6. **There is precedent for horizontal paging.** [verified] `MacroHeader` and
   `ProgressCarousel` use `ScrollView(.horizontal)` with `.containerRelativeFrame(.horizontal)`,
   `.scrollTargetBehavior(.paging)` and `.scrollPosition(id:)`. `MacroHeader` documents why it
   rejected `TabView(.page)`: the page style reserves room for its dots inside the content.
   `CalendarView` documents that `scrollPosition(id:)` resolves only against the scroll target
   layout's *immediate* children, so it switched to `ScrollViewReader`.
7. **The screen is a `fullScreenCover` with its own `RouterView` (NavigationStack).** [verified]
   Warm-ups, Targets, Swap, Rest, Equipment and Notes are router sheets presented from row,
   set-tracker and exercise-tracker routers. Anything that keeps a sheet up all the time blocks
   them.
8. **iPad is capped by `readableContentWidth` (700 pt).** [verified] A two-column layout has to
   widen through `.preferredReadableContentWidth(...)`, as `Dashboard` and `AnalyticsView` do.
   It switches at `ContentWidth.twoColumns` (740), measured with `onGeometryChange`.
9. **What the HIG says.** [verified]
   - "Avoid putting a scroll view inside another scroll view with the same orientation." A
     horizontally scrolling chip row inside a horizontal pager breaks this, and MacroFactor does
     exactly that.
   - Page controls with "more than about 10 dots are hard to count". Use a different
     arrangement there, so prefer a thumbnail strip or a count over dots.
   - "If the insertion point is on one page and people navigate to another page, scroll back to
     the insertion point as soon as they begin to enter text." That argues for locking paging
     while the keyboard is up.
   - "Apply one scroll edge effect per view": each pane can have its own on iPad.

### What MacroFactor actually does (from the screenshots)

- **Top:** hamburger menu, elapsed clock, rest clock, then a horizontal **thumbnail strip** with
  one underline segment per exercise (the selected one is black). The "S/A" tile is either an
  exercise without an image shown as initials, or a superset marker; I can't tell which.
- **Below:** a full-width **page per exercise**. Screenshot 1 is mid-swipe: half of "…Overhand
  Grip T-Bar", half of "Wide Grip Cable…". The underline has **not** moved yet, so the
  selection updates when the swipe settles, not during the drag.
- **Each page holds:** title, "Set 1 of 3", a **horizontally scrolling chip row** (sparkle,
  Info, Warm Up, Targets, Swap, …), a set table with W/1/2/F badges, "Previous" with RIR, kg
  and reps cells, a checkbox, a "+" add-set button and a Program Note card.
- **What it leaves out:** no swipe-to-delete on rows (the badge is the menu), no bottom CTA,
  and no inline Up Next list.
- **Why it works there:** pages carry no horizontal row gestures, so the pager has the
  horizontal axis to itself. The one exception is the chip row, the HIG violation above.

---

## 1. Every option, and what breaks

Each option below is described by:
- its **structure** (outer → page → table),
- the **gesture** conflicts,
- the **keyboard** behaviour (focus survival and avoidance),
- what **state** survives,
- **a11y** (accessibility),
- **perf** (performance),
- iOS 26 **glass** bar behaviour,
- how well it serves **the jobs**: log, overview, reorder, supersets, rest timer, CTA.

### A. Vertical, single List (the family today's screen is in)

**A1. Today: List of current card + Up Next + Completed (hybrid).**
- **Gesture:** only vertical scrolling plus row swipes. No conflicts.
- **Keyboard:** one List, and the card rows are stable while typing. Robust. Switching card
  re-identifies the rows, which drops the keyboard; that is correct behaviour.
- **State:** a single scroll offset. Switching exercise reflows the whole List; the card is
  always on top.
- **a11y:** best. Linear, with headers and the "Opens this exercise" hint.
- **Perf:** one card's rows plus N light rows. One `TimelineView` for the clock and one for rest.
- **Glass:** `safeAreaBar` plus `.scrollEdgeEffectStyle(.hard, for: .top)` on the List.
  Verified working today.
- **Jobs:**
  - Logging is one tap on the CTA.
  - Overview is good but costs a scroll, since Up Next sits below a tall card.
  - Reorder uses `onMove` in Up Next, plus Do Next/Later.
  - Supersets: the card swaps in place. It works but there is no spatial cue.
  - Rest is an inline row plus the CTA.

**A2. HEAD: List of `DisclosureGroup`s, one expanded.**
- **Gesture:** none.
- **Keyboard:** expanding or collapsing another group animates the rows above the focused field
  and can push it off screen, and the List rarely restores it. Medium risk.
- **Jobs:**
  - Overview is good: everything is in one list.
  - Logging needs an expand tap. HEAD had no log CTA.
  - `onMove` on expanded groups behaves oddly, because a drag lifts the whole group including
    its rows. [known: reordering an expanded `DisclosureGroup` is glitchy]
  - Supersets: two groups are expanded at once only if you change the single-id model.

**A3. List `.plain`, one `Section` per exercise with a sticky header, all expanded.**
- Plain-style Lists pin section headers natively [known], so you get "pinnedScrollableViews"
  without leaving List.
- **Keyboard:** robust.
- **Jump to current set:** `ScrollViewReader.scrollTo(setId)`.
- **Overview:** weak. A 7-exercise × 4-set workout is about 40 rows.
- **Supersets:** good, because the partners are adjacent and you only scroll a little.
- **Visual:** you lose the inset-grouped card look. `listRowBackground` and
  `listSectionMargins` still work.
- **Perf:** fine, since List cells are reused. A UITextField in a reused cell is rebuilt on
  scroll, so focus drops if the focused row scrolls far off. [uncertain whether
  UICollectionView keeps a first-responder cell alive here]

**A4. `Section(isExpanded:)` collapsible sections.**
- Collapse affordances render only in `.listStyle(.sidebar)`. [known] On iPhone that style
  looks wrong for this screen.
- Otherwise it behaves like A2.

**A5. `OutlineGroup` (exercise → sets).**
- Needs homogeneous tree data. The set table is heterogeneous (header, note, column headers,
  rest row, Add Set). Not viable.

**A6. `ScrollView` + `LazyVStack(pinnedViews: [.sectionHeaders])`.**
- Every List modifier in `SetTracker*` stops working (constraint 1): swipe actions, row
  highlight, separators, insets and `onMove`.
- **Keyboard:** keyboard avoidance in a ScrollView works. Lazy stacks can drop the focused
  row's view when it scrolls far off. [known]
- **Cost:** high, for no gain over A3.

**A7. `Form` instead of `List`.**
- On iOS, `Form` is a grouped List with form styling. Same capabilities, same gestures. Nothing
  to gain; listed only for completeness.

### B. Horizontal pager of per-exercise pages (the MacroFactor family)

Common rules for every B option:

- **Each page is its own `List`.** This is what lets `SetTrackerView` work unchanged.
- **Height in a horizontal ScrollView is fine.** A horizontal `ScrollView` proposes its own
  height on the cross axis, so a greedy `List` with `.containerRelativeFrame(.horizontal)`
  fills the page. [known] (The well-known zero-height trap is a `List` inside a **vertical**
  ScrollView. That does not apply here.)
- **Gesture conflicts:**
  - *Page pan vs row `swipeActions`.* Both are horizontal pans, on the outer UIScrollView and
    on the inner UICollectionView cell. Which one wins on SwiftUI's hosting stack is
    **[uncertain]**. Expect trailing full-swipe Delete to fire sometimes when the user meant to
    page, which is a data-loss hazard. The safe design is to **drop `.swipeActions` in paged
    mode**. Every action survives without it: the existing `.contextMenu` carries Rest Timer
    and Delete, and the set-number `Menu` is still there.
  - *Pager vs chip row.* The page header has no horizontal ScrollView today: the card uses the
    overflow `actionsMenu`. Keep it that way, and do not copy MacroFactor's chip row (HIG
    nesting rule).
  - *Back swipe.* At the tracker's root there is no back swipe. iOS 26 lets content swipe back
    from anywhere on a pushed screen. **[uncertain]** how it interacts with a horizontal pager
    on a *pushed* screen. Not relevant unless the pager is pushed (it isn't).
- **Keyboard:**
  - While a field is first responder the keyboard stays up across a page swipe, editing a
    field on a page you can no longer see.
  - **Fix:** `.scrollDisabled(isKeyboardVisible)` on the pager, plus a global resign on
    programmatic page changes. The keyboard has its own Next/Done, so locking paging costs
    nothing.
  - Keyboard avoidance: whether the inner List receives the keyboard safe-area inset through a
    horizontal ScrollView is **[uncertain]**. Prototype it first.
- **Selection sync:**
  - Bind `scrollPosition(id:)` to a presenter property.
  - In the binding's setter, only set `expandedExerciseId`/`currentExerciseIndex`. No haptic,
    no analytics, no Live Activity.
  - Do the haptic, `exerciseSelected` and `refreshLiveActivity()` in
    `onScrollPhaseChange { if new == .idle }`.
  - Whether the binding updates mid-drag or only at settle is **[uncertain]**; the screenshots
    suggest MacroFactor updates at settle. Commit work at idle either way.
- **"Peek" vs "position":** a swipe to look at the next exercise moves the CTA and the Live
  Activity, because both follow the card. Either accept it (it matches today: opening an Up
  Next row does the same) or split it into a `viewedExerciseId` and a `positionExerciseId`.
  Splitting means touching `primaryAction` and the Live Activity logic and their tests.
  Recommend accepting it.
- **Rest:** only the selected page gets `restTimer` (constraint 4).
- **a11y:**
  - VoiceOver reads off-screen pages that are already built. Add
    `.accessibilityHidden(id != selection)`.
  - Give the strip `.accessibilityAdjustableAction` ("Exercise 3 of 8, Lat Pulldown", swipe up
    or down to change).
  - Three-finger scroll on a SwiftUI paging ScrollView: **[uncertain]** whether it announces a
    page.
  - Reduce Motion: drive programmatic page changes with `withReducedMotionAnimation` (the repo
    helper), and do not use `.scrollTransition` effects.
- **Supersets:** a page per *exercise* means every logged set flips the page (the
  `advanceWithinSuperset` round-robin), which is disorienting. **A page per *block*** (a single
  exercise, or a whole superset/circuit with its member tables as Sections of one List) removes
  the flipping.

**B1. `ScrollView(.horizontal)` + `LazyHStack` + `.paging` + `containerRelativeFrame` +
`scrollPosition(id:)`, page = List, strip in `safeAreaBar`.**
- **Perf:** only visible pages and their neighbours are built.
- **State:** dropped pages lose their List scroll offset and the Auto/Last toggle
  (`SetTrackerPresenter.showAutoRanges` is page-local `@State`). Move per-exercise UI state into
  the tracker presenter keyed by exercise id. On page appear, `ScrollViewReader.scrollTo` the
  current set.

**B2. B1 with an eager `HStack`.**
- **State:** every page stays alive, so offsets and toggles survive.
- **Perf:** N `UICollectionView`s and about 10–20 UITextFields each, all re-evaluated per
  keystroke (constraint 5). Fine for 5 exercises, sluggish at 12 or more. **[uncertain]**
  without profiling.
- **a11y:** all pages are in the accessibility tree, so `accessibilityHidden` is mandatory.

**B3. B1 with `.viewAligned(limitBehavior: .alwaysByOne)`, peeking via
`.contentMargins(.horizontal, Spacing.l)` and `.scrollClipDisabled()`.**
- **Overview:** the next exercise's edge shows, which hints the next page is there.
- **Cost:**
  - Lists clipped by neighbours' margins look odd.
  - `scrollClipDisabled` makes neighbouring Lists draw under the bars.
  - The peeking edge of the next page takes horizontal swipes meant for row actions.
- **Reduce Motion:** `.scrollTransition` scale and opacity effects must be disabled under Reduce
  Motion manually.

**B4. `TabView(selection:)` + `.tabViewStyle(.page(indexDisplayMode: .never))`, strip bound to
the selection.**
- **Pluses:**
  - Native page semantics.
  - VoiceOver page announcements are more likely. **[uncertain]** on iOS 26.
  - A plain `selection` binding; no scroll-target plumbing.
- **Minuses:**
  - Historically fragile when the page set changes while displayed (add, delete, reorder),
    showing blank pages or the selection jumping. **[known]** through iOS 17. **[uncertain]**
    on 26.
  - Page content and safe areas interact oddly; Lists inside sometimes get a doubled top
    inset. **[known, intermittent]**
  - Neighbouring pages are kept alive by the backing collection view, so `@State` retention is
    **[uncertain]**.
  - `.scrollDisabled` may not lock TabView paging. **[uncertain]** You may need
    `.disabled`-free tricks or `.allowsHitTesting`.
- **The repo already chose against it** in `MacroHeader`, for a different reason (dot space).

**B5. `TabView(.page)` with index dots.**
- Same as B4, plus dots that stop being countable past about 10 (HIG), and the reserved dot
  space (MacroHeader's finding).

**B6. `TabView` `.tabBarOnly` or `.sidebarAdaptable`, one tab per exercise.**
- **Wrong semantics:** tabs are app sections. You would get a second tab bar inside a cover
  over the app's own tab bar.
- **iPad:** `sidebarAdaptable` gives a sidebar list, which is attractive, but there is no
  reorder (tab customisation is not workout order) and dynamic tabs churn.
- **State:** good, since tabs keep their state.
- Reject.

**B7. Pager of `ScrollView { VStack }` pages (not List).**
- Removes the swipe-action conflict by removing swipe actions, but also loses everything in
  constraint 1. Higher cost than B1 with nothing gained.

### C. Nesting permutations

- **C1. Horizontal pager containing Lists.** This is B1/B2/B4. Viable.
- **C2. A List containing a horizontal pager row** (exercise tables as pages inside one row).
  - Tables cannot be Lists: a List in a List row has no intrinsic height.
  - The row height must equal the tallest page, or animate per page.
  - Cell reuse resets the pager's position.
  - The pager is a horizontal scroll inside a cell with horizontal swipe actions.
  - **Broken on several axes.**
- **C3. `TabView(.page)` inside a List row.** Needs a fixed `.frame(height:)`, cannot size to
  its content, and resets on reuse. [known] Only usable for fixed-height carousels. Not for set
  tables.
- **C4. `TabView(.page)` containing `ScrollView`/`List`.** This is B4. Viable, with B4's
  caveats.
- **C5. `ScrollView(.horizontal)` containing Lists.** This is B1. Each page needs
  `.containerRelativeFrame(.horizontal)`. Without it the List gets an unbounded width proposal
  and collapses or expands unpredictably. [known]
- **C6. Pager plus a persistent bottom sheet** (`presentationDetents([.height(…), .large])`,
  `.presentationBackgroundInteraction(.enabled(upThrough:))`, `interactiveDismissDisabled`).
  - **Router:** blocks every router sheet the rows and cards present (constraint 7). SwiftUI
    will not present a second sheet from under a presented one.
  - **Keyboard:** the inputView keyboard rises over the sheet.
  - **CTA:** collides with `bottomCTA`.
  - The memory note about stale bindings in routed sheets applies too.
  - Reject.
- **C7. Thumbnail strip + pager synced through `scrollPosition`.**
  - Two scroll views; the strip is a viewer of `selection`.
  - Drive the strip with `ScrollViewReader.scrollTo(id, anchor: .center)` in
    `onChange(of: selection)`, not a second `scrollPosition` binding. Two `scrollPosition`
    bindings to one value fight while the user scrolls the strip. [known pattern]
  - Tapping a thumbnail sets `selection` with animation.
  - The strip works as a navigator with **any** content container, not only a pager. See D2.
- **C8. Pager inside `NavigationStack` with a push per exercise** (exercise list root → push the
  exercise).
  - **Supersets:** push/pop churn on every set.
  - **Gesture:** the iOS 26 content back-swipe competes with leading row swipes. [uncertain]
  - **Overview:** excellent at the root.
  - **Logging:** costs a tap per exercise and a back per return.
- **C9. Overview List; exercise as a `.sheet` (`.large`).** Like C8, but modal. Row sheets
  would present from the sheet's router (workable with SwiftfulRouting). Drag-to-dismiss on top
  of a scrolling List is fine. A medium option, with no advantage over A1.
- **C10. Keyboard in a sheet instead of `inputView`.** Loses hardware-keyboard typing, system
  keyboard placement, avoidance and input clicks. The `SetKeyboardTextField` header comment
  explains why `inputView` was chosen. Reject.
- **C11. `.inspector` holding Up Next and Completed.** Trailing column on iPad, sheet on iPhone.
  On iPad regular width it is a cheap second column, inside the NavigationStack, with its own
  edge effect. On iPhone it collapses to C9-like behaviour, so gate it to regular width.
- **C12. `NavigationSplitView` inside the cover.** The cover's root is already a
  NavigationStack (RouterView). Nesting a split view in a stack is unsupported territory.
  Reject in favour of C13 or C11.
- **C13. iPad two-column `HStack` (overview List | exercise List).**
  - Switch at `width >= ContentWidth.twoColumns`, measured with `onGeometryChange`, and widen
    through `.preferredReadableContentWidth(ContentWidth.dashboard)`. Same mechanics as
    `Dashboard`.
  - Gives two scroll views with two edge effects (HIG-sanctioned per pane). `onMove` works in
    the left column, and the keyboard stays robust in the right one.
- **C14. Pages per *block*** (a single exercise, or a superset as one page). A modifier on
  B1/B4; strongly recommended if you page.

### D. Hybrids that borrow MacroFactor's navigator without the pager

- **D1. A1 + a compact strip in the `safeAreaBar`** (thumbnails with a per-exercise progress
  underline; tap = `onExerciseSelected`). Up Next and Completed stay below.
  - **Overview:** at a glance.
  - **Cost:** no new gestures and no keyboard risk.
  - **Duplication:** the strip repeats what Up Next shows. Fine, or slim Up Next down to the
    reorder affordance.
- **D2. D1, but Up Next and Completed move into an "All Exercises" sheet** opened from a strip
  trailing button. The sheet is a List with `onMove`, Do Next/Later and Completed: today's
  sections moved verbatim. The main List becomes just the current exercise (or block), which
  is MacroFactor's look with no horizontal paging.
- **D3. D2 + `.gesture(DragGesture)` on the card header only, to swipe to next or previous.**
  A custom gesture limited to the header avoids the row conflict. It is unidiomatic with no
  live drag preview, and you still need the a11y actions. Skip.

---

## 2. Scores

Scale 1–5, where 5 is best. **Cost** is inverted: 5 means cheapest in this codebase.
**Keyboard** covers focus survival, avoidance and page-change safety. **Gesture** means no
ambiguous or destructive gesture overlaps.

| # | Container (outer → page → table) | Taps-to-log | Overview | Gesture safety | Keyboard | Cost | A11y | Total |
|---|---|---|---|---|---|---|---|---|
| A1 | Today: List [card · Up Next · Completed] | 5 | 3 | 5 | 5 | 5 | 5 | 28 |
| D1 | A1 + thumbnail strip in safeAreaBar | 5 | 5 | 5 | 5 | 4 | 4 | **28** |
| D2 | Strip + single-exercise List + "All Exercises" sheet (onMove) | 5 | 4 | 5 | 5 | 4 | 4 | **27** |
| C13 | iPad: HStack [overview List │ exercise List] (phone falls back to D1) | 5 | 5 | 5 | 5 | 4 | 5 | **29** (iPad only) |
| C11 | iPad: `.inspector` with Up Next/Completed | 5 | 4 | 5 | 5 | 4 | 4 | 27 (iPad only) |
| B1+C14 | ScrollView(.h)+LazyHStack+.paging, page = **block** List, strip, swipeActions off, scrollDisabled while typing | 5 | 4 | 4 | 4 | 3 | 3 | **23** |
| B1 | Same, page = exercise, swipeActions kept | 5 | 4 | 2 | 3 | 3 | 3 | 20 |
| B2 | B1 with eager HStack | 5 | 4 | 2 | 3 | 3 | 2 | 19 |
| B3 | B1 with .viewAligned + peek + scrollClipDisabled + scrollTransition | 5 | 4 | 2 | 3 | 2 | 2 | 18 |
| B4 | TabView(selection:) .page(.never) + strip, page = List | 5 | 4 | 3 | 3 | 3 | 4 | 22 |
| B5 | TabView .page with dots | 4 | 2 | 3 | 3 | 4 | 4 | 20 |
| B6 | TabView tabBarOnly / sidebarAdaptable, tab per exercise | 3 | 3 | 5 | 4 | 2 | 3 | 20 |
| B7 | Pager of ScrollView{VStack} pages | 5 | 4 | 4 | 3 | 1 | 3 | 20 |
| A2 | HEAD: List of DisclosureGroups | 4 | 4 | 5 | 3 | 5 | 4 | 25 |
| A3 | List .plain, sticky header per exercise, all expanded | 4 | 2 | 5 | 4 | 4 | 4 | 23 |
| A4 | Section(isExpanded:) .sidebar | 4 | 4 | 5 | 3 | 3 | 4 | 23 |
| A5 | OutlineGroup | 3 | 3 | 4 | 3 | 1 | 3 | 17 |
| A6 | ScrollView+LazyVStack pinned headers | 4 | 2 | 4 | 3 | 1 | 4 | 18 |
| A7 | Form | 5 | 3 | 5 | 5 | 4 | 5 | 27 (≡ A1) |
| C2 | List containing pager row | 4 | 3 | 1 | 2 | 1 | 2 | 13 |
| C3 | TabView(.page) inside List row | 4 | 3 | 2 | 2 | 1 | 2 | 14 |
| C6 | Pager + persistent bottom sheet | 4 | 4 | 3 | 1 | 1 | 2 | 15 |
| C8 | Overview root → push exercise | 3 | 5 | 4 | 5 | 3 | 5 | 25 |
| C9 | Overview → exercise sheet | 3 | 4 | 4 | 4 | 3 | 4 | 22 |
| C10 | Keyboard in a sheet | 2 | – | 3 | 1 | 1 | 2 | — |
| C12 | NavigationSplitView in the cover | 4 | 5 | 4 | 4 | 1 | 4 | 22 |
| D3 | D2 + header-only drag to change exercise | 5 | 4 | 4 | 5 | 3 | 3 | 24 |

How to read it:
- **A1, D1, D2 and C13 dominate.** Their only weakness is "no swipe between exercises".
- **The best pager (B1 + C14) loses about 5 points.** The costs are gesture safety (you must
  give up row swipe actions), keyboard handling (lock while typing, resign on change), cost
  (selection plumbing, per-exercise state lifted into the presenter, rest-row gating) and
  VoiceOver work.
- **What a pager buys** is the swipe-to-glance-at-the-next-exercise feel and spatial
  continuity. That is real but small next to its risks, and every pager option here also needs
  the strip.

---

## 3. Top three, with skeletons

### #1 D1, extending to D2: a thumbnail strip over today's List

Keep the List. Put a MacroFactor-style strip in the existing `safeAreaBar`, with the counts
line underneath it. Tapping a thumbnail calls the existing `onExerciseSelected`. The underline
is per-exercise progress (logged ÷ working sets). Ship it as D1. If Up Next feels redundant
afterwards, move it into a sheet (D2) and leave only the card on the main List.

```swift
// WorkoutTrackerView.swift: replaces `progressHeader` inside .safeAreaBar(edge: .top)
@ScaledMetric(relativeTo: .body) private var thumbSide = ControlSize.thumbnail

private var exerciseStrip: some View {
    ScrollViewReader { proxy in
        ScrollView(.horizontal) {
            LazyHStack(spacing: Spacing.xs) {
                ForEach(presenter.workoutSession.exercises) { exercise in
                    let isCurrent = exercise.id == presenter.currentExercise?.id
                    Button { presenter.onExerciseSelected(exercise.id) } label: {
                        VStack(spacing: Spacing.xxs) {
                            ExerciseImageView(name: exercise.name, imageName: exercise.imageName)
                                .frame(width: thumbSide, height: thumbSide)
                                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                            ProgressView(value: presenter.stripProgress(for: exercise))
                                .tint(isCurrent ? Color.accentColor : .secondary)
                        }
                        .frame(width: thumbSide)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exercise.name)
                    .accessibilityValue(presenter.upNextSummary(for: exercise))
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .id(exercise.id)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        // ScrollViewReader, not a second scrollPosition binding (see CalendarView's note).
        .onChange(of: presenter.currentExercise?.id) { _, id in
            withReducedMotionAnimation(.standard) { proxy.scrollTo(id, anchor: .center) }
        }
    }
}
// Presenter (+ActiveExercise): one line, reusing the model's counts.
// func stripProgress(for e: WorkoutExerciseModel) -> Double {
//     e.workingSetCount == 0 ? 0 : Double(e.loggedSetCount) / Double(e.workingSetCount) }
```

Notes:
- **Images.** `ExerciseTrackerView` resolves images through `presenter.imageName(for:)`, not
  `exercise.imageName`. Use whichever the Up Next rows use (`ListRow`'s `imageName:
  exercise.imageName`) so the strip matches them.
- **Accessibility sizes.** Swap the strip for the current "Exercise 3 of 8" text line plus a
  `Menu` of exercises. 44 pt thumbnails at AX5 crowd the bar.
- **Edge effect.** `.scrollEdgeEffectStyle(.hard, for: .top)` stays on the List.
- **Tests.** `WorkoutTrackerPresenterTests` already covers `onExerciseSelected`. Add one test
  for `stripProgress`.

### #2 B1 + C14: a block pager, if swiping between exercises is a must-have

```swift
// ExercisePager.swift: a generic view with no presenter. Pages are blocks: an exercise, or a
// superset with every member.
struct ExercisePager<Page: View>: View {
    let pageIds: [String]
    @Binding var selection: String?
    let isLocked: Bool                    // the set keyboard is up
    var onSettled: () -> Void
    @ViewBuilder var page: (String) -> Page

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pageIds, id: \.self) { id in
                    page(id)
                        .containerRelativeFrame(.horizontal)
                        .accessibilityHidden(id != selection)
                        .id(id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selection)
        .scrollIndicators(.hidden)
        .scrollDisabled(isLocked)
        .onScrollPhaseChange { _, phase in if phase == .idle { onSettled() } }
    }
}

// WorkoutTrackerView.body, replacing List { … }
ExercisePager(
    pageIds: presenter.blockIds,
    selection: Binding(get: { presenter.currentBlockId },
                       set: { presenter.onPageScrolled(to: $0) }),   // ids only: no haptic, no Live Activity
    isLocked: isKeyboardVisible,
    onSettled: presenter.onPageSettled                             // haptic, event, refreshLiveActivity
) { blockId in
    List {
        ForEach(presenter.members(ofBlock: blockId)) { member in
            Section { exerciseTrackerView(delegate(for: binding(member.id),
                                                   showsRest: blockId == presenter.currentBlockId), startRest) }
        }
    }
    .scrollEdgeEffectStyle(.hard, for: .top)
    .environment(\.defaultMinListRowHeight, Spacing.xl)
}
.safeAreaBar(edge: .top) { exerciseStrip }   // from #1, bound to the block id
.bottomCTA { /* unchanged */ }
```

Required changes beyond the skeleton:
1. **Rest row.** `delegate(for:)` gets `showsRest`; pass `restTimer: nil` off the current block
   (constraint 4).
2. **Swipe actions.** `SetTrackerRowView` drops `.swipeActions` when a new
   `SetTrackerRowDelegate.allowsSwipeActions` is false. The context menu already carries both
   actions.
3. **Per-exercise state.** Lift `SetTrackerPresenter.showAutoRanges` into the tracker presenter,
   keyed by exercise id, or it resets when a lazy page is dropped.
4. **Programmatic moves.** Wrap them (`advanceWithinSuperset`, CTA `.next`, Do Later) in
   `withReducedMotionAnimation`, and resign first responder before them.
   `advanceWithinSuperset` no longer needs to move pages inside a block. Inside a block, the
   current set highlight should move to the partner's row, plus a `ScrollViewReader.scrollTo`.
5. **Up Next and Completed** become the "All Exercises" sheet from D2; that is where `onMove`
   lives.
6. **Prototype these [uncertain] items before committing:**
   - keyboard inset reaching the inner List,
   - when the `scrollPosition` binding writes,
   - `safeAreaBar` and the edge effect with Lists nested inside a horizontal ScrollView.

### #3 C13: iPad two-column (pairs with #1 or #2 on the phone)

```swift
// WorkoutTrackerView.swift
@State private var width: CGFloat = 0
private var isTwoColumn: Bool { width >= ContentWidth.twoColumns }

var body: some View {
    Group {
        if isTwoColumn {
            HStack(spacing: 0) {
                List {                                   // overview column: reorder lives here
                    upNextSection                          // existing, with .onMove
                    completedSection                       // existing
                    addExerciseSection
                }
                .frame(width: 320)
                .scrollEdgeEffectStyle(.hard, for: .top)
                Divider()
                List { currentExerciseSection }          // existing card, unchanged
                    .scrollEdgeEffectStyle(.hard, for: .top)
            }
        } else {
            phoneLayout                                  // today's List, or #2's pager
        }
    }
    .preferredReadableContentWidth(ContentWidth.dashboard)   // escape the 700 pt cap
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .environment(\.editMode, $presenter.editMode)
    .safeAreaBar(edge: .top) { progressHeader }
    .bottomCTA { /* unchanged; it spans both columns, or move it under the right column */ }
    .toolbar { toolbarContent }
    // …the rest of today's modifiers, unchanged
}
```

Notes:
- **Why this layout.** Both columns are Lists, so constraint 1 holds, swipe actions and `onMove`
  work, and the keyboard is unchanged. The HIG allows one edge effect per pane.
- **The CTA spans both columns** with `bottomCTA` on the HStack. To put it under the exercise
  column only, move `.bottomCTA` onto the right-hand List.
- **`.inspector` (C11)** is the alternative: less code, but less control over width, and on
  iPhone it turns into a sheet, so gate it.

---

## 4. SwiftUI pitfalls specific to these options

1. **`List` inside a vertical `ScrollView`** collapses to zero height. A horizontal ScrollView is
   fine if each page has `.containerRelativeFrame(.horizontal)`. Without it the List gets an
   unbounded width proposal.
2. **`TabView(.page)` inside a `List` row** needs a fixed height, cannot size to content, and is
   rebuilt (selection reset) when the cell is reused.
3. **`TabView(.page)` reserves space for its index dots** inside the content even when they are
   empty, which is MacroHeader's finding; `.never` removes the dots. Page TabViews have also
   historically gone blank or jumped when pages were inserted, deleted or reordered while
   showing. This tracker reorders constantly (Do Next/Later, superset moves).
4. **`swipeActions` inside a horizontal pager.** Two horizontal pans compete, and the winner
   depends on where the touch starts and how fast it moves. A trailing `allowsFullSwipe: true`
   Delete is the dangerous one. `swipeActions` only does anything in `List`, and it is silently
   ignored in `LazyVStack`/`ScrollView`.
5. **`onMove` exists only on `ForEach` inside `List`** (or `Form`). There is no reorder for a
   ScrollView strip without `draggable`/`dropDestination` and your own insertion logic, so
   reorder belongs in a List: Up Next, a sheet, or the iPad column. (Done that way on 8 Oct
   2026: the strip's thumbnails are `draggable` and every thumbnail plus Add is a
   `dropDestination`; a dropped block takes the place of the thumbnail it landed on, the target
   is ringed while hovered, and Move Earlier/Later sit in the menu and the actions rotor.)
6. **`scrollPosition(id:)`** only matches the scroll target layout's *immediate* children
   (CalendarView's note). Wrap a block page in a `Section` or `Group` and it stops resolving.
   Two `scrollPosition` bindings to the same value (strip and pager) feed back while the user
   drags. Drive the strip with `ScrollViewReader`.
7. **Setting `scrollPosition` before the layout exists does nothing.** MacroHeader sets its page
   in `onAppear` for this reason. Do the same for the initial page.
8. **Lazy stacks drop off-screen children.** Any `@State` in them (scroll offset, Auto/Last,
   `SetKeyboardInputHost`) may be lost. Keep anything that must survive in a presenter keyed by
   id.
9. **The `UIViewRepresentable` first responder outlives its page.** A page swipe does not resign
   it. Lock paging while the keyboard is up, and send `resignFirstResponder` before programmatic
   moves.
10. **`updateUIView` focus is async** (`DispatchQueue.main.async`). If a programmatic page change
    and a row's `isActive` toggle happen in one transaction, the order is undefined. Resign
    first, then move the page on the next run loop, or in the scroll phase's `.idle`.
11. **`.scrollTransition` and Reduce Motion.** It ignores Reduce Motion; read
    `accessibilityReduceMotion` yourself. It is visual only, so it costs no layout, but scaled
    pages blur crisp table text mid-swipe.
12. **`.scrollClipDisabled()`** draws neighbouring pages outside the pager, including under the
    `safeAreaBar` and the CTA. With Lists as pages that looks broken.
13. **Edge effects.** `.scrollEdgeEffectStyle` belongs on the scroll view that runs under the bar:
    the inner List, not the pager. Whether a `safeAreaBar` attached outside a horizontal
    ScrollView picks up the inner List's edge is **[uncertain]**, so check it in a build.
    Today's `.background(Color.canvas)` on the header makes this mostly cosmetic.
14. **Live timers.** Today there are three: the title clock (`.periodic` 1 s), the rest row
    (`.explicit`, two redraws only) and the CTA's `Text(timerInterval:)` (system-driven, cheap).
    In a pager only the rest row multiplies, and only if `restTimer` is not gated per page.
15. **`Section(isExpanded:)`** has collapse UI only in `.sidebar` style.
16. **Nested `NavigationSplitView` in a `NavigationStack`** (the cover's RouterView) is
    unsupported. Use an HStack or `.inspector`.
17. **The HIG nesting rule.** If a pager ships, the chip row MacroFactor uses must not: keep the
    card's overflow `Menu`.

---

## 5. Recommendation

Ship **#1 (D1): the thumbnail strip in the existing `safeAreaBar` over today's List**, plus
**#3 (C13) two columns on iPad**. It gets the MacroFactor overview at a glance for about a
day's work. It keeps the parts of the screen that are already solid: the keyboard, swipe
actions, `onMove`, Live Activity sync and the single CTA. It introduces no gesture ambiguity.

Build **#2 (the block pager)** only if user testing says "I want to swipe to the next exercise".
Prototype the three [uncertain] items first, and accept losing row swipe actions in exchange.
Never page per exercise while supersets round-robin: page per block.
