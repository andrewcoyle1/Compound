//
//  GoalSettingPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class GoalSettingPresenter {
    private let interactor: GoalSettingInteractor
    private let router: GoalSettingRouter
    
    init(
        interactor: GoalSettingInteractor,
        router: GoalSettingRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onContinuePressed() {
        interactor.trackEvent(event: Event.navigate)
        router.showOverarchingObjectiveView()
    }

    enum Event: LoggableEvent {
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "GoalSetting_Navigate"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default: return nil
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
