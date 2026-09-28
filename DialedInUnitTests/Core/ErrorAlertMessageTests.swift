//
//  ErrorAlertMessageTests.swift
//  DialedInUnitTests
//
//  What an error alert says under its title: the app's own words, never a framework's.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct ErrorAlertMessageTests {

    private enum AppError: LocalizedError {
        case described
        case silent

        var errorDescription: String? {
            switch self {
            case .described: return "That name is already taken."
            case .silent: return nil
            }
        }
    }

    @Test("Test An App Error With Its Own Description Says It")
    func testAnAppErrorWithItsOwnDescriptionSaysIt() {
        #expect(AppError.described.userFacingMessage == "That name is already taken.")
    }

    @Test("Test Framework Errors And Undescribed Errors Say Please Try Again")
    func testFrameworkErrorsAndUndescribedErrorsSayPleaseTryAgain() {
        let firebaseLike = NSError(domain: "FIRFirestoreErrorDomain", code: 7, userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."])
        #expect(firebaseLike.userFacingMessage == "Please try again.")
        #expect(URLError(.timedOut).userFacingMessage == "Please try again.")
        #expect(CocoaError(.fileNoSuchFile).userFacingMessage == "Please try again.")
        #expect(AppError.silent.userFacingMessage == "Please try again.")
    }
}
