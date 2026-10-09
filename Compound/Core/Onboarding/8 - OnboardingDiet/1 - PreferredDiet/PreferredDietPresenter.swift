//
//  PreferredDietPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class PreferredDietPresenter {
    private let interactor: PreferredDietInteractor
    private let router: PreferredDietRouter

    var selectedDiet: PreferredDiet?
    private(set) var isFromSettings: Bool = false

    /// Picking an option row: record it and give the selection tick.
    func onDietSelected(_ value: PreferredDiet) {
        selectedDiet = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: PreferredDietInteractor,
        router: PreferredDietRouter,
        isFromSettings: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isFromSettings = isFromSettings
        // Opens on the current plan's answer when rebuilding it, otherwise on the recommendation.
        selectedDiet = interactor.currentDietPlan.flatMap { PreferredDiet(rawValue: $0.preferredDiet) } ?? .balanced
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isFromSettings))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isFromSettings))
    }

    func navigateToCalorieFloor() {
        if let diet = selectedDiet {
            let delegate = CalorieFloorDelegate(preferredDiet: diet, isFromSettings: isFromSettings)
            interactor.trackEvent(event: Event.navigate)
            if isFromSettings {
                router.showCalorieFloorView(delegate: delegate)
            } else {
                // Onboarding applies the standard floor without asking (decision 3b): it is the only
                // floor (1,200 kcal for women, 1,500 for men, 1,350 unstated), so there is nothing to
                // choose. Settings still shows the step, to explain the floor.
                router.showCalorieDistributionView(delegate: CalorieDistributionDelegate(delegate: delegate, calorieFloor: .standard))
            }
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
            case .onAppear: return "PreferredDietView_Appear"
            case .onDisappear: return "PreferredDietView_Disappear"
            case .navigate: return "Onboarding_PrefDiet_Navigate"
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

enum PreferredDiet: String, CaseIterable, Identifiable {
    case balanced
    case lowFat
    case lowCarb
    case keto

    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .balanced:
            return String(localized: "Balanced")
        case .lowFat:
            return String(localized: "Low Fat")
        case .lowCarb:
            return String(localized: "Low Carb")
        case .keto:
            return String(localized: "Keto")
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .balanced:
            return String(localized: "30% of calories from fat, with carbs making up the rest.")
        case .lowFat:
            return String(localized: "20% of calories from fat, the lowest guidelines advise, so more carbs.")
        case .lowCarb:
            return String(localized: "20% of calories from carbs, with fat making up the rest.")
        case .keto:
            return String(localized: "About 30 g of carbs a day, with fat making up the rest.")
        }
    }
}
