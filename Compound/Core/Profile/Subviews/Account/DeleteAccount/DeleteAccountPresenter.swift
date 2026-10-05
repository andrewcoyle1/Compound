//
//  DeleteAccountPresenter.swift
//  Compound
//
//  The confirmation screen that replaced the "Delete Account?" alert. The alert said nothing about
//  the subscription Apple keeps billing, the sign-in that follows the tap, or when the rest of the
//  data goes, then switched to onboarding with no word that it had worked.
//

import SwiftUI

@Observable
@MainActor
class DeleteAccountPresenter {

    private let interactor: DeleteAccountInteractor
    private let router: DeleteAccountRouter

    private(set) var isDeleting: Bool = false
    /// Deletion finished: the screen says so, and Done leaves for onboarding.
    private(set) var isDeleted: Bool = false
    /// Apple's Manage Subscriptions sheet. Bound by the view.
    var isManageSubscriptionsPresented: Bool = false

    /// Apple and Google accounts sign in again before deletion; an anonymous one has nothing to
    /// sign in with.
    var asksToSignInAgain: Bool {
        interactor.auth?.isAnonymous == false
    }

    init(interactor: DeleteAccountInteractor, router: DeleteAccountRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onManageSubscriptionPressed() {
        interactor.trackEvent(event: Event.manageSubscriptionPressed)
        isManageSubscriptionsPresented = true
    }

    func onDeletePressed() {
        guard !isDeleting, !isDeleted else { return }
        interactor.trackEvent(event: Event.deleteAccountStartConfirm)
        isDeleting = true
        router.showLoadingModal()

        Task {
            defer { isDeleting = false }
            do {
                try await interactor.deleteAccount()
                router.dismissModal()
                interactor.trackEvent(event: Event.deleteAccountSuccess)
                interactor.playHaptic(option: .success)
                isDeleted = true
            } catch where SignInCancellation.isCancellation(error) {
                // Closing the sign-in sheet keeps the account; nothing went wrong.
                router.dismissModal()
                interactor.trackEvent(event: Event.deleteAccountCancelled)
            } catch {
                router.dismissModal()
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Delete Account"), error: error)
                interactor.trackEvent(event: Event.deleteAccountFail(error: error))
            }
        }
    }

    /// Leaves the deleted account for onboarding, after the person has read that it is gone.
    func onDonePressed() {
        router.dismissEnvironment()
        Task {
            try? await Task.sleep(for: .seconds(1))
            router.switchToOnboardingModule()
        }
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case manageSubscriptionPressed
        case deleteAccountStartConfirm
        case deleteAccountSuccess
        case deleteAccountCancelled
        case deleteAccountFail(error: Error)

        /// The three `Settings_DeleteAccount_*` names are the ones the alert logged, kept so the
        /// deletion funnel carries on.
        var eventName: String {
            switch self {
            case .onAppear:                     return "DeleteAccountView_Appear"
            case .onDisappear:                  return "DeleteAccountView_Disappear"
            case .manageSubscriptionPressed:    return "DeleteAccountView_ManageSubscription_Press"
            case .deleteAccountStartConfirm:    return "Settings_DeleteAccount_StartConfirm"
            case .deleteAccountSuccess:         return "Settings_DeleteAccount_Success"
            case .deleteAccountCancelled:       return "Settings_DeleteAccount_Cancelled"
            case .deleteAccountFail:            return "Settings_DeleteAccount_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteAccountFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteAccountFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
