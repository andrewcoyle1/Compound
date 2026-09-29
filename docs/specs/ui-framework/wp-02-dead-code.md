# WP-02 · Delete dead components

**Wave 1. Depends on nothing. Size: small, deletion only.**

**Goal:** remove the components with zero live call sites, so Wave 2 does not deprecate or
migrate them. No visual change.

**Owns:** the files listed below; `Components/ViewModifiers/View+EXT.swift`;
`Components/Models/MetricConfiguration.swift`/`MetricChartType.swift`.

## Steps

1. **Confirm each candidate is dead.** For each one, grep the type name across `DialedIn/`,
   `DialedInUnitTests/` and `WorkoutSessionActivity/`. A candidate is dead when it is referenced
   only in its own file and its previews, or only by another candidate on this list. If anything
   else uses one, keep it and report it.

   Candidates:
   - **Components:** `AsyncCallToActionButton`, `ProfileModalView`, `ModalSupportView`,
     `CustomPresetPickerButton`, `CarouselView`, `HeroCellView`, `CategoryCellView`,
     `RowCellView`, `RowCellViewBuilder`, `MultipleSelectionRow`, `ProgressCircle`, `StatLabel`,
     `MetricCard`, `MetricView`, `RestDayRow`, `EmptyState` (`Components/Views/Training/EmptyState.swift`).
   - **Modifiers in `View+EXT.swift`:** `callToActionButton()`/`CtaButtonViewModifier`,
     `ifSatisfiedCondition`, `addingGradientBackgroundForText`.
   - **`onFirstAppear`** (not `onFirstTask`).
   - **The `chartType` field** on `MetricConfiguration`, and `MetricChartType` if nothing else
     uses it.
2. **Delete them,** building after each group.
3. **Fix `badgeButton()` in `View+EXT.swift`.** Its only live user is the paywall, and it draws
   `.white` on the accent, which is white in dark mode. Change the foreground to
   `Color(uiColor: .systemBackground)`, because WP-01's `onAccent` may not be merged yet. Commit
   it as `[Fix]`. WP-05's `Chip` replaces the modifier later.
4. **Remove leftover references** in `DevPreview.swift`, `CoreBuilder` or the codebase map
   inputs. Do not edit the map itself.

**Done when:** everything builds, `build-for-testing` passes, and `swiftlint` is clean. Report the
list of what was deleted and anything kept.
