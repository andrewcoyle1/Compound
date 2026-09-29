# Screenshot review after the HIG fixes (2026-09-29)

Decks compared: `shots-before/` (captured 28 Sep 2026) against `shots-after/` (29 Sep 2026), 42
screens, light and dark, 1206x2622. I opened 64 before/after pairs: all 63 images the diff log
marks as changed, plus `FOOD_DETAIL-light` because its dark twin changed. The ten screens unchanged
in both appearances (ACTIVE_PROGRAM, BODY_METRICS, CHALLENGES, EXERCISE_DETAIL, GYM_PROFILES,
MEAL_DETAIL, MUSCLE_BALANCE, PROGRAM_LIBRARY, SHARE_CARD, USERNAME) were not opened. I cropped
full-size detail for the Analytics header, the Dashboard circle strip, the set tracker table, the
Nutrition title and the Create Program status bar.

A still image cannot show tap target size, hit areas, VoiceOver, animation, Reduce Motion,
scrolling behaviour, or anything at a larger Dynamic Type size. The 44 pt changes are judged only
on how they look, not on whether they are actually 44 pt. Two after images carry capture noise:
the Dynamic Island shows in TRAINING-light and CREATE_PROGRAM/CREATE_WORKOUT-light, and an "Apple
Intelligence" system banner covers the navigation bar in SOCIAL_PROFILE-light.

## Findings

### 1. Analytics: the weekly target grid runs off both edges of the screen
Severity: hurts usability
Screen: STARTSCREEN_ANALYTICS, both
What I see: The new "This Week Against Your Targets" heading and the key under the grid sit flush
against the left screen edge with no margin. The grid is wider than the screen, so the weekly
totals column is clipped at the right edge ("15,210 kcal" touches the edge).
Before: The grid had even margins on both sides and fitted.
Likely cause: `DialedIn/Core/Analytics/AnalyticsView.swift` `headerSection` (commit 4e93460d). The
`ScrollView(.horizontal)` was replaced with a plain `HStack` plus `.padding(.horizontal,
headerCardSpacing)`, but `headerCard` still sizes the card with `containerRelativeFrame(.horizontal,
count: 1, …)`. Outside a scroll view, that makes the card as wide as the whole row, and the padding
is then added on top of it.

### 2. Disabled call-to-action buttons have a nearly invisible label
Severity: hurts usability
Screen: STARTSCREEN_CREATE_EXERCISE, both
What I see: The disabled "Next" button at the bottom shows white text on a near-white capsule in
light mode and dark text on a dark capsule in dark mode. It is barely legible, and it hardly reads
as a button at all.
Before: A grey capsule with a clearly legible label.
Likely cause: `DialedIn/Components/Buttons/CallToActionButton.swift` (commit 61351645) now always
draws the primary label in `Color.onAccent`. The disabled glass-prominent background is no longer
the accent, so the label loses its contrast. This is a shared component, so every disabled
`CallToActionButton` in the app is probably affected (Create Food, Create Recipe, onboarding and
others that were not captured here).

### 3. The warm-up set badge shows a clipped glyph instead of "W"
Severity: hurts usability
Screen: STARTSCREEN_WORKOUT_TRACKER and STARTSCREEN_SET_KEYBOARD, both
What I see: In the set table, the warm-up row's circle shows a small orange "Λ", the middle of a
clipped "W". A person cannot tell this row is a warm-up set. Numbered sets ("1") still read,
because the digit is narrow.
Before: A small outlined circle with a legible orange "W".
Likely cause: `…/SetTracker/SetTrackerRow/SetTrackerRowView.swift` `setNumber(set:)`. It uses
`.buttonStyle(.glass)`, `.buttonBorderShape(.circle)` and `.controlSize(.large)` inside
`.frame(width: setColumnWidth)`, which is 44 pt. The large glass circle's padding leaves too
little width for the "W" label. hig-handoffs.md already lists these control sizes as "unverified,
needs a device".

### 4. Set tracker header: the "Auto" label is gone and the chip row no longer fits
Severity: polish
Screen: STARTSCREEN_WORKOUT_TRACKER and STARTSCREEN_SET_KEYBOARD, both
What I see: The Prev/Auto column header is now a large, faint glass pill with only the wand icon.
The word "Auto" has dropped out. The "Kg" header is a large faint blob of the same kind. The
Equipment / Warmup / Targets chip row has grown, so "Targets" is cut to "Tar" at the card's edge,
and each exercise card is noticeably taller.
Before: Compact pills reading "Auto" and "Kg", and all three chips fitted on one line.
Likely cause: `…/SetTracker/SetTrackerView.swift`. `prevAutoHeader` has `.controlSize(.large)`
inside a 78 pt frame, which leaves no room for the title. `equipmentButton` has
`.controlSize(.large)` on the chips (active-workout finding 3). The chip row is a horizontal
`ScrollView`, so "Tar…" is technically scrollable, but nothing makes that obvious.

