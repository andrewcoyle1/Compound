//
//  NumberField.swift
//  DialedIn
//
//  A number entry row: an `AutoSelectNumberField` (select-all on focus, non-finite input
//  rejected) with its unit as trailing secondary text, or as a menu picker when the user can
//  choose the unit. With a `label` it renders as `LabeledContent`, the field trailing.
//

import SwiftUI

/// A unit a `NumberField` can offer in its picker.
protocol PickableUnit: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var id: String { get }
    var acronym: String { get }
}

struct NumberField: View {

    private let prompt: String
    @Binding private var value: Double?
    private let label: String?
    private let unitView: AnyView?

    /// A field with a fixed unit, or none.
    init(_ prompt: String = "", value: Binding<Double?>, unit: String? = nil, label: String? = nil) {
        self.prompt = prompt
        self._value = value
        self.label = label
        self.unitView = unit.map { unit in
            AnyView(
                Text(unit)
                    .font(.rowTitle)
                    .foregroundStyle(.secondary)
            )
        }
    }

    /// A field whose unit the user picks from `units`.
    init<U: PickableUnit>(
        _ prompt: String = "",
        value: Binding<Double?>,
        units: [U],
        selection: Binding<U>,
        label: String? = nil
    ) {
        self.prompt = prompt
        self._value = value
        self.label = label
        self.unitView = AnyView(
            Picker("Unit", selection: selection) {
                ForEach(units, id: \.self) { unit in
                    Text(unit.acronym).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        )
    }

    var body: some View {
        if let label {
            LabeledContent(label) {
                field(alignment: .trailing)
            }
        } else {
            field(alignment: .leading)
        }
    }

    private func field(alignment: TextAlignment) -> some View {
        HStack(spacing: Spacing.s) {
            AutoSelectNumberField(prompt: prompt, value: $value, alignment: alignment)
                .textFieldStyle(.plain)
                .font(.rowTitle)
            unitView
        }
        .frame(minHeight: ControlSize.row)
    }
}

// MARK: - Previews

private struct NumberFieldPreview: View {
    @State private var weight: Double? = 82.5
    @State private var protein: Double?
    @State private var unit: NutritionWeightUnit = .grams

    var body: some View {
        List {
            Section("Plain") {
                NumberField("Enter a number", value: $weight)
            }
            Section("Fixed unit") {
                NumberField("Enter weight", value: $weight, unit: "kg")
            }
            Section("Unit picker") {
                NumberField("Enter protein", value: $protein, units: Array(NutritionWeightUnit.allCases), selection: $unit)
            }
            Section("Labelled") {
                NumberField("0", value: $weight, unit: "kg", label: "Body Weight")
                NumberField("0", value: $protein, units: Array(NutritionWeightUnit.allCases), selection: $unit, label: "Protein")
            }
        }
    }
}

#Preview("NumberField, light") {
    NumberFieldPreview().preferredColorScheme(.light)
}

#Preview("NumberField, dark") {
    NumberFieldPreview().preferredColorScheme(.dark)
}

#Preview("NumberField, accessibility3") {
    NumberFieldPreview().dynamicTypeSize(.accessibility3)
}
