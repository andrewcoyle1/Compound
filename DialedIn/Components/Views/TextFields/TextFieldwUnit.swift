//
//  TextFieldwUnit.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/03/2026.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `NumberField`.
@available(*, deprecated, message: "Use NumberField(_:value:unit:label:)")
struct TextFieldwUnit<T: PickableUnit>: View {

    var prompt: String = ""
    @Binding var value: Double?
    var unit: T

    var body: some View {
        NumberField(prompt, value: $value, unit: unit.acronym)
    }
}
