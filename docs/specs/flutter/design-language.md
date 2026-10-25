# Compound design language

What Compound looks, moves and sounds like. The owner chose this direction on 25 Oct 2026, and
it replaces the neutral look decided on 19 Oct (`decisions.md`). `ui-contract.md` says **how**
to build a screen (which `app_ui` widget, which token). This page says **what** the screen
should be: when a card is right, how loud a number is, where the accent goes.

Where this page and the contract meet, the contract names the widget and this page decides its
look. Apple's HIG still applies to anything neither page covers.

## The idea

**Bold and energetic, built on data.** Compound is a training app for people who log
everything. It should feel like an athletic brand, not a spreadsheet:

- heavy condensed numbers;
- one electric accent on a dark ground;
- a show when something is achieved.

Under that, every number is exact and every screen stays as calm as a list where the user
enters data.

| From | Take | Leave |
|---|---|---|
| Nike Training Club / Run Club | Heavy condensed type for titles and hero numbers; black and volt; confident, uncluttered screens | Photography; all-caps paragraphs |
| Strava | One loud accent used only for the thing to do; a stat as a big number over a small label; the social feed's card rhythm | Orange; dense ad-style banners |
| Apple Fitness | Vivid data colors on true black; rings for goals; award moments | Playful illustrations |

## Principles

1. **One hero per screen.** Each screen has one number or one action that matters most. Draw it
   biggest, in the display face. Everything else steps down.
2. **The accent means "you".** Volt marks your next action and your own progress: the primary
   button, the selected tab or segment, a goal ring filling, a ticked task, a streak, a personal
   record. It never marks plain information.
3. **Data colors mean their data.** Protein is coral in every chart, bar, icon and ring, and
   nothing else is. A data color never decorates.
4. **Loud at the top, quiet below.** Dashboards and summaries get the display type and the
   accent. Lists, forms and settings stay plain iOS: system font, grouped rows, no flourish.
5. **Celebrate what was earned.** Motion is quick and functional everywhere, with a show only for
   real achievements (Motion, below).
6. **Graphic, not photographic.** Energy comes from type, the accent and the data visuals. The
   only photos are the user's own: progress photos, food, avatars, gyms.

## Color

### Appearance

**Dark first.** Design every screen in dark mode, then check it in light. The app follows the
system setting; dark is just where it looks its best.

| Role | Dark | Light | Token |
|---|---|---|---|
| Canvas (the screen) | `#000000` | `#F2F2F7` | `appColors.canvas` |
| Surface (cards, grouped rows, the tab dock) | `#1C1C1E` | `#FFFFFF` | `appColors.surface` |
| Raised (a control or field on a surface) | `#2C2C2E` | `#E5E5EA` | `appColors.raised` (new) |
| Primary text | `#FFFFFF` | `#000000` | `colorScheme.onSurface` |
| Secondary text | `#AEAEB2` | `#6C6C70` | `appColors.secondaryLabel` (new) |
| Tertiary text (footnotes, placeholders) | `#8E8E93` | `#8A8A8E` | `appColors.tertiaryLabel` (new) |
| Divider | `#38383A` | `#C6C6C8` | `appColors.separator` (new) |

Surfaces are flat: no shadows, no blur, no gradients. Depth comes from the step between canvas,
surface and raised.

### The accent: volt

| Token | Dark | Light | Use |
|---|---|---|---|
| `colorScheme.primary` | `#C8F31D` | `#C8F31D` | Fills: the primary button, the selected tab's capsule, a segment's thumb, a ring, a tick |
| `colorScheme.onPrimary` | `#000000` | `#000000` | Text and icons on a volt fill (16:1) |
| `appColors.accentInk` (new) | `#C8F31D` | `#4D6600` | Volt as **text or a line on the canvas**: a text button, a link, a chart's goal line. Light mode needs the dark olive, because volt on white is 1.2:1 |

- **Fill, don't tint text.** Volt is a background with black on it. Volt text appears only in
  dark mode, and in light mode it becomes `accentInk`.
- **Sparingly.** One volt-filled control per screen, plus selection and progress marks. No volt
  backgrounds bigger than a button, and no volt headings.
- **Never alone.** A selected tab also fills its icon and bolds its label; a ticked task also
  shows ✓. In light mode, volt is barely distinguishable from white, so the second cue carries
  the meaning.
