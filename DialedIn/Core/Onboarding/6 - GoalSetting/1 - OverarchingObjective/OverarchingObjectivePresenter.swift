//
//  OverarchingObjectivePresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class OverarchingObjectivePresenter {
    private let interactor: OverarchingObjectiveInteractor
    private let router: OverarchingObjectiveRouter

    let isStandaloneMode: Bool
    
    var selectedObjective: OverarchingObjective?
        
    var userWeight: Double? {
        interactor.currentUser?.submittedWeightKilograms
    }
    
    var canContinue: Bool { selectedObjective != nil && userWeight != nil }
    
    init(
        interactor: OverarchingObjectiveInteractor,
        router: OverarchingObjectiveRouter,
        isStandaloneMode: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isStandaloneMode = isStandaloneMode
    }
    
    func onContinuePressed() {
        guard let objective = selectedObjective else { return }
        guard let currentWeight = userWeight else { return }
        if objective == .maintain {
            let delegate = GoalSummaryDelegate(overarchingObjective: objective, targetWeight: currentWeight, weightChangeRate: 0)
            interactor.trackEvent(event: Event.navigate)
            router.showGoalSummaryView(delegate: delegate)
        } else {
            let delegate = TargetWeightDelegate(overarchingObjective: objective)
            interactor.trackEvent(event: Event.navigate)
            router.showTargetWeightView(delegate: delegate)
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
            case .navigate: return "OverarchingObjecting_Navigate"
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
            case .navigate: return .info
            }
        }
    }
}

enum OverarchingObjective: Codable, CaseIterable {
    case loseWeight
    case maintain
    case gainWeight
    
    var description: String {
        switch self {
        case .loseWeight:
            String(localized: "Lose weight")
        case .maintain:
            String(localized: "Maintain")
        case .gainWeight:
            String(localized: "Gain weight")
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .loseWeight:
            String(localized: "Goal of losing weight")
        case .maintain:
            String(localized: "Goal of maintaining weight")
        case .gainWeight:
            String(localized: "Goal of gaining weight")
        }
    }
}
