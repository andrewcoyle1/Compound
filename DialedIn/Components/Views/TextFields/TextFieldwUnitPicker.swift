//
//  TextFieldwUnitPicker.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/03/2026.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `NumberField`.
@available(*, deprecated, message: "Use NumberField(_:value:units:selection:label:)")
struct TextFieldwUnitPicker<T: PickableUnit>: View {

    var prompt: String = ""
    @Binding var value: Double?
    @Binding var unit: T

    var body: some View {
        NumberField(prompt, value: $value, units: Array(T.allCases), selection: $unit)
    }
}
