# Accent-swap findings (WP-01)

WP-01 set `AccentColor` to systemBlue and `OnAccent` to white, ran the screenshot deck, then
reverted. Each entry is a place that must change so a future accent change works. The WP in
brackets owns the fix. Fix your own entries as part of the Wave 3 checklist.

## Text unreadable on an accent fill

All of these use `colorScheme.background*`/`foreground*` on an accent fill. Use
`.foregroundStyle(.onAccent)`.

| File | Owner |
|---|---|
| `Components/Buttons/CallToActionButton.swift`: the root cause of most dark-mode CTA problems (CreateProgram, CreateWorkout, WorkoutTemplateDetail, SharedItem) | WP-07 |
| `Components/Modals/CustomModalView.swift:49` (`foregroundSecondary`) | WP-07 |
| `Core/Paywalls/Paywall/PaywallView.swift:18,28` | WP-12 |
| `Core/Training/TrainingView.swift:90`, `ProgramDesignView.swift:132`, `MuscleGroupPickerView.swift:101` | WP-10 |
| `Core/Nutrition/NutritionOverview/NutritionOverviewView.swift:57`, and the Nutrition library picker, MealDescribe, FoodPhotoScanner and BarcodeScanner (×4) | WP-08 |
| `Components/Views/CalendarHeader/CalendarDayCell.swift:149` | WP-10 |
| `View+EXT.swift` `badgeButton` | WP-05 |

## Accent missing where it belongs

| Where | Owner |
|---|---|
| Dashboard "Find People" link, Social/Own Profile "See All" | WP-11 |
| Analytics "See All" | WP-14 |
| Analytics "Goal Progress" bar, which is green and should be accent | WP-14 |
| Training "Microcycle 1 of 8" link | WP-10 |
| Training active-program workout checkmark circles, which are black and should be accent (selection) | WP-10 |
| Notifications "Enable Notifications" is a grey `.glass` button but is the primary action | WP-11 |
| Meal Detail and Nutrition item icons are `labelColor`-filled circles, hardcoded `.primary` brand emphasis | WP-08 |
| Search quick actions ("Start Workout", "Log Meal") are black. Secondary, so this is acceptable; decide | WP-11 |

## Accent used where it must not be

| Where | Owner |
|---|---|
| The Dashboard "Push Day A" card's title and subtitle turn into accent body text | WP-10 (`TodaysWorkoutCard`) |

## Macro colours still defined outside `DesignSystem/`

| Where | Owner |
|---|---|
| `Components/Views/WeeklyMacroChart.swift:42-84`: RGB literals, protein blue | WP-13 |
| Protein drawn blue: `NutritionOverviewView.swift:173`, `MealDescribeView.swift:91`, `BarcodeScannerView.swift:256`, `FoodPhotoScannerView.swift:141` | WP-08 |
| `Components/Views/Nutrition/NutritionCard.swift:33` | WP-11 |
| `NutritionAnalyticsView.swift:51`: `Color.blue` for calories, should be `.calories` | WP-14 |

The images live in the orchestrator's job tmp dir and are not committed.
