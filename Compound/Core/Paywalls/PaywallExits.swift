//
//  PaywallExits.swift
//  Compound
//
//  The way out for someone who will not subscribe (decision 1). The app stays subscription-only,
//  but "Why Subscribe?" and the onboarding paywall offer Sign Out, and Account, which reaches
//  Delete Account, so nobody is held at the paywall with an account they cannot leave or delete.
//

@MainActor
protocol PaywallExitsInteractor: GlobalInteractor {
    func signOut() async throws
}

@MainActor
protocol PaywallExitsRouter: GlobalRouter {
    func showAccountView(delegate: AccountDelegate)
    func switchToOnboardingModule()
}

@MainActor
struct PaywallExits {
    let interactor: PaywallExitsInteractor
    let router: PaywallExitsRouter
    /// The screen's analytics prefix, such as "PaywallView".
    let screenName: String

    func onAccountPressed() {
        interactor.trackEvent(eventName: "\(screenName)_Account_Press", parameters: nil, type: .analytic)
        router.showAccountView(delegate: AccountDelegate())
    }

    /// Signs out and starts onboarding again from Welcome.
    func onSignOutPressed() {
        interactor.trackEvent(eventName: "\(screenName)_SignOut_Start", parameters: nil, type: .analytic)
        Task {
            do {
                try await interactor.signOut()
                interactor.trackEvent(eventName: "\(screenName)_SignOut_Success", parameters: nil, type: .analytic)
                router.switchToOnboardingModule()
            } catch {
                interactor.trackEvent(eventName: "\(screenName)_SignOut_Fail", parameters: error.eventParameters, type: .severe)
                router.showAlert(title: String(localized: "Unable to Sign Out"), error: error)
            }
        }
    }
}

extension CoreInteractor: PaywallExitsInteractor { }
extension CoreRouter: PaywallExitsRouter { }
