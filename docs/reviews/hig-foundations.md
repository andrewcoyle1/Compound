# Cross-cutting foundations: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`. Pages read:
`designing-for-ios`, `accessibility`, `voiceover`, `typography`, `color`, `dark-mode`, `materials`,
`motion`, `gestures`, `right-to-left`, `sf-symbols`, `icons`, `app-icons`, `launching`, `layout`,
`buttons`, `inclusion`, `writing`, `branding`, plus `scroll-views`, `entering-data` and
`lists-and-tables` for findings 1, 5 and 9.

**Scope.** Every file under `Components/` (72 files, all read), then pattern sweeps across `Core/`
(897 files) for the eight areas below. A sweep hit was only counted after the surrounding code was
read; totals are given per finding. Also read: `Root/LaunchScreen.storyboard`, the `AppIcon`,
`AccentColor` and `SplashScreen` assets, `Localizable.xcstrings`, `.swiftlint.yml`.

**Not reviewed.** Feature behaviour, navigation and modality: those are in the per-area reviews
beside this file, and this one points to them instead of repeating them. The widget extension.
Share cards (exempt by contract). `Core/DevSettings/`.

**Not checked.** This is a code review. Nothing was run, so Dark Mode, the largest text sizes,
VoiceOver, right-to-left, iPad and Mac Catalyst are all unverified. Contrast ratios are calculated
from sRGB values with the WCAG formula, not measured on a device. Other people were editing this
tree during the review, so line numbers are as read on 2026-09-28.

Paths are relative to `DialedIn/`. Findings are most serious first.

## Resolution (2026-09-28, branch hig/foundations)

Scope was `Components/` (except `Modals/`, `Presentation.swift`, `BottomCTA.swift`) and
`Extensions/`. Sites in `Core/`, `Root/`, assets and `.swiftlint.yml` are left to their owners.

| # | Status | What changed |
|---|---|---|
| 1 | fixed (before this branch) | `Double.typed(_:locale:)` behind `enteredAmount` and `AutoSelectNumberField`; no other `Double(text)` parse of typed input in these paths. Account and set keypad are in `Core/`. |
| 2 | fixed in part; ring mark skipped: decision | `CalendarDayCell` is one element: full date label, value "Today" plus `CalendarDayMarker.accessibilityDescription` (logged count, % of goal, goal met / over goal), `.isSelected`. The over-goal ring shape waits on the decision. |
| 3 | fixed in part; set table skipped: decision | Calendar strip height is `@ScaledMetric`; `DashboardCard` uses `minHeight` and wraps its title; `ActivityRingView` scales with its caption (capped at 2x); `AnalyticsCardGrid` goes to one column and `AnalyticsCard` drops its line limits at accessibility sizes. `AutoSelectNumberField`'s shrink belongs to the set-table decision. The Dashboard carousel's fixed height is in `Core/`. |
| 4 | fixed in shared components | New `tapTarget()`; `chipTapTarget()` calls it. Applied to `SectionHeaderView`'s action and the onboarding secondary button. `FollowButton` drops `.controlSize(.small)`. Feature-folder sites are in `Core/`. |
| 5 | fixed in shared components | New `rowActions(edge:allowsFullSwipe:_:)` in `View+EXT.swift`: swipe actions plus the same buttons in a context menu. Adopting it is in `Core/`. |
| 6 | fixed in shared components | `ListRow`, `ListRowButton`, `ListRowToggle`, `SelectableRow` and `SectionHeaderView` take `LocalizedStringResource` for literals (the `String` initialisers are disfavoured), which translates `TrainingView`'s four rows; "See All" and "Unknown" are localized. Other literals are in `Core/`. |
| 7 | fixed in shared components | `ImageLoaderView` is hidden unless given `imageDescription`; `UserAvatarView` is hidden. Passing descriptions for content images is in `Core/`. |
| 8 | needs a change elsewhere | `Root/LaunchScreen.storyboard`. |
| 9 | fixed in part | `CalendarView`: weekday row is a `safeAreaBar`, month headers unpinned, both `.bar` backgrounds removed. `ExerciseListBuilderView` and `TrainingView` are in `Core/`. |
| 10 | fixed in part | `AnalyticsCard` and `CalendarHeaderView` use `chevron.forward` / `.backward`. Five sites are in `Core/`. |
| 11 | fixed in part | `HighlightButtonStyle` and `PressableButtonStyle` animate through `reducedMotionAnimation`, and a press dims rather than scales under Reduce Motion. `AppViewBuilder` and the lint rule are elsewhere. |
| 12 | skipped: decision | Needs the source artwork. |
| Smaller: card titles | fixed | `DashboardCard` title has `.isHeader`; month titles in `CalendarView` too. |
| Smaller: others | needs a change elsewhere | Colour/icon names, week start, custom modal, toasts, back chevrons are all outside these paths. |

