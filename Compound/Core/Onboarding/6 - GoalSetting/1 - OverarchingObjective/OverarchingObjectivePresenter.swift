//
//  OverarchingObjectivePresenter.swift
//  Compound
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
        interactor.currentWeightKilograms
    }
    
    var canContinue: Bool { selectedObjective != nil && userWeight != nil }

    /// Picking an option row: record it and give the selection tick.
    func onObjectiveSelected(_ value: OverarchingObjective) {
        selectedObjective = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: OverarchingObjectiveInteractor,
        router: OverarchingObjectiveRouter,
        isStandaloneMode: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isStandaloneMode = isStandaloneMode
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onDismissPressed() {
        router.dismissEnvironment()
    }

    func onContinuePressed() {
        guard let objective = selectedObjective else { return }
        guard let currentWeight = userWeight else { return }
        if objective == .maintain {
            let delegate = GoalSummaryDelegate(
                overarchingObjective: objective,
                targetWeight: currentWeight,
                weightChangeRate: 0,
                isStandaloneMode: isStandaloneMode
            )
            interactor.trackEvent(event: Event.navigate)
            router.showGoalSummaryView(delegate: delegate)
        } else {
            let delegate = TargetWeightDelegate(overarchingObjective: objective, isStandaloneMode: isStandaloneMode)
            interactor.trackEvent(event: Event.navigate)
            router.showTargetWeightView(delegate: delegate)
        }
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case navigate

        var eventName: String {
            switch self {
            case .onAppear: return "OverarchingObjectiveView_Appear"
            case .onDisappear: return "OverarchingObjectiveView_Disappear"
            case .navigate: return "OverarchingObjecting_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear, .onDisappear:
                return nil
            case .navigate:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onAppear, .onDisappear:
                return .analytic
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
