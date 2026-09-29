//
//  ServingUnitPicker.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

import SwiftUI

/// Picks what a food amount is typed in: its base unit (nil), or one of its serving units.
struct ServingUnitPicker: View {
    let baseLabel: String
    let units: [ServingUnit]
    @Binding var selection: ServingUnit?

    var body: some View {
        Picker("Unit", selection: $selection) {
            Text(baseLabel).tag(ServingUnit?.none)
            ForEach(units, id: \.self) { unit in
                Text(unit.name).tag(ServingUnit?.some(unit))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}
