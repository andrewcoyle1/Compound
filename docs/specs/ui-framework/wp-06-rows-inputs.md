# WP-06 · Rows and inputs

**Wave 2. Depends on WP-01 and WP-02. Size: medium.**

**Goal:** build `ListRow`, `ListRowButton`, `ListRowToggle`, `SelectableRow` and `NumberField`,
token-ise `SectionHeaderView`, and deprecate what they replace. This WP does not migrate Core call
sites.

**Owns:**
- `Components/DesignSystem/ListRow.swift`, `NumberField.swift` (new)
- `Components/Views/SectionHeaderView.swift`
- `Components/Views/CustomListCellView.swift`, `CustomLabelButtonView.swift`,
  `CustomToggleView.swift`, `MetricRow.swift`
- `Components/Views/TextFields/`

## Steps

1. **`ListRow`**
   - Leading symbol in a `ControlSize.icon` frame, tinted. Title in `Font.rowTitle`, subtitle in
     `Font.rowDetail` `.secondary`.
   - Trailing accessory per the contract. `.value(String)` shows secondary text.
   - Also accept an image-URL leading variant (`ImageLoaderView`, `Radius.s`, `ControlSize.thumbnail`),
     because `CustomListCellView` supports images.
   - Selection overlay behaviour from `CustomListCellView` maps to `.checkmark(Bool)`.
   - It has no background of its own: inside a `List` the row supplies it.
2. **`ListRowButton`**
   - A `Button(action:) { ListRow(accessory: .chevron) }` with `.contentShape(.rect)`, so the
     **whole row** is tappable. Today `CustomLabelButtonView` only responds on the chevron; fixing
     that is part of this WP.
   - It keeps native List highlight: no `.plain` style inside a List. Tint the text `.primary`.
3. **`ListRowToggle`:** a `Toggle` whose label is the `ListRow` content.
4. **`SelectableRow`:** checkmark accessory, whole-row button, and `.isSelected` when selected.
   It replaces the onboarding option row, which is copied about 9 times with three tap mechanisms.
5. **`NumberField(value: Binding<Double?>, unit: String? | units: [U] + selection: Binding<U>, label: String?)`**
   - Built on `AutoSelectNumberField`, which keeps select-all on focus.
   - Unit shown as trailing secondary text, or a menu `Picker` when `units` is passed. This removes
     `TextFieldwUnitPicker`'s `.padding(.trailing, -16)` hack.
   - The `label` form renders as `LabeledContent`, not a `Section` header.
6. **`SectionHeaderView`:** switch its fonts and spacing to tokens. Its "See All" becomes a plain
   button styled `.secondary` with `Font.label`, not underlined, and gets an accessibility label.
7. **Deprecate** `CustomListCellView`, `CustomLabelButtonView`, `CustomToggleView`, `MetricRow`,
   `TextFieldwUnit`, `TextFieldwUnitPicker` and the `LabeledTextField*` types, with messages naming
   the replacement. Where feasible, re-implement their bodies on the new primitives with identical
   init signatures. That way the row tap-target fix and the new look reach every screen before
   Wave 3.
8. **Previews** cover each accessory, a toggle row, a selectable list, and each `NumberField`
   form, in light, dark and `.accessibility3`.

**Tests:** none needed unless `NumberField` gains parsing logic beyond `AutoSelectNumberField`.

**Done when:** it builds with only the new deprecation warnings and `swiftlint` is clean.
