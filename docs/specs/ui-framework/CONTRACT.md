# Design system contract

The names every WP uses. WP-01 creates the tokens, WP-05/06/07 the primitives. Values marked
*decide* are the implementing WP's call, within the rule given, and are then fixed. Everything
lives in `DialedIn/Components/DesignSystem/`, one file per section below. It is in the app
target only. The widget extension keeps its own styling (see WP-15).

## Tokens (WP-01)

### Spacing and radius — `Spacing.swift`

```swift
enum Spacing { static let xxs: CGFloat = 2, xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12,
               l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32 }
enum Radius  { static let s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24 }
enum ControlSize { static let icon: CGFloat = 24, thumbnail: CGFloat = 40, row: CGFloat = 44 }
enum ChartHeight { static let compact: CGFloat = 150, regular: CGFloat = 200 }
```

- Plain `.padding()` and `.padding(.horizontal)` stay. They are the system default (16) and read fine.
- Use a token wherever a number is written. Off-grid values (1, 3, 5, 6, 10, 14) round to the nearest token.
- Every rounded shape is continuous. Use `.rect(cornerRadius: Radius.l, style: .continuous)`
  or `RoundedRectangle(cornerRadius:style: .continuous)`. Never `.cornerRadius(_:)`.

| Radius | Use |
|---|---|
| `xl` | Full-width cards |
| `l` | Grid tiles |
| `m` | Inline panels |
| `s` | Thumbnails and small controls |

Capsules and circles stay as they are.

### Colour — `Palette.swift`

`extension Color` statics, plus `extension ShapeStyle where Self == Color` mirrors so
`.foregroundStyle(.protein)` compiles.

| Token | Value / rule |
|---|---|
| `onAccent` | A colour-set asset `OnAccent` beside `AccentColor`. It is white-on-black for today's monochrome accent: `systemBackground` values, meaning any appearance white and dark black. It replaces every `foregroundStyle(colorScheme.backgroundPrimary)` label hack. |
| `surface` | `Color(uiColor: .secondarySystemGroupedBackground)`. Visually identical to today's `colorScheme.backgroundPrimary`. |
| `canvas` | `Color(uiColor: .systemGroupedBackground)`. Identical to `colorScheme.backgroundSecondary`. |
| `static func tintedSurface(_ c: Color) -> Color` | `c.opacity(0.15)`. The one fill for tinted tiles, chips and badges. |
| `protein`, `carbs`, `fat` | The existing RGB values in `Macro.swift:52-54`. |
| `calories` | `.blue` (README decision 2). |
| `vitamins`, `minerals`, `otherNutrients` | The existing values in `MacroProgressChart.swift`. |
| `success`, `warning`, `danger` | `.green`, `.orange`, `.red`. Errors are always `danger`. Toasts included. |
| `warmup`, `superset`, `personalRecord` | *decide*. Three distinct hues. `warmup` and `superset` must differ; today both are orange. |
| `Metric` namespace: `Color.Metric.workouts`, `.steps`, `.scaleWeight`, `.bodyFat`, `.measurements`, `.expenditure`, `.goalProgress`, `.nutrition`, `.muscleGroups`, `.exercises`, `.habits` | *decide*. No two metrics shown on the Analytics tab share a hue. Avoid the macro colours. |

After WP-01, nothing outside `DesignSystem/` writes `Color(red:…)`. The exceptions are user data
(`Color(hex:)`), share cards and the widget.

### Accent

The accent is the brand colour. Today it is monochrome: `AccentColor` = `labelColor`. Changing
it later must be **one edit to two assets**, `AccentColor` and `OnAccent` together, and must
recolour the whole app. That only holds if code never bypasses it.

**Spelling.**
- Use `.tint` as a `ShapeStyle` (`.foregroundStyle(.tint)`, `.fill(.tint)`) wherever a view
  draws accent. It follows the environment tint, which defaults to the accent.
- Use `Color.accentColor` only where a `Color` value is required.
- `Color.accent` and bare `.accent` (about 40 sites today) are retired.

