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
    /// The goal being edited; nil when setting one. Its figures start every step of the flow.
    let editingGoal: WeightGoal?
    
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
        isStandaloneMode: Bool = false,
        editingGoal: WeightGoal? = nil
    ) {
        self.interactor = interactor
        self.router = router
        self.isStandaloneMode = isStandaloneMode
        self.editingGoal = editingGoal
        self.selectedObjective = editingGoal?.objective
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isStandaloneMode))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isStandaloneMode))
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
                isStandaloneMode: isStandaloneMode,
                editingGoal: editingGoal
            )
            interactor.trackEvent(event: Event.navigate)
            router.showGoalSummaryView(delegate: delegate)
        } else {
            let delegate = TargetWeightDelegate(overarchingObjective: objective, isStandaloneMode: isStandaloneMode, editingGoal: editingGoal)
            interactor.trackEvent(event: Event.navigate)
            router.showTargetWeightView(delegate: delegate)
        }
    }

    enum Event: LoggableEvent {
        /// `isOnboarding` is false when the step was opened after onboarding, from Settings, Profile
        /// or Progress, so the onboarding funnel can leave those visits out.
        case onAppear(isOnboarding: Bool)
        case onDisappear(isOnboarding: Bool)
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
            case .onAppear(let isOnboarding), .onDisappear(let isOnboarding):
                return ["is_onboarding": isOnboarding]
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
