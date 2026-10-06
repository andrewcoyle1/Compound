# Workout tracker redesign: HIG review (2026-10-06)

Read against the live HIG with the `apple-hig` skill (`hig.py get … --platform ios`, and
`--platform ipados` for scroll-views, tab-views, layout, sidebars, split-views and
designing-for-ipados). Every page fetched live; none came from the offline cache.

**Pages read:** designing-for-ios, designing-for-ipados, workouts, scroll-views, tab-views,
page-controls, lists-and-tables, collections, entering-data, text-fields, virtual-keyboards,
toolbars, tab-bars, sheets, modality, context-menus, menus, buttons, segmented-controls,
progress-indicators, gauges (followed from progress bars), live-activities, accessibility,
typography, materials, layout, gestures, feedback, playing-haptics, sidebars, split-views.
The iPadOS variants of scroll-views, tab-views and layout are word-for-word the same as the iOS
ones. Neither has an iPad-only section.

**Page dates that matter.** scroll-views changed 2026-06-08 (scroll edge effects). layout changed
2026-09-09. tab-bars changed 2026-06-08. toolbars and buttons changed 2025-12-16 (Liquid Glass).
page-controls was last changed in 2023, so it predates Liquid Glass. Its guidance on placement
and dot count still stands.

**Code read (working tree on `feature/workout-tracker-redesign`):**
`WorkoutTrackerView.swift`, `ExerciseTracker/ExerciseTrackerView.swift`,
`ExerciseTracker/SetTracker/SetTrackerView.swift`, `SetTrackerRow/SetTrackerRowView.swift`,
`InlineRestTimerRow.swift`, `ProgressionNote.swift`, plus `SetKeyboardTextField.swift`,
`Components/DesignSystem/BottomCTA.swift` and `CallToActionButton.swift` where a finding depended
on them. Paths below are relative to `Compound/Core/Training/Subviews/WorkoutTracker/` unless
given in full.

**Reference screenshots:** two MacroFactor screens, which page horizontally between exercises.
A strip of exercise thumbnails runs along the top with the current one underlined. Below it are
the exercise name, "Set 1 of 3", a row of action chips (Info, Warm Up, Targets, Swap), the set
table (Set / Previous / kg / Reps / checkbox) and a pinned program note. Body-size numbers
throughout. One screenshot is caught mid-swipe and shows the next page peeking in.

**Project decisions that take precedence** (CLAUDE.md, `docs/specs/ui-framework/CONTRACT.md`,
the README decisions, `docs/reviews/hig-decisions.md`):
- README decision 3: Finish stays in the tracker's menu. A Finish button animates into the
  bottom safe area once every set is done.
- hig-decisions 5b: Pause and Resume live in the tracker menu.
- hig-decisions 5d: Done on the set keyboard logs the set.
- Standing decision: tap targets on glass buttons keep the system's size. Not re-raised here.
- CONTRACT: `.bottomCTA` is `safeAreaInset(.bottom)`. Glass is allowed only in the navigation
  layer, which includes the pinned CTA and bars pinned over a scrolling list. Dismiss is
  `role: .close`. Sheets are presented through the router presets, which always include `.large`.
- README follow-up 7: Mac Catalyst is out of scope.

Where the HIG disagrees with one of these, the finding says so and leaves the decision alone.

**What I could and could not verify.** This review is from code only. Nothing was built or run.
- **Verified from code:** which text style each element uses; where Dynamic Type stacks the
  layout (accessibility sizes stack the set row); frames that guarantee 44 pt hit areas; which
  modifiers set colour and background; what Reduce Motion does to transitions; accessibility
  labels, values and traits.
- **Not verified:** Light and Dark contrast ratios; how the glass CTA and scroll edge actually
  look; behaviour at AX1–AX5; VoiceOver order; iPad at any width; Increase Contrast and Reduce
  Transparency; whether a long press on a focused set field raises the edit menu and the row's
  context menu together.

