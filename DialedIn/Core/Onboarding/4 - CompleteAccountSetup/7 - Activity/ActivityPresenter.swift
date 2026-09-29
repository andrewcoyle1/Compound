//
//  ActivityPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ActivityPresenter {
    private let interactor: ActivityInteractor
    private let router: ActivityRouter

    var selectedActivityLevel: ActivityLevel?
        
    var canSubmit: Bool {
        selectedActivityLevel != nil
    }
    
    init(
        interactor: ActivityInteractor,
        router: ActivityRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onContinuePressed(delegate: ActivityDelegate) {
        guard let activityLevel = selectedActivityLevel else { return }
        let delegate = CardioFitnessDelegate(delegate: delegate, activityLevel: activityLevel)
        interactor.trackEvent(event: Event.navigate)
        router.showCardioFitnessView(delegate: delegate)
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
            case .navigate: return "ActivityLevel_Navigate"
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

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    var description: String {
        switch self {
        case .sedentary:
            return String(localized: "Sedentary")
        case .light:
            return String(localized: "Light Activity")
        case .moderate:
            return String(localized: "Moderate Activity")
        case .active:
            return String(localized: "Active")
        case .veryActive:
            return String(localized: "Very Active")
        }
    }
    
    var detailDescription: String {
        switch self {
        case .sedentary:
            return String(localized: "Desk job, minimal walking, mostly sitting")
        case .light:
            return String(localized: "Light walking, some daily activities, occasional stairs")
        case .moderate:
            return String(localized: "Regular walking, standing work, daily movement")
        case .active:
            return String(localized: "Active lifestyle, frequent movement, manual work")
        case .veryActive:
            return String(localized: "Highly active, constant movement, physically demanding")
        }
    }
}
