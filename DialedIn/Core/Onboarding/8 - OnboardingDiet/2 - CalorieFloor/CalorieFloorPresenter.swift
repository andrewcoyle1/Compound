//
//  CalorieFloorPresenter.swift
//  DialedIn
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

    init(
        interactor: CalorieFloorInteractor,
        router: CalorieFloorRouter
    ) {
        self.interactor = interactor
        self.router = router
        prefillCalorieFloor()
    }

    /// `loadTrainingContext()` used to be called here and was empty, so `prefillCalorieFloor` — which
    /// it was the only caller of — never ran and the screen opened with nothing selected. Its two
    /// properties, `trainingDaysPerWeek` and `hasTrainingPlan`, were written by nothing and read by
    /// nothing, and its own comment recorded that every training volume mapped to `.standard` anyway.
    /// So this is what it did, minus the parameter that changed nothing.
    private func prefillCalorieFloor() {
        guard selectedFloor == nil else { return }
        selectedFloor = .standard
        interactor.trackEvent(event: Event.calorieFloorPrefilled(floor: .standard, reason: "default"))
    }
    
    func onContinuePressed(delegate oldDelegate: CalorieFloorDelegate) {
        guard let floor = selectedFloor else { return }
        let delegate = CalorieDistributionDelegate(delegate: oldDelegate, calorieFloor: floor)
        interactor.trackEvent(event: Event.navigate())
        router.showCalorieDistributionView(delegate: delegate)
        
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case calorieFloorPrefilled(floor: CalorieFloor, reason: String)
        case navigate(skipReason: String? = nil)

        var eventName: String {
            switch self {
            case .calorieFloorPrefilled: return "Onboarding_CalFloor_Prefilled"
            case .navigate: return "Onboarding_CalFloor_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
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
            case .navigate, .calorieFloorPrefilled:
                return .info
            }
        }
    }
}

enum CalorieFloor: String, CaseIterable, Identifiable {
    case standard
    case low
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .standard:
            return String(localized: "Standard Floor (Recommended)")
        case .low:
            return String(localized: "Low Floor")
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .standard:
            return String(localized: "Your recommendations will never go below 1200 calories per day, even if your TDEE is lower.")
        case .low:
            return String(localized: "Your recommendations will never go below 800 calories per day. Proceed with caution.")
        }
    }
}
