# Flutter UI contract

The rules every screen in `app/` follows. The owner set them on 18 Oct 2026, after the first
TestFlight build worked but looked inconsistent: each screen had styled its own pieces (216
private widgets in 83 files, 331 raw Material buttons, 83 ad-hoc text styles). Where a rule needs
a value, the Swift app's `docs/specs/ui-framework/CONTRACT.md` has already decided it; the Dart
names are below.

The design system is the `app_ui` package (`app/packages/app_ui/`). Charts live in
`compound_charts` (`app/packages/compound_charts/`), which draws on `app_ui`'s tokens and depends on
nothing else. Feature code in `app/lib/` uses the two and styles nothing itself.

What the app should look and feel like (the accent, type, cards, screen types, motion, voice) is
`design-language.md`. This contract is how to build it.

## 1. Reuse before you build

- **Look in `app_ui` first.** If a widget there fits, use it, even if it is not quite what you
  pictured. Ask the owner before building something that differs from it.
- **A new component goes in `app_ui`, never in the screen.** That includes a variant of an
  existing one: add a parameter to the existing widget rather than a near-copy beside it.
- **Private widgets (`class _Foo`) are for laying out one screen only.** They arrange `app_ui`
  widgets; they never set a colour, text style, padding, radius or shape. If two screens need
  the same private widget, move it to `app_ui`.
- `app/lib/widgets/` holds app-level widgets that need app types (blocs, models). They follow
  the same rules and move to `app_ui` once they no longer need the app.

## 2. Tokens only

| Instead of | Use |
|---|---|
| `Colors.white`, `Color(0x…)` | `context.appColors.*` (`canvas`, `surface`, `raised`, `secondaryLabel`, `tertiaryLabel`, `separator`, `accentInk`, `tintedSurface`, `muted`, the macro, metric and status colours; never an opacity typed in with `withValues(alpha:)`) or the `ColorScheme` (`primary` is the accent as a fill, `onPrimary` the text on it) |
| `TextStyle(…)`, `fontSize:`, `fontWeight:`, a text style's `copyWith(color:, fontFeatures:, …)` | `AppTextStyles.largeTitle`, `display`, `metricLarge`, `metric`, `metricSmall`, `sectionTitle`, `rowTitle`, `rowDetail`, `label`, `overline`, `formula`; `.secondary(context)` for secondary text, `.accent(context)` for the accent as text, `.onAccent(context)` on a volt fill, `.semibold`, `.tabular` for a number in a reading style. A data or status colour goes on the icon beside the text, not the text |
| A number in `EdgeInsets` or `SizedBox` | `AppSpacing.xxs` … `xxl` (2–32); `AppControlSize`, `AppChartHeight`, `AppContentWidth` for sizes |
| `BorderRadius.circular(12)` | `AppRadius.s` … `xl` |
| `Duration(…)` on an animation | `AppMotion.quick` / `standard` / `emphasis` / `progress`, through `durationOf` so reduced motion is honoured |
| `Icons.*` | `AppSymbols.*`: one concept, one icon. Add the concept there if it is missing |
| Formatting a number by hand | `AppFormat` |
| `DateFormat`, `formatTimeOfDay`, a date built by hand | `AppFormat.date` (with an `AppDateStyle`), `time`, `hour`, `dateTime`, passing `locale: context.dateLocale` and `use24HourFormat: context.use24HourFormat`: the app's language with the device's region and clock, as iOS does |

- The accent is never written as its current value. Text on an accent fill is `onPrimary`; the
  accent as text, an icon or a line on the canvas or a surface is `appColors.accentInk`.
- Status colours are never the only signal: pair them with an icon or text.
- Exempt: share cards (`lib/sharing/share_card/`, `weekly_review_share_card.dart`), which render
  to fixed-size images, and user data such as a gym's chosen colour.
