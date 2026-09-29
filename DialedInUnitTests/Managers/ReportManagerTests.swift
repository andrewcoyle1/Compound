//
//  ReportManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// Reporting a comment, a session or a profile.
///
/// The submission is the whole record moderation sees — if the reporter, the reported user or the
/// content id is wrong there is nothing left to trace it back with, so the mapping is asserted
/// field by field through a capturing service. `MockReportService` drops what it is given, so it
/// can only stand in where the submission itself is not the thing under test.
@MainActor
struct ReportManagerTests {

    /// Keeps what the manager submitted. `RemoteReportService` is `Sendable` and its method is
    /// nonisolated, so the store is an actor rather than a main-actor spy.
    private actor CapturingReportService: RemoteReportService {
        private(set) var submissions: [ReportSubmission] = []
        func submit(report: ReportSubmission) async throws {
            submissions.append(report)
        }
    }

    private struct FailingReportService: RemoteReportService {
        func submit(report: ReportSubmission) async throws { throw ReportSubmitFailure() }
    }

    /// Records what the manager hands the log manager. `LogService` is `Sendable`, so the store
    /// has to be one too.
    private final class SpyLogService: LogService, @unchecked Sendable {
        private let lock = NSLock()
        private var names: [String] = []

        var trackedEventNames: [String] {
            lock.withLock { names }
        }

        func identifyUser(userId: String, name: String?, email: String?) { }
        func addUserProperties(dict: [String: Any], isHighPriority: Bool) { }
        func deleteUserProfile() { }
        func trackEvent(event: LoggableEvent) { lock.withLock { names.append(event.eventName) } }
        func trackScreenView(event: LoggableEvent) { lock.withLock { names.append(event.eventName) } }
    }

    private func makeManager(
        user: UserModel?,
        service: RemoteReportService = MockReportService(),
        logManager: LogManager? = nil
    ) async throws -> ReportManager {
        ReportManager(
            service: service,
            userManager: try await TestManagers.signedInUserManager(user),
            logManager: logManager
        )
    }

    // MARK: - The signed-in reporter

