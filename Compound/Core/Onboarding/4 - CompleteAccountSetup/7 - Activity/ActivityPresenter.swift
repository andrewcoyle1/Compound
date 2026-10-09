//
//  ActivityPresenter.swift
//  Compound
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

    /// Picking an option row: record it and give the selection tick.
    func onActivityLevelSelected(_ value: ActivityLevel) {
        selectedActivityLevel = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: ActivityInteractor,
        router: ActivityRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onContinuePressed(delegate: ActivityDelegate) {
        guard let activityLevel = selectedActivityLevel else { return }
        let delegate = ExpenditureDelegate(delegate: delegate, activityLevel: activityLevel)
        interactor.trackEvent(event: Event.navigate)
        router.showExpenditureView(delegate: delegate)
    }
    
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case navigate

        var eventName: String {
            switch self {
            case .onAppear: return "ActivityView_Appear"
            case .onDisappear: return "ActivityView_Disappear"
            case .navigate: return "ActivityLevel_Navigate"
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
            return String(localized: "Desk job, minimal walking, little or no exercise")
        case .light:
            return String(localized: "Light walking and some daily activity, or a desk job with a few workouts a week")
        case .moderate:
            return String(localized: "Regular walking or standing work, with regular workouts")
        case .active:
            return String(localized: "Active lifestyle or manual work, plus training")
        case .veryActive:
            return String(localized: "Physically demanding work or hard training most days")
        }
    }
}