**Use the accent for:**
- primary buttons (`.glassProminent` already takes the tint)
- selected state in chips, segments and selectable rows (the checkmark)
- toggles, sliders and progress indicators that are not data
- links, and "See All" style actions
- the active tab
- focus and highlight rings
- goal progress, where the goal is the user's own target and not a metric colour

**Never use the accent for:**
- data meaning: macros, metrics, status, warmup and similar
- body text
- surfaces

**Never write the accent's current value where the accent is meant.** That means no `.primary`,
`.black`, `.white` or `labelColor` standing in for brand emphasis. Text drawn on an accent fill
uses `onAccent`, never `.white`, `.black` or `colorScheme.*`. If the accent is swapped for a
colour today, nothing may become unreadable.

### Typography — `Typography.swift`

`extension Font` statics. All are built on text styles, so they scale with Dynamic Type.

| Token | Definition | Use |
|---|---|---|
| `display` | `.system(.largeTitle, design: .rounded, weight: .bold)` | Hero numbers, onboarding headings |
| `metricLarge` | `.system(.title, design: .rounded, weight: .semibold).monospacedDigit()` | Card headline number |
| `metric` | `.system(.title3, design: .rounded, weight: .semibold).monospacedDigit()` | Stat value |
| `metricSmall` | `.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()` | Compact stat, row trailing value |
| `sectionTitle` | `.headline` | Card and section titles |
| `rowTitle` | `.body` | List row title (README decision 4). 17 pt at the default Dynamic Type size (Large) |
| `rowDetail` | `.subheadline` | Row subtitle, with `.secondary`. 15 pt at Large |
| `label` | `.caption` | Stat labels, chips, with `.secondary` |

- Use weight through the token or `.fontWeight(_)`. Never `.bold()` on top of a token.
- Icons get their size from `.iconSize(_ size: IconSize)`, a modifier backed by `@ScaledMetric`.
  `enum IconSize { case small /*17*/, medium /*24*/, large /*44*/, hero /*64*/ }`. This replaces
  every `.font(.system(size:))` on an `Image`.
- `.font(.system(size:))` remains allowed only in share cards (`Core/Dashboard/ShareCard/**`,
  `Core/Dashboard/WeeklyReview/WeeklyReviewShareCardView.swift`) and the widget.

### Motion — `Motion.swift`

`extension Animation { static let quick = .snappy, standard = .smooth, emphasis = .bouncy,
progress = .easeOut(duration: 1.0) }`.

Always apply them through the existing `reducedMotionAnimation(_:value:)` and
`withReducedMotionAnimation(_:_:)` (`Components/ViewModifiers/ReducedMotionViewModifier.swift`).
Never call bare `withAnimation` or `.animation(`.

### Symbols — `Symbols.swift`

`enum Symbol` with `static let` SF Symbol names, one per concept. **One concept, one symbol. One
symbol, one concept.**

WP-01 fills it from a sweep of `systemImage:`/`systemName:` literals. At minimum it covers:
workout, exercise, set, reps, weight, volume, equipment, duration, rest, personal record, program,
history, library, template, meal, food, recipe, calories, the four macros, steps, scale weight,
body fat, measurement, goal, streak, settings, notifications, add, edit, delete, close, share,
search, filter, info, warning, error.

UI chrome that the system already owns does not go in `Symbol`: `role: .close`, the chevron, and
the search tab.

### Formatting — `Format.swift`

`enum Format` with static functions returning `String`. Every one is covered by unit tests.

| Function | Output |
|---|---|
| `kcal(_:)` | `"1,850 kcal"`, 0 decimals |
| `grams(_:)` | `"12 g"`, 0 decimals ≥ 10, else 0–1 |
| `weight(kg:unit:)` | Respects `ExerciseWeightUnit` / `WeightUnitPreference`: `"82.5 kg"`, `"181.9 lb"`, 0–1 decimals |
| `reps(_:)` | `"8 reps"` |
| `repRange(_:_:)` | `"8–12"`, en dash |
| `duration(_:)` | `"1:05:30"` / `"4:30"` |
| `distance(meters:unit:)` | Distance in the user's unit |
| `percent(_:)` | Percentage |
| `placeholder` | `"—"` (em dash) for a missing value |

