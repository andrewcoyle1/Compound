# UI audit (2026-09-27)

Pre-planning for an app-wide design system. Read-only audit of `DialedIn/`, `WorkoutSessionActivity/`
and `Shared/`. Counts are grep-based and approximate. Paths are relative to `DialedIn/` unless noted.

## Headline

There is **no token layer at all**. There are no named colours: `AccentColor` is `labelColor`,
so it renders black in light mode and white in dark. There is no spacing, radius, typography or motion constant anywhere. Every screen picks
raw values, so the drift is uniform rather than concentrated. The good news: the building blocks
for a system already exist and are used correctly in pockets (`CallToActionButton`,
`MetricDetailView`, `AnalyticsSection`, `ContentUnavailableView`, `Button(role: .close/.confirm)`,
`SetKeyboardView`), accessibility labelling is already strong (no unlabelled icon-only buttons
found), and localisation is ~99% Spanish-complete.

## 1. Tokens

| Area | What exists today | Proposed token |
|---|---|---|
| Colour | 358 named system colours, 173 `.opacity(N)` (0.1/0.12/0.15/0.2/0.25/0.3/0.35/0.5), 22 RGB literals, 3 background systems (`Color(.system…)`, `colorScheme.backgroundPrimary` ×68 from `ColorScheme+EXT`, `Color.background` ×1) | `Palette`: `Macro.protein/carbs/fat/calories`, `Metric.*`, `Status.success/warning/error`, `Surface.base/raised/grouped/tinted(c)`, real brand accent in the asset catalog |
| Type | 215 caption, 143 subheadline, 94 headline… semibold set 3 ways (`.fontWeight` / `.weight(` / `.bold()`); 28 `.system(size:)`; 3 `@ScaledMetric` | `TextStyle`: `display`, `metricValue` (rounded + monospacedDigit), `sectionTitle`, `rowTitle`, `rowDetail`, `caption`; `IconSize` via `@ScaledMetric` |
| Spacing | padding 8/4/12/6/2/16 dominate; stack spacing 4/8/12/2/0/6/16; off-grid 1/3/5/10/14; row heights 35/36/38/40 for the same thing | 4-pt scale `xxs 2, xs 4, s 8, m 12, l 16, xl 24, xxl 32`; `ControlSize` 24/40/44; `ChartHeight` 150/200 |
| Radius | 36 deprecated `.cornerRadius`; radii 3,4,6,8,10,12,16,19,20,22,24,25,28,30; one `.continuous`; zero `ConcentricRectangle` | `Radius s 8, m 12, l 16, xl 24`, always continuous; concentric inside glass |
| Surfaces | 9 ad-hoc shadows; `.bar` background under glass toolbars | `Surface.card`, `Surface.floating` (glass); one elevation or none |
| Motion | ~12 distinct curves; reduce-motion wrapper used in 5 of ~15 sites | `Motion.quick/standard/emphasis/progress`, always via `reducedMotionAnimation` |
| Buttons | `.glassProminent` 34, `.bordered` 29-32, `.plain` 24, `.glass` 19, `.borderedProminent` 3, `.anyButton` ~100 | primary `.glassProminent`, secondary `.glass`, row `.anyButton(.highlight)`; retire `.bordered*` |

### The same concept, different colours

- **Protein** is coral in `Managers/Nutrition/Models/Macro.swift:52`. It is `.blue` in `NutritionOverviewView.swift:173`, `NutritionCard.swift:33` and `MealDescribeView.swift:91`, and RGB blue in `WeeklyMacroChart.swift:42`.
- **Carbs and fat are swapped** in `NutritionTargetChartPresenter.swift:133-134`: carbs are yellow and fat is green.
- **Calories** come in four colours: blue, orange, red and orange again.
- **The macro palette is declared three times**: `Macro.swift:52-54` and `MacroProgressChart.swift:68-74` and `:79-85`.
- **Analytics tab**: Workouts and Steps are both orange, and Scale weight and Goal progress are both green (`AnalyticsView.swift:187-190`).
- **Errors** are orange in the toast (`AppToastView.swift:28`) but red inline.
- **Accent** is written three ways: `.accent`, `Color.accentColor` and `Color.accent`.

## 2. Components: consolidate into 8 primitives

