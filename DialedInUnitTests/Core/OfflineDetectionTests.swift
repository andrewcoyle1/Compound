//
//  OfflineDetectionTests.swift
//  DialedInUnitTests
//
//  The offline helper: which errors mean "could not reach the server", the pre-flight check that
//  shows "You're offline" instead of starting a spinner, and the generic error alert saying the
//  same when an offline error gets that far.
//

import Testing
import SwiftUI
@testable import DialedIn

@MainActor
struct OfflineDetectionTests {

    private final class Router: GlobalRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    // MARK: - Classifying errors

    @Test("Test Errors That Mean No Network Are Offline Errors")
    func testErrorsThatMeanNoNetworkAreOfflineErrors() {
        let offline: [Error] = [
            OfflineError(),
            URLError(.notConnectedToInternet),
            URLError(.networkConnectionLost),
            URLError(.timedOut),
            NSError(domain: "FIRFirestoreErrorDomain", code: 14),
            NSError(domain: "com.firebase.functions", code: 14),
            NSError(domain: "com.firebase.functions", code: 13, userInfo: [NSUnderlyingErrorKey: URLError(.notConnectedToInternet)])
        ]
        for error in offline {
            #expect(error.isOfflineError, "\(error)")
        }
    }

    /// The server answering "no" is not being offline: an alert saying so would send the user
    /// looking for a signal they already have.
    @Test("Test A Refusal From The Server Is Not An Offline Error")
    func testARefusalFromTheServerIsNotAnOfflineError() {
        let answered: [Error] = [
            NSError(domain: "FIRFirestoreErrorDomain", code: 7),
            NSError(domain: "com.firebase.functions", code: 16),
            URLError(.badServerResponse),
            UsernameError.taken,
            AppError("Not signed in.")
        ]
        for error in answered {
            #expect(!error.isOfflineError, "\(error)")
        }
    }

    @Test("Test The Offline Error Reads As You're Offline")
    func testTheOfflineErrorReadsAsYoureOffline() {
        #expect(OfflineError().localizedDescription.hasPrefix("You're offline"))
    }

    // MARK: - The pre-flight check

    @Test("Test Offline The Check Shows The Alert And Says Stop")
    func testOfflineTheCheckShowsTheAlertAndSaysStop() {
        let interactor = SpyGlobalInteractor()
        interactor.isOffline = true
        let router = Router()

        #expect(interactor.ensureOnline(or: router) == false)
        #expect(router.alertTitles == ["You're offline"])
        #expect(interactor.trackedEventNames == ["Offline_ActionBlocked"])
    }

    @Test("Test Online The Check Passes Silently")
    func testOnlineTheCheckPassesSilently() {
        let interactor = SpyGlobalInteractor()
        let router = Router()

        #expect(interactor.ensureOnline(or: router))
        #expect(router.alertTitles.isEmpty)
        #expect(interactor.trackedEventNames.isEmpty)
    }

    // MARK: - The generic error alert

    @Test("Test The Error Alert Says Offline For An Offline Error")
    func testTheErrorAlertSaysOfflineForAnOfflineError() {
        let router = Router()

        router.showAlert(error: URLError(.notConnectedToInternet))

        #expect(router.alertTitles == ["You're offline"])
    }

    @Test("Test The Error Alert Is Unchanged For Any Other Error")
    func testTheErrorAlertIsUnchangedForAnyOtherError() {
        let router = Router()

        router.showAlert(error: AppError("Nope"))

        // The ordinary path goes straight to the package router, not through `showSimpleAlert`.
        #expect(router.alertTitles.isEmpty)
    }
}
