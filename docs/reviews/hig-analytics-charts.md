# Analytics, charts and body metrics: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`. Pages read:
`designing-for-ios`, `charting-data`, `charts`, `activity-rings`, `healthkit`, `color`,
`dark-mode`, `accessibility`, `voiceover`, `typography`, `gauges`, `progress-indicators`,
`entering-data`, `pickers`, `segmented-controls`, `lists-and-tables`, `loading`, plus `sheets`,
`modality`, `layout`, `context-menus` and `alerts` for findings 2, 3, 16 and 17.

**Scope.** Code read: all of `Core/Analytics/` (views and presenters), `Components/Views/Charts/`,
`Components/Views/MetricDetailView.swift`, `MetricAllDataView.swift`, `AnalyticsCard.swift`,
`AnalyticsSection.swift`, `ActivityRingView.swift`, `SectionHeaderView.swift`,
`Components/DesignSystem/Stat.swift`, `Palette.swift`, `Components/Models/MetricConfiguration.swift`,
and `Core/Onboarding/Components/WeeklyMacroChart.swift`. The QuickCharts package was read at the
pinned revision (0.6.1, `641fabc7`) from a SwiftPM checkout, to check what the app cannot see
from its call sites. Package-level problems are marked **needs a package change**.

**Not reviewed.** `MetricRow`, `MetricView`, `StatCard` and `ProgressCircle` no longer exist
(deleted in WP-15; `Stat` and `ListRow` replace them). `WeeklyMacroChart` lives in
`Core/Onboarding/Components/`, not `Components/Views/`. Customize Analytics, Weekly Review and the
Add Meal, Workouts and Account screens these screens route to were not read.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Contrast ratios are my arithmetic from
the documented light-mode system colour values. `Steps/StepsPresenter.swift` and
`StepsInteractor.swift` had uncommitted edits by someone else while this was written; line numbers
are from the working tree at `30962eae`.

Paths are relative to `DialedIn/`. `pkg:` paths are relative to the package's
`Sources/QuickCharts/`. Findings are most serious first.

## Findings

### 1. Weight and measurements can only be logged in whole units
Severity: hurts usability
Where: `Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView/WeightPickerInput.swift:22`,
`:23`, `:45`, `:53`, `:57`, `:65`; `LogWeightPresenter.swift:17`, `:54`;
`LogMeasurement/LogMeasurementView.swift:64`, `:72`, `:76`, `:84`; `LogMeasurementPresenter.swift:57`
Guideline: "Use predictable and logically ordered values." —
https://developer.apple.com/design/human-interface-guidelines/pickers ; "consider using a number
formatter… to display the value in a specific way, such as with a certain number of decimal
places" — https://developer.apple.com/design/human-interface-guidelines/entering-data . The
precision point itself is **my judgment**; no fetched page states it.
What happens: the wheels are `Int` ranges (30...200 kg, 66...440 lb, whole cm and in), so 82.4 kg
cannot be entered. Every screen that shows the value prints one decimal, and the trend line is
an average of whole numbers. Opening the sheet on an existing 82.4 kg selects 82, and switching
units truncates rather than rounds (100 cm becomes 39 in, which saves as 99.06 cm). Both wheels
are `.reversed()`, so values fall as you scroll down, the opposite of every system number wheel.
Fix: two wheel columns, whole and tenths, as Health does, in ascending order; or `NumberField`
with a decimal pad. Round on unit conversion. `WeightPickerInput` is shared with the weekly
check-in, so one change covers both.
Size: M
Decision needed: yes — wheel with a tenths column, or `NumberField`?