| Primitive | Replaces | Notes |
|---|---|---|
| `Card` | `DashboardCard` (24, base), `AnalyticsCard` (16, fixed 120pt, unused `themeColor`), `MetricCard`, `TodaysWorkoutCardLabel`, `MacroStatCard`, ~60 hand-rolled `.background+cornerRadius` in Core | `.surface` / `.tinted(color)` |
| `Stat` | `StatItem` (base), `StatCard`, `MetricCard`, `MetricView`, `StatLabel`, `OverallTargetCellView`, share-card `stat()` ×2, `MuscleBalanceView.tile` | `.inline/.compact/.prominent` + `.tile`; value above label |
| `ListRow` | `CustomListCellView` (10 knobs), `CustomLabelButtonView` (only chevron tappable, a bug), `CustomToggleView` label, `RowCellView`, `MetricRow`, 22 hand-rolled Profile rows | whole row tappable, chevron, toggle/selection trailing variants with `.isSelected` |
| `CTAButton` | `CallToActionButton` (base), `AsyncCallToActionButton`, `CtaButtonViewModifier`, 16 inline `.glassProminent` body buttons | add `isLoading`, built-in bottom padding |
| `Chip` | `.badgeButton`, ~36 hand-rolled capsules (Edit pills built 3 ways, macro chips copied ×3, warmup/superset badges) | `Chip(text:tint:)` |
| `NumberField` | `TextFieldwUnit`, `TextFieldwUnitPicker`, `LabeledTextField*` trio | `unit: Binding?`, `label:` |
| `SectionHeader` | `SectionHeaderView` vs ~168 plain `header: { Text }` | one header |
| `EmptyState` | Standardise on `ContentUnavailableView` (40 sites). Delete `EmptyState`. Keep `FeatureUnavailableView` for "coming soon". Replace ~14 `Text("No …")` stacks and `TrainingView.swift:70-95` | also covers errors (no raw red `Text`) |

Plus two scaffolds:
- **`OnboardingStepScaffold`**. The 27 steps share no template and have no progress indicator. The option row is copy-pasted about nine times, with three different tap mechanisms. Bottom padding is inconsistent, and title modes are random.
- **`SheetScaffold`**. It carries the toolbar convention and named detents.

**Delete first, no visual change (~20 dead types):** AsyncCallToActionButton, ProfileModalView,
ModalSupportView, CustomPresetPickerButton, CarouselView, HeroCellView, CategoryCellView,
RowCellView + Builder, MultipleSelectionRow, ProgressCircle, StatLabel, MetricCard, MetricView,
RestDayRow, EmptyState, `callToActionButton`/`CtaButtonViewModifier`, `ifSatisfiedCondition`,
`onFirstAppear`, `addingGradientBackgroundForText`, `MetricConfiguration.chartType`.

**Move out of `Components/`:** ~30 feature-bound modules, such as MealAccessory, TrainingAccessory,
TodaysWorkoutCard, WeeklyMacroChart, TargetCellView and SetDetailRow. They belong under
`Core/<feature>/Components`, so `Components/` holds only generic primitives.

## 3. Patterns

| Pattern | Today | Standard |
|---|---|---|
| Dismiss / confirm | 45 hand-drawn `xmark`, 23 `role: .close`, 8 `role: .confirm`, 15 `checkmark`, text Save/Done/Cancel; leading and trailing both used | `Button(role: .close)` in `.cancellationAction`, `Button(role: .confirm)` in `.confirmationAction` |
| Primary action | bottom inset CTA, hand-rolled glass, `.bottomBar`, `.confirmationAction` "Add"; "Log Foods"/"Log Food"/"Add" | `CTAButton` in `safeAreaInset(.bottom)` for flows; confirm role for sheet forms |
| Sheets | 63 plain, 22 router detents, 15 native `.presentationDetents`, ~15 distinct fractions (0.2 to 0.8), drag indicator in 3 places, 24 hand-rolled `NavigationStack`s | 3 named detents via router, drag indicator on all resizable sheets |
| Titles | 128 inline, 10 large, stray `.inlineLarge`; 7 routed screens with no title | tab roots `.large` + `minimizingLargeTitleBar`, everything else `.inline`, every routed screen titled |
| Alerts | router 195, native 3 (justified) | router only; `confirmationDialog` for destructive; add Cancel to delete-account alert; confirm gym-profile swipe-delete |
| Loading | 48 `ProgressView`, 13 blocking modals, 2 redacted | redacted skeletons for lists, modal only for blocking writes |
| Haptics | 5 call sites + 2 raw UIKit generators | `.success` on every save/log/complete |
| Numbers | 6 formatting styles, 3 private `formatted()` helpers, "kcal"/"Cal"/"Calories", "12g"/"12 g", "–"/"-"/"—" | one `Format` namespace (weight with unit pref, macros, kcal, placeholder "—") |
| Symbols | `scalemass` = volume *and* equipment; `map`, `book`, `list.bullet`, `dumbbell` each mean 2-3 things | one concept-to-SF-Symbol table |
| Numeric input | custom `SetKeyboardView` for weight and reps, but TextFields, wheels and Steppers for time, distance and duration in the same row | `SetKeyboardView` for all set entry |
| Charts | QuickCharts (accessible), Swift Charts, hand-drawn `GeometryReader` bars (no a11y); `EnergyBalanceChart` duplicates `ComboChart` | QuickCharts; retire hand-drawn bars |
| Accessibility | labels strong; 28 fixed font sizes; colour-only meaning in set Done column, muscle chips, goal delta, target grid, band swatches; selection rows lack `.isSelected` | tokens make fixed sizes impossible; icon+text for status |

