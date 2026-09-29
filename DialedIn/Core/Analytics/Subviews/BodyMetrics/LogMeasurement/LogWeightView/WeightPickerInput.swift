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
///
/// Each unit is two wheels — whole and tenths — so 82.4 kg can be entered, as Health does. The
/// tenths bindings default to a fixed `.constant(0)` so an existing caller that only passes the
/// whole-number bindings keeps compiling; it just cannot enter a decimal until it passes its own.
struct WeightPickerInput: View {

    @Binding var unit: UnitOfWeight
    @Binding var selectedKilograms: Int
    @Binding var selectedKilogramsTenths: Int
    @Binding var selectedPounds: Int
    @Binding var selectedPoundsTenths: Int
    /// The wheel shows about five rows; it grows with Dynamic Type so they are never clipped.
    @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 150

    /// The ranges the wheels offer. Kept here so both callers show the same span.
    static let kilogramRange = 30...200
    static let poundRange = 66...440

    init(
        unit: Binding<UnitOfWeight>,
        selectedKilograms: Binding<Int>,
        selectedKilogramsTenths: Binding<Int> = .constant(0),
        selectedPounds: Binding<Int>,
        selectedPoundsTenths: Binding<Int> = .constant(0)
    ) {
        _unit = unit
        _selectedKilograms = selectedKilograms
        _selectedKilogramsTenths = selectedKilogramsTenths
        _selectedPounds = selectedPounds
        _selectedPoundsTenths = selectedPoundsTenths
    }

    var body: some View {
        unitPickerSection
        weightPickerSection
    }

    private var unitPickerSection: some View {
        Section {
            Picker("Units", selection: $unit) {
                Text("Metric (kg)").tag(UnitOfWeight.kilograms)
                Text("Imperial (lb)").tag(UnitOfWeight.pounds)
            }
            .pickerStyle(.segmented)
        }
        .removeListRowFormatting()
    }

    private var weightPickerSection: some View {
        Section {
            HStack(spacing: 0) {
                if unit == .kilograms {
                    Picker("Weight", selection: $selectedKilograms) {
                        ForEach(Self.kilogramRange, id: \.self) { value in
                            Text("\(value) kg").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedKilograms) { _, _ in syncPoundsFromKilograms() }

                    Picker("Tenths", selection: $selectedKilogramsTenths) {
                        ForEach(DecimalWheelValue.tenths, id: \.self) { value in
                            Text(".\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedKilogramsTenths) { _, _ in syncPoundsFromKilograms() }
                } else {
                    Picker("Weight", selection: $selectedPounds) {
                        ForEach(Self.poundRange, id: \.self) { value in
                            Text("\(value) lb").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedPounds) { _, _ in syncKilogramsFromPounds() }

                    Picker("Tenths", selection: $selectedPoundsTenths) {
                        ForEach(DecimalWheelValue.tenths, id: \.self) { value in
                            Text(".\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedPoundsTenths) { _, _ in syncKilogramsFromPounds() }
                }
            }
            .frame(height: wheelHeight)
            .clipped()
        } header: {
            Text("Weight")
        }
        .removeListRowFormatting()
    }

    private func syncPoundsFromKilograms() {
        let kilograms = DecimalWheelValue.combine(whole: selectedKilograms, tenths: selectedKilogramsTenths)
        let (whole, tenths) = DecimalWheelValue.split(UnitConversion.kgToLbs(kilograms))
        selectedPounds = whole
        selectedPoundsTenths = tenths
    }

    private func syncKilogramsFromPounds() {
        let pounds = DecimalWheelValue.combine(whole: selectedPounds, tenths: selectedPoundsTenths)
        let (whole, tenths) = DecimalWheelValue.split(UnitConversion.lbsToKg(pounds))
        selectedKilograms = whole
        selectedKilogramsTenths = tenths
    }
}
