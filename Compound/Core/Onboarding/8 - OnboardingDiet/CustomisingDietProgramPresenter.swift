//
//  CustomisingDietProgramPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CustomisingDietProgramPresenter {
    private let interactor: CustomisingDietProgramInteractor
    private let router: CustomisingDietProgramRouter

    init(
        interactor: CustomisingDietProgramInteractor,
        router: CustomisingDietProgramRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func navigateToPreferredDiet() {
        interactor.trackEvent(event: Event.navigate)
        router.showPreferredDietView()
    }

    /// Skips the four questions with the answer each one would open on: a balanced diet, the
    /// standard floor, the split the mesocycle suggests, and moderate protein.
    func onUseRecommendedPlanPressed() {
        interactor.trackEvent(event: Event.useRecommended)
        router.showDietPlanView(delegate: DietPlanDelegate(
            preferredDiet: .balanced,
            calorieFloor: .standard,
            calorieDistribution: .recommended(for: interactor.activeMesocycle),
            proteinIntake: .moderate,
            isFromSettings: false
        ))
    }

    enum Event: LoggableEvent {
        case navigate
        case useRecommended

        var eventName: String {
            switch self {
            case .navigate: return "Onboarding_CustProgram_Navigate"
            case .useRecommended: return "Onboarding_CustProgram_UseRecommended"
            }
        }
        
        var parameters: [String: Any]? {
            nil
        }
        
        var type: LogType {
            .info
        }
    }
}
