//
//  ProteinIntakePresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ProteinIntakePresenter {
    private let interactor: ProteinIntakeInteractor
    private let router: ProteinIntakeRouter

    var selectedProteinIntake: ProteinIntake?
    var hasTrainingPlan: Bool = false

    init(
        interactor: ProteinIntakeInteractor,
        router: ProteinIntakeRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onContinuePressed(delegate oldDelegate: ProteinIntakeDelegate) {
        if let proteinIntake = selectedProteinIntake {
            let delegate = DietPlanDelegate(oldDelegate: oldDelegate, proteinIntake: proteinIntake)
            interactor.trackEvent(event: Event.navigate)
            router.showDietPlanView(delegate: delegate)
        }
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
            case .navigate: return "Onboarding_ProteinIntake_Navigate"
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

enum ProteinIntake: String, CaseIterable, Identifiable {
    case low
    case moderate
    case high
    case veryHigh
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .low:
            return String(localized: "Low")
        case .moderate:
            return String(localized: "Moderate")
        case .high:
            return String(localized: "High")
        case .veryHigh:
            return String(localized: "Very High")
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .low:
            return String(localized: "On the low side of the optimal range.")
        case .moderate:
            return String(localized: "In the middle of the optimal range.")
        case .high:
            return String(localized: "On the high end of the optimal range.")
        case .veryHigh:
            return String(localized: "Highest recommended intake.")
        }
    }
}