## 4. Shell

- **iPad and Mac are broken.** `AdaptiveMainView` sends every regular width to `SplitViewContainer`, a stub. Its sidebar buttons only `print` (`Core/SplitViewContainer/SplitViewContainer.swift:24`). The content column is always `tabs.first!`, and it has no Dashboard or Search. Fix: delete both and use `.tabViewStyle(.sidebarAdaptable)`.
- **The same module id is registered twice.** `AppView.swift:135` and `AdaptiveMainView.swift:39` register `RouterView` under one module id.
- **The tab bar is modern and good.** It uses the `Tab` API, a search role, a bottom accessory and minimize-on-scroll. Leftover commented code sits at `TabBarView.swift:80-86`.
- **The widget extension has no string catalog**, so Live Activity text is never translated.

## 5. Bugs found along the way

Verified by reading the source:
- **Dark-mode CTA text is invisible.** `CtaButtonViewModifier` and `badgeButton` draw `.white` on the accent, which is white in dark mode (`Components/ViewModifiers/View+EXT.swift:16-24,59-63`).
- **Restore Subscription does nothing.** Its action is empty (`Core/Paywalls/Paywalls/CustomPaywallView.swift:99-101`).
- **The template detail "+" does nothing.** Its action is commented out (`WorkoutTemplateDetailView.swift:188-190`).

Reported by the auditors, not yet verified:
- **Subscribe can be tapped with nothing selected** (`CustomPaywallView.swift:94`).
- **The paywall error title uses the background colour as its foreground** (`PaywallView.swift:18`).
- **Session detail shows the wrong set count.** It passes the exercise count, and the unit is hardcoded to kg (`WorkoutSessionDetailView.swift:218`).
- **`SetDetailRow` ignores the unit preference.** It hardcodes `"%.1f kg"`.
- **The rest-timer fallback shows workout elapsed time** under the "Rest Timer" caption (`WorkoutTrackerView.swift:203`).
- **Ingredient and recipe list-builder search can never show.** `searchText` is never bound.
- **`CustomLabelButtonView` rows are only tappable on the chevron.**
- **Health onboarding sets conflicting title modes** (`HealthDataView.swift:22,29`).
- **Finish Workout is hidden** in a hamburger menu next to Delete.

## 6. Suggested order

1. **Delete** the dead types (no visual change). Fix the bugs above, each as its own commit with a test.
2. **Tokens.** Add `Palette`, `TextStyle`, `Spacing`, `Radius`, `Motion`, `Format` and the symbol table. Set a real accent. Fold `ColorScheme+EXT` into `Surface`.
3. **Primitives.** Build `Card`, `Stat`, `ListRow`, `CTAButton`, `Chip`, `NumberField`, `SectionHeader` and `EmptyState`, then the onboarding and sheet scaffolds.
4. **Patterns.** Add toolbar roles, named detents, title rules and haptics. These are mechanical sweeps.
5. **Migrate by feature.** Go Nutrition, then Training, Profile, Onboarding, Analytics, one PR each.
6. **Shell.** Switch to `.sidebarAdaptable` and give the widget its own string catalog.
7. **Lock it in.** Add SwiftLint custom rules banning `.cornerRadius(`, `.foregroundColor(`, `.font(.system(size:` outside share cards and widgets, raw `Color(red:`, and bare `withAnimation`.