## Sweep totals

| Area | What was counted | Result |
|---|---|---|
| Accessibility | `Image(systemName:)` sites outside share cards | 145. None is an unlabelled button. |
| | `onTapGesture` on a non-button | 3 in shipping code. 2 carry `.isButton`; 1 is a scrim with buttons beside it. |
| | `ImageLoaderView` / `UserAvatarView` call sites | 37. 20 have no label and are not hidden (finding 7). |
| Dynamic Type | `minimumScaleFactor` | 12 |
| | `lineLimit(1)` | 36 |
| | `.dynamicTypeSize(...)` caps | 3 |
| | Grids with a fixed column count | 8 |
| Motion | Bare `.animation(` | 3 in shipping code |
| | `repeatForever`, parallax | 0 in shipping code |
| Materials | `glassEffect` | 12, all in a bar, inset or overlay |
| | `.bar` or a material as a background | 6 |
| Gestures | `swipeActions` blocks | 19 in 14 files |
| | `contextMenu` | 2 |
| | Long-press | 1 |
| Colour | `.white` / `.black` outside share cards | 24, all on a scrim, a photo or a sign-in button |
| Right to left | `.left` / `.right` used for alignment or edges | 0 |
| | `chevron.left` / `chevron.right` | 8 |
| Localisation | Alert calls passing a bare string literal | 23 of 206 |
| | String catalog entries marked `stale` | 148 of 2,113 |
| SF Symbols | Names checked against the system list | 62 `Symbol` constants and 150 literals. All exist. |

## Findings

### 1. Typed decimals are parsed with `Double(_:)`, which does not accept a decimal comma
Severity: blocks people (in regions that write 1,5), not run
Where: `Components/Views/TextFields/AutoSelectNumberField.swift:43`, `:65`;
`Extensions/Double+EXT.swift:51`; `Core/Profile/Subviews/Account/AccountPresenter.swift:29` against
`:96`; `Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetKeyboard/SetKeyboardPresenter.swift:174`, `:178`
Guideline: "People expect to customize their device by choosing a language for text and a region
for formatting values like date, time, and money." —
https://developer.apple.com/design/human-interface-guidelines/inclusion
"For numeric data in particular, consider using a number formatter" —
https://developer.apple.com/design/human-interface-guidelines/entering-data
What happens: `.decimalPad` shows the region's separator, so in Spain the key types a comma.
`Double("82,5")` is nil, so `NumberField` sets its value to nil and `Double.enteredAmount("1,5")`
returns 0. The Account screen formats height with the locale (`:96`, "175,5") and reads it back
with `Double(_:)` (`:29`), so an untouched field fails to parse. The app ships a complete Spanish
translation. `hig-nutrition.md` finding 1 has the nutrition screens; the cause is these shared
helpers, which every numeric field goes through (11 `NumberField` call sites, 5 text-bound fields).
Fix: parse with the locale in the two shared places.
```swift
// AutoSelectNumberField and Double.enteredAmount
let parsed = try? Double(text, format: .number)
```
Write the field's text with `value.formatted(.number.precision(.fractionLength(0...2)))` so it
round-trips. Give the in-app set keypad the locale's separator
(`Locale.current.decimalSeparator`) in place of the literal ".". Eleven fields already use
`TextField(value:format: .number)` and are correct.
Size: M (three files and their tests)
Decision needed: no

