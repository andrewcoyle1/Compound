//
//  LogMeasurementPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/09/2026.
//

import SwiftUI

@Observable
@MainActor
class LogMeasurementPresenter {
    private let interactor: LogMeasurementInteractor
    private let router: LogMeasurementRouter

    let kind: BodyMeasurementKind

    var selectedDate = Date()
    var selectedCentimeters: Int
    var selectedInches: Int
    var unit: UnitOfLength = .centimeters
    var isLoading: Bool = false

    private var measurementCm: Double {
        switch unit {
        case .centimeters:
            return Double(selectedCentimeters)
        case .inches:
            return Double(selectedInches) * 2.54
        }
    }

    init(
        kind: BodyMeasurementKind,
        interactor: LogMeasurementInteractor,
        router: LogMeasurementRouter
    ) {
        self.kind = kind
        self.interactor = interactor
        self.router = router
        self.selectedCentimeters = kind.defaultCentimetres
        self.selectedInches = kind.defaultInches
    }

    func loadInitialData() async {
        guard let user = interactor.currentUser else { return }

        if let preference = user.submittedLengthUnitPreference {
            unit = preference == .centimeters ? .centimeters : .inches
        }

        if let latest = interactor.bodyMeasurements
            .filter({ $0.deletedAt == nil && $0[keyPath: kind.entryValue] != nil })
            .sorted(by: { $0.date > $1.date })
            .first,
           let circumference = latest[keyPath: kind.entryValue] {
            selectedCentimeters = Int(circumference)
            selectedInches = Int(circumference / 2.54)
        }
    }

    func saveMeasurement() async {
        guard let user = interactor.currentUser else { return }

        isLoading = true

        do {
            let existingEntries = interactor.bodyMeasurements
                .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.deletedAt == nil }

            let base = existingEntries.first ?? BodyMeasurementEntry(authorId: user.userId, date: selectedDate)
            try await interactor.saveBodyMeasurement(bodyMeasurement: base.withUpdated(kind.update(to: measurementCm)))

            interactor.playHaptic(option: .success)
            router.dismissScreen()
        } catch {
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Save Measurement"), error: error)
        }

        isLoading = false
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}
