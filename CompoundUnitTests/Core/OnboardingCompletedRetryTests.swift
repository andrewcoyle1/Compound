//
//  OnboardingCompletedRetryTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The last screen of onboarding. Its Continue button is disabled while the save is in flight, so
/// whether that flag is cleared on the failure path decides if a user whose save fails once can
/// ever finish onboarding.
@MainActor
struct OnboardingCompletedRetryTests {

    private final class Interactor: SpyGlobalInteractor, OnboardingCompletedInteractor {
        var shouldThrow = false
        private(set) var saveCount = 0

        func saveOnboardingComplete() async throws {
            saveCount += 1
            if shouldThrow { throw URLError(.notConnectedToInternet) }
        }
    }

    private final class Router: OnboardingCompletedRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var switchedToCore = 0
        private(set) var alertedErrors: [Error] = []

        func switchToCoreModule() { switchedToCore += 1 }
        func showDevSettingsView() { }
        func showAlert(error: Error) { alertedErrors.append(error) }
    }

    @Test("A failed save re-enables the button so the user can try again")
    func testAFailedFinishLeavesTheScreenUsable() async {
        let interactor = Interactor()
        interactor.shouldThrow = true
        let router = Router()
        let sut = OnboardingCompletedPresenter(interactor: interactor, router: router)

        sut.onFinishButtonPressed()

        #expect(await TestManagers.eventually { router.alertedErrors.count == 1 })
        #expect(sut.isCompletingProfileSetup == false)
        #expect(router.switchedToCore == 0)
        #expect(interactor.trackedEventNames.contains("OnboardingCompletedView_Finish_Fail"))
        #expect(interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("The retry after a failure gets through and finishes onboarding")
    func testTheUserCanRetryAfterAFailure() async {
        let interactor = Interactor()
        interactor.shouldThrow = true
        let router = Router()
        let sut = OnboardingCompletedPresenter(interactor: interactor, router: router)

        sut.onFinishButtonPressed()
        #expect(await TestManagers.eventually { router.alertedErrors.count == 1 })

        interactor.shouldThrow = false
        sut.onFinishButtonPressed()

        #expect(await TestManagers.eventually { router.switchedToCore == 1 })
        #expect(interactor.saveCount == 2)
        #expect(sut.isCompletingProfileSetup == false)
    }

    @Test("A successful finish switches to the main app and clears the flag")
    func testASuccessfulFinishHandsOverToTheApp() async {
        let interactor = Interactor()
        let router = Router()
        let sut = OnboardingCompletedPresenter(interactor: interactor, router: router)

        sut.onFinishButtonPressed()

        #expect(await TestManagers.eventually { router.switchedToCore == 1 })
        #expect(sut.isCompletingProfileSetup == false)
        #expect(router.alertedErrors.isEmpty)
        #expect(interactor.trackedEventNames.contains("OnboardingCompletedView_Finish_Success"))
        #expect(interactor.playedHaptics.map { "\($0)" } == ["success"])
    }
}
