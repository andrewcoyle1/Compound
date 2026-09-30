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
    var selectedKilogramsTenths: Int = 0
    var selectedPounds: Int = 154
    var selectedPoundsTenths: Int = 0
    var notes: String = ""
    var unit: UnitOfWeight = .kilograms
    var isLoading: Bool = false

    private var weightKg: Double {
        switch unit {
        case .kilograms:
            return DecimalWheelValue.combine(whole: selectedKilograms, tenths: selectedKilogramsTenths)
        case .pounds:
            let pounds = DecimalWheelValue.combine(whole: selectedPounds, tenths: selectedPoundsTenths)
            return UnitConversion.lbsToKg(pounds)
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

        // Start from the latest weigh-in, which is what Today and the charts show, and fall back to
        // the weight given at onboarding. That profile weight alone used to open the wheel on a
        // number days or weeks old. A whole-number entry saved before the tenths wheel existed
        // splits to a tenths digit of 0.
        let latestWeighIn = interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .max { $0.date < $1.date }?
            .weightKg
        if let currentWeight = latestWeighIn ?? user.submittedWeightKilograms {
            (selectedKilograms, selectedKilogramsTenths) = DecimalWheelValue.split(currentWeight)
            (selectedPounds, selectedPoundsTenths) = DecimalWheelValue.split(UnitConversion.kgToLbs(currentWeight))
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

    func onDismissPressed() {
        router.dismissScreen()
    }
}
