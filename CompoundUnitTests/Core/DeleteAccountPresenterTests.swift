//
//  DeleteAccountPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import AuthenticationServices
@testable import Compound

/// The screen that confirms account deletion. It replaced an alert, and inherits that alert's
/// tests: nothing is destroyed until the person confirms, and a failure leaves them in the account.
/// New here: closing the sign-in sheet is not an error, and success says so before leaving.
@MainActor
struct DeleteAccountPresenterTests {

    private final class Interactor: SpyGlobalInteractor, DeleteAccountInteractor {
        var auth: UserAuthInfo?
        var deleteAccountError: Error?
        private(set) var didDeleteAccount = false

        func deleteAccount() async throws {
            if let deleteAccountError { throw deleteAccountError }
            didDeleteAccount = true
        }
    }

    private final class Router: DeleteAccountRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didSwitchToOnboarding = false
        private(set) var alertTitles: [String] = []

        func switchToOnboardingModule() { didSwitchToOnboarding = true }
        func showAlert(title: String, error: Error) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: DeleteAccountPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(isAnonymous: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.auth = UserAuthInfo(uid: "user-1", isAnonymous: isAnonymous, authProviders: isAnonymous ? [] : [.apple])
        let router = Router()
        return Screen(presenter: DeleteAccountPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    @Test("Test Opening The Screen Deletes Nothing")
    func testOpeningTheScreenDeletesNothing() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(!screen.interactor.didDeleteAccount)
        #expect(!screen.presenter.isDeleted)
        #expect(screen.interactor.trackedScreenEventNames == ["DeleteAccountView_Appear"])
    }

    /// Success says "Account deleted" and waits for Done; it used to switch to onboarding a second
    /// later with no word that it had worked. The funnel's event names are the alert's.
    @Test("Test Confirming Deletes The Account And Says So Before Leaving")
    func testConfirmingDeletesTheAccountAndSaysSoBeforeLeaving() async {
        let screen = makeScreen()

        screen.presenter.onDeletePressed()
        #expect(await TestManagers.eventually { screen.presenter.isDeleted })

        #expect(screen.interactor.didDeleteAccount)
        #expect(!screen.presenter.isDeleting)
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(screen.interactor.trackedEventNames == ["Settings_DeleteAccount_StartConfirm", "Settings_DeleteAccount_Success"])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])

        screen.presenter.onDonePressed()
        #expect(await TestManagers.eventually { screen.router.didSwitchToOnboarding })
    }

    /// Closing Apple's or Google's sign-in sheet keeps the account, and is not an error.
    @Test("Test Cancelling The Sign In Keeps The Account Without An Error")
    func testCancellingTheSignInKeepsTheAccountWithoutAnError() async {
        let screen = makeScreen()
        screen.interactor.deleteAccountError = ASAuthorizationError(.canceled)

        screen.presenter.onDeletePressed()
        #expect(await TestManagers.eventually { !screen.presenter.isDeleting })

        #expect(screen.router.alertTitles.isEmpty)
        #expect(screen.interactor.playedHaptics.isEmpty)
        #expect(!screen.presenter.isDeleted)
        #expect(screen.interactor.trackedEventNames.last == "Settings_DeleteAccount_Cancelled")
    }

    /// The account still exists after a failure, so the person stays in it and is told.
    @Test("Test A Failed Deletion Leaves The Person In Their Account")
    func testAFailedDeletionLeavesThePersonInTheirAccount() async {
        let screen = makeScreen()
        screen.interactor.deleteAccountError = URLError(.networkConnectionLost)

        screen.presenter.onDeletePressed()
        #expect(await TestManagers.eventually { !screen.presenter.isDeleting })

        #expect(screen.router.alertTitles == ["Unable to Delete Account"])
        #expect(!screen.presenter.isDeleted)
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(screen.interactor.trackedEventNames.last == "Settings_DeleteAccount_Fail")
    }

    @Test("Test Only Signed In Accounts Are Told They Will Sign In Again")
    func testOnlySignedInAccountsAreToldTheyWillSignInAgain() {
        #expect(makeScreen().presenter.asksToSignInAgain)
        #expect(!makeScreen(isAnonymous: true).presenter.asksToSignInAgain)
    }

    @Test("Test Manage Subscription Opens Apple's Sheet")
    func testManageSubscriptionOpensApplesSheet() {
        let screen = makeScreen()

        screen.presenter.onManageSubscriptionPressed()

        #expect(screen.presenter.isManageSubscriptionsPresented)
        #expect(screen.interactor.trackedEventNames == ["DeleteAccountView_ManageSubscription_Press"])
    }
}

/// Which errors mean the person closed a sign-in sheet.
struct SignInCancellationTests {

    @Test("Test Closing A Sign In Sheet Counts As Cancelling")
    func testClosingASignInSheetCountsAsCancelling() {
        #expect(SignInCancellation.isCancellation(ASAuthorizationError(.canceled)))
        #expect(SignInCancellation.isCancellation(ASWebAuthenticationSessionError(.canceledLogin)))
        #expect(SignInCancellation.isCancellation(NSError(domain: "com.google.GIDSignIn", code: -5)))
        #expect(SignInCancellation.isCancellation(CancellationError()))
    }

    @Test("Test A Real Failure Is Not A Cancellation")
    func testARealFailureIsNotACancellation() {
        #expect(!SignInCancellation.isCancellation(ASAuthorizationError(.failed)))
        #expect(!SignInCancellation.isCancellation(URLError(.notConnectedToInternet)))
        #expect(!SignInCancellation.isCancellation(NSError(domain: "com.google.GIDSignIn", code: -4)))
    }
}