Text sizes quoted below are the Large (default) values from the typography page's
specification table: Caption 2 is 11 pt, Caption 1 12 pt, Subhead 15 pt, Headline and Body 17 pt.

---

## 1. Where the current design conflicts with the HIG

Most serious first.

### Set values can shrink to 9 pt, column headings to under 7 pt
Severity: hurts usability
Where: `ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard/SetKeyboardTextField.swift:78-79`
(`adjustsFontSizeToFitWidth = true`, `minimumFontSize = 9`);
`ExerciseTracker/SetTracker/SetTrackerView.swift:276-280` (`.caption2` with
`.minimumScaleFactor(0.6)`)
Guideline:
- "Use recommended defaults for custom type sizes … iOS, iPadOS: default 17 pt, minimum 11 pt"
  (https://developer.apple.com/design/human-interface-guidelines/accessibility)
- "Make sure text is legible for when people are in motion. When a session requires movement,
  use large font sizes, high-contrast colors, and arrange text so that the most important
  information is easy to read." (https://developer.apple.com/design/human-interface-guidelines/workouts)

The weight and reps fields are 70 and 50 pt wide. A long value such as "102.5" at a larger
standard size can shrink to 9 pt. The column headings start at Caption 2, which is already the
11 pt minimum, and 0.6 of that is about 6.6 pt.
Fix:
- Raise `minimumFontSize` to at least 11, or remove it and widen the columns.
- Drop `minimumScaleFactor(0.6)` from the headings. Let them wrap, or switch to the stacked
  layout earlier than `isAccessibilitySize`, for example at `.xxxLarge`.

### The set table's reference numbers are all caption-sized and secondary
Severity: hurts usability
Where:
- `SetTrackerRow/SetTrackerRowView.swift:318-322`: `columnText` uses `.caption`, secondary.
- `:414-416`: RIR uses `.caption2`, secondary.
- `:181-183`: the set number uses `.caption`.
- `InlineRestTimerRow.swift:44-54`: the rest countdown uses `.label`, which is `.caption`,
  in secondary.
- `WorkoutTrackerView.swift:133-137`: the progress counts use `.label`.
Guideline:
- "Make sure text is legible for when people are in motion … use large font sizes,
  high-contrast colors" (https://developer.apple.com/design/human-interface-guidelines/workouts)
- "Ensure text is easy to read. Use large, heavier-weight text … Use small text sparingly and
  make sure key information is legible at a glance."
  (https://developer.apple.com/design/human-interface-guidelines/live-activities). This is a
  Live Activity page, cited here as the closest at-a-glance rule.

Last session's numbers, the rest countdown and the set number are what people read between
sets, at arm's length. Here they are 11–12 pt in secondary grey, while the input fields are
Body. The MacroFactor reference sets "50 kg x 11" at body size.
Fix:
- Set the Last/Auto column in `.rowDetail` (Subhead, 15 pt) at least, with RIR in `.label`.
- Set the set number in `.rowDetail`.
- Set the inline rest time in `.metricSmall`, at primary or in the tint while it is running.

### Delete Set and the per-set rest timer are reachable only by swipe or long press
Severity: hurts usability
Where: `SetTrackerRow/SetTrackerRowView.swift:103-120`
Guideline:
- "Always make context menu items available in the main interface, too."
  (https://developer.apple.com/design/human-interface-guidelines/context-menus)
- "Offer alternatives to gestures. Make sure your UI's core functionality is accessible through
  more than one type of physical interaction … offer onscreen ways to achieve the same outcome."
  (https://developer.apple.com/design/human-interface-guidelines/accessibility)

The swipe actions and the context menu are both hidden routes, so a mirrored pair gives no
visible path. VoiceOver exposes swipe actions as custom actions, but sighted people who do not
know to swipe never find "Rest Timer".
Fix: each row already has a visible menu, the set-number circle (`setNumber`, `:162-193`). Add
"Rest Timer…" and a destructive "Delete Set" at its foot, after a `Divider`, and keep the swipe
and the context menu as shortcuts.

### Pausing leaves no visible sign that the workout is paused
Severity: hurts usability
Where: `WorkoutTrackerView.swift:150-166` (title) and `:126-147` (header). `presenter.isActive`
is read only by the menu label at `:354`. Nothing in the tracker's views says "Paused".
Guideline:
- "Provide workout controls that are easy to find and tap. In addition to making it easy for
  people to pause, resume, and stop a workout, be sure to provide clear feedback that indicates
  when a session starts or stops."
- "Use a distinct visual appearance to indicate an active workout."
  (both https://developer.apple.com/design/human-interface-guidelines/workouts)

While paused, the only cue is that the clock stops. Pause and Resume sit in the menu by
decision 5b, so that placement stands. The missing feedback is a separate gap.
Fix:
- While paused, show "Paused" in place of the clock in `titleView`. Change the header's bar to
  the secondary tint.
- Make the bottom CTA "Resume Workout" while paused. This is one prominent button, so it stays
  within the contract.

### Finish and Pause are buried in a six-item menu with no groups
Severity: polish. Placement is decided (README 3, hig-decisions 5b), so only the grouping is in
scope.
Where: `WorkoutTrackerView.swift:349-396`
Guideline:
- "Provide workout controls that are easy to find and tap … easy … to pause, resume, and stop
  a workout" (https://developer.apple.com/design/human-interface-guidelines/workouts)
- "Consider grouping logically related items … use a separator."
  (https://developer.apple.com/design/human-interface-guidelines/menus)

Fix: keep the placement. Add `Divider()` to make three groups:
1. Pause/Resume and Finish
2. Notes, Workout Settings and Gym Settings
3. Discard

For the owner: the workouts page argues for Pause and Finish being visible controls. On iPad
there is room to do that without changing the iPhone layout (see §3).

### Solid background under the pinned header, on top of a hard scroll edge
Severity: polish
Where: `WorkoutTrackerView.swift:145` (`.background(Color.canvas)`) and `:59`
(`.scrollEdgeEffectStyle(.hard, for: .top)`)
Guideline:
- "Differentiate controls from content … Instead of applying a solid or semi-opaque background
  color beneath controls, use a scroll edge effect to visually elevate controls above content."
  (https://developer.apple.com/design/human-interface-guidelines/layout, updated 2026-09-09)
- "Prefer the automatic scroll edge effect style. … This style provides a more opaque visual
  separation for … text that appears outside of Liquid Glass controls, and pinned table
  headers." (https://developer.apple.com/design/human-interface-guidelines/scroll-views,
  updated 2026-06-08)

The automatic style now covers the case the code comment worries about: text outside glass.
Fix: remove `.background(Color.canvas)` and try `.automatic`. Keep `.hard` only if a
highlighted row still bleeds through at AX sizes, which needs checking on device. Do not stack
both.

### The rest-state CTA puts two buttons of different sizes side by side
Severity: polish
Where: `WorkoutTrackerView.swift:64-86`. A full-width `glassProminent` "Skip Rest 1:27" sits next
to a narrow `.glass` "+15s".
Guideline: "Use style — not size — to visually distinguish the preferred choice among multiple
options. … placing two buttons of different sizes near each other can make the interface look
confusing and inconsistent."
(https://developer.apple.com/design/human-interface-guidelines/buttons)
Fix: give both equal width with `.frame(maxWidth: .infinity)` on each, and let style alone
mark Skip as preferred. Alternatively, move +15s into the inline rest row, beside the bar it
extends.

### Long press on a focused set field may raise two menus
Severity: polish. Unverified at runtime.
Where: `SetTrackerRowView.swift:115-120` (row `.contextMenu`) wrapping `SetKeyboardTextField`, a
`UITextField` that keeps its standard edit menu.
Guideline: "Provide either a context menu or an edit menu for an item, but not both. If you
provide both features for the same item, it can be confusing to people — and difficult for the
system to detect their intent."
(https://developer.apple.com/design/human-interface-guidelines/context-menus)
Fix: check on device. If both appear, either suppress the field's edit menu
(`canPerformAction` returning false, since paste into a custom keypad is of little use) or move
the context menu off the input cells.

### Chevron on Up Next rows that do not navigate
Severity: polish
Where: `WorkoutTrackerView.swift:242-251` (`accessory: .chevron`). Tapping moves the exercise
onto the card in place (`onExerciseSelected`). It does not push.
Guideline: "If you need to let people drill into a list or table row's subviews, use a
disclosure indicator accessory control."
(https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)
Fix: drop the chevron, or replace it with a "Start" glyph, so the row does not promise a push.

### Toggled menu items show their state only by tint
Severity: polish
Where: `SetTrackerView.swift:194-206`. "Split L/R" uses `.tint(isSplit ? .accentColor :
.secondary)` and `.isSelected`. Inside a `Menu` the tint is not drawn, so the state is
invisible to sighted people. The "Warmup Set" item at `SetTrackerRowView.swift:165` does this
correctly with a `Toggle`.
Guideline: "Consider using a checkmark to show that an attribute is currently in effect."
(https://developer.apple.com/design/human-interface-guidelines/menus)
Fix: `Toggle("Split L/R", isOn: …)` in the menu.

### Menu items that open a sheet lack an ellipsis
Severity: polish
Where: `SetTrackerView.swift:178-236` ("Equipment", "Warmup", "Targets", "Swap", "Superset") and
`WorkoutTrackerView.swift:369-385`.
Guideline: "Append an ellipsis to a menu item's label when the action requires more information
before it can complete." (https://developer.apple.com/design/human-interface-guidelines/menus)
Fix: use "Swap…", "Targets…", "Warmup Sets…", "Superset…", "Workout Notes…" and so on. These are
catalog strings, so the Spanish entries need the same change.

### Hidden scroll indicator on a long list
Severity: polish
Where: `WorkoutTrackerView.swift:43` (`.scrollIndicators(.hidden)`)
Guideline: "Make it apparent when content is scrollable. Because scroll indicators aren't always
visible, it can be helpful to make it obvious when content extends beyond the view."
(https://developer.apple.com/design/human-interface-guidelines/scroll-views)
Fix: remove the modifier. The exception is a horizontal pager with a page control, where the
page control replaces the indicator (see §2a).

### Done well. Keep these through the redesign.
- **Custom keypad as a real `inputView`** that plays `playInputClick` and keeps hardware keys
  working (`SetKeyboardTextField.swift`). This is exactly the "custom input view" pattern on
  virtual-keyboards.
- **The CTA steps aside while the keypad is up**, and the keypad's own Done logs the set.
- **The set row stacks at accessibility sizes**, which typography asks for: "consider using a
  stacked layout … Reduce the number of columns when the font size increases".
- **Current set is marked by more than colour:** a highlight, outlined fields, and
  `accessibilityValue("Next to log")`. A finished exercise gets a check as well as green, and the
  plate warning pairs an icon with text.
- **The title and clock offer the large content viewer**, since the navigation bar caps its
  text size.
- **Reorder sits behind an explicit Reorder/Done button**, the iOS edit mode lists-and-tables
  describes.
- **The progression note stays until tapped**, which follows accessibility: "Minimize use of
  time-boxed interface elements".
- **Exactly one prominent button per view**: Add Set is `.bordered`.

---

## 2. What the HIG says about each candidate container

### 2a. Horizontally paged exercises (paging scroll view, page control or thumbnail strip)

**Encouraged**
- scroll-views: "Consider supporting page-by-page scrolling if it makes sense for your content
  … define the size of such a page — typically the current height or width of the view". Doc:
  `PagingScrollTargetBehavior`.
- scroll-views: "It's alright to place a horizontal scroll view inside a vertical scroll view
  (or vice versa)". A horizontal pager whose pages are vertical lists is allowed.
- scroll-views: "Make it apparent when content is scrollable … displaying partial content at the
  edge of a view". MacroFactor's peeking next page does this.
- page-controls: "Use page controls to represent movement between an ordered list of pages."
  A workout's exercises are ordered.

**Constraints**
1. **Too many exercises for a page control.** "More than about 10 dots are hard to count at a
   glance. If your app needs to display more than 10 pages as peers, consider using a different
   arrangement‚ such as a grid" (page-controls). Many workouts run 6–12 exercises.
2. **Where a page control has to go.** "Center a page control at the bottom of the view or
   window" (page-controls). That spot is taken by the bottom CTA.
3. **A thumbnail strip is a horizontal collection, not a page control.** As a collection it is
   appropriate, because "collections are ideal for showing image-based content" and "Use the
   standard row or grid layout" (collections). Treated as a page control it would break "Avoid
   using more than two different indicator images" and "Avoid coloring indicator images".
4. **Selection in the strip.**
   - "persistently highlight[s] the selected row" (lists-and-tables, and split-views for
     panes). The current exercise must stay marked by more than colour: MacroFactor's underline,
     plus `.isSelected`.
5. **Page control and scroll indicator together.** "If you show a page control with a scroll
   view, don't show the scrolling indicator on the same axis" (scroll-views).
6. **Gesture collision. This is the hard one.**
   - Each set row has trailing and leading swipe actions (`SetTrackerRowView.swift:103-112`).
   - A horizontal page swipe over the same rows competes with them.
   - gestures: "respond to gestures in ways that are consistent with people's expectations"
     and custom gestures must be "Distinct from other gestures".
   - The Swipe row of the standard gestures table covers both "Reveal actions and controls"
     and "scroll".
   - You cannot keep both. Paging means dropping the row swipes and putting their actions in
     visible controls, which the §1 finding needs anyway.
7. **Moving to another exercise without being asked.**
   - collections: "avoid changing the layout while people are viewing and interacting with it,
     unless it's in response to an explicit action". Paging to the next exercise must wait for
     the "Next: …" tap and never happen after a timer.
   - scroll-views, on scrolling automatically: "only as much as necessary to help people retain
     context."
8. **Reduce Motion.** Swiping between pages follows the finger, which the accessibility page
   allows: "Tracking animations directly with people's gestures". A jump from tapping a
   thumbnail is different. Under Reduce Motion it should cross-fade: "Replacing transitions in
   x-, y-, and z-axes with fades". page-controls also says "Avoid animating page transitions
   during scrubbing."
9. **Reordering and Do Later.**
   - The Up Next list's Reorder, Do Next and Do Later have to survive the move to a strip.
   - collections: "touch and hold to edit", and "use animations to provide feedback when people
     insert, delete, or reorder items".
   - Any context menu on a thumbnail still needs a visible equivalent (context-menus).
10. **Text belongs in lists.**
    - lists-and-tables: "Prefer displaying text in a list or table".
    - collections: "Consider using a table instead of a collection for text."
    - The set table must stay a list inside each page. Only the thumbnails are a collection.

### 2b. `TabView` used for content paging
- **tab-views on iOS and iPadOS:** "Not supported in iOS, iPadOS … For similar functionality,
  consider using a segmented control instead." The tab-views page does not govern a tabbed
  `TabView` on iPhone.
- **`TabView(.page)` is `PageTabViewStyle`.** page-controls lists it as that page's developer
  API, so every constraint in 2a applies, including the 10-dot limit and the bottom-centre
  placement.
- **A tab bar is the wrong tool.**
  - "Use a tab bar to support navigation, not to provide actions" between top-level sections
    (tab-bars).
  - The tracker is a full-screen cover, so the app's own tab bar is correctly hidden: "The
    exception is when a modal view covers the tab bar" (tab-bars).
  - A second tab bar for exercises would misuse the component.
- **A segmented control does not scale to exercises.**
  - "no more than about five segments on iPhone" (segmented-controls).
  - Its job is "closely related subviews", such as switching the Last and Auto columns. That
    toggle (`SetTrackerView.swift:310-329`) is a candidate for a two-segment control, which
    would show both options and the selection: "clearly show their selection state".

### 2c. Collapsible lists (one exercise expanded, the rest as rows)
This is the most strongly supported option, and it is close to what the code does now.
- layout: "Use progressive disclosure to make layouts cleaner … Use disclosure triangles,
  menus, or nested views to reduce how much content to initially display."
- lists-and-tables: "Prefer displaying text in a list or table", and reordering in edit mode is
  standard.
- designing-for-ios: "limiting the number of onscreen controls while making secondary details
  and actions discoverable with minimal interaction".

Constraints:
- **Collapsing on its own is risky.** Collapsing or expanding exercises automatically after a set
  is logged is a layout change while people are interacting (collections). Tie it to the
  explicit "Next" action, and scroll only as far as needed (scroll-views).
- **Keep hierarchy at every size.** typography: "keep primary elements toward the top of a view
  even when the font size is very large". The open card must stay first at AX sizes.

### 2d. A bottom sheet for the keyboard
The HIG points away from this.
- **Use an input view instead.** virtual-keyboards: "A custom input view replaces the
  system-provided keyboard while people are in your app." Its doc points to
  `ToolbarItemPlacement` and `inputViewController`, not to sheets. "Play the standard keyboard
  sound" also applies. The current `UIInputView` already meets all of this.
- **One sheet at a time.** sheets: "Display only one sheet at a time from the main interface."
  The tracker already presents the rest picker, warm-ups, swap, targets and notes as sheets, so
  a keypad sheet would stack under them.
- **A non-modal sheet carries extra duties.** sheets allows a non-modal sheet on iOS "to present
  supplementary items that affect the main task in the parent view", as Notes does for
  formatting. It must then have a grabber, support swipe-to-dismiss, and keep `.large` per the
  contract. It would also hide the very rows it edits, and it loses the hardware-keyboard path.
- **Controls above the keypad.** virtual-keyboards: "If other views in your app use Liquid
  Glass, or if your view looks out of place above the keyboard, apply Liquid Glass to the view
  that contains your controls … Use the keyboard layout guide and standard padding". This
  applies to any plate or effort row above the keys.

### 2e. Persistent bottom CTA on Liquid Glass
Encouraged:
- designing-for-ios: "it tends to be easier and more comfortable for people to reach a control
  when it's located in the middle or bottom area of the display".
- workouts: "Provide workout controls that are easy to find and tap."
- materials: "Liquid Glass forms a distinct functional layer for controls and navigation
  elements … that floats above the content layer". A pinned CTA belongs in that layer, and the
  contract agrees.

Constraints:
- **Keep glass out of the content layer.** "Don't use Liquid Glass in the content layer" and
  "Use Liquid Glass effects sparingly … Limit these effects to the most important functional
  elements" (materials). Nothing in the set table should be glass. `.bordered` Add Set is
  correct.
- **One or two prominent buttons per view.** "Keep the number of prominent buttons to one or
  two per view" (buttons). A destructive action never takes the primary role.
- **Equal sizes for paired buttons.** "Use style — not size" (buttons). See the rest-state
  finding in §1.
- **A busy state belongs inside the button.** "Configure a button to display an activity
  indicator when you need to provide feedback about an action that doesn't instantly complete"
  (buttons, iOS). This applies if Finish saves remotely.
- **Scroll edge under the CTA.**
  - layout: "use a scroll edge effect to visually elevate controls above content".
  - scroll-views: "Only use a scroll edge effect when a scroll view is behind floating
    interface elements".
  - `.bottomCTA` is `safeAreaInset`, which as far as I know (judgment, not checked on device)
    gets no scroll edge effect. `safeAreaBar` is the iOS 26 API that does.
  - This is a design-system primitive and the contract fixes it as `safeAreaInset`. Raise it
    with the owner rather than change it inside this feature.

### 2f. Headers pinned with `safeAreaBar` (progress, thumbnail strip)
- **Use the automatic edge effect, not a solid fill.**
  - scroll-views: "Prefer the automatic scroll edge effect style" and "Apply one scroll edge
    effect per view".
  - layout: no solid or semi-opaque fill under controls. See the finding in §1.
  - With a pager, each page's list has its own scroll view under one shared bar. The edge effect
    must stay the same height across pages, which the HIG states for split-view panes: "keep them
    consistent in height to maintain alignment".
- **Status in the bar is encouraged.**
  - feedback: "Consider integrating status feedback into your interface … Mail … displays the
    number of unread messages in the toolbar".
  - toolbars: "Reduce the use of toolbar backgrounds and tinted controls."
- **Watch the bar's height.** A strip plus counts plus title is tall.
  - designing-for-ios: limit onscreen controls.
  - toolbars: "Consider temporarily hiding toolbars for a distraction-free experience … offer
    ways to reliably restore hidden interface elements".
  - Judgment: at AX sizes, let the strip collapse on scroll, the way `TabBarMinimizeBehavior`
    does for tab bars.

### 2g. A progress indicator in the bar
- **Determinate is right.** progress-indicators: "When possible, use a determinate progress
  indicator", and "Display a progress indicator in a consistent location".
- **But this is not a wait.** The page also says "All progress indicators are transient,
  appearing only while an operation is ongoing" and "Keep progress indicators moving so people
  know something is continuing to happen". Workout progress stands still between sets, which
  that page reads as stalled. Two choices:
  - Model it as a gauge, which "displays a specific numerical value within a range of values"
    (https://developer.apple.com/design/human-interface-guidelines/gauges), with a linear
    capacity style. Gauges: "Write succinct labels that describe the current value and both
    endpoints", which the "x of y working sets" text already does.
  - Or keep `ProgressView`, accepting that it reports a count and is never a wait indicator.
- **Do not change shape.** "Don't switch from the circular style to the bar style"
  (progress-indicators). Keep one shape everywhere this progress appears, including the Live
  Activity.

### 2h. Context menus as the only route to an action
This is a hard constraint.
- "Always make context menu items available in the main interface, too."
- "it's hidden by default, so people might not know it's there".
- "Support context menus consistently throughout your app".
- "Provide either a context menu or an edit menu for an item, but not both".
- Destructive items go "at the end of the menu".
  (all https://developer.apple.com/design/human-interface-guidelines/context-menus)
- gestures: a custom gesture must be "Not the only way to perform an important action".
- accessibility: "Offer alternatives to gestures".

How the current code measures up:
- **Up Next rows:**
  - Do Next has a visible route: tap the row to make it current.
  - Do Later has a visible route only for the current exercise (the card menu).
  - For an Up Next row the visible route is Reorder followed by a drag. That is marginal but
    present.
- **Set rows:** no visible route. See §1.

---

## 3. iPadOS at regular width

The app ships to iPad (`TARGETED_DEVICE_FAMILY = 1,2`). Every routed screen centres on a 700 pt
readable column (`ContentWidth.readable`, set in `DialedInApp.swift:36`). Nothing in the tracker
reads `horizontalSizeClass`. None of this was run on iPad.

1. **Adapt to size class, keep the same functions, show more of them.**
   - layout: "Determine layout based on size classes, not device type or orientation."
   - layout: "Keep functionality the same as size classes change … However, you can change the
     amount of functionality that's visible … expose functionality that might otherwise be
     grouped into an overflow menu."
   - At regular width, put these in the toolbar as visible items:
     - Pause/Resume
     - Finish
     - Notes
   - Give the card's Warmup, Targets and Swap visible bordered buttons, MacroFactor-style.
   - On compact width, keep the More menu as decided.
   - toolbars: "The system automatically adds an overflow menu in macOS or iPadOS when items no
     longer fit. Don't add an overflow menu manually". Define the items and let the system
     collapse them.
2. **A two-pane layout fits better than paging at regular width.**
   - split-views: "use a split view to show multiple levels of your app's hierarchy at once …
     selecting an item in the view's primary pane displays the item's contents in the secondary
     pane"
   - split-views: "persistently highlight the current selection in each pane"
   - split-views: "Account for narrow, compact, and intermediate window widths."
   - The workout's exercise list would sit leading, with the current one highlighted. The open
     exercise's set table would sit trailing.
   - sidebars: "A sidebar … lets people navigate between areas of your app or top-level
     collections". A workout's exercises are not app areas, so use a list column, not the
     `.sidebar` style. Do not hide it by default: "Avoid hiding the sidebar by default".
   - Paging one exercise per page on an 11–13 inch screen wastes the display.
     designing-for-ipados: "Take advantage of the large display to elevate the content people
     care about".
3. **Full-screen cover on iPad.**
   - designing-for-ipados: "minimizing modal interfaces and full-screen transitions".
   - Its counterpart, modality: "Consider using a full-screen modal style for … a complex task",
     with "an obvious way to dismiss".
   - The cover is defensible. On iPad the minimize chevron is the only way out, so keep it
     obvious.
   - Sub-sheets (rest picker, swap, targets): "Prefer using the page or form sheet presentation
     styles in an iPadOS app" (sheets).
4. **Viewing distance and density.**
   - designing-for-ipados: "people are typically within about 3 feet of the device"
   - designing-for-ipados: "Use viewing distance and input mode to help you determine the size
     and density of the onscreen content".
   - An iPad on a bench or stand is read from further away than a phone. This strengthens the
     §1 type findings: at regular width, set the set values and rest time larger, not just
     wider.
5. **Pointer and keyboard.**
   - accessibility: "Let people use the keyboard alone to navigate and interact with your app".
   - The `inputView` already routes hardware keys. Add `keyboardShortcut`s for these, in line
     with hig-decisions 12a, which added iPad shortcuts elsewhere:
     - Log Set (Return)
     - Skip Rest
     - Next exercise
   - Context menus also open by secondary click on iPad (context-menus), so the visible-route
     rule matters equally there.
6. **Scroll edges with two panes.** "In split view layouts on iPad … each pane can have its own
   scroll edge effect; in this case, keep them consistent in height to maintain alignment"
   (scroll-views).
7. **Mac Catalyst** is out of scope by README follow-up 7, so it was not reviewed.

---

## Summary of the hard constraints

- **Text size.** Nothing below 11 pt. Workout values must be large and high-contrast.
  (accessibility, workouts)
- **Visible routes.** Every context-menu or swipe action also needs a visible control.
  (context-menus, gestures, accessibility)
- **Pause feedback.** Pause and resume need clear visible feedback, not just a frozen clock.
  (workouts)
- **No solid fills under bars.** Use the automatic scroll edge effect instead of a solid fill
  under pinned controls. (layout, scroll-views)
- **Paging versus row swipes.** A horizontal pager and horizontal row swipe actions cannot
  coexist. (gestures)
- **Page controls.** At most about 10 dots, centred at the bottom. A thumbnail strip is a
  collection with persistent selection, not a page control. (page-controls, collections)
- **Glass.** Glass only in the navigation layer. One or two prominent buttons per view. Size
  must not signal preference. (materials, buttons)
- **Keypad.** Keep it as a custom input view, not a sheet. One sheet at a time.
  (virtual-keyboards, sheets)
- **iPad.** Lay out by size class, with the same functions and more of them visible. Use a
  two-pane list and detail rather than one exercise per page. (layout, split-views,
  designing-for-ipados)