### 2. A calendar day reads as "M", "14" to VoiceOver, and goal met or missed is red against green
Severity: hurts usability
Where: `Components/Views/CalendarHeader/CalendarDayCell.swift:26-37`, `:134-142`;
`Components/Views/CalendarHeader/CalendarHeaderView.swift:162-165`;
`Components/Views/CalendarHeader/Calendar/CalendarView.swift:127-130`
Guideline: "Provide alternative labels for all key interface elements… Add labels to any custom
elements your app defines." — https://developer.apple.com/design/human-interface-guidelines/voiceover
"Convey information with more than color alone… people who are color blind may have particular
difficulty with pairings such as red-green" —
https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: the cell is two `Text`s with a tap gesture and the button trait. It has no combined
element and no label, so the month and year are never spoken, the selected day has no
`.isSelected`, today is a 4 pt dot, and the marker (sessions logged, calories against goal) is not
exposed at all. For sighted people a day that met its goal and a day that went over both draw a
full ring, one in `success` and one in `danger` at 50% opacity: the only difference is the hue.
This is the header on both the Training and Nutrition tabs. It also breaks two rules in
`CONTRACT.md` § Patterns (Selection, Status).
Fix: make the cell one element and give the over-goal ring a shape.
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
.accessibilityValue(markerDescription)   // "2 workouts", "1,850 of 2,200 kcal, over goal", "Today"
.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
```
For the ring, keep green for met and mark over-goal with something that is not colour: a dashed
stroke, or the caret `TargetCellView` already uses for the same meaning.
Size: S (one file, plus a `CalendarDayMarker` description)
Decision needed: yes — which mark means "over goal" on the ring

### 3. Text that matters is capped, shrunk or boxed in at large sizes
Severity: hurts usability
Where: caps — `…/SetTracker/SetTrackerRow/SetTrackerRowView.swift:41` and
`…/SetTracker/SetTrackerView.swift:149` (`xxxLarge`), `…/SetKeyboard/SetKeyboardView.swift:36`
(`xxLarge`). Fixed height around text — `Components/Views/CalendarHeader/CalendarHeaderView.swift:57`
with `:148` (70 pt), `Components/Views/DashboardCard.swift:39` (200 pt),
`Components/Views/ActivityRingView.swift:65-71` (a `.label` text inside a fixed 80 pt ring).
Shrink instead of wrap — `Components/Views/DashboardCard.swift:35-36` (to 50%),
`Components/Views/TextFields/AutoSelectNumberField.swift:60` (to 50%),
`Core/Challenges/ChallengeRing.swift:33`. Fixed columns — `Components/Views/AnalyticsSection.swift:35`
with `Components/Views/AnalyticsCard.swift:70`, `:94`, `:100` (two columns, one-line title, value
and unit), `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerView.swift:73` (three),
`…/CreateExercise/MuscleGroupPicker/MuscleGroupPickerView.swift:52`, `:66` (three),
`Core/Training/Components/ProgramColourIconGrid.swift:39` (six)
Guideline: "give people the option to enlarge text by at least 200 percent" —
https://developer.apple.com/design/human-interface-guidelines/accessibility
"Keep text truncation to a minimum as font size increases" and "Reduce the number of columns when
the font size increases to avoid truncation" —
https://developer.apple.com/design/human-interface-guidelines/typography
"table rows or other containers may need to grow in height so that text isn't cropped" —
https://developer.apple.com/design/human-interface-guidelines/layout
What happens: the set table, the numbers people read between sets, stops growing at `xxxLarge`,
about 135% of the default. The calendar strip needs roughly 130 pt at AX5 by the HIG's own size
table (Caption 2 leading 48, Subhead leading 58, plus padding) and is given 70. The Dashboard
cards are already full at the default size. Analytics tiles stay two-up, so titles truncate.
`ListRow` and `WorkoutSessionRowView` show the pattern that works: `AdaptiveStack`, and no line
limit at accessibility sizes.
Fix: `minHeight` in place of `height` (or `@ScaledMetric`) for the three fixed containers. Drive
the grids from `dynamicTypeSize.isAccessibilitySize` (one column for Analytics tiles, fewer for the
pickers). Replace `minimumScaleFactor` on the card title and the number field with wrapping. For
the set table, a stacked row at accessibility sizes instead of the cap. Detail per screen is in
`hig-dashboard-social.md` finding 3, `hig-analytics-charts.md` findings 4 and 10,
`hig-active-workout.md` (smaller items) and `hig-nutrition.md` finding 20.
Size: L
Decision needed: yes — whether the set table gets a second, stacked layout or keeps its cap

### 4. Controls under 44 pt, from four repeated habits
Severity: hurts usability
Where, by cause:
- `.buttonStyle(.plain)` around a small label: `…/SetTrackerRow/SetTrackerRowView.swift:238-252`
  (the set-complete button, 32 pt wide), `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:102-122`
  (like), `Components/Views/SectionHeaderView.swift:30-33` ("See All", caption text; 7 call sites
  pass an action)
- `.frame(maxWidth: .infinity)` written outside the `Button`, so the row looks wide but only the
  glyph is hit: `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:160-219` (like,
  comment, share, more)
- a `Chip` in a button without `.chipTapTarget()`: `Core/Training/Components/RowChipButton.swift:24-27`
- `.controlSize(.small)` or `.mini` on a glass button: `Components/Views/User/UserRowView.swift:104`
  (Follow), `Core/Dashboard/CircleActivityStripView.swift:154-160` (Nudge, Set goal),
  `Core/Notifications/NotificationsView.swift:122`
- a 40 pt swatch: `Core/Training/Components/ProgramColourIconGrid.swift:53-63`
Guideline: "As a general rule, a button needs a hit region of at least 44x44 pt" —
https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: the most repeated taps in the app (complete a set, like, follow) are the smallest.
`CONTRACT.md` already says every `Chip` inside a button uses `.chipTapTarget()`.
Fix: one modifier used everywhere, shaped like `.chipTapTarget()`:
```swift
func tapTarget() -> some View {
    frame(minWidth: ControlSize.row, minHeight: ControlSize.row).contentShape(.rect)
}
```
applied to the label, inside the button. Move the four `.frame(maxWidth: .infinity)` calls in the
feed footer inside their labels. Rename `.chipTapTarget()` to it or have it call it. Per-screen
lists: `hig-active-workout.md` finding 3, `hig-dashboard-social.md` finding 4,
`hig-training-library.md` finding 9, `hig-analytics-charts.md` finding 9,
`hig-profile-settings-paywalls.md` finding 19.
Size: M
Decision needed: no

### 5. Nineteen swipe actions, and for most of them the swipe is the only way
Severity: hurts usability
Where: 19 `swipeActions` blocks in 14 files; 2 `contextMenu`s in the whole app. Confirmed to have
no other route: `…/SetTrackerRow/SetTrackerRowView.swift:43-59` (delete set, rest timer),
`Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:37-59` (reply, delete, report),
`Core/Nutrition/NutritionView.swift:124-135`, `Core/Nutrition/MealLog/AddMeal/AddMealView.swift:128`,
`Core/Dashboard/SocialProfile/FollowersList/FollowersListView.swift:40`,
`Core/Notifications/NotificationsView.swift:281`,
`Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfilesView.swift:43`, `:59`, `:66`,
`…/RestTimerSettings/TimerDuration/TimerDurationView.swift:44`,
`Core/Training/Subviews/ActiveTrainingProgram/ActiveTrainingProgramView.swift:33`,
`…/CreateWorkout/DefineWorkout/DefineWorkoutView.swift:83`,
`…/CreateWorkout/SetTarget/SetTargetView.swift:57`. Also one long-press:
`Core/Nutrition/Components/MealHourHeader/MealHourHeaderView.swift:25`
Guideline: "Offer alternatives to gestures… if you use a swipe gesture to dismiss a view, also
make a button available so people can tap or use an assistive device." —
https://developer.apple.com/design/human-interface-guidelines/accessibility
"Not the only way to perform an important action" —
https://developer.apple.com/design/human-interface-guidelines/gestures
What happens: VoiceOver and Switch Control get these as actions, so they are covered. Someone who
cannot swipe and uses neither cannot delete a set, reply to a comment or report one. Reporting
matters most: it is how people flag other people's content.
Fix: add a `.contextMenu` with the same buttons wherever a row has swipe actions. One helper keeps
the two in step:
```swift
func rowActions<A: View>(@ViewBuilder _ actions: () -> A) -> some View {
    swipeActions { actions() }.contextMenu { actions() }
}
```
Put Reply and Report on the comment row as visible controls. Per-screen notes:
`hig-dashboard-social.md` finding 6, `hig-training-library.md` finding 7, `hig-nutrition.md`
finding 19.
Size: M
Decision needed: no

### 6. Strings passed as `String` never reach the catalog, so translations that exist are not shown
Severity: hurts usability
Where: the primitives take `String` (`Components/DesignSystem/ListRow.swift:42`,
`Components/Views/SectionHeaderView.swift:17`, `:20`, `Components/Modals/CustomModalView.swift:12-16`,
`GlobalRouter.showSimpleAlert`), so a literal at the call site is a plain `String` and `Text(title)`
does no lookup. Sites with a bare literal:
- `Core/Onboarding/5 - HealthDisclaimer/HealthDisclaimerRouter.swift:27-36` — the consent text and
  both buttons of the health disclaimer. It also says "DialedIn" where the app is called Compound.
- `Core/Training/TrainingView.swift:85-94` — four rows. The catalog has Spanish for three of them,
  marked `stale`.
- `Core/Nutrition/Foods/FoodDetail/FoodDetailView.swift:154` — 38 nutrient labels through
  `LabeledContent(label, …)`
- `Core/Dashboard/Components/NutritionCard.swift:33-35`,
  `Core/Nutrition/MealLog/MealDetail/MealDetailPresenter.swift:37-40` (also writes `"\(protein)g"`
  by hand instead of `Format.grams`)
- `Components/Views/SectionHeaderView.swift:20` — the default "See All"
- 23 of 206 alert calls, in 17 files, for example
  `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerPresenter.swift:277`,
  `Core/Profile/ProfilePresenter.swift:99`, `:113`, `:121`,
  `Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:202`, `:236`
- English fallbacks inside an interpolation: `Core/Challenges/ChallengesDashboardSection.swift:78`
  ("You"), `Core/Challenges/ChallengeDetail/ChallengeDetailView.swift:78`, `:96`,
  `Core/Dashboard/CircleGoals/CircleLeaderboardView.swift:46`, `:66`,
  `Core/AppView/ActivityNotificationBannerView.swift:35`, `:37`,
  `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:86`, `:130`,
  `Components/Views/User/UserRowView.swift:42` ("Unknown")
- A label built with `+`: `Core/Dashboard/CircleActivityStripView.swift:91-93`
Guideline: "provide translated text and resources for specific locales" —
https://developer.apple.com/design/human-interface-guidelines/inclusion
"write with accessibility and localization in mind" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: a Spanish user sees English on these rows, in these alerts and in the health
consent. 148 of the catalog's 2,113 entries are `stale`, which is what a key looks like once no
code extracts it.
Fix: wrap each literal in `String(localized:)`, which is what most call sites already do. To stop
it coming back, give the primitives a `LocalizedStringKey` initialiser beside the `String` one, as
`Chip` and `InlineMessage` have (`Components/DesignSystem/Chip.swift:20-27`), so a literal
localises by default. Review the 148 stale entries: each is either a string that lost its lookup or
one to delete. `hig-dashboard-social.md` finding 15 and `hig-onboarding-data-steps.md` finding 7
list more sites.
Size: M
Decision needed: no

### 7. Hero and placeholder images are read out by asset name
Severity: hurts usability (VoiceOver), not run
Where: `Components/Images/ImageLoaderView.swift:28`, `:47`; `Components/Views/User/UserRowView.swift:20`.
20 of 37 call sites add no label and do not hide the image, for example
`Core/Training/Subviews/AddTraining/CreateWorkout/CreateWorkoutView.swift:24`,
`…/CreateProgram/CreateProgram/CreateProgramView.swift:20`, `Core/Onboarding/2 - AuthView/AuthView.swift:16`,
`Core/Profile/Subviews/Account/AccountView.swift:75-77`,
`Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/GymProfileView.swift:126`,
`Core/Nutrition/Foods/FoodDetail/FoodDetailView.swift:52`,
`Core/Nutrition/Recipes/RecipeDetail/RecipeDetailView.swift:43`
Guideline: "Exclude purely decorative images from VoiceOver." and "Describe meaningful images." —
https://developer.apple.com/design/human-interface-guidelines/voiceover
What happens: `Image(urlString)` with the default name gives VoiceOver an image element called
"SplashScreen". The same collage is the fallback for a missing exercise, gym or profile picture
(`Utilities/Constants.swift:13`), so it is announced there too. My reading of SwiftUI's default
label; confirm with VoiceOver.
Fix: decide it once, in the component.
```swift
struct ImageLoaderView: View {
    var accessibilityLabel: String?        // nil means decorative
    …
    .accessibilityHidden(accessibilityLabel == nil)
    .accessibilityLabel(accessibilityLabel ?? "")
}
```
Pass a label where the picture is content (a food photo, a progress photo). Hide the glyph in
`UserAvatarView`; the name beside it already says who it is.
Size: S
Decision needed: no

### 8. The launch screen is a full-colour collage with the app name on it
Severity: polish
Where: `Root/LaunchScreen.storyboard:3`, `:18`, `:23`, `:32`;
`SupportingFiles/Assets.xcassets/SplashScreen.imageset`
Guideline: "Design a launch screen that's nearly identical to the first screen of your app…
Also make sure that your launch screen matches the device's current orientation and appearance
mode." and "Avoid including text on your launch screen" —
https://developer.apple.com/design/human-interface-guidelines/launching
"Avoid using a launch screen as a branding opportunity." —
https://developer.apple.com/design/human-interface-guidelines/branding
What happens: every launch shows a busy illustration and "COMPOUND" in Arial Bold Italic on a white
label, then cuts to the Dashboard, which looks nothing like it. The background is hard-coded white
and the storyboard is fixed to the light appearance, so in Dark Mode launch is a white flash.
`hig-shell-navigation.md` finding 11 covers the splash; the Dark Mode flash is the part to add.
Fix: a launch screen that is only `systemGroupedBackground`, which is `Color.canvas`. Remove the
image view and the label. The collage can stay on the Welcome screen, where it already is.
Size: S
Decision needed: no

### 9. Clear glass over a plain list, and bar material behind pinned headers
Severity: polish
Where: `Core/Training/Components/ExerciseListBuilder/ExerciseListBuilderView.swift:131`, `:259`
(`.glassEffect(.clear.interactive())`); `Core/Training/TrainingView.swift:61`,
`Components/Views/CalendarHeader/Calendar/CalendarView.swift:57`, `:97` (`.background(.bar)`)
Guideline: "Only use clear Liquid Glass for components that appear over visually rich
backgrounds… Use the regular variant when background content might create legibility issues" —
https://developer.apple.com/design/human-interface-guidelines/materials
"Instead of applying a solid or semi-opaque background color beneath controls, use a scroll edge
effect" — https://developer.apple.com/design/human-interface-guidelines/layout
"[The automatic] style provides a more opaque visual separation for top toolbars that contain a
large number of controls, text that appears outside of Liquid Glass controls, and pinned table
headers." — https://developer.apple.com/design/human-interface-guidelines/scroll-views
What happens: the nine filter chips use the variant meant for photos and video, over list rows
that scroll under them. The calendar strip and the month headers paint a bar material, where the
system's scroll edge effect would separate them from the list. Glass is otherwise used only in
bars, insets and overlays: the other ten `glassEffect` sites are correct.
The same chips show an active filter only by `.tint` against `.primary` (`:258`). The accent is
`labelColor`, so the two are the same colour and a single selection in Type or Laterality changes
nothing on screen. `hig-training-library.md` finding 10 has the detail.
Fix: `.glassEffect(.regular.interactive())` on the chips. Remove the three `.background(.bar)`
calls and check the result at the top of the list and mid-scroll. `hig-training-library.md`
finding 20 covers the Training tab.
Size: S
Decision needed: no

### 10. Eight chevrons point the same way in every language
Severity: polish (no right-to-left language ships today)
Where: `Components/Views/AnalyticsCard.swift:104`,
`Components/Views/CalendarHeader/CalendarHeaderView.swift:111`,
`Core/Challenges/ChallengesDashboardSection.swift:60`,
`Core/Dashboard/WeeklyReview/WeeklyReviewCard.swift:25`,
`Core/Dashboard/WeeklyReview/WeeklyReviewView.swift:94`, `:103`,
`Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramDesignView.swift:207`
Guideline: "Flip controls that help people navigate or access items in a fixed order. For example,
in the RTL context, a back button must point to the right" —
https://developer.apple.com/design/human-interface-guidelines/right-to-left
What happens: `chevron.right` and `chevron.left` name a fixed direction. `ListRow` already uses
`chevron.forward` (`Components/DesignSystem/ListRow.swift:169`), which follows the layout
direction. In the calendar strip the button moves to the other edge in a right-to-left layout and
its arrow does not. That `.forward` flips and `.right` does not is my knowledge of SF Symbols, not
a line from the page.
Fix: `chevron.forward` and `chevron.backward` at all eight. Everything else is already correct:
the sweep found no `.left` or `.right` alignment anywhere.
Size: S
Decision needed: no

### 11. Three animations skip the reduced-motion helpers, and the lint rule cannot see them
Severity: polish
Where: `Core/AppView/AppViewBuilder.swift:20-26` (onboarding and the tab bar slide across the whole
screen), `Components/ViewModifiers/ButtonViewModifiers.swift:17`, `:26` (every `.anyButton(.press)`
and `.highlight`, 25 call sites)
Guideline: "ensure your app or game responds by reducing automatic and repetitive animations,
including zooming, scaling, and peripheral motion… Replacing transitions in x-, y-, and z-axes
with fades" — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: with Reduce Motion on, finishing onboarding still slides a full screen sideways, and
pressable cards still scale. `CONTRACT.md` forbids bare `.animation(`, but `no_bare_with_animation`
only matches `withAnimation(`.
Fix: `.reducedMotionAnimation(.standard, value: activeModuleId)` and an opacity transition when
`accessibilityReduceMotion` is on, as `AppView.swift:61` already does. In the two button styles,
read `accessibilityReduceMotion` and skip the scale. Add a lint rule for `\.animation\(` with
`ReducedMotionViewModifier.swift` excluded.
Size: S
Decision needed: no

### 12. The app icon is a flat image with its own rounded shape drawn in
Severity: polish
Where: `SupportingFiles/Assets.xcassets/AppIcon.appiconset/CompoundDefault.png`,
`CompoundDark.png`, `Contents.json`
Guideline: "Produce appropriately shaped, unmasked layers… Providing layers with pre-defined
masking negatively impacts specular highlight effects and makes edges look jagged." and "Let the
system handle blurring and other visual effects… there's no need to include specular highlights,
drop shadows between layers, beveled edges" —
https://developer.apple.com/design/human-interface-guidelines/app-icons
What happens: both files are opaque 1024 px PNGs that contain a rounded square on a white canvas
(the dark icon's corner pixels are white), a drop shadow under the letter and a baked gradient.
The system masks them again and has no layers to light. The tinted slot and all ten Mac sizes are
empty; the system generates the first, and Catalyst is out of scope by decision 7.
Fix: rebuild in Icon Composer from two layers, a plain background and the "C" as a vector, with no
shadow, and let it produce the dark, clear and tinted variants.
Size: M (design work)
Decision needed: yes — needs the source artwork

## Smaller items

- **Labels that are developer strings.** `Core/Training/Components/ProgramColourIconGrid.swift:31`
  reads `colour.description.capitalized` and `:45` reads the raw symbol name
  ("gauge.with.dots.needle.bottom.100percent"). Give each colour and icon a localised name.
  `hig-training-library.md` finding 8.
- **Card titles are not headings.** `Components/Views/DashboardCard.swift:32` draws a section title
  with no `.isHeader`, so the rotor cannot jump between the three Dashboard cards. The whole app
  has five `.isHeader` sites. "Use titles and headings to help people navigate your information
  hierarchy" — voiceover page.
- **The week starts on Sunday for everyone.**
  `Core/Training/Components/WorkoutStreakCard/WorkoutStreakCard.swift:71-72` subtracts
  `weekday - 1`. Use `calendar.dateInterval(of: .weekOfYear, for: today)`, which honours
  `firstWeekday`.
- **The custom modal is not marked modal.** `Components/Modals/CustomModalView.swift` sets no
  `.accessibilityAddTraits(.isModal)`, so VoiceOver can reach what is behind it. My judgment.
  `hig-shell-navigation.md` finding 4 covers the component.
- **Toasts and banners disappear after four seconds and are not announced**
  (`Core/AppView/AppPresenter.swift:95-110`), including "Couldn't save your workout". "Minimize use
  of time-boxed interface elements" — accessibility page. `hig-shell-navigation.md` finding 14.
- **Two pushed screens draw their own back chevron**
  (`…/ProgramDesign/ProgramDesignView.swift:55`, `…/GymProfile/GymProfileView.swift:94`), which also
  removes the edge swipe. `hig-shell-navigation.md` finding 12.

## Contract conflicts

These are settled in `CONTRACT.md` or the README decisions. They are listed because the HIG says
otherwise, not as findings.

### A. Coloured text on a 15% tint of the same colour is below the contrast minimum
Contract: `Chip` is "`tint` on `tintedSurface(tint)`", `tintedSurface` is `c.opacity(0.15)`, and
the macro and status colours are fixed values.
HIG: "make sure the contrast ratio between colors is no lower than 4.5:1" —
https://developer.apple.com/design/human-interface-guidelines/dark-mode ; the same table is on
https://developer.apple.com/design/human-interface-guidelines/accessibility
Calculated for a chip on a white surface, 12 pt semibold:

| Tint | Light | Dark |
|---|---|---|
| `fat` | 1.6:1 | 7.2:1 |
| `personalRecord` (yellow) | 1.4:1 | 7.9:1 |
| `warning`, `warmup` (orange) | 2.0:1 | 5.9:1 |
| `success` (green) | 2.0:1 | 5.9:1 |
| `carbs` | 2.0:1 | 5.8:1 |
| `protein` | 2.8:1 | 4.3:1 |
| `calories` (blue) | 3.3:1 | 3.6:1 |
| `superset` (indigo) | 4.6:1 | 2.7:1 |

System colour values are the documented light-mode ones and may differ on iOS 26. Sites:
`Core/Nutrition/Components/Shared/MacroChips.swift:31`,
`Core/Training/Components/WorkoutStreakCard/WorkoutStreakCard.swift:53-55`,
`Core/Training/Components/SetDetailRow.swift:73`,
`…/ExerciseTracker/ExerciseTrackerView.swift:72`. The same colours are used as plain text by
`InlineMessage` (`Components/DesignSystem/InlineMessage.swift:64`, warning at about 2.2:1 on white)
and `Core/Dashboard/CircleActivityStripView.swift:72-75`.
A way through that keeps the contract's shape: keep the tinted fill, draw the text in `.primary`,
and let the symbol carry the colour.

### B. Seven palette colours have one value for every appearance
Contract: "`protein`, `carbs`, `fat`: the existing RGB values".
HIG: "If you define a custom color, make sure to supply light and dark variants, and an increased
contrast option for each variant" — https://developer.apple.com/design/human-interface-guidelines/color
Where: `Components/DesignSystem/Palette.swift` — `protein`, `carbs`, `fat`, `vitamins`, `minerals`,
`otherNutrients`, `Metric.habits`. Moving them to colour-set assets, as `OnAccent` already is,
keeps the names and adds the variants.

### C. The accent is the label colour
Contract: README decision 1, and `CONTRACT.md` § Accent (links and "See All" take the accent).
HIG: "if you use your brand color to indicate that a borderless button is interactive, using the
same or similar color to stylize noninteractive text is confusing." —
https://developer.apple.com/design/human-interface-guidelines/color
While `AccentColor` is `labelColor`, a `.tint` link and body text are the same colour, and a state
shown only by tint cannot be seen (finding 9). The contract already plans for a change of accent;
until then any control that relies on tint alone needs a second cue.

## Done well — keep

- Icon-only buttons are labelled. The sweep read 145 symbol sites and found no unlabelled control.
- `ListRow` and `AdaptiveStack` move accessories under the title at accessibility sizes, scale the
  glyph with `@ScaledMetric`, and drop the line limit. Every design-system file previews in light,
  dark and AX3.
- `Stat`, `InlineMessage`, `Chip`, `ActivityRingView` and the charts each read as one element with
  a label and a value. `TargetCellView` and `AppToastView` pair colour with a symbol.
- Motion goes through `withReducedMotionAnimation` and `reducedMotionAnimation` almost everywhere
  (21 uses against 3 misses). Nothing loops and nothing uses parallax. The four custom transitions
  that move switch to opacity under Reduce Motion.
- Layout is written with `.leading` and `.trailing` throughout.
- Every SF Symbol name in the app exists, including the five built by appending to a `Symbol`
  constant.
- Surfaces are semantic system colours. The 24 uses of `.white` and `.black` are all on a scrim, a
  photo or a sign-in button.
- `.bottomCTA` pins controls with `safeAreaInset` and draws no background behind them.
- Swipe actions use `Label`s and destructive roles, so VoiceOver gets them as named actions.
