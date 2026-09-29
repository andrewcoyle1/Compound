# WP-04 · App shell: iPad, Mac and the widget string catalog

**Wave 1. Depends on nothing. Size: medium.**

**Owns:**
- `Core/AppView/AppView.swift`
- `Core/AdaptiveMain/`
- `Core/SplitViewContainer/`
- `Core/TabBar/`
- `Root/RIBs/Core/CoreBuilder*.swift`, only for removing the adaptive and split builders
- `WorkoutSessionActivity/` (catalog only)

## 1. Replace the split-view stub with an adaptable tab view

Today `AdaptiveMainView` sends every regular width and every Mac Catalyst launch to
`SplitViewContainer`. That container is a stub: its sidebar buttons only `print`, it always
shows the first tab, and it has no Dashboard or Search. So iPad and Mac are broken.

1. Give `TabBarView` `.tabViewStyle(.sidebarAdaptable)`. Keep `.tabBarMinimizeBehavior`, the
   search role tab, the badge and the bottom accessory. Confirm the accessory still shows on
   iPhone, and look at what it does in the iPad sidebar layout.
2. Route every width to `TabBarView`. Delete `SplitViewContainer` and its presenter, router and
   interactor. Delete `AdaptiveMainView` and its module, unless it does something besides
   choosing the layout; read it first.
3. **Remove the double registration.** `AppView.swift:135` and `AdaptiveMainView.swift:39` both
   open a `RouterView` with `Constants.tabBarModuleId`. Keep one. Keep the one that carries the
   module-switching behaviour `AppState.startingModuleId` relies on.
4. Delete the commented-out code at `TabBarView.swift:80-86`.
5. Check for deep links (`Core/TabBar/DeepLink.swift`, the `selectTab` notification): tab
   selection must still work from notifications.
6. **Verify on three simulators:**
   - iPhone: build and screenshot the four tabs.
   - iPad: build, run, and screenshot the sidebar layout.
   - Mac Catalyst: build only.

   Attach the iPad screenshot path in the report.

## 2. Widget string catalog

`WorkoutSessionActivity/` has no string catalog, so Live Activity text is never localised.

1. Add `WorkoutSessionActivity/Localizable.xcstrings`. Synchronized folders pick it up; confirm it
   lands in the extension target's resources.
2. Build the `WorkoutSessionActivityExtension` scheme so it extracts keys.
3. Add Spanish for every key. Reuse the app catalog's translation where the same English key
   exists there.

This is the one WP that commits a catalog. It is the widget's own, so no other WP touches it.

**Tests:** existing `TabBar`/`AppView` presenter suites, if any, under `-only-testing`.

**Done when:** all three platforms build and iPad shows real content in every tab.
