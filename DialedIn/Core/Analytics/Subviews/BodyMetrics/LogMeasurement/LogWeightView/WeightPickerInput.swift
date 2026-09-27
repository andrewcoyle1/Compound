//
//  WeightPickerInput.swift
//  DialedIn
//

import SwiftUI

/// The unit toggle and weight wheel from the log-weight sheet, as one reusable pair of sections.
///
/// Extracted so the weekly check-in's weigh-in step is literally the same control rather than a
/// second picker that drifts: two wheels with different ranges, or one that converts to pounds
/// and one that does not, is the kind of difference nobody notices until a weigh-in is wrong.
struct WeightPickerInput: View {

    @Binding var unit: UnitOfWeight
    @Binding var selectedKilograms: Int
    @Binding var selectedPounds: Int
    /// The wheel shows about five rows; it grows with Dynamic Type so they are never clipped.
    @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 150

    /// The ranges the wheels offer. Kept here so both callers show the same span.
    static let kilogramRange = 30...200
    static let poundRange = 66...440

    var body: some View {
        unitPickerSection
        weightPickerSection
    }

    private var unitPickerSection: some View {
        Section {
            Picker("Units", selection: $unit) {
                Text("Metric (kg)").tag(UnitOfWeight.kilograms)
                Text("Imperial (lbs)").tag(UnitOfWeight.pounds)
            }
            .pickerStyle(.segmented)
        }
        .removeListRowFormatting()
    }

    private var weightPickerSection: some View {
        Section {
            if unit == .kilograms {
                Picker("Weight", selection: $selectedKilograms) {
                    ForEach(Self.kilogramRange.reversed(), id: \.self) { value in
                        Text("\(value) kg").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: wheelHeight)
                .clipped()
                .onChange(of: selectedKilograms) { _, newValue in
                    selectedPounds = Int(UnitConversion.kgToLbs(Double(newValue)))
                }
            } else {
                Picker("Weight", selection: $selectedPounds) {
                    ForEach(Self.poundRange.reversed(), id: \.self) { value in
                        Text("\(value) lbs").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: wheelHeight)
                .clipped()
                .onChange(of: selectedPounds) { _, newValue in
                    selectedKilograms = Int(UnitConversion.lbsToKg(Double(newValue)))
                }
            }
        } header: {
            Text("Weight")
        }
        .removeListRowFormatting()
    }
}
