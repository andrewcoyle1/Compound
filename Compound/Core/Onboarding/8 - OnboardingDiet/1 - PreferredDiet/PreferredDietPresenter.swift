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
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func navigateToCalorieFloor() {
        if let diet = selectedDiet {
            let delegate = CalorieFloorDelegate(preferredDiet: diet, isFromSettings: isFromSettings)
            interactor.trackEvent(event: Event.navigate)
            if isFromSettings {
                router.showCalorieFloorView(delegate: delegate)
            } else {
                // Onboarding applies the standard 1,200 kcal floor without asking (decision 3b):
                // the 800 kcal floor is offered only from settings, which leaves this step one option.
                router.showCalorieDistributionView(delegate: CalorieDistributionDelegate(delegate: delegate, calorieFloor: .standard))
            }
        }
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
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
            return String(localized: "Standard distribution of carbs and fat.")
        case .lowFat:
            return String(localized: "Fat will be reduced to prioritize carb and protein intake.")
        case .lowCarb:
            return String(localized: "Carbs will be reduced to prioritize fat and protein intake.")
        case .keto:
            return String(localized: "Carbs will be very restricted to allow for higher fat intake.")
        }
    }
}
