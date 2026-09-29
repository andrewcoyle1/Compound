//
//  CardioFitnessPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CardioFitnessPresenter {
    private let interactor: CardioFitnessInteractor
    private let router: CardioFitnessRouter

    var selectedCardioFitness: CardioFitnessLevel?
        
    var canSubmit: Bool {
        selectedCardioFitness != nil
    }

    init(
        interactor: CardioFitnessInteractor,
        router: CardioFitnessRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onContinuePressed(delegate: CardioFitnessDelegate) {
        guard let cardioFitness = selectedCardioFitness else { return }
        let delegate = ExpenditureDelegate(delegate: delegate, cardioFitnessLevel: cardioFitness)
        interactor.trackEvent(event: Event.navigate)
        router.showExpenditureView(delegate: delegate)
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
            case .navigate: return "CardioFitness_Navigate"
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

enum CardioFitnessLevel: String, CaseIterable, Codable {
    case beginner
    case novice
    case intermediate
    case advanced
    case elite
    
    var description: String {
        switch self {
        case .beginner:
            return String(localized: "Beginner")
        case .novice:
            return String(localized: "Novice")
        case .intermediate:
            return String(localized: "Intermediate")
        case .advanced:
            return String(localized: "Advanced")
        case .elite:
            return String(localized: "Elite")
        }
    }
    
    var detailDescription: String {
        switch self {
        case .beginner:
            return String(localized: "Just starting cardio, gets winded easily, low endurance")
        case .novice:
            return String(localized: "Some cardio experience, can handle light jogging, moderate endurance")
        case .intermediate:
            return String(localized: "Regular cardio, comfortable running, good endurance")
        case .advanced:
            return String(localized: "Experienced runner, high endurance, can maintain pace")
        case .elite:
            return String(localized: "Athlete level, exceptional endurance, competitive fitness")
        }
    }
}