- **Increase Contrast** (`MediaQuery.highContrastOf`): in light mode, volt fills gain a 1 pt
  `onPrimary` outline, and `accentInk` darkens to `#3A4D00`.
- **Done is volt, not green.** A completed task, a closed ring and a finished set use the accent.
  `success` green is kept for system messages ("Saved", a connected integration), so the two
  greens never sit side by side.

### Data and status colors

The data colors in `AppColors` (calories, protein, carbs, fat, steps, expenditure, scale weight,
body fat and the rest) stay as they are. None is close to volt. They appear:

- in charts, bars and rings for that metric;
- as the icon tint in that metric's card header.

Nowhere else. Status colors (`success`, `warning`, `danger`) are for messages and destructive
actions, always paired with an icon or words.

## Type

Two faces, each with one job.

| Face | For | Styles |
|---|---|---|
| **Barlow Condensed** (Google Fonts, Open Font License, bundled in `app_ui`), weights 700 and 800 (900 bundled too), tabular figures | Large titles, hero numbers, stats, celebration text | `largeTitle` (new), `display`, `metricLarge`, `metric` |
| **System** (San Francisco on iOS, Roboto on Android) | Everything you read: rows, body, buttons, labels | `sectionTitle`, `rowTitle`, `rowDetail`, `label`, `overline` (new), and `metricSmall`, which moves to the system face with tabular figures because it sits inline with row text |

- Barlow Condensed replaces Nunito. It is narrow, so its styles sit one step above the iOS size
  they replace. The ramp, set in the preview PR:

  | Style | Face | Size / line | Weight |
  |---|---|---|---|
  | `largeTitle` | Barlow Condensed | 40 / 44 | 800 |
  | `display` | Barlow Condensed | 44 / 48 | 800 |
  | `metricLarge` | Barlow Condensed | 34 / 38 | 800 |
  | `metric` | Barlow Condensed | 24 / 28 | 700 |
  | `metricSmall` | System | 15 / 20 | 600 |
  | `overline` | System | 12 / 16, +0.6 | 600 |

  The system styles (`sectionTitle`, `rowTitle`, `rowDetail`, `label`) keep iOS's sizes.
- **A stat is a number over an overline.** The number is in `metric` or bigger, and the overline
  is the unit or name, in `overline`: 12 pt semibold system, all caps, tracked +0.6. For example,
  "1,842" over "KCAL LEFT", or "101 KG" over "EST. 1RM". All caps is for overlines only, never
  for sentences.
- **Numbers always line up.** Every number style has tabular figures built in, so no screen
  adds `fontFeatures` itself.
- **Secondary text uses its token.** A style comes with a `.secondary` variant
  (`AppTextStyles.rowDetail.secondary`) instead of `copyWith(color: …)` on each screen.
- **Bold Text** (`MediaQuery.boldTextOf`) moves the system styles to bold (Flutter sets every
  style to 700). Barlow Condensed keeps its weight: Flutter cannot make it heavier without a
  variable font, so `app_ui` only makes sure Bold Text never draws it lighter. Every style
  scales with the user's text size, up to 200%.

## Shape and space

- Spacing, radii and control sizes are the existing tokens. Density stays **balanced**: 52 pt
  rows, 16 pt margins, the hero big and the details compact.
- Corners: `AppRadius.l` (16) for cards and the dock, `AppRadius.m` (12) for controls inside
  them, capsules for buttons, chips and the search field.
- Lines are 1 pt `separator`. Rings and progress strokes use `AppChartMark`'s widths.

## Components: cards or lists

**Lists by default.** Anything the user browses, picks from or edits is grouped rows in an
`AppSection`: settings, libraries, forms, a workout's sets, history.

**A card is a summary at a glance**, and every card has the same three parts:

```
┌──────────────────────────────────────┐
│ ◉ PROTEIN                     ›      │  header: data-colored icon, overline title,
│                                      │          optional trailing (chevron, chip, ⓘ)
│ 104 / 165 G                          │  hero: one number in the display face,
│ ███████████░░░░░░  ▲ 12 this week    │        or a chart or ring; one delta at most
│                                      │
│ 61 g to go · on track                │  footer (optional): one line, secondary text
└──────────────────────────────────────┘
```

