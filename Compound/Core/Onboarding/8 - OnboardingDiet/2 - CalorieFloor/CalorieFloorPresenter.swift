//
//  CalorieFloorPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CalorieFloorPresenter {
    private let interactor: CalorieFloorInteractor
    private let router: CalorieFloorRouter

    var selectedFloor: CalorieFloor?

    /// Picking an option row: record it and give the selection tick.
    func onFloorSelected(_ value: CalorieFloor) {
        selectedFloor = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: CalorieFloorInteractor,
        router: CalorieFloorRouter
    ) {
        self.interactor = interactor
        self.router = router
        prefillCalorieFloor()
    }

    func onViewAppear(isFromSettings: Bool) {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isFromSettings))
    }

    func onViewDisappear(isFromSettings: Bool) {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isFromSettings))
    }

    /// `loadTrainingContext()` used to be called here and was empty, so `prefillCalorieFloor` — which
    /// it was the only caller of — never ran and the screen opened with nothing selected. Its two
    /// properties, `trainingDaysPerWeek` and `hasMesocycle`, were written by nothing and read by
    /// nothing, and its own comment recorded that every training volume mapped to `.standard` anyway.
    /// So this is what it did, minus the parameter that changed nothing.
    private func prefillCalorieFloor() {
        guard selectedFloor == nil else { return }
        // Rebuilding a plan opens on the floor it was built with.
        if let current = interactor.currentDietPlan.flatMap({ CalorieFloor(rawValue: $0.calorieFloor) }) {
            selectedFloor = current
            interactor.trackEvent(event: Event.calorieFloorPrefilled(floor: current, reason: "current_plan"))
            return
        }
        selectedFloor = .standard
        interactor.trackEvent(event: Event.calorieFloorPrefilled(floor: .standard, reason: "default"))
    }
    
    func onContinuePressed(delegate oldDelegate: CalorieFloorDelegate) {
        guard let floor = selectedFloor else { return }
        let delegate = CalorieDistributionDelegate(delegate: oldDelegate, calorieFloor: floor)
        interactor.trackEvent(event: Event.navigate())
        router.showCalorieDistributionView(delegate: delegate)
        
    }

    enum Event: LoggableEvent {
        /// `isOnboarding` is false when the step was opened after onboarding, from Settings, Profile
        /// or Progress, so the onboarding funnel can leave those visits out.
        case onAppear(isOnboarding: Bool)
        case onDisappear(isOnboarding: Bool)
        case calorieFloorPrefilled(floor: CalorieFloor, reason: String)
        case navigate(skipReason: String? = nil)

        var eventName: String {
            switch self {
            case .onAppear: return "CalorieFloorView_Appear"
            case .onDisappear: return "CalorieFloorView_Disappear"
            case .calorieFloorPrefilled: return "Onboarding_CalFloor_Prefilled"
            case .navigate: return "Onboarding_CalFloor_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let isOnboarding), .onDisappear(let isOnboarding):
                return ["is_onboarding": isOnboarding]
            case .calorieFloorPrefilled(floor: let floor, reason: let reason):
                return ["floor": floor.rawValue, "reason": reason]
            case .navigate(skipReason: let skipReason):
                var params: [String: Any] = [:]
                if let skipReason = skipReason {
                    params["skipReason"] = skipReason
                }
                return params
            }
        }

        var type: LogType {
            switch self {
            case .onAppear, .onDisappear:
                return .analytic
            case .navigate, .calorieFloorPrefilled:
                return .info
            }
        }
    }
}

/// One floor, set by sex (`CalorieFloor.minimumValue(for:)`): 1,200 kcal for women, 1,500 for men
/// and 1,350 when sex is not given, the bottom of the AHA/ACC/TOS prescription ranges.
///
/// There used to be an 800 kcal `low` option. Diets at or under 800 kcal are very-low-calorie
/// diets, which are run under medical supervision (NIDDK; NICE NG246), so it was removed. Plans
/// saved with it store "low", which no longer decodes to a case: every reader falls back to
/// `.standard` (`CalorieFloor(rawValue:) ?? .standard`), so those plans get the standard floor.
enum CalorieFloor: String, CaseIterable, Identifiable {
    case standard

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard:
            return String(localized: "Standard Floor")
        }
    }

    var detailedDescription: String {
        switch self {
        case .standard:
            return String(localized: "Your daily target never goes below 1,200 calories for women or 1,500 for men (1,350 if you'd rather not say), even if your expenditure is lower.")
        }
    }
}
