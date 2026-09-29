//
//  PaywallPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

enum PaywallTestError: Error { case failed }

/// The paywall: the one screen where the app takes money, and the one gate between a free user and
/// the rest of the product.
///
/// Two failures matter more than everything else here and both are silent. A paywall that stays up
/// after a successful purchase charges someone and gives them nothing — so every path that ends in
/// money changing hands must move the user on. And a paywall that moves the user on without an
/// active entitlement gives the product away — so "the call returned without throwing" is never
/// enough; the entitlement has to be checked. Both directions are pinned below.
///
/// `dismissEnvironment()` and `dismissScreen()` are `GlobalRouter` extensions, statically
/// dispatched, so a double never sees them. Off onboarding, a successful purchase dismisses the
/// paywall that way and there is nothing to observe — those tests assert that the onboarding
/// routing did *not* happen instead, which is the mistake that would actually hurt.
@MainActor
struct PaywallPurchasePresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, PaywallInteractor {
        var currentUser: UserModel?
        var paywallTest: PaywallTestOption = .custom

        var products: [AnyProduct] = []
        var getProductsError: Error?
        var purchaseError: Error?
        var restoreError: Error?
        var purchaseResult: [PurchasedEntitlement] = []
        var restoreResult: [PurchasedEntitlement] = []

        private(set) var requestedProductIds: [[String]] = []
        private(set) var purchasedProductIds: [String] = []
        private(set) var restoreCount = 0

        func getProducts(productIds: [String]) async throws -> [AnyProduct] {
            requestedProductIds.append(productIds)
            if let getProductsError { throw getProductsError }
            return products
        }

        func restorePurchase() async throws -> [PurchasedEntitlement] {
            restoreCount += 1
            if let restoreError { throw restoreError }
            return restoreResult
        }

