//
//  DietPlanPresenter.swift
//  Compound
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
    /// The formula's resting calories, set with the plan, when some day's target is below them.
    private(set) var restingKcalAboveTarget: Double?
    var mesocycleName: String?
    var trainingDaysPerWeek: Int?
    private var isFromSettings: Bool = false
    
    init(
        interactor: DietPlanInteractor,
        router: DietPlanRouter
    ) {
        self.interactor = interactor
        self.router = router

    }

    func onViewAppear(isFromSettings: Bool) {
        interactor.trackScreenEvent(event: Event.onAppear(isOnboarding: !isFromSettings))
    }

    func onViewDisappear(isFromSettings: Bool) {
        interactor.trackEvent(event: Event.onDisappear(isOnboarding: !isFromSettings))
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    func createPlan(delegate: DietPlanDelegate) {
        isFromSettings = delegate.isFromSettings
        let plan = interactor.computeDietPlan(user: currentUser, delegate: delegate)
        self.plan = plan
        let resting = interactor.estimateRestingKcal(user: currentUser)
        let lowestDay = plan.days.map(\.calories).min() ?? 0
        restingKcalAboveTarget = resting.isFinite && lowestDay > 0 && lowestDay < resting ? resting : nil
    }

    /// The floor this user's plan is held to, which depends on sex. Plans saved with the removed
    /// 800 kcal option store "low" and get the standard floor, so the figure is shown, not the name.
    var calorieFloorText: String {
        Format.kcal(CalorieFloor.standard.minimumValue(for: currentUser?.submittedGender))
    }

    /// Said when a day's target is under the estimated resting rate: allowed, since it is above the
    /// floor, but a steep deficit worth knowing about. Compound's own warning, not a clinical rule.
    var belowRestingWarningText: String? {
        guard let resting = restingKcalAboveTarget else { return nil }
        return String(localized: "Some days' targets are below your estimated resting calories (\(Format.kcal(resting))). That's a steep deficit: a slower rate is easier to sustain and keeps more muscle.")
    }
    
    func navigate() {
        guard let plan = plan else { return }
        router.showLoadingModal()

        Task {
            interactor.trackEvent(event: Event.saveDietPlanStart)
            do {
                try await interactor.saveDietPlan(plan)
                interactor.trackEvent(event: Event.saveDietPlanSuccess)
                if !isFromSettings {
                    // The plan is the last answer, so onboarding finishes here, as
                    // `OnboardingCompletedPresenter` does, rather than on a screen with one more
                    // button. That screen stays for a profile that resumes at `.complete`.
                    try await interactor.saveOnboardingComplete()
                    interactor.playHaptic(option: .success)
                }
                interactor.trackEvent(event: Event.navigate)
                if isFromSettings {
                    router.dismissScreen()
                } else {
                    // Strava is no longer offered here (decision 11d): it is in Profile > Integrations.
                    router.switchToCoreModule()
                }
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to update your profile"), subtitle: String(localized: "Please check your internet connection and try again"))
                interactor.trackEvent(event: Event.saveDietPlanFail(error: error))
            }
            router.dismissModal()
        }
    }

    enum Event: LoggableEvent {
        /// `isOnboarding` is false when the step was opened after onboarding, from Settings, Profile
        /// or Progress, so the onboarding funnel can leave those visits out.
        case onAppear(isOnboarding: Bool)
        case onDisappear(isOnboarding: Bool)
        case saveDietPlanStart
        case saveDietPlanSuccess
        case saveDietPlanFail(error: Error)
        case navigate

        var eventName: String {
            switch self {
            case .onAppear: return "DietPlanView_Appear"
            case .onDisappear: return "DietPlanView_Disappear"
            case .saveDietPlanStart:            return "DietView_SaveDietPlan_Start"
            case .saveDietPlanSuccess:          return "DietView_SaveDietPlan_Success"
            case .saveDietPlanFail:             return "DietView_SaveDietPlan_Fail"
            case .navigate:                     return "DietView_Navigate"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let isOnboarding), .onDisappear(let isOnboarding):
                return ["is_onboarding": isOnboarding]
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
