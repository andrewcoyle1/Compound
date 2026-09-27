//
//  LabeledTextFieldWithUnit.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/03/2026.
//
//  Each of these is a whole `Section` with the label as its header. They keep that shape so the
//  screens built from them do not change structure; `NumberField(label:)` renders the label as
//  `LabeledContent` inside a row instead.
//

import SwiftUI

@available(*, deprecated, message: "Use TextField inside a Section, or LabeledContent(label) { TextField }")
struct LabeledTextField: View {

    let label: String
    var prompt: String = ""
    let text: Binding<String>

    var body: some View {
        Section {
            TextField(prompt, text: text)
        } header: {
            Text(label)
        }
    }
}

@available(*, deprecated, message: "Use NumberField(_:value:unit:label:)")
struct LabeledTextFieldWithUnit<T: PickableUnit>: View {

    let label: String
    var prompt: String = ""
    let value: Binding<Double?>
    let unit: T

    var body: some View {
        Section {
            NumberField(prompt, value: value, unit: unit.acronym)
        } header: {
            Text(label)
        }
    }
}

@available(*, deprecated, message: "Use NumberField(_:value:units:selection:label:)")
struct LabeledTextFieldWithUnitPicker<T: PickableUnit>: View {

    let label: String
    let value: Binding<Double?>
    let unit: Binding<T>

    var body: some View {
        Section {
            NumberField(value: value, units: Array(T.allCases), selection: unit)
        } header: {
            Text(label)
        }
    }
}