    /// A report with no reporter is unactionable, and the only user id available is the signed-in
    /// one — so the manager has to refuse rather than submit an anonymous record.
    @Test("Test Reporting Without A Current User Throws")
    func testReportingWithoutACurrentUserThrows() async throws {
        let manager = try await makeManager(user: nil)

        await #expect(throws: ReportManager.ReportError.self) {
            try await manager.report(
                contentType: .comment,
                contentId: "comment-1",
                authorUserId: "author-1",
                reason: .spam,
                notes: nil
            )
        }
    }

    @Test("Test Reporting Without A Current User Submits Nothing")
    func testReportingWithoutACurrentUserSubmitsNothing() async throws {
        let service = CapturingReportService()
        let manager = try await makeManager(user: nil, service: service)

        _ = try? await manager.report(
            contentType: .comment,
            contentId: "comment-1",
            authorUserId: "author-1",
            reason: .spam,
            notes: nil
        )

        #expect(await service.submissions.isEmpty)
    }

    // MARK: - The submission

    @Test("Test The Submission Carries The Reporter And The Reported Content")
    func testTheSubmissionCarriesTheReporterAndTheReportedContent() async throws {
        // Captured once: `UserModel.mock` builds its dates from `Date()`, so two reads differ.
        let user = UserModel.mock
        let service = CapturingReportService()
        let manager = try await makeManager(user: user, service: service)

        try await manager.report(
            contentType: .comment,
            contentId: "comment-1",
            authorUserId: "author-1",
            reason: .harassment,
            notes: "Targeted abuse"
        )

        let submission = try #require(await service.submissions.first)
        #expect(submission.reporterUserId == user.userId)
        #expect(submission.reportedUserId == "author-1")
        #expect(submission.contentType == .comment)
        #expect(submission.contentId == "comment-1")
        #expect(submission.reason == .harassment)
        #expect(submission.notes == "Targeted abuse")
    }

    /// The author is unknown when the reported content's author could not be resolved, and the
    /// report still has to go through — a nil there must not become the reporter's own id.
    @Test("Test A Report With No Known Author Keeps The Reported User Nil")
    func testAReportWithNoKnownAuthorKeepsTheReportedUserNil() async throws {
        let user = UserModel.mock
        let service = CapturingReportService()
        let manager = try await makeManager(user: user, service: service)

        try await manager.report(
            contentType: .comment,
            contentId: "comment-1",
            authorUserId: nil,
            reason: .other,
            notes: nil
        )

        let submission = try #require(await service.submissions.first)
        #expect(submission.reportedUserId == nil)
        #expect(submission.notes == nil)
        #expect(submission.reporterUserId == user.userId)
    }

    /// `reportId` is the Firestore document id `FirebaseReportService` writes under, so two reports
    /// sharing one would overwrite each other.
    @Test("Test Each Report Gets Its Own Id")
    func testEachReportGetsItsOwnId() async throws {
        let service = CapturingReportService()
        let manager = try await makeManager(user: UserModel.mock, service: service)

        try await manager.report(
            contentType: .comment, contentId: "comment-1", authorUserId: "author-1", reason: .spam, notes: nil
        )
        try await manager.report(
            contentType: .comment, contentId: "comment-1", authorUserId: "author-1", reason: .spam, notes: nil
        )

        let ids = await service.submissions.map(\.reportId)
        #expect(ids.count == 2)
        #expect(Set(ids).count == 2)
    }

    @Test("Test The Submission Is Stamped With The Time It Was Made")
    func testTheSubmissionIsStampedWithTheTimeItWasMade() async throws {
        let service = CapturingReportService()
        let manager = try await makeManager(user: UserModel.mock, service: service)
        let before = Date()

        try await manager.report(
            contentType: .comment, contentId: "comment-1", authorUserId: "author-1", reason: .spam, notes: nil
        )

        let submission = try #require(await service.submissions.first)
        #expect(submission.createdAt >= before)
        #expect(submission.createdAt <= Date())
    }

    /// The submission is what the backend decodes, so the coding keys have to survive a round trip
    /// of the raw values the reasons and content types are stored as.
    @Test("Test The Submission Round Trips Through Codable")
    func testTheSubmissionRoundTripsThroughCodable() async throws {
        let service = CapturingReportService()
        let manager = try await makeManager(user: UserModel.mock, service: service)
        try await manager.report(
            contentType: .comment,
            contentId: "comment-1",
            authorUserId: "author-1",
            reason: .inappropriate,
            notes: "Threatening language"
        )
        let submission = try #require(await service.submissions.first)

        let data = try JSONEncoder().encode(submission)
        let decoded = try JSONDecoder().decode(ReportSubmission.self, from: data)

        #expect(decoded.reportId == submission.reportId)
        #expect(decoded.reporterUserId == submission.reporterUserId)
        #expect(decoded.reportedUserId == submission.reportedUserId)
        #expect(decoded.contentType == .comment)
        #expect(decoded.reason == .inappropriate)
        #expect(decoded.notes == "Threatening language")
    }

    // MARK: - Reporting the outcome

    /// The success event is tracked after the write, so a failed submission must not report one —
    /// the pair is how submission drop-off is measured.
    @Test("Test A Failed Submission Tracks The Start But Not The Success")
    func testAFailedSubmissionTracksTheStartButNotTheSuccess() async throws {
        let spy = SpyLogService()
        let manager = try await makeManager(
            user: UserModel.mock,
            service: FailingReportService(),
            logManager: LogManager(services: [spy])
        )

        await #expect(throws: ReportSubmitFailure.self) {
            try await manager.report(
                contentType: .comment, contentId: "comment-1", authorUserId: "author-1", reason: .spam, notes: nil
            )
        }

        #expect(spy.trackedEventNames == ["Report_Submit_Start"])
    }

    @Test("Test A Successful Submission Tracks Start And Success")
    func testASuccessfulSubmissionTracksStartAndSuccess() async throws {
        let spy = SpyLogService()
        let manager = try await makeManager(
            user: UserModel.mock,
            logManager: LogManager(services: [spy])
        )

        try await manager.report(
            contentType: .comment, contentId: "comment-1", authorUserId: "author-1", reason: .spam, notes: nil
        )

        #expect(spy.trackedEventNames == ["Report_Submit_Start", "Report_Submit_Success"])
    }

    // MARK: - Reasons and content types

    /// The reasons are what the report sheet lists, in this order, and `displayName` is the only
    /// place their wording lives.
    @Test("Test Every Reason Has A Readable Name")
    func testEveryReasonHasAReadableName() {
        #expect(ReportReason.allCases.map(\.displayName) == ["Spam", "Harassment", "Inappropriate", "Other"])
    }

    /// The identifier is the raw value, which is also what is stored — so renaming a case's
    /// display wording must not move the id out from under reports already filed.
    @Test("Test A Reason Identifies Itself By Its Stored Value")
    func testAReasonIdentifiesItselfByItsStoredValue() {
        #expect(ReportReason.allCases.map(\.id) == ReportReason.allCases.map(\.rawValue))
        #expect(ReportReason.allCases.map(\.rawValue) == ["spam", "harassment", "inappropriate", "other"])
    }

    @Test("Test Content Types Keep Their Stored Values")
    func testContentTypesKeepTheirStoredValues() {
        #expect(ReportContentType.comment.rawValue == "comment")
        #expect(ReportContentType.session.rawValue == "session")
        #expect(ReportContentType.user.rawValue == "user")
    }
}

/// The failure a submission is made to throw. At file scope because a type nested two deep
/// inside the suite trips SwiftLint's nesting rule.
private struct ReportSubmitFailure: Error { }
