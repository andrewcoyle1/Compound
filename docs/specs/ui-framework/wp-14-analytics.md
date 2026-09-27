# WP-14 · Migrate Analytics, metric detail and charts

**Wave 3. Size: large.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Analytics/**`
- `Components/Views/Charts/**`
- `Components/Views/MetricDetailView.swift`, `MetricAllDataView.swift`
- `Components/Views/TargetCellView.swift`, `OverallTargetCellView.swift`, which move to
  `Core/Analytics/Components/`
- `Components/Views/ActivityRingView.swift`
- `Components/Models/`, `Components/Protocols/`

## Specific issues

- **`MetricDetailView` is the good pattern.** About 20 detail screens share it. Keep the layout,
  and move its values, fonts and colours onto tokens. Extend `MetricConfiguration` so number
  formatting goes through `Format`.
- **Analytics tab colours.** Every card's `themeColor` comes from `Color.Metric.*`, so no two
  share a hue.
- **`BodyMetricCardView.swift:15,27`** restates the `.compact` chart config and
  `.tappableBackground().anyButton(.press)`. Use `.compact` and `.analyticsCardButton`.
- **Hand-drawn charts:** `MacroStackedBarChart`, `SetsBarChart`, `MacroProgressChart`, and the
  `NutritionTargetChart` cells.
  - Where a QuickCharts type already draws the same thing, replace the hand-drawn chart.
    `EnergyBalanceChart` duplicates QuickCharts `ComboChart`: replace it and delete it.
  - Where none does, keep the hand-drawn chart and give it `.accessibilityElement` with a label
    and a value summary, for example "Protein 48 of 150 grams".
  - QuickCharts is a package: changing it is out of scope. Report gaps.
- **Target grid.** It shows over and under by colour only. Add a symbol or text.
- **`MuscleBalanceView.tile`** (`:58-94`) becomes `Stat.tile(tint:)`. Keep its accessibility
  pattern, which is the reference.
  - Its below/within/above colours (orange/green/blue) become status tokens plus a symbol.
- **`ProgressPhotosView`** uses `.regularMaterial` cards at radius 12 and 10. Use `.cardSurface`.
  Its native `.confirmationDialog` for a photo action is fine.
- **Load lifecycles.** `NutritionAnalyticsView` uses `.task` while `AnalyticsView` uses
  `.onFirstTask`. Pick one per the view's needs and note why.
- **Formatting.** "Cal" (`NutritionTargetChartPresenter.swift:120`) and every calorie label go
  through `Format.kcal`.
