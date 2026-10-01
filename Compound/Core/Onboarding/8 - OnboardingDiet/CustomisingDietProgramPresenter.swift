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
    
    enum Event: LoggableEvent {
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "Onboarding_CustProgram_Navigate"
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
            case .navigate:
                return .info
            }
        }
    }
}
