# Flutter UI contract

The rules every screen in `app/` follows. The owner set them on 18 Oct 2026, after the first
TestFlight build worked but looked inconsistent: each screen had styled its own pieces (216
private widgets in 83 files, 331 raw Material buttons, 83 ad-hoc text styles). Where a rule needs
a value, the Swift app's `docs/specs/ui-framework/CONTRACT.md` has already decided it; the Dart
names are below.

The design system is the `app_ui` package (`app/packages/app_ui/`). Feature code in `app/lib/`
uses it and styles nothing itself.

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
| `Colors.white`, `Color(0x…)` | `context.appColors.*` (`canvas`, `surface`, `tintedSurface`, the macro, metric and status colours) or the `ColorScheme` (`primary` is the accent, `onPrimary` the text on it) |
| `TextStyle(…)`, `fontSize:`, `fontWeight:` | `AppTextStyles.display`, `metricLarge`, `metric`, `metricSmall`, `sectionTitle`, `rowTitle`, `rowDetail`, `label` |
| A number in `EdgeInsets` or `SizedBox` | `AppSpacing.xxs` … `xxl` (2–32); `AppControlSize`, `AppChartHeight`, `AppContentWidth` for sizes |
| `BorderRadius.circular(12)` | `AppRadius.s` … `xl` |
| `Duration(…)` on an animation | `AppMotion.quick` / `standard` / `emphasis` / `progress`, through `durationOf` so reduced motion is honoured |
| `Icons.*` | `AppSymbols.*`: one concept, one icon. Add the concept there if it is missing |
| Formatting a number by hand | `AppFormat` |
| `DateFormat`, `formatTimeOfDay`, a date built by hand | `AppFormat.date` (with an `AppDateStyle`), `time`, `hour`, `dateTime`, passing `locale: context.dateLocale` and `use24HourFormat: context.use24HourFormat`: the app's language with the device's region and clock, as iOS does |

- The accent is never written as its current value. Text on an accent fill is `onPrimary`.
- Status colours are never the only signal: pair them with an icon or text.
- Exempt: share cards (`lib/sharing/share_card/`, `weekly_review_share_card.dart`), which render
  to fixed-size images, and user data such as a gym's chosen colour.

## 3. No raw Material building blocks in features

`TextButton`, `IconButton`, `FilledButton`, `OutlinedButton`, `ListTile`, `Card`,
`showDialog`, `AlertDialog` and `showModalBottomSheet` are wrapped once in `app_ui`, and screens
use the wrapper. Restyling the wrapper then restyles every screen.

| Need | Use |
|---|---|
| Primary action | `AppCtaButton` in `AppBottomCta` |
| A row | `AppListRow`, `AppListRowButton`, `AppListRowToggle`, `AppSelectableRow` in an `AppSection` |
| A card | `AppCard`, `AppStatTile` |
| A value | `AppStat` |
| A tag or filter | `AppChip` |
| A number entry | `AppNumberField` |
| A form or scanner message | `AppInlineMessage` |
| A screen | `AppScaffold`, `AppDashboard` for tab roots, `AppOnboardingStepScaffold` for onboarding |
| Swipe actions | `AppSwipeActions` |

Not wrapped yet, so the first screen that needs one adds it to `app_ui`: toolbar close and
confirm buttons, a secondary or text button, an icon button, the confirmation dialog, sheets
(`compact` / `half` / `full`), and the empty, loading and error states.

## 4. Screen patterns

Ported from the Swift contract's Patterns table.

| Pattern | Rule |
|---|---|
| Primary action | One per screen, `AppCtaButton` pinned in `AppBottomCta` |
| Dismiss | A close button at the leading edge of a modal's app bar. No "Cancel" text button |
| Confirm | A confirm button at the trailing edge, with a spinner while saving |
| Titles | Tab roots have a large title. Every other screen has a standard title |
| Empty and error states | The shared empty-state widget: icon, title, description and, where possible, the action |
| Loading | A list or card shows placeholder rows shaped like its content. A full-screen spinner only for a screen's first load |
| Destructive | Destructive styling. Irreversible actions confirm first, with a Cancel |
| Sheets | Only `compact`, `half` or `full`, each able to grow to full height at large text, always with a drag handle |
| Selection | Anything with a selected state announces it to screen readers |
| Haptics | Success after every save, log, complete or finish; error when one fails; selection for pickers and segments |

## 5. Accessibility is part of done

- Text at 200% scale: nothing clipped or overlapping; rows grow, they don't truncate titles.
- Tap targets at least 44 × 44 points (48 dp on Android).
- Contrast checked in light and dark mode.
- Every icon-only button has a semantic label.

## 6. Golden tests for `app_ui`

Every `app_ui` widget has golden-image tests in light mode, dark mode and at 200% text, so a
change that makes a component look worse fails a test and agents get visual proof without a
device.

## 7. Component gallery

The development flavor has a gallery screen, reached from Developer Settings, that shows every
`app_ui` widget in each of its states. A new `app_ui` widget is added to it in the same PR.

## 8. Before-and-after screenshots

A PR that changes how something looks includes before and after screenshots (light and dark),
or the golden diffs.

## Platform look

**One Compound look on both platforms** (own brand, decided 14 Oct 2026), with each platform's
native behaviour where people expect it: swipe back on iOS, the platform's date and time pickers,
and the platform's style of sheets and alerts. These are chosen inside the `app_ui` wrappers, so
screens never branch on platform themselves.

## Enforcement

`scripts/flutter-ui-check.py` runs in CI (`flutter.yml`, **UI contract** job) and enforces rules 2
and 3 on `app/lib/`. Code from before the contract is baselined per rule: a count may fall but
never rise. When you fix screens, lower the baseline in the same PR.

```bash
python3 scripts/flutter-ui-check.py                  # what CI runs
python3 scripts/flutter-ui-check.py --list text-style  # every remaining match of one rule
```

Rules 1 and 4–8 are checked in review.
