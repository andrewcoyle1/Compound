# compound_charts

Compound's charts for the Flutter app, drawn with `CustomPainter` on `app_ui`'s tokens. No
third-party chart library: the aim is the polish of a commercial one without its licence.

```dart
import 'package:compound_charts/compound_charts.dart';
```

| Swift (QuickCharts) | Flutter |
|---|---|
| `LineChart`, `BarChart`, `StackedBarChart`, `ComboChart` | `CartesianChart` with `ChartData` |
| `YAxisFit` | `ChartYFit` |
| a chart's legend | `ChartLegend`, `ChartSwatch` |
| `chartCallout` | `ChartCallout` |
| `SeriesSummary` | `ChartCalloutSummary` |

Every user-facing word is passed in already localized; the package holds no strings.

Tests are held at 100% line coverage. Goldens follow `docs/specs/flutter/ui-contract.md`, rule 6,
as in `app_ui`: `goldens/ci/` beside each test is what every run compares, and
`--dart-define=HUMAN_GOLDENS=true` draws the readable set into `goldens/macos/`. Update them with a
path (`flutter test --tags golden --update-goldens test/src`).
