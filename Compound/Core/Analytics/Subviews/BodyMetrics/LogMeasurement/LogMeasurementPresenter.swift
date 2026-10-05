//
//  LogMeasurementPresenter.swift
//  Compound
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
    var selectedCentimetersTenths: Int = 0
    var selectedInches: Int
    var selectedInchesTenths: Int = 0
    var unit: UnitOfLength = .centimeters
    var isLoading: Bool = false

    private var measurementCm: Double {
        switch unit {
        case .centimeters:
            return DecimalWheelValue.combine(whole: selectedCentimeters, tenths: selectedCentimetersTenths)
        case .inches:
            let inches = DecimalWheelValue.combine(whole: selectedInches, tenths: selectedInchesTenths)
            return inches * 2.54
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

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(kind: kind))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(kind: kind))
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
            // A whole-number entry saved before the tenths wheel existed splits to tenths of 0.
            (selectedCentimeters, selectedCentimetersTenths) = DecimalWheelValue.split(circumference)
            (selectedInches, selectedInchesTenths) = DecimalWheelValue.split(circumference / 2.54)
        }
    }

    func saveMeasurement() async {
        guard let user = interactor.currentUser else { return }

        isLoading = true
        interactor.trackEvent(event: Event.saveStart(kind: kind))

        do {
            let existingEntries = interactor.bodyMeasurements
                .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.deletedAt == nil }

            let base = existingEntries.first ?? BodyMeasurementEntry(authorId: user.userId, date: selectedDate)
            try await interactor.saveBodyMeasurement(bodyMeasurement: base.withUpdated(kind.update(to: measurementCm)))
            interactor.trackEvent(event: Event.saveSuccess(kind: kind))

            interactor.playHaptic(option: .success)
            router.dismissScreen()
        } catch {
            interactor.trackEvent(event: Event.saveFail(kind: kind, error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Save Measurement"), error: error)
        }

        isLoading = false
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension LogMeasurementPresenter {
    /// One set of names for all eighteen measurements, told apart by the `measurement` parameter.
    enum Event: LoggableEvent {
        case onAppear(kind: BodyMeasurementKind)
        case onDisappear(kind: BodyMeasurementKind)
        case saveStart(kind: BodyMeasurementKind)
        case saveSuccess(kind: BodyMeasurementKind)
        case saveFail(kind: BodyMeasurementKind, error: Error)

        var eventName: String {
            switch self {
            case .onAppear:    return "LogMeasurementView_Appear"
            case .onDisappear: return "LogMeasurementView_Disappear"
            case .saveStart:   return "LogMeasurementView_Save_Start"
            case .saveSuccess: return "LogMeasurementView_Save_Success"
            case .saveFail:    return "LogMeasurementView_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let kind), .onDisappear(let kind), .saveStart(let kind), .saveSuccess(let kind):
                return ["measurement": kind.rawValue]
            case .saveFail(let kind, let error):
                return error.eventParameters.merging(["measurement": kind.rawValue]) { $1 }
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default:        return .analytic
            }
        }
    }
}
