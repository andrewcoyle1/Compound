//
//  RetryPolicyTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The two judgement calls behind retrying a failed write: how long to wait, and whether waiting
/// could possibly help.
///
/// The second is the one with teeth. A rejected document or a permission failure will be rejected
/// identically every time, so retrying it only delays the bad news — while a lost connection is
/// exactly the case the retry exists for. Getting the classification wrong is not a slow app, it
/// is either a user told "it failed" when it had not, or a user watching a spinner that was never
/// going to resolve.
struct RetryPolicyTests {

    private let schedule = RetryBackoff(
        baseDelay: .seconds(2),
        multiplier: 3,
        maxAttempts: 4,
        maxTotalDelay: .seconds(60)
    )

    // MARK: - The schedule

    @Test("Test The First Attempt Never Waits")
    func testTheFirstAttemptNeverWaits() {
        #expect(schedule.delay(beforeAttempt: 1, alreadyWaited: .zero) == nil)
    }

    @Test("Test Each Retry Waits Longer Than The Last")
    func testEachRetryWaitsLongerThanTheLast() {
        #expect(schedule.delay(beforeAttempt: 2, alreadyWaited: .zero) == .seconds(2))
        #expect(schedule.delay(beforeAttempt: 3, alreadyWaited: .seconds(2)) == .seconds(6))
        #expect(schedule.delay(beforeAttempt: 4, alreadyWaited: .seconds(8)) == .seconds(18))
    }

    @Test("Test The Attempts Run Out")
    func testTheAttemptsRunOut() {
        #expect(schedule.delay(beforeAttempt: 5, alreadyWaited: .seconds(26)) == nil)
    }

    /// The elapsed cap is the backstop that stops a generously tuned schedule keeping a loop alive
    /// long after anyone cares about the answer.
    @Test("Test The Elapsed Cap Stops A Schedule That Would Otherwise Run On")
    func testTheElapsedCapStopsAScheduleThatWouldOtherwiseRunOn() {
        let generous = RetryBackoff(
            baseDelay: .seconds(30),
            multiplier: 4,
            maxAttempts: 10,
            maxTotalDelay: .seconds(60)
        )

        #expect(generous.delay(beforeAttempt: 2, alreadyWaited: .zero) == .seconds(30))
        // The next wait would be two minutes, which alone is past the minute's budget.
        #expect(generous.delay(beforeAttempt: 3, alreadyWaited: .seconds(30)) == nil)
    }

    /// The shipped schedule, pinned: four tries, the last of them 26 seconds in.
    @Test("Test The Workout Save Schedule Is Four Tries Inside Half A Minute")
    func testTheWorkoutSaveScheduleIsFourTriesInsideHalfAMinute() {
        var waited = Duration.zero
        var delays: [Duration] = []
        var attempt = 2
        while let delay = RetryBackoff.workoutSave.delay(beforeAttempt: attempt, alreadyWaited: waited) {
            delays.append(delay)
            waited += delay
            attempt += 1
        }

        #expect(delays == [.seconds(2), .seconds(6), .seconds(18)])
        #expect(waited == .seconds(26))
    }

    // MARK: - What is worth retrying

    @Test("Test A Lost Connection Is Worth Retrying")
    func testALostConnectionIsWorthRetrying() {
        #expect(URLError(.notConnectedToInternet).isTransientWriteFailure)
        #expect(URLError(.networkConnectionLost).isTransientWriteFailure)
        #expect(URLError(.timedOut).isTransientWriteFailure)
        #expect(URLError(.cannotConnectToHost).isTransientWriteFailure)
    }

    /// A TLS failure is a configuration problem, not a flaky link — the second attempt fails the
    /// same way.
    @Test("Test A Connection That Is Refused On Principle Is Not Retried")
    func testAConnectionThatIsRefusedOnPrincipleIsNotRetried() {
        #expect(!URLError(.secureConnectionFailed).isTransientWriteFailure)
        #expect(!URLError(.appTransportSecurityRequiresSecureConnection).isTransientWriteFailure)
    }

    /// Firestore's own retry set for idempotent writes.
    @Test("Test Firestore's Unavailable And Friends Are Retried")
    func testFirestoreUnavailableAndFriendsAreRetried() {
        for code in [2, 4, 8, 10, 13, 14] {
            #expect(firestoreError(code).isTransientWriteFailure, "code \(code) should be transient")
        }
    }

    /// A verdict on the request itself. Retrying a permission failure four times is four identical
    /// rejections and half a minute of the user not being told.
    @Test("Test A Rejected Write Is Surfaced Rather Than Retried")
    func testARejectedWriteIsSurfacedRatherThanRetried() {
        // permissionDenied, invalidArgument, unauthenticated, failedPrecondition, notFound.
        for code in [7, 3, 16, 9, 5] {
            #expect(!firestoreError(code).isTransientWriteFailure, "code \(code) should be permanent")
        }
    }

    @Test("Test A Document That Cannot Be Encoded Is Never Retried")
    func testADocumentThatCannotBeEncodedIsNeverRetried() {
        let error = EncodingError.invalidValue(
            Double.nan,
            EncodingError.Context(codingPath: [], debugDescription: "not representable")
        )
        #expect(!error.isTransientWriteFailure)
    }

    @Test("Test Cancellation Is Not A Failure To Retry Around")
    func testCancellationIsNotAFailureToRetryAround() {
        #expect(!CancellationError().isTransientWriteFailure)
    }

    /// An error nobody has classified is more likely a rejected document than a flaky network, so
    /// the honest default is to tell the user now.
    @Test("Test An Unrecognised Error Is Treated As Permanent")
    func testAnUnrecognisedErrorIsTreatedAsPermanent() {
        #expect(!RetryPolicyTestError.unknown.isTransientWriteFailure)
    }

    private func firestoreError(_ code: Int) -> NSError {
        NSError(domain: "FIRFirestoreErrorDomain", code: code)
    }
}

private enum RetryPolicyTestError: Error {
    case unknown
}