- Material comes through `package:app_ui/app_ui.dart`, never `package:flutter/material.dart`.
  Since Flutter 3.47 the app's Material is the `material_ui` package, and the framework's copy
  is a second library with its own `Theme`: a widget or route built from it finds no theme and
  draws stock Material 3 (the lavender sheet strip and purple dialog buttons in the comparison).
  Cupertino likewise comes from `package:cupertino_ui`. CI's `framework-import` rule enforces both.

## 3. No raw Material building blocks in features

`TextButton`, `IconButton`, `FilledButton`, `OutlinedButton`, `ListTile`, `Card`,
`showDialog`, `AlertDialog` and `showModalBottomSheet` are wrapped once in `app_ui`, and screens
use the wrapper. Restyling the wrapper then restyles every screen.

| Need | Use |
|---|---|
| Primary action | `AppCtaButton` in `AppBottomCta` |
| A secondary action | `AppCtaButton(variant: AppCtaVariant.secondary)`: a tinted fill, never an outline |
| An inline button in a row or card (Follow, Accept, Edit Profile) | `AppCtaButton(size: AppCtaSize.compact)`, primary or secondary |
| A low-emphasis text action (See All, Not now) | `AppTextButton`, `isDestructive` for a removal |
| An app bar button | `AppToolbarButton`; `.close` at a modal's leading edge, `.confirm` (with `isSaving`) at its trailing edge, `.avatar` for the profile button |
| An icon-only button in content (a row's edit pencil) | `AppIconButton` |
| A row | `AppListRow`, `AppListRowButton`, `AppListRowToggle`, `AppSelectableRow` in an `AppSection` |
| A picker row | `AppListRowMenu(value)` as the row's accessory: the value with an up-and-down chevron |
| A destructive row | `AppListRowButton(destructive: true)`: the title in `appColors.danger` |
| A section header's note or action | `AppSection(trailing:)`: a `Text` ("Required", a count) or an `AppChip` with `onPressed` ("See All", "New", "Hide") |
| A search | `AppSearchField` |
| A choice between a few options | `AppSegmentedControl` |
| The tab bar | `AppTabBar`: an inset card dock, with `accessory:` for the bars above it |
| A bar above the tab bar (the workout under way, the unlogged meal) | `AppTabAccessory` |
| A colour the user stored as `#RRGGBB` | `AppColors.fromHex` |
| A card | `AppCard`, `AppStatTile` |
| A colour or a mesocycle's glyph in a circle, as a picker or a row's thumbnail | `AppSwatch` |
| A grid cell's selected state (a photo, a muscle, a day) | `AppSelectionRing` |
| A value | `AppStat` |
| A tag or filter | `AppChip` |
| A number entry | `AppNumberField` |
| A form or scanner message | `AppInlineMessage` |
| A screen | `AppScaffold`, `AppDashboard` for tab roots, `AppOnboardingStepScaffold` for onboarding |
| Swipe actions | `AppSwipeActions` |
| An alert, confirmation or choice | `showAppDialog` with `AppDialogAction`s; `AppDialog.confirmDestructive` for an irreversible action |
| A brief notice ("Saved", "Set deleted" with Undo, a failure to retry) | `showAppSnackBar(context, message, style:, action:, duration:)`, never `SnackBar` or `ScaffoldMessenger`. It shows above the tab bar, a bottom CTA and the keyboard, one at a time, and outlives the screen; to show one after an `await` that may close the screen, take `AppSnackBarScope.of(context)` first and call its `show` |
| A sheet | `AppSheetPage` (a route's `pageBuilder`) or `showAppSheet`, sized `AppSheetSize.compact` / `half` / `full` |
| Nothing to show, or a failure | `AppEmptyState`, `AppErrorState` |
| Loading | `AppPlaceholderRow` / `AppPlaceholder` in place of the content (they shimmer, and hold still under reduced motion); `AppLoadingView` for a screen's first load |
| Work under way in a control or beside text (saving, connecting, looking up) | `AppSpinner`, `AppSpinnerSize.small` in a row, button or line of text; never `CircularProgressIndicator` or `CupertinoActivityIndicator`. A ring or bar showing real progress (a `value:`) is not a spinner |
| A one-time tip on a feature hidden behind a gesture | `AppTip` around the target, inside the screen's `ScreenTips` (`lib/tips/`), which remembers it per device |
| A chart, or the readout over one | `compound_charts`: `ChartCallout` with a `ChartCalloutSummary`. A new chart piece goes there, not in `app_ui` or the screen |

Every icon-only button takes a required `semanticLabel`, which is also its tooltip.

## 4. Screen patterns

Ported from the Swift contract's Patterns table.

| Pattern | Rule |
|---|---|
| Primary action | One per screen, `AppCtaButton` pinned in `AppBottomCta` |
| Dismiss | A close button at the leading edge of a modal's app bar. No "Cancel" text button. In a dialog, Cancel is an `AppDialogRole.cancel` action |
| Confirm | A confirm button at the trailing edge, with a spinner while saving |
| Titles | Tab roots have a large title. Every other screen has a standard title |
| Empty and error states | `AppEmptyState` / `AppErrorState`: icon, title, description and, where possible, the action (Try Again for an error) |
| Loading | A list or card shows `AppPlaceholderRow`s or `AppPlaceholder`s shaped like its content. `AppLoadingView` only for a screen's first load |
| Destructive | Destructive styling (`AppDialogRole.destructive` in a dialog). Irreversible actions confirm first with `AppDialog.confirmDestructive`, which has a Cancel |
| Sheets | `AppSheetPage` or `showAppSheet`, sized only `compact`, `half` or `full`; each drags to full height, opens at full height at large text, and has a drag handle |
| Selection | Anything with a selected state announces it to screen readers |
| Haptics | `AppHaptics`, never Flutter's `HapticFeedback`: `success` after every save, log, complete or finish; `error` when one fails; `selection` for pickers and segments; `warning`, `light`, `medium` and `heavy` where those fit. It plays the iOS patterns on Android too (`haptic_feedback`). Tests record them with `AppHaptics.debugPlay` |

## 5. Accessibility is part of done

- Text at 200% scale: nothing clipped or overlapping; rows grow, they don't truncate titles.
- Tap targets at least 44 × 44 points (48 dp on Android).
- Contrast checked in light and dark mode.
- Every icon-only button has a semantic label.

## 6. Golden tests for `app_ui` and `compound_charts`

Every `app_ui` and `compound_charts` widget has golden-image tests in light mode, dark mode and at 200% text, so a
change that makes a component look worse fails a test and agents get visual proof without a
device.

- **One image per widget**, its states as rows and light, dark and light at 200% text as columns.
  Write them with `goldenStates` (`test/helpers/golden.dart`) in the widget's own test file;
  `onIos(…)` draws a state in its iOS form where the widget adapts (alerts, switches, spinners).
  A new widget, or a new state of one, gets a row in the same PR.
- **Two sets of images**, made with [alchemist](https://pub.dev/packages/alchemist) beside each
  test file:
  - `goldens/ci/`: every text run and icon drawn as a solid block, without shadows. Text is laid
    out in Roboto (which alchemist bundles) or else Flutter's test font, so line breaks are
    real, but no glyph is drawn. These are what every test run compares, on a Mac and on CI's
    Linux alike, because glyph rasterisation differs between the two and blocks do not. Up to 0.5% of pixels may
    differ (`test/flutter_test_config.dart`), for the anti-aliasing an arm64 Mac and the x86
    runner disagree on.
  - `goldens/macos/`: the same images with real text (Barlow Condensed, Material Icons, and Roboto in place
    of San Francisco, which may not be redistributed), for people to look at. They are made and
    checked only on request, on a Mac.
- `compound_charts` has its own copy of `goldenStates` and `flutter_test_config.dart` in its
  `test/` folder; `app_ui` does not export them.
- **Run** (from `app/packages/app_ui`, or `app/packages/compound_charts` with `test/src`; the
  very_good MCP `test` tool takes the same options):

  | To | Run |
  |---|---|
  | Check, as CI does | the package's tests, as usual |
  | Update the CI images | `flutter test --tags golden --update-goldens test/src/widgets` |
  | Update the readable images | the same, plus `--dart-define=HUMAN_GOLDENS=true` |

  Update with a path, as above: very_good's test optimiser can only compare against images that
  already exist, so it cannot write a new one. A failure leaves the expected, actual and diff
  images in `failures/` beside the test (ignored by git).
- **A changed image needs the owner's eye.** Update both sets together. A PR that changes any
  existing golden lists each changed file in its body, with a line on why, so the owner can
  look at the readable image before it merges. A new golden needs no note.

## 7. Component gallery

Development and staging builds have a gallery screen, reached from Developer Settings
(`/profile/settings/developer/gallery`), that shows every `app_ui` widget in each of its states
and every token, with switches for light and dark and for 100%, 150% and 200% text. Production
never registers its route.

- **A new `app_ui` widget, or a new state of one, gets a gallery entry in the same PR.** The
  entries are in `app/lib/settings/dev/gallery/gallery_components.dart` (tokens in
  `gallery_tokens.dart`, charts in `gallery_charts.dart`); `component_gallery_page_test.dart`
  fails while an exported `app_ui` or `compound_charts` widget, `show…` function, `AppSymbols`
  icon or `AppColors` colour is missing from them.
- `scripts/flutter-screenshots.sh <udid> <out-dir> GALLERY` shoots the whole gallery a screen at
  a time, light and dark.

## 8. Before-and-after screenshots

A PR that changes how something looks includes before and after screenshots (light and dark),
or the golden diffs.

`scripts/flutter-screenshots.sh <simulator-udid> [out-dir] [NAME,…]` shoots every staging screen
listed in `app/integration_test/screens_test.dart`, light and dark, into `app/build/screenshots`.
Run it on the base branch for "before" and on yours for "after"; it needs a booted simulator.

## Platform look

**One Compound look on both platforms** (own brand, decided 14 Oct 2026), with each platform's
native behaviour where people expect it: swipe back on iOS, the platform's date and time pickers,
and the platform's style of sheets and alerts. These are chosen inside the `app_ui` wrappers, so
screens never branch on platform themselves.

## Enforcement

`scripts/flutter-ui-check.py` runs in CI (`flutter.yml`, **UI contract** job) and enforces rules 2
and 3 on `app/lib/` and `compound_charts/lib/` (and `framework-import` on `app/test/` and
`compound_charts/test/`). Its `raw-haptic` rule holds rule 4's haptics to `AppHaptics` there and in
`app_ui/lib/`, where only `AppHaptics` itself calls `HapticFeedback`. Its `raw-snackbar` rule holds snack bars to
`showAppSnackBar` everywhere in `app/lib/`, share cards included. Its `showcase-import` rule keeps
`showcaseview` inside `app_ui`. Its `raw-spinner` rule holds
spinners to `AppSpinner` in `app/lib/` and `app_ui/lib/`: an indeterminate
`CircularProgressIndicator`, `LinearProgressIndicator` or `CupertinoActivityIndicator` fails, and
one given its own `value:` (the progress rings and macro bars) is allowed. Its `style-copywith` rule
holds text styles in `app/lib` to those tokens, `alpha-literal` its colours' opacities, and `box-decoration` its boxes to app_ui's widgets; its `ALLOWED` list names each file a rule lets
through, and why. Every screen was moved onto
`app_ui` by 19 Oct 2026 (#212–#217), so there is no baseline: any match fails CI.

```bash
python3 scripts/flutter-ui-check.py                  # what CI runs
python3 scripts/flutter-ui-check.py --list text-style  # every match of one rule
```

Rules 1 and 5–8, and the rest of 4, are checked in review.