Wording: the unit is always `kcal`, and the label is always "Calories". Use locale-aware
`FormatStyle`, never `String(format:)`.

### Sheets and haptics — `Presentation.swift`

`extension ResizableSheetConfig`. Every preset includes `.large`, so content can never be trapped
at large Dynamic Type sizes. The drag indicator is always visible.

| Preset | Detents |
|---|---|
| `.compact` | `[.fraction(0.35), .large]` |
| `.half` | `[.medium, .large]` |
| `.full` | `[.large]` |

- Present through `router.showScreen(.sheetConfig(config: .half))`.
- Plain `.sheet` means full height with no detents, and stays allowed.
- Native `.sheet(`/`.presentationDetents` in views are replaced by the router, except where a
  sheet must host a binding the router cannot.

Haptics are not a token. The rule: a presenter calls `interactor.playHaptic(option: .success)`
after every successful save, log, complete or finish, and `.error` when one fails. Use `.selection`
for picker and segment changes. There are no raw `UI*FeedbackGenerator`s.

### Notes from WP-01 (as built)

- **`onAccent`** is generated by Xcode from the `OnAccent` colour asset (`Color.onAccent` and
  `.onAccent` as a `ShapeStyle`). Never define it by hand, because it would collide.
- **`.iconSize(_:)`** scales relative to `.body`.
- **`Format` takes non-optionals.** For a missing value write `value.map(Format.kcal) ?? Format.placeholder`.
- **`Format.weight`** writes "lb". `WeightUnitPreference.abbreviation` and
  `ExerciseWeightUnit.abbreviation` still say "lbs". WP-15 settles on "lb" app-wide.
- **`Format.distance`** takes `DistanceUnitPreference`. If WP-09 needs per-exercise
  `ExerciseDistanceUnit`, it adds that overload in `Format.swift` and says so in its report.
- **`Spacing` and `Radius`** carry a scoped `identifier_name` lint suppression. That is
  intentional.
- **Metric colours, set colours and symbols** are decided and documented at the top of
  `Palette.swift` and `Symbols.swift`. Read those tables; do not re-decide them.
- **Accent-swap problems** are listed per WP in `accent-swap-findings.md`.

## Primitives (Wave 2)

| Primitive | WP | Replaces (deprecated in Wave 2, deleted in WP-15) |
|---|---|---|
| `.cardSurface(_ style: CardStyle = .card)`, `CardStyle { case card /*surface, xl*/, tile /*surface, l*/, tinted(Color) /*tintedSurface, l*/ }` | 05 | Hand-rolled `.background(…, in: .rect(cornerRadius:))` card surfaces |
| `DashboardCard`, `AnalyticsCard` family | 05 | Kept, rebuilt on `.cardSurface` |
| `Stat(value:label:systemImage:size:alignment:)`, `size: .small/.medium/.large` (value above label) | 05 | `StatItem`, `StatCard`, `MetricCard`-style tiles |
| `Chip(_ text:systemImage:tint:isSelected:)` | 05 | `.badgeButton`, hand-rolled capsules |
| `ListRow(title:subtitle:systemImage:tint:accessory:)`, `accessory: .none/.chevron/.checkmark(Bool)/.value(String)/.custom(AnyView)` | 06 | `CustomListCellView`, `CustomLabelButtonView`, `MetricRow` |
| `ListRowButton(… , action:)` | 06 | Whole row tappable, chevron by default |
| `ListRowToggle(title:subtitle:systemImage:isOn:)` | 06 | `CustomToggleView` |
| `SelectableRow(title:subtitle:isSelected:action:)` | 06 | The onboarding option row; `.isSelected` trait |
| `SectionHeaderView` | 06 | Kept, token-ised. The one custom section header. Plain `header: { Text }` stays fine. |
| `NumberField(value:unit:units:label:)` | 06 | `TextFieldwUnit`, `TextFieldwUnitPicker`, `LabeledTextField*` |
| `CallToActionButton(isPrimaryAction:isLoading:action:label:)` + `.bottomCTA { … }` | 07 | `.bottomCTA` = `safeAreaInset(.bottom)` with standard padding. Replaces inline `.glassProminent` body buttons and `.bottomBar` primary buttons. |
| `InlineMessage(_ kind: .error/.warning/.info, _ text:)` | 07 | Raw red or orange `Text` errors |
| `OnboardingStepScaffold(title:subtitle:progress:content:primary:secondary:)` | 07 | Per-step List + title + CTA scaffolding |

