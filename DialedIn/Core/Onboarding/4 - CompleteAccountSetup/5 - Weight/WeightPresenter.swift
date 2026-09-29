//
//  WeightPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WeightPresenter {
    private let interactor: WeightInteractor
    private let router: WeightRouter

    var unit: UnitOfWeight = .kilograms
    var selectedKilograms: Int = 70
    var selectedPounds: Int = 154
        
    var weight: Double {
        switch unit {
        case .kilograms:
            Double(selectedKilograms)
        case .pounds:
            Double(selectedPounds) * 0.453592
        }
    }
    
    var preference: WeightUnitPreference {
        switch unit {
        case .kilograms:
            return .kilograms
        case .pounds:
            return .pounds
        }
    }
        
    var canSubmit: Bool {
        switch unit {
        case .kilograms:
            return (30...200).contains(selectedKilograms)
        case .pounds:
            return (66...440).contains(selectedPounds)
        }
    }
    
    func updatePoundsFromKilograms() {
        selectedPounds = Int(UnitConversion.kgToLbs(Double(selectedKilograms)))
    }

    func updateKilogramsFromPounds() {
        selectedKilograms = Int(UnitConversion.lbsToKg(Double(selectedPounds)))
    }
    
    init(
        interactor: WeightInteractor,
        router: WeightRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onContinuePressed(delegate: WeightDelegate) {
        let delegate = ExerciseFrequencyDelegate(delegate: delegate, weightInKilograms: weight, weightUnitPreference: preference)
        interactor.trackEvent(event: Event.navigate)
        router.showExerciseFrequencyView(delegate: delegate)
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "WeightView_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .navigate:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .navigate:
                return .info
            }
        }
    }
}

enum UnitOfWeight: String, PickableUnit {
    
    var id: String { self.rawValue }
    case kilograms
    case pounds
    
    var name: String {
        switch self {
        case .kilograms: return String(localized: "Kilograms")
        case .pounds: return String(localized: "Pounds")
        }
    }
    
    var acronym: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lbs"
        }
    }
    
}
