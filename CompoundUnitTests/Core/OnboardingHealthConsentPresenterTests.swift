//
//  OnboardingHealthConsentPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Health consent is two toggles and Continue (decision 2a). A confirmation alert repeating both
/// statements used to come between Continue and the save; the consent recorded must not change.
@MainActor
struct OnboardingHealthConsentPresenterTests {

    private final class Interactor: SpyGlobalInteractor, HealthDisclaimerInteractor {
        private(set) var consents: [(disclaimer: String, privacy: String)] = []
        var failure: Error?

        func updateHealthConsents(disclaimerVersion: String, privacyVersion: String, acceptedAt: Date) async throws {
            if let failure { throw failure }
            consents.append((disclaimerVersion, privacyVersion))
        }
    }

    private final class Router: SpyOnboardingRouter, HealthDisclaimerRouter {
        func showDevSettingsView() { record("devSettings") }
    }

    @Test("Continue with both toggles saves both versions and moves on, with no alert")
    func testContinueSavesBothVersionsWithoutAnAlert() async {
        let interactor = Interactor()
        let router = Router()
        let sut = HealthDisclaimerPresenter(interactor: interactor, router: router)
        sut.acceptedTerms = true
        sut.acceptedPrivacy = true

        sut.onContinuePressed()

        #expect(await TestManagers.eventually { router.shown == ["objective"] })
        #expect(interactor.consents.map(\.disclaimer) == [UserModel.currentHealthDisclaimerVersion])
        #expect(interactor.consents.map(\.privacy) == [UserModel.currentHealthPrivacyPolicyVersion])
        #expect(router.alertTitles.isEmpty)
    }

    @Test("Continue does nothing until both toggles are on")
    func testContinueNeedsBothToggles() {
        let interactor = Interactor()
        let router = Router()
        let sut = HealthDisclaimerPresenter(interactor: interactor, router: router)
        sut.acceptedTerms = true

        #expect(sut.canContinue == false)
        sut.onContinuePressed()

        #expect(interactor.trackedEventNames.isEmpty)
        #expect(router.shown.isEmpty)
    }

    @Test("A failed save stays on the screen and says so")
    func testAFailedSaveStaysOnTheScreen() async {
        let interactor = Interactor()
        interactor.failure = URLError(.notConnectedToInternet)
        let router = Router()
        let sut = HealthDisclaimerPresenter(interactor: interactor, router: router)
        sut.acceptedTerms = true
        sut.acceptedPrivacy = true

        sut.onContinuePressed()

        #expect(await TestManagers.eventually { router.alertTitles == ["Unable to Save Consent"] })
        #expect(router.shown.isEmpty)
    }
}
