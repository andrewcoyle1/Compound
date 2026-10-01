//
//  RetryPolicy.swift
//  Compound
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Foundation

// MARK: - Backoff schedule

/// How often, and how patiently, a failed write is tried again.
///
/// This is a value rather than a hard-coded sleep so a test can drive a schedule of milliseconds
/// instead of waiting out the real one. A test that sleeps through a real backoff is a flake in
/// waiting.
struct RetryBackoff: Sendable, Equatable {

    /// How long to wait before the first retry.
    let baseDelay: Duration

    /// What each subsequent wait is multiplied by.
    let multiplier: Double

    /// Total tries, counting the first one — which is not a retry.
    let maxAttempts: Int

    /// Ceiling on time spent waiting, so a tuned-up schedule can never keep a loop alive for hours.
    let maxTotalDelay: Duration

    /// The wait before `attempt`, or `nil` when that attempt is past the schedule's budget.
    ///
    /// `attempt` is 1-based: attempt 1 is the original try and never waits, attempt 2 is the first
    /// retry. `alreadyWaited` is what the loop has spent so far, which is what the elapsed cap is
    /// measured against.
    func delay(beforeAttempt attempt: Int, alreadyWaited: Duration) -> Duration? {
        guard attempt > 1, attempt <= maxAttempts else { return nil }
        let steps = Double(attempt - 2)
        let delay = Duration.seconds(baseDelay.inSeconds * pow(multiplier, steps))
        guard alreadyWaited + delay <= maxTotalDelay else { return nil }
        return delay
    }
}

extension RetryBackoff {

    /// Four tries spread over at most a minute: the save, then retries at 2s, 6s and 18s.
    ///
    /// The first retry has to be quick enough that a user still holding the phone sees the toast
    /// resolve, and slow enough to outlast a cell handoff — two seconds is both. Tripling reaches
    /// eighteen seconds in three steps, which covers a lift or a short tunnel; someone who has
    /// genuinely lost signal for longer than that is better served by being told the workout is
    /// safe on the device than by a message that never settles. The elapsed cap is slack with
    /// these numbers — the attempts run out first, at 26s — but it keeps the ceiling honest if
    /// the numbers are ever tuned upwards.
    static let workoutSave = RetryBackoff(
        baseDelay: .seconds(2),
        multiplier: 3,
        maxAttempts: 4,
        maxTotalDelay: .seconds(60)
    )
}

private extension Duration {
    var inSeconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

// MARK: - Which failures are worth retrying

/// The codes that mean "the same request could still succeed".
private enum TransientFailure {

    /// Matched on the domain string rather than by importing FirebaseFirestore, which keeps the
    /// rule a plain value test the unit tests can drive without a configured Firebase.
    static let firestoreDomain = "FIRFirestoreErrorDomain"

    /// Firestore's own retry set for idempotent writes: unknown, deadlineExceeded,
    /// resourceExhausted, aborted, internal, unavailable. Everything else it reports —
    /// permissionDenied, unauthenticated, invalidArgument, failedPrecondition — is a verdict on
    /// the request itself and will be the same verdict every time.
    static let firestoreCodes: Set<Int> = [2, 4, 8, 10, 13, 14]

    /// Connectivity failures only. A TLS or certificate failure is deliberately absent: it is a
    /// configuration problem, not a flaky link, and retrying it just delays the bad news.
    static let urlCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .internationalRoamingOff,
        .callIsActive,
        .dataNotAllowed
    ]
}

extension Error {

    /// Whether retrying this write unchanged could plausibly succeed.
    ///
    /// Anything unrecognised is treated as permanent. An error nobody has classified is more
    /// likely to be a rejected document than a flaky network, and telling the user straight away
    /// beats spending half a minute arriving at the same answer.
    var isTransientWriteFailure: Bool {
        // Cancellation is the caller's decision, not a failure to work around.
        if self is CancellationError { return false }

        // A value that cannot be encoded will not encode on the second go either.
        if self is EncodingError || self is DecodingError { return false }

        if let urlError = self as? URLError {
            return TransientFailure.urlCodes.contains(urlError.code)
        }

        let nsError = self as NSError
        switch nsError.domain {
        case TransientFailure.firestoreDomain:
            return TransientFailure.firestoreCodes.contains(nsError.code)
        case NSURLErrorDomain:
            return TransientFailure.urlCodes.contains(URLError.Code(rawValue: nsError.code))
        default:
            return false
        }
    }
}
