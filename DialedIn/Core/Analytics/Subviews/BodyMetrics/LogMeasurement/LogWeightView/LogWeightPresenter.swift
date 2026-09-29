//
//  LogWeightPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class LogWeightPresenter {
    private let interactor: LogWeightInteractor
    private let router: LogWeightRouter

    var selectedDate = Date()
    var selectedKilograms: Int = 70
    var selectedPounds: Int = 154
    var notes: String = ""
    var unit: UnitOfWeight = .kilograms
    var isLoading: Bool = false

    private var weightKg: Double {
        switch unit {
        case .kilograms:
            return Double(selectedKilograms)
        case .pounds:
            return Double(selectedPounds) * 0.453592
        }
    }

    var weightHistory: [BodyMeasurementEntry] {
        interactor.bodyMeasurements
    }

    init(
        interactor: LogWeightInteractor,
        router: LogWeightRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func loadInitialData() async {
        guard let user = interactor.currentUser else { return }

        // Set initial unit based on user preference
        if let preference = user.submittedWeightUnitPreference {
            unit = preference == .kilograms ? .kilograms : .pounds
        }

        // Set initial weight to current weight if available
        if let currentWeight = user.submittedWeightKilograms {
            selectedKilograms = Int(currentWeight)
            selectedPounds = Int(UnitConversion.kgToLbs(currentWeight))
        }

    }

    func saveWeight() async {
        guard let user = interactor.currentUser else { return }

        isLoading = true

        do {
            // Save weight entry
            let entry = BodyMeasurementEntry(authorId: user.userId, weightKg: weightKg, date: selectedDate)
            try await interactor.saveBodyMeasurement(bodyMeasurement: entry)

            // Update user's current weight
            try await interactor.updateWeight(userId: user.userId, weight: weightKg, weightUnitPreference: unit == .kilograms ? .kilograms : .pounds)

            interactor.playHaptic(option: .success)
            router.dismissScreen()
        } catch {
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Save Weight"), error: error)
        }

        isLoading = false
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    func onDismissPressed() {
        router.dismissScreen()
    }
}
