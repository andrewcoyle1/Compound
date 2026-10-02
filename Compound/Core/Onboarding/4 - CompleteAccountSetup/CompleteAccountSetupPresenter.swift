//
//  CompleteAccountSetupPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CompleteAccountSetupPresenter {
    private let interactor: CompleteAccountSetupInteractor
    private let router: CompleteAccountSetupRouter

    init(
        interactor: CompleteAccountSetupInteractor,
        router: CompleteAccountSetupRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func handleNavigation() {
        interactor.trackEvent(event: Event.navigate)
        router.showNamePhotoView()
    }

    enum Event: LoggableEvent {
        
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "CompleteAccountSetup_Navigate"
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
