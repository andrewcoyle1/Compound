//
//  ProteinIntakePresenter.swift
//  Compound
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
    var hasMesocycle: Bool = false

    /// Picking an option row: record it and give the selection tick.
    func onProteinIntakeSelected(_ value: ProteinIntake) {
        selectedProteinIntake = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: ProteinIntakeInteractor,
        router: ProteinIntakeRouter
    ) {
        self.interactor = interactor
        self.router = router
        // Opens on the current plan's answer when rebuilding it, otherwise on the recommendation.
        selectedProteinIntake = interactor.currentDietPlan.flatMap { ProteinIntake(rawValue: $0.proteinIntake) } ?? .moderate
    }

    func onViewAppear(isFromSettings: Bool) {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isFromSettings))
    }

    func onViewDisappear(isFromSettings: Bool) {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isFromSettings))
    }
    
    func onContinuePressed(delegate oldDelegate: ProteinIntakeDelegate) {
        if let proteinIntake = selectedProteinIntake {
            let delegate = DietPlanDelegate(oldDelegate: oldDelegate, proteinIntake: proteinIntake)
            interactor.trackEvent(event: Event.navigate)
            router.showDietPlanView(delegate: delegate)
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
            case .onAppear: return "ProteinIntakeView_Appear"
            case .onDisappear: return "ProteinIntakeView_Disappear"
            case .navigate: return "Onboarding_ProteinIntake_Navigate"
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
            return String(localized: "1.6 g per kg a day: where the benefit for muscle levels off for most people.")
        case .moderate:
            return String(localized: "2.0 g per kg a day: a margin above that for people who train hard.")
        case .high:
            return String(localized: "2.2 g per kg a day: the top of the range studies support for building muscle.")
        case .veryHigh:
            return String(localized: "2.6 g per kg a day: for lean lifters cutting hard. No guideline recommends this much for everyone.")
        }
    }
}