- That card is one `app_ui` widget (the preview PR names it). The 13 card classes in feature code
  become arrangements of it.
- **The whole card is the tap target.** It gets one pressed state and one haptic, and no inner
  buttons except an `AppChip` in the header.
- A card never holds a list longer than three rows. Longer content gets "See All" in the section
  header.

## Screen types

Every screen is one of these. Pick the type before designing a screen.

| Type | Examples | Shape |
|---|---|---|
| **Dashboard** (tab root) | Today, Training, Nutrition, Progress, Social | Large title in Barlow Condensed. The hero card first: today's one number, with the accent if it's a goal. Then summary cards, then "See All" sections. The one primary action is a volt CTA or the toolbar's + |
| **Detail** | A metric, an exercise, a past workout, a program | A standard title. A hero stat block (number, overline, delta) and the chart, then grouped rows of the details |
| **Logging** (sheet or form) | Log Weight, Create Food, Set Target | Plain: grouped rows, `AppNumberField`, close at the leading edge and ✓ at the trailing edge. No display type, no cards |
| **Library** | Exercises, Foods, Templates, People | A search field, then grouped rows; chips to filter |
| **Live** | Active workout, rest timer, label scanner | Readable at arm's length mid-set. The current set and timer in Barlow Condensed at their largest, volt on the current set and on Finish, big tap targets. It follows the appearance setting like every screen |
| **Moment** | Workout summary, PR, day complete, streak milestone, weekly review | Full-bleed hero: the achievement in `display` at its largest, a count-up, confetti, then the details as a list. Shareable |

## Motion

Quick and functional everywhere, with a show only for real achievements.

- **Interface:** push, sheet and dialog transitions are the platform's own. In-place changes
  (a value updating, a row appearing) use `AppMotion.quick` and `standard`. No springs on cards
  and no parallax.
- **Charts** draw in once when they first appear and morph when the range changes (already built).
- **Moments**, the only places with a show:
  - a personal record;
  - finishing a workout;
  - completing the day;
  - a streak milestone;
  - closing a goal ring.

  Each gets a count-up of its hero number (`AppMotion.emphasis`), the accent flashing on, a
  `success` haptic, and confetti in volt and the data colors for the bigger ones (workout, day,
  streak).
- **Reduce Motion** turns every one of those off, leaving the final state and the haptic.

## Icons and imagery

- Material Symbols, outlined, through `AppSymbols`: one concept, one icon. A selected tab's
  icon is filled.
- An icon is never bigger than the text beside it, except in an empty state.
- No stock photography and no illustrations. Empty states are an icon, a line and an action.

## Voice

**A direct coach.** Short, active and specific. Encourage with facts, not adjectives.

| Do | Don't |
|---|---|
| "61 g protein to go." | "You're doing great, keep going!" |
| "New PR. Bench Press 101 kg." | "Crushed it! 🔥" |
| "Log a meal to see what's left today." | "No data available." |
| "Couldn't save. Check your connection and try again." | "An error occurred." |

- Second person, present tense, no exclamation marks, no emoji.
- Use numbers rather than words, with units: "3 workouts", "8,000 steps".
- Buttons and titles in Title Case, US spelling, as now. Every string has a Spanish version
  (`arb-spanish.py`).
- The coach speaks the same way.

## How we get there

1. **This page.**
2. **Preview PR: theme and tokens only.**
   - Volt, the dark-first palette and the new color tokens.
   - Barlow Condensed in place of Nunito.
   - `overline`, `largeTitle`, `.secondary` and tabular figures in the type ramp.
   - Done marks in volt.
   - Goldens regenerated, and before-and-after screenshots of every staging screen in dark and
     light, for the owner to judge. No screen is redesigned in it.
3. **Close the gaps the lint can't see**, one PR each, each adding a `flutter-ui-check.py` rule
   once the count reaches zero:
   - the color and font changes screens make to text styles themselves (`copyWith`);
   - opacity values typed in by hand;
   - `BoxDecoration` in feature code;
   - raw `InkWell` and `GestureDetector` (replaced by a pressable surface in `app_ui`);
   - raw `TextField` (replaced by an `app_ui` text field).
4. **The summary card**, then the 13 card classes moved onto it.
5. **Screens by type:** dashboards first, then the moments, then details. Each PR comes with
   before-and-after screenshots.
