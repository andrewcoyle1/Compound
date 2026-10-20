# app_ui

Compound's own design system for the Flutter app: the same brand on iOS and Android, ported from
the Swift app's `Compound/Components/DesignSystem/` (contract: `docs/specs/ui-framework/CONTRACT.md`).

```dart
import 'package:app_ui/app_ui.dart'; // also exports Material

MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, …);
```

| Swift | Flutter |
|---|---|
| `Spacing`, `Radius`, `ControlSize`, `ChartHeight`, `ContentWidth` | `AppSpacing`, `AppRadius`, `AppControlSize`, `AppChartHeight`, `AppContentWidth` |
| `Palette.swift` colours | `context.appColors` (`AppColors` theme extension); the accent is `colorScheme.primary`, `onAccent` is `onPrimary` |
| `Font.display` … `Font.label`, `.iconSize(_:)` | `AppTextStyles.*`, `AppIconSize.x.of(context)` |
| `Animation.quick` … `.progress` + reduced motion | `AppMotion.x.durationOf(context)`, `.curve` |
| `Symbol.*` | `AppSymbols.*` (bundled Material Icons, rounded) |
| `Format.*` | `AppFormat.*` (numbers and unit symbols; words and plurals live in the app's ARB) |
| `.cardSurface(_:)` | `AppCard(style: AppCardStyle.card / .tile / .tinted(c))` |
| `Stat`, `Stat.tile` | `AppStat`, `AppStatTile` |
| `Chip` (+ `chipTapTarget`) | `AppChip` (44 pt target when `onPressed` is set) |
| `ListRow`, `ListRowButton`, `ListRowToggle`, `SelectableRow` | `AppListRow`, `AppListRowButton`, `AppListRowToggle`, `AppSelectableRow`, inside an `AppSection` |
| `NumberField` | `AppNumberField`, `AppNumberField.units` |
| `.bottomCTA { CallToActionButton … }` | `AppScaffold(bottomNavigationBar: AppBottomCta(children: [AppCtaButton(…)]))` |
| `InlineMessage` | `AppInlineMessage` |
| `OnboardingStepScaffold` | `AppOnboardingStepScaffold` |
| `readableContentWidth`, `preferredReadableContentWidth` | `AppScaffold` (and its `maxWidth`) in place of `Scaffold`: the app bar spans the window, the body and bottom CTA sit in an `AppReadableWidth` column |
| `Dashboard` | `AppDashboard(sections: […])` |
| `horizontalSizeClass == .regular` | `context.isRegularWidth` |
| `.alert` / `showConfirmationDialog`, `Button(role: .destructive)` | `showAppDialog` with `AppDialogAction`s (`AppDialogRole.standard / preferred / cancel / destructive`), `AppDialog.confirmDestructive` |
| `ResizableSheetConfig.compact / .half / .full` | `AppSheetPage(size: AppSheetSize.x)` for a route, `showAppSheet(size: …)` otherwise |
| `ContentUnavailableView` | `AppEmptyState`, `AppErrorState` |
| `.redacted(reason: .placeholder)`, a first-load `ProgressView` | `AppPlaceholderRow`, `AppPlaceholder`; `AppLoadingView` |

Every user-facing word is passed in already localized; the package holds no strings.

Tests are held at 100% line coverage, with no golden files.