        func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement] {
            purchasedProductIds.append(productId)
            if let purchaseError { throw purchaseError }
            return purchaseResult
        }

        private(set) var didSignOut = false
        func signOut() async throws { didSignOut = true }
    }

    /// The three alert methods are protocol requirements with default implementations, so this
    /// double can intercept them — which is what lets the failure tests below assert the user was
    /// actually told something went wrong rather than just left staring at the paywall.
    private final class Router: PaywallRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertedErrors: [Error] = []
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertedErrors.append(error) }
        func showAlert(title: String, error: Error) {
            alertTitles.append(title)
            alertedErrors.append(error)
        }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }

        func showCompleteAccountSetupView() { shown.append("completeAccountSetup") }
        func showHealthDisclaimerView() { shown.append("healthDisclaimer") }
        func showGoalSettingView() { shown.append("goalSetting") }
        func showCreateGymProfileView(delegate: CreateGymProfileDelegate) { shown.append("gymProfileSetup") }
        func showOnboardingTrainingProgramView(delegate: CreateProgramDelegate) { shown.append("trainingProgramSetup") }
        func showCustomisingDietProgramView() { shown.append("customisingDietProgram") }
        func showOnboardingCompletedView() { shown.append("onboardingCompleted") }
        func showAccountView(delegate: AccountDelegate) { shown.append("account") }
        func switchToOnboardingModule() { shown.append("onboardingModule") }
    }

    private struct Screen {
        let presenter: PaywallPresenter
        let interactor: Interactor
        let router: Router
    }

    /// A user who has answered nothing, so `inferredOnboardingStep` is `.completeAccountSetup` and
    /// "was the user moved on?" reads as one unambiguous destination.
    private func makeScreen(
        isOnboarding: Bool = true,
        user: UserModel? = UserModel(userId: "user-1")
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        return Screen(
            presenter: PaywallPresenter(interactor: interactor, router: router, isOnboarding: isOnboarding),
            interactor: interactor,
            router: router
        )
    }

    private func product(_ id: String = "monthly") -> AnyProduct {
        AnyProduct(id: id, title: "Monthly", subtitle: "Billed monthly", priceString: "£4.99", productDuration: .month)
    }

    private func entitlement(active: Bool) -> PurchasedEntitlement {
        PurchasedEntitlement(
            id: "entitlement-1",
            productId: "monthly",
            expirationDate: active ? Date().addingTimeInterval(86_400) : Date(timeIntervalSince1970: 0),
            isActive: active,
            originalPurchaseDate: Date(timeIntervalSince1970: 0),
            latestPurchaseDate: Date(timeIntervalSince1970: 0),
            ownershipType: .purchased,
            isSandbox: true,
            isVerified: true
        )
    }

    // MARK: - What the paywall offers

    /// Nothing can be bought that the store did not return, so the products are the screen.
    @Test("Test The Paywall Shows The Products The Store Returns")
    func testThePaywallShowsTheProductsTheStoreReturns() async {
        let screen = makeScreen()
        screen.interactor.products = [product("monthly"), product("yearly")]

        await screen.presenter.onLoadProducts()

        #expect(screen.presenter.products.map(\.id) == ["monthly", "yearly"])
        // The first plan starts chosen; each card used to need a tap on a "Start" chip first.
        #expect(screen.presenter.selectedProduct?.id == "monthly")
        #expect(screen.presenter.loadErrorMessage == nil)
        #expect(!screen.presenter.isLoadingProducts)
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Load_Success"))
        #expect(screen.interactor.requestedProductIds == [EntitlementOption.allProductIds])
    }

    /// A store that returns nothing is a broken paywall, not an empty one: without a message the
    /// user sees a subscribe screen with nothing to subscribe to and no idea why.
    @Test("Test An Empty Store Response Explains Itself")
    func testAnEmptyStoreResponseExplainsItself() async {
        let screen = makeScreen()
        screen.interactor.products = []

        await screen.presenter.onLoadProducts()

        #expect(screen.presenter.products.isEmpty)
        #expect(screen.presenter.loadErrorMessage != nil)
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Load_Fail"))
        // Nothing was thrown, so nothing is alerted — the message on the screen is the whole report.
        #expect(screen.router.alertedErrors.isEmpty)
    }

    /// A store that fails outright says so on the screen and stops spinning. A paywall stuck
    /// loading forever cannot be bought from or backed out of intelligibly. The screen's error
    /// state is the whole report: an alert on top of it said the same thing twice.
    @Test("Test A Failed Load Stops Spinning And Says Why")
    func testAFailedLoadStopsSpinningAndSaysWhy() async {
        let screen = makeScreen()
        screen.interactor.getProductsError = PaywallTestError.failed

        await screen.presenter.onLoadProducts()

        #expect(!screen.presenter.isLoadingProducts)
        #expect(screen.presenter.loadErrorMessage != nil)
        #expect(screen.router.alertedErrors.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Load_Fail"))
    }

    /// A retry after a failure clears the old message, so a paywall that recovers does not keep
    /// showing the error that no longer applies.
    @Test("Test A Successful Retry Clears The Earlier Error")
    func testASuccessfulRetryClearsTheEarlierError() async {
        let screen = makeScreen()
        screen.interactor.getProductsError = PaywallTestError.failed
        await screen.presenter.onLoadProducts()
        #expect(screen.presenter.loadErrorMessage != nil)

        screen.interactor.getProductsError = nil
        screen.interactor.products = [product()]
        await screen.presenter.onLoadProducts()

        #expect(screen.presenter.loadErrorMessage == nil)
        #expect(screen.presenter.products.count == 1)
    }

    // MARK: - Buying

    /// Subscribe used to be tappable before a plan was chosen and then silently did nothing. The
    /// button is disabled until `selectedProduct` is set, and pressing it without one buys nothing.
    @Test("Test Subscribe Without A Chosen Plan Buys Nothing")
    func testSubscribeWithoutAChosenPlanBuysNothing() async {
        let screen = makeScreen()

        #expect(screen.presenter.selectedProduct == nil)
        screen.presenter.onSubscribePressed()
        await Task.yield()

        #expect(screen.interactor.purchasedProductIds.isEmpty)
        #expect(!screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Start"))
    }

    @Test("Test Subscribe Buys The Chosen Plan")
    func testSubscribeBuysTheChosenPlan() async {
        let screen = makeScreen()
        screen.interactor.purchaseResult = [entitlement(active: true)]

        screen.presenter.onProductSelected(product("yearly"))
        screen.presenter.onSubscribePressed()

        #expect(screen.presenter.selectedProduct?.id == "yearly")
        #expect(screen.interactor.playedHaptics.map { "\($0)" }.first == "selection")
        #expect(await TestManagers.eventually { screen.interactor.purchasedProductIds == ["yearly"] })
    }

    /// The purchase that works: the user is charged and moved on. A paywall that stayed up here
    /// would have taken their money and shown them the same screen again.
    @Test("Test A Purchase With An Entitlement Moves The User On")
    func testAPurchaseWithAnEntitlementMovesTheUserOn() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseResult = [entitlement(active: true)]

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually { screen.router.shown == ["completeAccountSetup"] })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
        #expect(screen.interactor.purchasedProductIds == ["monthly"])
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Success"))
    }

    /// The other direction, and the one that gives the product away if it is wrong: a call that
    /// returned without throwing but granted nothing is not a purchase. The user stays behind the
    /// paywall.
    @Test("Test A Purchase Granting Nothing Does Not Let The User Through")
    func testAPurchaseGrantingNothingDoesNotLetTheUserThrough() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseResult = [entitlement(active: false)]

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Success")
        })
        #expect(screen.router.shown.isEmpty)
    }

    /// And an empty result is the same thing: no entitlement, no entry.
    @Test("Test A Purchase Returning No Entitlements Keeps The Paywall Up")
    func testAPurchaseReturningNoEntitlementsKeepsThePaywallUp() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseResult = []

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Success")
        })
        #expect(screen.router.shown.isEmpty)
    }

    /// A failed purchase tells the user. Failing silently on a payment screen reads as a charge
    /// that may or may not have gone through.
    @Test("Test A Failed Purchase Is Reported To The User")
    func testAFailedPurchaseIsReportedToTheUser() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseError = PaywallTestError.failed

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Fail"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
        #expect(screen.router.shown.isEmpty)
    }

    /// Closing Apple's purchase sheet is a choice, not a failure: no alert titled "Error", no
    /// error haptic.
    @Test("Test Cancelling A Purchase Says Nothing")
    func testCancellingAPurchaseSaysNothing() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseError = NSError(domain: "RevenueCat.ErrorCode", code: 1)

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually { screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Cancelled") })
        #expect(screen.router.alertedErrors.isEmpty)
        #expect(screen.interactor.playedHaptics.isEmpty)
        #expect(!screen.presenter.isPurchasePending)
    }

    /// Ask to Buy leaves the purchase waiting for a parent. That is said on the screen, not
    /// reported as a failure.
    @Test("Test A Purchase Waiting For Approval Says So Inline")
    func testAPurchaseWaitingForApprovalSaysSoInline() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.purchaseError = NSError(domain: "RevenueCat.ErrorCode", code: 20)

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually { screen.presenter.isPurchasePending })
        #expect(screen.router.alertedErrors.isEmpty)
        #expect(screen.router.shown.isEmpty)
    }

    @Test("Test Purchase Errors Are Sorted Into Cancel, Pending And Failure")
    func testPurchaseErrorsAreSortedIntoCancelPendingAndFailure() {
        let cancelled = PaywallPresenter.outcome(of: NSError(domain: "RevenueCat.ErrorCode", code: 1))
        let pending = PaywallPresenter.outcome(of: NSError(domain: "RevenueCat.ErrorCode", code: 20))
        let failed = PaywallPresenter.outcome(of: PaywallTestError.failed)
        #expect(cancelled == .cancelled)
        #expect(pending == .pending)
        #expect(failed == .failed)
    }

    /// The StoreKit and RevenueCat paywalls load their own products.
    @Test("Test Only The Custom Paywall Loads Products")
    func testOnlyTheCustomPaywallLoadsProducts() async {
        let screen = makeScreen()
        screen.interactor.paywallTest = .storeKit

        await screen.presenter.onViewTask()

        #expect(screen.interactor.requestedProductIds.isEmpty)
    }

    // MARK: - Restoring

    /// Someone who already paid, on a new device, gets back in without paying again.
    @Test("Test Restoring An Active Subscription Lets The User Back In")
    func testRestoringAnActiveSubscriptionLetsTheUserBackIn() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.restoreResult = [entitlement(active: true)]

        screen.presenter.onRestorePurchasePressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["completeAccountSetup"] })
        #expect(screen.interactor.restoreCount == 1)
        #expect(screen.interactor.trackedEventNames.contains("PaywallView_Restore_Start"))
    }

    /// Restore is the obvious way to try to get in for free, so a restore that finds nothing
    /// active must not open the door.
    @Test("Test Restoring Nothing Active Does Not Let The User Through")
    func testRestoringNothingActiveDoesNotLetTheUserThrough() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.restoreResult = [entitlement(active: false)]

        screen.presenter.onRestorePurchasePressed()

        #expect(await TestManagers.eventually { screen.interactor.restoreCount == 1 })
        #expect(screen.router.shown.isEmpty)
    }

    /// A restore that succeeds but finds nothing is the commonest restore outcome — wrong Apple ID,
    /// a subscription that lapsed, a purchase made on someone else's account. It used to change
    /// nothing on screen at all, which reads as a dead button on the one screen a paying customer
    /// has to get past.
    @Test("Test Restoring Nothing Active Tells The User Why")
    func testRestoringNothingActiveTellsTheUserWhy() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.restoreResult = []

        screen.presenter.onRestorePurchasePressed()

        #expect(await TestManagers.eventually { screen.router.alertTitles.count == 1 })
        #expect(screen.router.shown.isEmpty)
    }

    /// A restore that errors says so, rather than looking to the user like "you never paid".
    @Test("Test A Failed Restore Is Reported To The User")
    func testAFailedRestoreIsReportedToTheUser() async {
        let screen = makeScreen(isOnboarding: true)
        screen.interactor.restoreError = PaywallTestError.failed

        screen.presenter.onRestorePurchasePressed()

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Where a successful purchase lands

    /// Off onboarding the paywall is a sheet over whatever the user was doing, so a purchase closes
    /// it and returns them there. `dismissEnvironment()` is statically dispatched and invisible to
    /// a double; what is checked here is that the user is *not* thrown into onboarding instead.
    @Test("Test Buying Outside Onboarding Does Not Restart Onboarding")
    func testBuyingOutsideOnboardingDoesNotRestartOnboarding() async {
        let screen = makeScreen(isOnboarding: false)
        screen.interactor.purchaseResult = [entitlement(active: true)]

        screen.presenter.onPurchaseProductPressed(product: product())

        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("PaywallView_Purchase_Success")
        })
        #expect(screen.router.shown.isEmpty)
    }

    /// During onboarding the paywall hands back to the step the profile says is next, so a user who
    /// has already answered the questionnaire is not made to answer it again.
    @Test("Test Onboarding Resumes At The Step The Profile Implies")
    func testOnboardingResumesAtTheStepTheProfileImplies() {
        let screen = makeScreen(
            isOnboarding: true,
            user: UserModel(
                userId: "user-1",
                submittedDateOfBirth: Date(timeIntervalSince1970: 0),
                submittedGender: .male,
                submittedHeightCentimeters: 180,
                submittedWeightKilograms: 80,
                submittedExerciseFrequency: .threeToFour,
                submittedDailyActivityLevel: .moderate,
                submittedCardioFitnessLevel: .intermediate,
                acceptedHealthDisclaimerVersion: UserModel.currentHealthDisclaimerVersion
            )
        )

        screen.presenter.handleNavigation()

        #expect(screen.router.shown == ["goalSetting"])
    }

    /// A user whose profile is complete is shown the finish line rather than being dropped back
    /// into a step they have already done.
    @Test("Test A Complete Profile Goes To The End Of Onboarding")
    func testACompleteProfileGoesToTheEndOfOnboarding() {
        let screen = makeScreen(
            isOnboarding: true,
            user: UserModel(
                userId: "user-1",
                submittedDateOfBirth: Date(timeIntervalSince1970: 0),
                submittedGender: .female,
                submittedHeightCentimeters: 165,
                submittedWeightKilograms: 60,
                submittedExerciseFrequency: .threeToFour,
                submittedDailyActivityLevel: .moderate,
                submittedCardioFitnessLevel: .intermediate,
                submittedCurrentGoalId: "goal-1",
                submittedActiveTrainingProgramId: "program-1",
                submittedFavouriteGymProfileId: "gym-1",
                didCompleteOnboarding: true,
                acceptedHealthDisclaimerVersion: UserModel.currentHealthDisclaimerVersion
            )
        )

        screen.presenter.handleNavigation()

        #expect(screen.router.shown == ["onboardingCompleted"])
    }

    /// If the profile has not arrived yet there is nothing to infer a step from, so the paywall
    /// stays put rather than guessing at a destination.
    @Test("Test No Profile Yet Means No Guess At A Destination")
    func testNoProfileYetMeansNoGuessAtADestination() {
        let screen = makeScreen(isOnboarding: true, user: nil)

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Which paywall

    // MARK: - Leaving without subscribing

    /// Someone who will not subscribe can reach their account (and so Delete Account) and sign
    /// out from the onboarding paywall; they used to be held there with no way out.
    @Test("Test The Paywall Offers The Account And Sign Out")
    func testThePaywallOffersTheAccountAndSignOut() async {
        let screen = makeScreen()

        screen.presenter.onAccountPressed()
        screen.presenter.onSignOutPressed()
        #expect(await TestManagers.eventually { screen.router.shown.contains("onboardingModule") })

        #expect(screen.router.shown == ["account", "onboardingModule"])
        #expect(screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames == ["PaywallView_Account_Press", "PaywallView_SignOut_Start", "PaywallView_SignOut_Success"])
    }

    /// Which of the three paywalls is shown comes from the A/B test, read live rather than captured
    /// at init, so a variant assigned after the screen was built still takes effect.
    @Test("Test The Paywall Variant Comes From The Active Test")
    func testThePaywallVariantComesFromTheActiveTest() {
        let screen = makeScreen()
        screen.interactor.paywallTest = .revenueCat

        #expect(screen.presenter.paywallTest == .revenueCat)
    }

    @Test("Test The Paywall Tracks Its Own Lifecycle And Back Button")
    func testThePaywallTracksItsOwnLifecycleAndBackButton() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()
        // `dismissScreen()` is a statically dispatched extension, so only the event is observable.
        screen.presenter.onBackButtonPressed()

        #expect(screen.interactor.trackedScreenEventNames == ["PaywallView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["PaywallView_Disappear", "PaywallView_BackButton_Pressed"])
    }
}
