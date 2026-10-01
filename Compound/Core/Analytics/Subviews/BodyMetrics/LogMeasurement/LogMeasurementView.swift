//
//  LogMeasurementView.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

import SwiftUI

struct LogMeasurementView: View {

    @State var presenter: LogMeasurementPresenter
    /// The wheel shows about five rows; it grows with Dynamic Type so they are never clipped.
    @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 150

    var body: some View {
        List {
            dateSection
                .removeListRowFormatting()
            unitPickerSection
            measurementPickerSection
        }
        .navigationTitle(presenter.kind.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .task {
            await presenter.loadInitialData()
        }
    }

    // The picker's own "Date" label already says what the row is; a header and footer that both
    // repeated it added nothing.
    private var dateSection: some View {
        Section {
            DatePicker(
                "Date",
                selection: $presenter.selectedDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
        }
    }

    private var unitPickerSection: some View {
        Section {
            Picker("Units", selection: $presenter.unit) {
                Text("Metric (cm)").tag(UnitOfLength.centimeters)
                Text("Imperial (in)").tag(UnitOfLength.inches)
            }
            .pickerStyle(.segmented)
        }
        .removeListRowFormatting()
    }

    private var measurementPickerSection: some View {
        Section {
            HStack(spacing: 0) {
                if presenter.unit == .centimeters {
                    Picker(presenter.kind.fieldLabel, selection: $presenter.selectedCentimeters) {
                        ForEach(presenter.kind.centimetreRange, id: \.self) { value in
                            Text("\(value) cm").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: presenter.selectedCentimeters) { _, _ in syncInchesFromCentimeters() }

                    Picker("Tenths", selection: $presenter.selectedCentimetersTenths) {
                        ForEach(DecimalWheelValue.tenths, id: \.self) { value in
                            Text(".\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: presenter.selectedCentimetersTenths) { _, _ in syncInchesFromCentimeters() }
                } else {
                    Picker(presenter.kind.fieldLabel, selection: $presenter.selectedInches) {
                        ForEach(presenter.kind.inchRange, id: \.self) { value in
                            Text("\(value) in").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: presenter.selectedInches) { _, _ in syncCentimetersFromInches() }

                    Picker("Tenths", selection: $presenter.selectedInchesTenths) {
                        ForEach(DecimalWheelValue.tenths, id: \.self) { value in
                            Text(".\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: presenter.selectedInchesTenths) { _, _ in syncCentimetersFromInches() }
                }
            }
            .frame(height: wheelHeight)
            .clipped()
        } header: {
            Text(presenter.kind.fieldLabel)
        }
        .removeListRowFormatting()
    }

    private func syncInchesFromCentimeters() {
        let centimeters = DecimalWheelValue.combine(whole: presenter.selectedCentimeters, tenths: presenter.selectedCentimetersTenths)
        (presenter.selectedInches, presenter.selectedInchesTenths) = DecimalWheelValue.split(centimeters / 2.54)
    }

    private func syncCentimetersFromInches() {
        let inches = DecimalWheelValue.combine(whole: presenter.selectedInches, tenths: presenter.selectedInchesTenths)
        (presenter.selectedCentimeters, presenter.selectedCentimetersTenths) = DecimalWheelValue.split(inches * 2.54)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if presenter.isLoading {
                ProgressView()
            } else {
                Button(role: .confirm) {
                    Task {
                        await presenter.saveMeasurement()
                    }
                }
            }
        }
    }
}

extension CoreBuilder {
    func logMeasurementView(router: AnyRouter, kind: BodyMeasurementKind) -> some View {
        LogMeasurementView(
            presenter: LogMeasurementPresenter(
                kind: kind,
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showLogMeasurementView(kind: BodyMeasurementKind) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.logMeasurementView(router: router, kind: kind)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.logMeasurementView(router: router, kind: .waist)
    }
}
