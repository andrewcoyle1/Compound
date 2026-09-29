//
//  DietPlanPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class DietPlanPresenter {
    private let interactor: DietPlanInteractor
    private let router: DietPlanRouter

    private(set) var plan: DietPlan?
    var trainingProgramName: String?
    var trainingDaysPerWeek: Int?
    private var isFromSettings: Bool = false
    
    init(
        interactor: DietPlanInteractor,
        router: DietPlanRouter
    ) {
        self.interactor = interactor
        self.router = router

    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    func createPlan(delegate: DietPlanDelegate) {
        isFromSettings = delegate.isFromSettings
        plan = interactor.computeDietPlan(user: currentUser, delegate: delegate)
    }
    
    func navigate() {
        guard let plan = plan else { return }
        router.showLoadingModal()

        Task {
            interactor.trackEvent(event: Event.saveDietPlanStart)
            do {
                try await interactor.saveDietPlan(plan)
                interactor.trackEvent(event: Event.saveDietPlanSuccess)
                interactor.trackEvent(event: Event.navigate)
                if isFromSettings {
                    router.dismissScreen()
                } else {
                    router.showStravaConnectView()
                }
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to update your profile"), subtitle: String(localized: "Please check your internet connection and try again"))
                interactor.trackEvent(event: Event.saveDietPlanFail(error: error))
            }
            router.dismissModal()
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case saveDietPlanStart
        case saveDietPlanSuccess
        case saveDietPlanFail(error: Error)
        case navigate

        var eventName: String {
            switch self {
            case .saveDietPlanStart:            return "DietView_SaveDietPlan_Start"
            case .saveDietPlanSuccess:          return "DietView_SaveDietPlan_Success"
            case .saveDietPlanFail:             return "DietView_SaveDietPlan_Fail"
            case .navigate:                     return "DietView_Navigate"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveDietPlanFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveDietPlanFail:
                return .severe
            case .navigate:
                return .info
            default:
                return .analytic
                
            }
        }
    }
}
