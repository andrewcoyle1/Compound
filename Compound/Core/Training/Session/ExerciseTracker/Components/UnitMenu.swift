//
//  UnitMenu.swift
//  Compound
//
//  A column heading that is also its unit's menu.
//

import SwiftUI

/// The heading shows `label`; the menu lists `units`, the chosen one ticked.
struct UnitMenu<Unit: Hashable, Heading: View>: View {

    let units: [Unit]
    let selected: Unit
    let name: (Unit) -> String
    let onSelect: (Unit) -> Void
    @ViewBuilder let label: () -> Heading

    var body: some View {
        Menu {
            ForEach(units, id: \.self) { unit in
                Button {
                    onSelect(unit)
                } label: {
                    if unit == selected {
                        Label(name(unit), systemImage: Symbol.selected)
                    } else {
                        Text(name(unit))
                    }
                }
            }
        } label: {
            label()
                .chipStyle(tint: .secondary, filled: false)
                .frame(minHeight: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
