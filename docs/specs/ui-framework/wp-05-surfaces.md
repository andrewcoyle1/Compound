# WP-05 · Surfaces: card, stat, chip

**Wave 2. Depends on WP-01 and WP-02. Size: medium.**

**Goal:** build `.cardSurface`, `Stat` and `Chip` from `CONTRACT.md`, rebuild the existing card
components on them, and deprecate what they replace. This WP does **not** migrate Core call sites.
Wave 3 does that, guided by the deprecation warnings.

**Owns:**
- `Components/DesignSystem/Card.swift`, `Stat.swift`, `Chip.swift` (new)
- `Components/Views/DashboardCard.swift`
- `Components/Views/AnalyticsCard.swift`
- `Components/Views/AnalyticsSection.swift`
- `Components/Views/StatCard.swift`, `StatItem.swift`
- `Components/ViewModifiers/View+EXT.swift` (`badgeButton` only)

## Steps

1. **`.cardSurface(_ style: CardStyle = .card)`**
   - Applies `.background(<fill>, in: .rect(cornerRadius:, style: .continuous))` with the fill and
     radius the contract gives.
   - Padding stays the caller's job.
   - It also sets `.containerShape` to the same shape, so nested content can use
     `ConcentricRectangle`.
2. **`Stat`**
   - Value above label.
   - Sizes map to `Font.metricSmall/.metric/.metricLarge` for the value and `Font.label` for the
     label, with an optional leading symbol.
   - `.accessibilityElement(children: .combine)`, reading as "label, value".
   - Add a `Stat.tile(...)` convenience, which is `Stat` + padding + `.cardSurface(.tile)` (or
     `.tinted(c)` when a tint is passed). It covers `MacroStatCard`, `MuscleBalanceView.tile` and
     the share-card helpers in Wave 3.
3. **`Chip`**
   - Capsule, `Font.label` weight semibold, fill `tintedSurface(tint)`, foreground `tint`.
   - When `isSelected` is true it uses a solid tint with `onAccent` text and `.isSelected`.
   - Horizontal `Spacing.s`, vertical `Spacing.xs`.
4. **Rebuild `DashboardCard` on `.cardSurface(.card)`.** Keep its API and its height statics.
5. **Rebuild `AnalyticsCard` on `.cardSurface(.tile)`.**
   - Replace the fixed `.frame(height: 120)` with a `minHeight`, so it grows at large type sizes.
   - Actually use `themeColor`: tint the title symbol or sparkline.
   - Draw the chevron only when the card is tappable. Add `showsChevron: Bool = true`, or infer
     it from `.analyticsCardButton`.
   - Rename `subsubtitle`/`subsubsubtitle` to meaningful labels, keeping deprecated forwarding
     inits so no call site breaks. Check `AnalyticsEmptyCard` for the same changes.
6. **Deprecate what the new primitives replace.** Mark `StatItem`, `StatCard` and `.badgeButton()`
   `@available(*, deprecated, message: "Use Stat / Chip, see docs/specs/ui-framework/CONTRACT.md")`.
   Rebuild their bodies on the new primitives, so a screen that has not migrated yet already
   looks right.
7. **Previews** show every size, style and tint in light and dark, plus one at `.accessibility3`.

**Tests:** none needed for pure views. If `AnalyticsCard` gains logic, such as chevron inference,
test that logic.

**Done when:** it builds with only the new deprecation warnings, `swiftlint` is clean, and the
previews render.