### 5. Dashboard: Nudge and Set goal buttons became oversized blobs
Severity: polish
Screen: STARTSCREEN_DASHBOARD, both (the band only in light)
What I see: Under each face in the circle strip, "Nudge" and "Set goal" are now fat rounded
glass shapes about 57 pt tall, nearly as wide as the avatars. They dominate the strip. In light
mode the strip also sits on a slightly darker grey band that ends in a hard edge just above
"This Week".
Before: Small capsule buttons about the height of a line of text, with no band.
Likely cause: `DialedIn/Core/Dashboard/CircleActivityStripView.swift`. `Text("Nudge").tapTarget()`
and `Text("Set goal").tapTarget()` sit inside the label of a `.buttonStyle(.glass)` button, so the
44 pt frame becomes the visible glass shape instead of an invisible hit area. The band is not
traced.

### 6. Create Workout and Create Program: status bar unreadable in dark mode
Severity: polish
Screen: STARTSCREEN_CREATE_WORKOUT and STARTSCREEN_CREATE_PROGRAM, dark
What I see: The time and battery are drawn in white over the white hero illustration. The time
reads as ":41" and the signal and Wi-Fi icons disappear.
Before: The status bar was dark over the light image in both appearances, and legible.
Likely cause: Not traced. The likeliest candidate is commit 04b1a0a7 ("Put the hero intro headings
back under the image"), which removed the bar title with `.toolbar(removing: .title)`. It may also
be how iOS picks the status bar style when no bar content sits under it. Check on a device.

### 7. Nutrition tab title truncates to "Nutriti…"
Severity: polish
Screen: STARTSCREEN_NUTRITION, both
What I see: The large inline title is cut to "Nutriti…" next to the info, calendar/more and
profile buttons.
Before: "Nutrition" fitted, just barely.
Likely cause: Not traced. The toolbar in `Core/Nutrition/NutritionView.swift` has not changed. The
`info` (developer settings) button is `#if DEV || MOCK`, so Production has one control fewer and
may fit, but the margin was already zero and any localisation will truncate it.

### 8. Recipe detail: the new close button crowds the bar and truncates the title
Severity: polish
Screen: STARTSCREEN_RECIPE_DETAIL, both
What I see: The bar now carries info, close, title and subtitle, heart and play. The title reads
"Classic Margherit…" and the subtitle "A simple and delicious pi…".
Before: The full title "Classic Margherita Pizza" fitted, without a close button.
Likely cause: Nutrition finding 9 added the close button, which is correct. The DEV-only info
button accounts for part of the squeeze. Food detail has the same new close button and still fits
because its title is short.

### 9. Comments: rows much taller, with the avatar and like button out of line
Severity: polish
Screen: STARTSCREEN_COMMENTS, both
What I see: Each comment is about 1.6 times taller. The avatar is centred vertically on the row
while the name and text are top-aligned, so the avatar sits beside the comment body rather than the
name. The heart is also centred, away from the timestamp. The small grey "Reply" under each comment
adds a lot of empty space.
Before: A compact row with the avatar, name and heart on one line.
Likely cause: The visible Reply button and the 44 pt like target (dashboard-social findings 4 and
6) in `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift`. The row alignment was not
updated for the taller content.

### 10. Notifications: Accept and Decline now stack vertically at the default text size
Severity: polish
Screen: STARTSCREEN_NOTIFICATIONS, both
What I see: For a follow request, Accept and Decline sit one above the other at the right,
leading-aligned and of different widths, which gives a ragged column. "Wants to follow you" still
wraps onto two lines, and the row is taller.
Before: Two small buttons side by side.
Likely cause: `Core/Notifications/NotificationsView.swift` `followRequestsSection`. With
`.controlSize(.small)` dropped (foundations finding 4), the `HStack` branch of `ViewThatFits` no
longer fits at the default size, so the fallback that was meant for accessibility sizes shows all
the time.

### 11. Own profile: "Set a weekly goal" is detached from the lines above it
Severity: polish
Screen: STARTSCREEN_OWN_PROFILE, both
What I see: In the header card, the name, handle, streak and "Following Block 1" are tightly
stacked, then a noticeably larger gap sits above "Set a weekly goal". The card is taller.
Before: All five lines had even spacing.
Likely cause: The 44 pt target on the weekly-goal button (dashboard-social finding 4, SocialProfile
weekly-goal button). The target frame is visible as spacing.

### 12. Search: shortcut chips pushed down, leaving a gap under the title
Severity: polish
Screen: STARTSCREEN_SEARCH, both
What I see: Start Workout / Log Meal / Log Weight sit about 13 pt lower, with empty space between
them and the "Search" title. The Enter Invite Code row moves down with them.
Before: The chips sat directly under the title.
Likely cause: Probably commit 52ece7bf ("Give every tappable chip a 44 pt tap target"). The chips
are drawn at their old size but take up 44 pt of height. Not confirmed in code.

### 13. Contribution grid clips the "Oct" month label to "C"
Severity: polish
Screen: STARTSCREEN_OWN_PROFILE and STARTSCREEN_INVITE, both
What I see: Under the Training Days grid, the last month label at the trailing edge shows only a
sliver ("C").
Before: Not visible. On 28 Sep the newest column did not start a new month.
Likely cause: Date-triggered, not a HIG regression. The new week's column (28 Sep to 4 Oct) gets an
"Oct" label that does not fit. The labels are drawn by QuickCharts' `ContributionGridView`, so the
fix belongs in the package.

### 14. Scale Weight and measurement detail: week axis does not match the header
Severity: polish (uncertain)
Screen: STARTSCREEN_SCALE_WEIGHT and STARTSCREEN_MEASUREMENT_DETAIL, both
What I see: The header says "Average, 28 Sep – 4 Oct 2026" (Monday to Sunday), but the chart's x
axis runs Sat, Sun, Mon … Fri. The line also enters from above the top of the plot area.
Before: The axis ran Mon to Sun, matching the header. The line was clipped then too.
Likely cause: Not traced. It may be date-driven (a scroll position anchored on today) rather than
a regression. Compare with the Analytics finding 15 change to `Calendar.current.firstWeekday` if
the two are related.

## Intended changes that look right

- Workout tracker: `chevron.down` Minimize in the leading slot, and no duplicate close.
- Account: Save checkmark in the toolbar, prominent, beside the photo button.
- Foods and Food detail: close button added. Library rows without a picture show a neutral
  placeholder instead of a random image.
- Progress Photos: the redundant close is gone and Delete sits in the toolbar group with Compare.
  The deck opens this screen as a root, so the system Back button that is meant to replace the
  close cannot be seen here.
- Training: "Programs" row title. Unfinished program days end in a chevron instead of an empty
  circle.
- Weekly Review: the forward arrow is disabled on the current week.
- Title case and wording: "This Week", "Premium", "Enter Invite Code", "Add to Library" /
  "Decline" on a shared item.
- Exercises: the filter chips are taller and still look even and aligned.
- Notifications: the Enable Notifications empty state reads more cleanly. The settings gear beside
  close is new (feature commit a916072b, not a HIG resolution). Dashboard-social finding 8, where
  the settings screen should live, is recorded as undecided.
- Analytics: the grid's heading and key are the right idea. Only their layout is wrong (finding 1).

## Screens that differ only by date or mock data

WEEKLY_REVIEW, SESSION_DETAIL, WORKOUT_HISTORY, CHALLENGE_DETAIL, SOCIAL_PROFILE, FOLLOWERS,
PROFILE (apart from the intended "Premium"), SHARED_ITEM (apart from the intended wording),
RECIPES, TEMPLATE_DETAIL (its title and subtitle are now centred rather than leading, which looks
fine), ACCOUNT (header photo). On DASHBOARD, the missing "Last week" and "weekly review is ready"
cards follow from the week rolling over.

## Not captured by this deck

- Onboarding (every step), paywalls, sign-in and Welcome.
- Live Activity, Dynamic Island, Lock Screen and widgets, and the rest-timer pill with +15s and
  Skip.
- Every sheet, alert and confirmation dialog the fixes introduced or reworded: discard-changes,
  draft meal, active workout, invite code, unit pickers, Set Rest, report and the rest.
- Toasts, loading overlays and spinners, error and "Try Again" states, and offline states.
- Nutrition flows: Add Meal and its bar, Create Food, Create Recipe, the barcode and label scanner,
  Quick Add, and Copy Day.
- Settings subpages: Integrations/Strava, Units, Food Log, rest timers, Gym Profile editing,
  About/Licences, and Notification Settings.
- Program design and editing, the exercise picker, and the multi-step create flows past their
  first screen.
- Dynamic Type at accessibility sizes, which is where most of the `AdaptiveStack` and
  `@ScaledMetric` work lives; VoiceOver; Reduce Motion; Spanish; iPad and split view.
- The ten screens whose images were unchanged in both appearances. They were not opened.