### Notes from Wave 2 (as built)

- **`Stat`** has an extra `tint: Color? = nil` that colours its symbol. VoiceOver reads it as
  label then value.
- **`AnalyticsCard`**
  - `subsubtitle` and `subsubsubtitle` are now `value` and `unit`. The old labels still compile
    with a deprecation warning; migrate them.
  - New `showsChevron: Bool = true`. Pass `false` on cards that are not tappable (AddMeal's macro
    cards, NutritionAnalytics' `breakdownCard`).
  - Optional `systemImage`, tinted by `themeColor`.
- **`CustomLabelButtonView` call sites** keep their action inside the trailing closure, so only
  that part is tappable until the call site moves to `ListRowButton`. Every one must move.
- **`ListRow` selection glyph:** `checkmark.circle.fill` in `.tint` / `circle` in `.tertiary`. It
  is treated as system chrome, like the chevron.
- **`NumberField`** takes an unlabelled leading `prompt`. `PickableUnit` now lives in
  `NumberField.swift`.
- **`CallToActionButton(isPrimaryAction:isLoading:action:label:)`** draws its primary label in
  `onAccent`.
- **`.bottomCTA { }`** adds its own bottom padding. Callers add none.
- **`InlineMessage(.error, text)`** accepts a `LocalizedStringKey` or a runtime `String`.
- **`OnboardingStepScaffold(title:subtitle:progress:primary:secondary:onDevSettingsPressed:content:)`**
  - `content` is the trailing closure.
  - `primary` is `.init(title:isEnabled:isLoading:action:)`.
  - `progress` comes from `OnboardingStep.progress`.
  - The dev toolbar appears only when `onDevSettingsPressed` is passed.
- **`Chip`** defaults its tint to `.accentColor`. A selected chip draws solid tint with
  `onAccent` text.

## Patterns (applied in Wave 3)

| Pattern | Rule |
|---|---|
| Dismiss | `Button(role: .close) { presenter.onDismissPressed() }` in `.cancellationAction`. No drawn `xmark`, no "Cancel" text. |
| Confirm | `Button(role: .confirm)` in `.confirmationAction`, spinner while saving (see `EditUsernameView`) |
| Primary action on a flow screen | `CallToActionButton` via `.bottomCTA`. One per screen. |
| Titles | Tab roots `.large` + `minimizingLargeTitleBar()`. Everything else `.navigationBarTitleDisplayMode(.inline)`. Every routed screen has a `navigationTitle`. |
| Empty and error states | `ContentUnavailableView` with `Label(…, systemImage: Symbol.x)`, a description and, where possible, the action. `FeatureUnavailableView` for "coming soon". |
| Loading | List and card content: `.redacted(reason: .placeholder)` over mock-shaped rows. Blocking writes: `router.showLoadingModal`. A bare centred `ProgressView` only for a whole-screen first load. |
| Destructive | `Button(role: .destructive)`. Irreversible ones confirm through `router.showConfirmationDialog` / alert with a Cancel. |
| Selection | Anything showing selected state adds `.accessibilityAddTraits(.isSelected)` when selected. |
| Status | Never colour alone. Pair it with a symbol or text. |
| Buttons | `.glassProminent` primary, `.glass` secondary, `ListRowButton` for rows in a List, `.anyButton(.press)` for tappable cards. No `.bordered`/`.borderedProminent`. |
| Deprecated APIs | `.foregroundColor` becomes `.foregroundStyle`. `.cornerRadius` becomes a clip shape. `.navigationBar*` placements become `.topBar*`. |
