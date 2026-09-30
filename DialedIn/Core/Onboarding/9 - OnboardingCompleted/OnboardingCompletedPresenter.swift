//
//  OnboardingCompletedPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Foundation

@Observable
@MainActor
class OnboardingCompletedPresenter {
    private let interactor: OnboardingCompletedInteractor
    private let router: OnboardingCompletedRouter

    private(set) var isCompletingProfileSetup: Bool = false

    init(
        interactor: OnboardingCompletedInteractor,
        router: OnboardingCompletedRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onFinishButtonPressed() {
        isCompletingProfileSetup = true
        interactor.trackEvent(event: Event.finishStart)

        Task {
            do {
                try await interactor.saveOnboardingComplete()
                interactor.trackEvent(event: Event.finishSuccess)
                interactor.playHaptic(option: .success)
                isCompletingProfileSetup = false
                router.switchToCoreModule()
            } catch {
                // The Continue button is disabled on this flag, so leaving it set after a failed
                // save left the last screen of onboarding with no working way forward.
                isCompletingProfileSetup = false
                interactor.playHaptic(option: .error)
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.finishFail(error: error))
            }
        }
    }

    enum Event: LoggableEvent {
        case finishStart
        case finishSuccess
        case finishFail(error: Error)

        var eventName: String {
            switch self {
            case .finishStart:   return "OnboardingCompletedView_Finish_Start"
            case .finishSuccess: return "OnboardingCompletedView_Finish_Success"
            case .finishFail:    return "OnboardingCompletedView_Finish_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .finishFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .finishFail:
                return .severe
            default:
                return .analytic

            }
        }
    }
}