### 2. Every analytics screen is a sheet, and they stack three and four deep
Severity: hurts usability
Where: 27 `router.showScreen(.sheet)` sites under `Core/Analytics/`, among them
`Subviews/BodyMetrics/BodyMetricsView.swift:110`,
`BodyMetrics/MeasurementDetails/BodyMeasurementDetail.swift:142`,
`BodyMetrics/LogMeasurement/LogMeasurementView.swift:129`,
`BodyMetrics/ScaleWeight/ScaleWeightView.swift:45`,
`NutritionAnalytics/NutritionAnalyticsView.swift:296`,
`NutritionAnalytics/NutritionMetricDetail/NutritionMetricDetailPresenter.swift:165`,
`InsightsAndAnalytics/InsightsAndAnalyticsView.swift:167`, `Habits/HabitsView.swift:109`,
`MuscleGroups/MuscleGroupsView.swift:100`, `MuscleBalance/MuscleBalanceView.swift:137`,
`ExerciseAnalytics/ExerciseAnalyticsView.swift:85`, `InsightsAndAnalytics/Steps/StepsView.swift:51`;
package: `pkg:Screen/ChartScreen.swift` (`.sheet(isPresented: $showsMore)`)
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are in your app." —
https://developer.apple.com/design/human-interface-guidelines/sheets ; "Take care to avoid
creating a modal experience that feels like an app within your app." and "Let people dismiss a
modal view before presenting another one." —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: Analytics tab → See All Body Metrics (sheet) → Waist (sheet on sheet) → + (half
sheet on both), or → Show More Waist Data (the package's own sheet). Each layer has its own close
button, so leaving takes three closes, and closing one returns to another sheet. These screens
browse a hierarchy; a sheet is for "a scoped task". Progress Photos is then pushed inside the
Body Metrics sheet, a navigation stack inside a modal.
Fix: push the See All screens and the metric detail screens onto the tab's navigation stack
(`.push`), which gives Back for free. Keep sheets for the two logging forms only. In the package,
push Show More or expand it in place.
Size: L
Decision needed: yes — move Analytics from sheets to push navigation?

### 3. The Nutrition analytics sheet has no close button
Severity: hurts usability
Where: `Core/Analytics/Subviews/NutritionAnalytics/NutritionAnalyticsView.swift:13-49` (no
`.toolbar`), presented at `:296`; `NutritionAnalyticsPresenter.swift` has no `onDismissPressed`
Guideline: "Always give people an obvious way to dismiss a modal view… people typically expect to
find a button in the top toolbar or swipe down" —
https://developer.apple.com/design/human-interface-guidelines/modality ; "if you use a swipe
gesture to dismiss a view, also make a button available so people can tap or use an assistive
device." — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: the other seven See All sheets carry `Button(role: .close)`. This one can only be
swiped down, and it is the longest of them (fifty-odd cards), so the swipe has to start at the top.
Fix: add `onDismissPressed()` to the presenter and the same toolbar item the siblings have.
Finding 2 removes the need.
Size: S
Decision needed: no

### 4. Card titles are cut to one line in a grid that is always two columns
Severity: hurts usability
Where: `Components/Views/AnalyticsCard.swift:70`, `:94`, `:100`;
`Components/Views/AnalyticsSection.swift:35`
Guideline: "Keep text truncation to a minimum as font size increases." and "Multicolumn text can
also be less readable at large sizes… Reduce the number of columns when the font size increases
to avoid truncation" — https://developer.apple.com/design/human-interface-guidelines/typography ;
"Design a layout that adapts gracefully and consistently." —
https://developer.apple.com/design/human-interface-guidelines/layout
What happens: a card's text area is about 150 pt wide on iPhone. `.lineLimit(1)` on a `.headline`
title truncates "B5, Pantothenic Acid" at the default size, and exercise names are user data:
"Incline Dumbbell Press" and "Incline Dumbbell Fly" both read "Incline Dumbbell…". At
accessibility sizes most titles go. "450 deficit" plus "kcal" plus the chevron share one line
the same way. On iPad the grid is still two columns, so each card is several hundred points wide
around a 36 pt chart.
Fix: `.lineLimit(2)` on the title. In `AnalyticsCardGrid`, one column when
`dynamicTypeSize.isAccessibilitySize`, otherwise `GridItem(.adaptive(minimum: 160))`.
Size: S
Decision needed: no

### 5. A card is a button whose VoiceOver label is whatever happens to be inside it
Severity: hurts usability — **unverified, needs a VoiceOver pass**
Where: `Components/Views/AnalyticsSection.swift:23-26` (`analyticsCardButton`), `:101-105`
(`ConsistencyAnalyticsCard`); `Components/Views/AnalyticsCard.swift:66`, `:104`;
`pkg:Marks/ContributionGridView.swift:97`
Guideline: "In some cases, it can make sense to use a single accessibility label that provides a
succinct, high-level description of the chart, such as when you use a small version of a chart in
a button that reveals a more detailed version." —
https://developer.apple.com/design/human-interface-guidelines/charts ; "Exclude purely decorative
images from VoiceOver." — https://developer.apple.com/design/human-interface-guidelines/voiceover
What happens: `AnalyticsCard` sets no accessibility of its own, so the wrapping `Button` builds
its label from its children. The sparkline, bar and progress thumbnails each collapse to one
element, which is right. The habit cards do not: `ContributionGridView` labels each of its 30
squares "12 Sep 2026, 1", and all 30 sit inside the button. The chevron and title symbol are
unhidden images.
Fix: make the card one element, in `AnalyticsCard`:
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(title ?? "")
.accessibilityValue([value, unit, subtitle, chartSummary].compactMap { $0 }.joined(separator: ", "))
```
with `chartSummary` passed by the caller ("3 of the last 7 days" for a habit card). Use spoken
units there: `Format` output says "g" and "kcal", and the charts page asks for "60 minutes"
over "60m".
Size: M
Decision needed: no

### 6. Series cannot be told apart: two lines in one colour, macros by colour alone
Severity: hurts usability
Where: `Components/Views/Charts/MetricChart.swift:182-194`;
`Core/Analytics/Subviews/InsightsAndAnalytics/WeightTrend/WeightTrendPresenter.swift:58-67`, `:99-103`;
`Components/Views/Charts/MacroStackedBarChart.swift:60-66`; package:
`pkg:Charts/TimeSeriesChart.swift:100` (`.chartLegend(.hidden)`), `pkg:Marks/ChartMarks.swift:167-171`,
`pkg:Marks/SeriesSummary.swift:53`
Guideline: "Avoid relying solely on color to differentiate between different pieces of data" and
"Aid comprehension by adding visual separation between contiguous areas of color… adding
separators between the marks can help people distinguish individual ones." —
https://developer.apple.com/design/human-interface-guidelines/charts
What happens: Weight Trend plots Scale Weight and Trend Weight. `seriesColors(color:)` returns
the one theme colour and the package repeats it, so both lines and both header names are the same
purple; only the point symbols differ, and the legend is hidden. The macros chart is the opposite
case: protein, carbs and fat are told apart only by coral, green and yellow, in the header by
coloured text and in the bars with no gap between segments. Coral against green is the pairing
the accessibility page names as hardest.
Fix (app, S): give Weight Trend a second colour through `lineSeriesColor`, or draw the raw
readings as points and the trend as the line. Put `Spacing.xxs` between segments in
`MacroStackedBarChart`.
Fix (**needs a package change**, M): a legend or header that shows each series' symbol beside its
name, a separator between stacked bars, and a dashed or patterned option per series.
Size: M
Decision needed: no

### 7. A selected chart row draws white text on the series colour
Severity: hurts usability — **needs a package change**
Where: `pkg:Screen/ChartAccessories.swift:63`, `:67`, `:71`; the colour comes from
`Components/Views/Charts/MetricChart.swift:70`, `:144`; `Components/DesignSystem/Palette.swift:80-89`
Guideline: "At a minimum, make sure the contrast ratio between colors is no lower than 4.5:1." —
https://developer.apple.com/design/human-interface-guidelines/dark-mode ; minimum 3:1 for bold
text — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: tapping Latest, Highest or Lowest fills the row with the metric colour and sets its
text to `Color.white`. Goal Progress uses the accent, which is `labelColor`: white in Dark Mode,
so the row becomes white on white. In light mode white on Workouts orange is about 2.2:1, on
Steps mint 2.1:1, on Exercises cyan 2.5:1. It is also the contract's "never `.white` on an accent
fill" rule, which the lint cannot see inside a package.
Fix: `ChartHighlight` takes a foreground colour as well as a fill, defaulting to one picked by
luminance; the app passes `.onAccent` for accent. Until then the app can pass a darker highlight
colour at `MetricChart.swift:144`.
Size: M
Decision needed: no

### 8. Twenty-two of fifty-two nutrient cards are permanently "Not Tracked", at half opacity
Severity: hurts usability
Where: `Core/Analytics/Subviews/NutritionAnalytics/NutritionAnalyticsView.swift:185-193`, and
the 22 `isTracked: false` call sites between `:200` and `:274` (all eleven under Protein Breakdown)
Guideline: "Strive to meet color contrast minimum standards… 4.5:1" —
https://developer.apple.com/design/human-interface-guidelines/accessibility ; "Keep a chart
simple… Resist the temptation to pack as much data as possible" —
https://developer.apple.com/design/human-interface-guidelines/charting-data
What happens: `.opacity(0.5)` over `.secondary` caption text puts "Not Tracked", the one line
that explains the card, at about 1.7:1. The card still holds a chart whose VoiceOver value is
"0 g", which claims a reading. A whole section, Protein Breakdown, is eleven cards that can never
show anything.
Fix: drop the untracked nutrients from the grid. If they must be listed, one plain row per
section ("Not tracked: Starch, Sugars Added") at full contrast, with no chart.
Size: S
Decision needed: yes — hide untracked nutrients, or list them as text?

### 9. "See All" is a 12 pt text button with no padding
Severity: hurts usability
Where: `Components/Views/SectionHeaderView.swift:29-33`; six uses on the tab,
`Core/Analytics/AnalyticsView.swift:268`, `:294`, `:345`, `:377`, `:409`, `:443`
Guideline: iOS default control size 44x44 pt, minimum 28x28 pt —
https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: a `.plain` button in `.caption` has a hit area of roughly 45 by 16 pt. It is the
only route to six screens. The component is shared with the Dashboard.
Fix: `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(.rect)` on the button, as
`.chipTapTarget()` does for chips.
Size: S
Decision needed: no

### 10. Four layouts cannot grow with the text size
Severity: hurts usability at accessibility sizes — **unverified**
Where: `pkg:Marks/SeriesSummary.swift:32`, `:75` (**needs a package change**);
`Components/Views/MetricAllDataView.swift:55-72`;
`Core/Onboarding/Components/WeeklyMacroChart.swift:37-53`;
`Components/Views/ActivityRingView.swift:65-71`
Guideline: "Make sure your app's layout adapts to all font sizes." and "consider using a stacked
layout where text appears above secondary items." —
https://developer.apple.com/design/human-interface-guidelines/typography
What happens: the chart header is `.fixedSize()` with one `.title2` column per series on one
line, so the three macro columns cannot wrap and run past the screen edge. All Recorded Data
keeps value and date on one line and shrinks the value to 70%. `WeeklyMacroChart` sets seven
columns of day name and calories side by side. `ActivityRingView` puts Dynamic Type text inside
a fixed 80 pt frame.
Fix: `ViewThatFits` or a vertical stack at accessibility sizes for the header and the row;
`minimumScaleFactor` and `lineLimit(1)` inside the ring, or scale it with `@ScaledMetric` as
`ChallengeRing` does; for the weekly chart, drop the per-day calories under the bars at
accessibility sizes, since VoiceOver and the average already carry them.
Size: M
Decision needed: no

### 11. Metric screens show "No data" while they are still loading
Severity: polish
Where: `Components/Views/MetricDetailView.swift:148-149`;
`Core/Analytics/Subviews/InsightsAndAnalytics/Steps/StepsPresenter.swift:26-34`;
`BodyMetrics/MeasurementDetails/VisualBodyFatMetric.swift:79-82`; also
`MuscleGroupDetailPresenter.swift:30`, `ExerciseDetailPresenter.swift:26`,
`NutritionMetricDetailPresenter.swift:84`, `FoodLoggingConsistencyPresenter.swift:19`,
`GoalProgressPresenter.swift:28`; `NutritionTargetChart/NutritionTargetChartView.swift:21`
Guideline: "consider showing placeholder text, graphics, or animations as content loads,
replacing these elements as content becomes available." —
https://developer.apple.com/design/human-interface-guidelines/loading
What happens: `MetricDetailPresenter` has no loading state, so `entries.isEmpty` means both
"nothing logged" and "not read yet". Steps is the clearest case: it awaits the Health permission
sheet and a backfill before reading anything, with "No step data" and a Sync button behind the
system sheet. The target grid shows a bare spinner where the contract asks for a redacted
placeholder.
Fix: add `var isLoading: Bool { get }` to the protocol, default `false`, and show the chart and
rows `.redacted(reason: .placeholder)` while it is true. Sync from Health needs the same flag,
since it currently gives no feedback at all when nothing new arrives.
Size: M
Decision needed: no

### 12. `ActivityRingView` borrows the Activity ring's look for calories
Severity: polish, App Review exposure
Where: `Components/Views/ActivityRingView.swift:10`, `:41-57`, `:73-74`; used once, at
`Core/Dashboard/Components/NutritionCard.swift:24-30`
Guideline: "Don't replicate or modify Activity rings for other purposes. Never use Activity rings
to display other types of data." —
https://developer.apple.com/design/human-interface-guidelines/activity-rings
What happens: it is one blue ring on the card surface, not Apple's three on black, and the app
shows no Move, Exercise or Stand data anywhere, so the hard rules are not broken. What it copies
is the signature: a round-capped arc with a shadowed tip that overlaps its own start, under that
name. Its VoiceOver label is the number ("1,450, 72%") with no word for what is measured. The
other rings (`ChallengeRing`, the Circle avatars, the calendar day capsule) are plain accent
progress rings and are fine.
Fix: rename it `ProgressRing`, remove the tip circle and its shadow (`:47-57`), and take a
`label` separate from the centre text so VoiceOver reads "Calories, 1,450 of 2,000 kcal". Or
replace it with `Gauge(value:)` in `.accessoryCircularCapacity` style.
Size: S
Decision needed: no

### 13. The Health app is called "Health"
Severity: polish
Where: `Core/Analytics/Subviews/InsightsAndAnalytics/Steps/StepsPresenter.swift:97`, `:116`, `:117`;
`BodyMetrics/MeasurementDetails/VisualBodyFatMetric.swift:64`
Guideline: "Refer to the Health app as Apple Health or the Apple Health app." —
https://developer.apple.com/design/human-interface-guidelines/healthkit
Fix: "Sync from Apple Health", "Unable to Access Apple Health", "Allow step access in the Apple
Health app to sync your steps."
Size: S
Decision needed: no

### 14. Chart descriptions for VoiceOver are thin or describe the drawing
Severity: polish
Where: `pkg:Marks/ChartAccessibility.swift:33`, `:41`; `pkg:Charts/TimeSeriesChart.swift:77-80`
(**needs a package change**); `Components/Views/Charts/SetsBarChart.swift:57`;
`Core/Onboarding/Components/WeeklyMacroChart.swift:14`, `:55`
Guideline: "supplying a chart title and descriptive summary that VoiceOver speaks"; "Describe
what the chart's details represent, not what they look like."; "avoiding potentially ambiguous
formats and abbreviations" — https://developer.apple.com/design/human-interface-guidelines/charts
What happens: the audio graph has a title but `summary: nil`, and its y axis is titled with the
unit ("kg") rather than the quantity. The range picker's segments are the raw values "W", "M",
"6M", "Y" with no spoken label. `SetsBarChart` says "the most in one bar 8". `WeeklyMacroChart`
labels its days "Mon", "Tue" from a hard-coded English array.
Fix: package — a `summary` built from the range header ("Average 82.4 kg, 14 to 20 September"),
the y axis titled with `accessibilityTitle`, and `.accessibilityLabel("Week")` and so on per
segment. App — "the most in one day 8" (or "workout", which the card knows), and
`Calendar.current.weekdaySymbols` for the day names.
Size: M
Decision needed: no

### 15. The weekly target grid has no title and no key
Severity: polish
Where: `Core/Analytics/Subviews/NutritionTargetChart/NutritionTargetChartView.swift:49-106`;
`Core/Analytics/Components/TargetCellView.swift:62-68`, `:78-86`;
`NutritionTargetChartPresenter.swift:43-63`
Guideline: "Write descriptions that help people understand what a chart does before they view
it." and "If you need to create a chart that presents data in a novel way, help people learn how
to interpret the chart." — https://developer.apple.com/design/human-interface-guidelines/charts ,
https://developer.apple.com/design/human-interface-guidelines/charting-data
What happens: it is the first thing on the tab and a custom chart type: 28 cells, a fill, a tick
and sometimes a caret. Nothing on screen names it, says the tick is the target or that the caret
means over by 10%. Rows are named only by a symbol in the last column. The week is Monday-first
whatever `Calendar.current.firstWeekday` says. VoiceOver is well served; sighted users are not.
Fix: a `.sectionTitle` heading ("This Week Against Your Targets") and a one-line key under the
grid. Build the day order from `firstWeekday`.
Size: S
Decision needed: no

### 16. Progress Photos: delete is only in a context menu, and Close sits beside Back
Severity: polish
Where: `Core/Analytics/Subviews/BodyMetrics/ProgressPhotos/ProgressPhotosView.swift:144-148`,
`:73-77`, pushed at `:171`
Guideline: "Always make context menu items available in the main interface, too." —
https://developer.apple.com/design/human-interface-guidelines/context-menus ; the Back button
"isn't intended to dismiss a sheet" and "Avoid showing all three buttons — Cancel, Done, and Back
— together." — https://developer.apple.com/design/human-interface-guidelines/sheets
What happens: a photo can be deleted only by touch and hold (VoiceOver has a custom action). The
screen is pushed, so it has a Back button, and it adds a leading close button whose action also
pops.
Fix: remove the close item. Add Select to the toolbar with a Delete action, or put Delete on the
compare screen.
Size: S
Decision needed: no

### 17. Energy Balance wording
Severity: polish
Where: `Core/Analytics/AnalyticsPresenter.swift:320`, `:322`;
`Subviews/InsightsAndAnalytics/InsightsAndAnalyticsPresenter.swift:201`, `:203`;
`Subviews/InsightsAndAnalytics/EnergyBalance/EnergyBalancePresenter.swift:43-70`
Guideline: "Use an action sheet — not an alert — to offer choices related to an intentional
action." — https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: the card puts the unit after the value, so it reads "450 deficit kcal". Tapping +
with a draft open shows an alert titled "Unable to add new meal" / "You already have an draft
meal." with three choices, one of which deletes the draft.
Fix: "450 kcal deficit" as one string with no `unit`. Use `router.showConfirmationDialog`,
titled "You have a draft meal", with Continue Editing, Delete Draft (destructive) and Cancel.
Size: S
Decision needed: no

## Smaller items

- **Strings that never reach the catalog** (project rule, not HIG). `MetricConfiguration` takes
  plain `String`s, so 44 `sectionHeader`, `emptyStateMessage`, `addActionTitle` and
  `contributionUnit` values and 25 `TimeSeries(name:)` series names show in English to Spanish
  users; the series names are also what VoiceOver and the chart header read. Same for
  `AnalyticsPresenter.swift:223`, `:378`, `:491`, `SectionHeaderView.swift:21`
  (`actionTitle = "See All"`) and `ProgressPhotoCompareView.swift:19-20`. The package has no
  string catalog at all ("No Data", "Time scale", "Show More … Data", "Days Logged").
- `MuscleGroupsView.swift:52` builds a sentence from a lowercased header
  (`"No \(header.lowercased()) body muscles…"`), which cannot be translated.
- `TargetCellView.swift:52` rotates a `ProgressView` to draw data. "All progress indicators are
  transient" (progress-indicators); "A gauge displays a specific numerical value within a range"
  (gauges). `Gauge` or a drawn bar is the component for this. It is hidden from VoiceOver, so
  the effect is visual only.
- `AnalyticsView.swift:83-90` wraps one card in a horizontal `ScrollView`. In split view the card
  takes half the width and the other half is empty.
- `pkg:Screen/ChartScreen.swift` closes Show More with `Button("Close", systemImage: "xmark")`,
  where the contract uses `role: .close`.
- `Utilities/UnitConversion.swift:59` formats weights with `String(format:)`, so every weight in
  this area has a full stop as its decimal separator in Spanish. The contract bans it.
- The Expenditure card's sparkline is one number repeated seven times
  (`AnalyticsPresenter.swift` `expenditureSparklineData`), under "Last 7 Days". The detail screen
  now reads `expenditureHistory`; the card should too, or show no chart.
- The sheets in `LogMeasurementView.swift:45` and `LogWeightView.swift:46` repeat "Date" as
  header and label, then add a footer that says to select the date.

## Contract conflicts

- **Monochrome accent (README decision 1) against the colour page.** "if you use your brand
  color to indicate that a borderless button is interactive, using the same or similar color to
  stylize noninteractive text is confusing." —
  https://developer.apple.com/design/human-interface-guidelines/color . With `AccentColor` =
  `labelColor`, "See All" (`SectionHeaderView.swift:32`), the today marker in the target grid
  (`NutritionTargetChartView.swift:67`, `:96`) and the Goal Progress series are the colour of
  body text. Not a finding; it resolves when the accent gets a hue. Finding 7 is the one place it
  makes something unreadable today.

## Done well — keep

- Every thumbnail chart (`SparklineChart`, `SetsBarChart`, `MacroStackedBarChart`,
  `EnergyBalanceChart`, `MacroProgressChart`) is one accessibility element with a value that
  summarises it, which is what the charts page asks of a chart inside a button.
- The full charts pass `accessibilityChartDescriptor`, so VoiceOver gets an audio graph, and the
  header and callout read one element per series with its unit.
- Muscle Balance carries status as colour, symbol and word, and says so in its own comment. The
  over-target caret in the target grid does the same.
- Bars start at zero and lines fit their range, as the axes guidance asks. The header states the
  average for the visible range, so nothing critical needs the press-and-hold callout.
- Health access for steps is requested when the Steps screen opens, not at launch.
- The target grid refuses to draw mock targets or zeros it has not read, and says "No Diet Plan"
  with the action to create one.
- Rows offer Delete only where the entry is stored, and a failed delete says so.
- The wheel height uses `@ScaledMetric`; the log sheets use `.half`, which includes `.large`.
- All ring and card animation goes through `withReducedMotionAnimation`.
