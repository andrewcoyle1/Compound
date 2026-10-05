//
//  StravaManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The connection, its tokens and the upload queue.
///
/// `authenticate()` drives an `ASWebAuthenticationSession`, which needs a foreground window scene
/// and a real browser redirect, so it is left to manual testing; what it does with the redirect is
/// covered through `authorizationCode(from:)`. Everything else runs against a capturing service,
/// with the session and exercise managers on mock engines and a scratch `UserDefaults`.
/// One activity edit `CapturingStravaService` was asked to send.
struct StravaActivityUpdate {
    let id: Int
    let name: String
    let description: String?
}

@MainActor
struct StravaManagerTests {

    /// Captures what was sent. `rejectedTokens` answers a request with those access tokens as
    /// Strava answers a revoked one. `statuses` are answered in turn, the first by the upload
    /// itself; `uploadErrors` are thrown by uploads in turn before any status is answered.
    final class CapturingStravaService: StravaService {
        var athlete: StravaAthlete? = StravaAthlete(id: 7, firstname: "Alex", lastname: "Runner", profile: nil)
        var tokens = ["token-1", "token-2", "token-3"]
        var tokenLifetime = 3_600
        var rejectedTokens: Set<String> = []
        var statuses = [StravaUploadStatus(id: 7, error: nil, activityId: 42)]
        var uploadErrors: [Error] = []
        var disconnectError: Error?
        var connectError: Error?
        private(set) var uploaded: [StravaUpload] = []
        private(set) var polledIds: [Int] = []
        private(set) var updates: [StravaActivityUpdate] = []
        private(set) var issuedTokens: [String] = []
        private(set) var connects: [(code: String?, refreshToken: String?)] = []
        private(set) var disconnectCount = 0

        func connect(code: String?, refreshToken: String?, clientId: String) async throws -> StravaConnectResult {
            connects.append((code, refreshToken))
            if let connectError { throw connectError }
            let athlete = StravaAthlete(id: 7, firstname: "Alex", lastname: "Runner", profile: nil)
            self.athlete = athlete
            return StravaConnectResult(accessToken: "connect-token", expiresAt: Int(Date().timeIntervalSince1970) + tokenLifetime, athlete: athlete)
        }

        func connection() async throws -> StravaAthlete? { athlete }

        func accessToken() async throws -> StravaAccessToken {
            guard athlete != nil else { throw StravaError.notConnected }
            let token = tokens.isEmpty ? "token-last" : tokens.removeFirst()
            issuedTokens.append(token)
            return StravaAccessToken(accessToken: token, expiresAt: Int(Date().timeIntervalSince1970) + tokenLifetime)
        }

        func disconnect() async throws {
            if let disconnectError { throw disconnectError }
            disconnectCount += 1
            athlete = nil
        }

        func upload(_ upload: StravaUpload, accessToken: String) async throws -> StravaUploadStatus {
            if rejectedTokens.contains(accessToken) { throw StravaError.authorizationRevoked }
            if !uploadErrors.isEmpty { throw uploadErrors.removeFirst() }
            uploaded.append(upload)
            return nextStatus()
        }

        func uploadStatus(id: Int, accessToken: String) async throws -> StravaUploadStatus {
            polledIds.append(id)
            return nextStatus()
        }

        func updateActivity(id: Int, name: String, description: String?, accessToken: String) async throws {
            if rejectedTokens.contains(accessToken) { throw StravaError.authorizationRevoked }
            updates.append(StravaActivityUpdate(id: id, name: name, description: description))
        }

        private func nextStatus() -> StravaUploadStatus {
            statuses.count > 1 ? statuses.removeFirst() : statuses[0]
        }
    }

    struct Fixture {
        let manager: StravaManager
        let service: CapturingStravaService
        let sessions: WorkoutSessionManager
        let defaults: UserDefaults
    }

    /// A manager signed in as `author-1`, its sessions loaded. `signIn` sends the queue, so a
    /// session is only queued by what the test does next.
    func makeFixture(
        sessions: [WorkoutSessionModel] = [],
        service: CapturingStravaService? = nil,
        defaults: UserDefaults? = nil,
        pollAttempts: Int = 10
    ) async -> Fixture {
        let service = service ?? CapturingStravaService()
        let defaults = defaults ?? TestManagers.scratchDefaults("strava")
        let sessionManager = await TestManagers.signedInWorkoutSessionManager(sessions: sessions)
        let manager = StravaManager(
            service: service,
            clientId: "client-id",
            activitySyncEngine: TestManagers.collectionEngine([StravaImportedActivity](), key: "strava-activities"),
            sessions: sessionManager,
            exercises: TestManagers.exerciseModelManager(),
            users: TestManagers.userManager(user: nil),
            logger: LogManager(services: []),
            defaults: defaults,
            pollInterval: .zero,
            pollAttempts: pollAttempts
        )
        Self.clearDeviceTokens()
        await manager.signIn(userId: "author-1")
        return Fixture(manager: manager, service: service, sessions: sessionManager, defaults: defaults)
    }

    static func clearDeviceTokens() {
        for key in ["strava_access_token", "strava_refresh_token", "strava_expires_at"] {
            KeychainHelper.delete(forKey: key)
        }
    }

    // MARK: - The connection

    @Test("Test Signing In Reads The Connection From The Server")
    func testSigningInReadsTheConnectionFromTheServer() async {
        let fixture = await makeFixture()

        #expect(fixture.manager.isConnected)
        #expect(fixture.manager.athlete?.name == "Alex Runner")
    }

    /// The connection belongs to the account: signing out forgets it here and nothing more, and the
    /// last answer is remembered per account so the next launch knows before the server answers.
    @Test("Test Signing Out Forgets The Connection Here Only")
    func testSigningOutForgetsTheConnectionHereOnly() async {
        let fixture = await makeFixture()

        fixture.manager.signOut()

        #expect(!fixture.manager.isConnected)
        #expect(fixture.service.disconnectCount == 0)
        #expect(fixture.defaults.data(forKey: StravaManager.athleteKey("author-1")) != nil)
    }

    @Test("Test An Account Not Connected On The Server Is Not Connected")
    func testAnAccountNotConnectedOnTheServerIsNotConnected() async {
        let service = CapturingStravaService()
        service.athlete = nil

        let fixture = await makeFixture(service: service)

        #expect(!fixture.manager.isConnected)
    }

    @Test("Test Disconnecting Clears The Connection And The Queue")
    func testDisconnectingClearsTheConnectionAndTheQueue() async throws {
        let fixture = await makeFixture()
        fixture.manager.pendingSessionIds = ["s"]

        try await fixture.manager.disconnect()

        #expect(fixture.service.disconnectCount == 1)
        #expect(!fixture.manager.isConnected)
        #expect(fixture.manager.pendingSessionIds.isEmpty)
    }

    /// The server did not disconnect, so neither does the app.
    @Test("Test A Failed Disconnect Leaves The Account Connected")
    func testAFailedDisconnectLeavesTheAccountConnected() async {
        let service = CapturingStravaService()
        service.disconnectError = URLError(.notConnectedToInternet)
        let fixture = await makeFixture(service: service)

        await #expect(throws: URLError.self) { try await fixture.manager.disconnect() }

        #expect(fixture.manager.isConnected)
    }

    /// Older builds kept the refresh token in the iCloud Keychain. The first sign-in hands it to
    /// the server and forgets it here.
    @Test("Test A Device Token Is Moved To The Server")
    func testADeviceTokenIsMovedToTheServer() async {
        let service = CapturingStravaService()
        service.athlete = nil
        let manager = StravaManager(
            service: service, clientId: "client-id",
            activitySyncEngine: TestManagers.collectionEngine([StravaImportedActivity](), key: "strava-activities"),
            sessions: TestManagers.workoutSessionManager(), exercises: TestManagers.exerciseModelManager(),
            users: TestManagers.userManager(user: nil), logger: LogManager(services: []),
            defaults: TestManagers.scratchDefaults("strava")
        )
        KeychainHelper.save("old-refresh", forKey: "strava_refresh_token", synchronizable: true)
        defer { Self.clearDeviceTokens() }

        await manager.signIn(userId: "author-1")

        #expect(service.connects.map(\.refreshToken) == ["old-refresh"])
        #expect(manager.isConnected)
        #expect(KeychainHelper.read(forKey: "strava_refresh_token", synchronizable: true) == nil)
    }

    // MARK: - Tokens

    /// A token is asked for once and reused until it is within a minute of expiring.
    @Test("Test A Token Is Reused Until It Nearly Expires")
    func testATokenIsReusedUntilItNearlyExpires() async throws {
        let fixture = await makeFixture()

        try await fixture.manager.updateActivity(1, from: StravaFixture.session())
        try await fixture.manager.updateActivity(1, from: StravaFixture.session())
        #expect(fixture.service.issuedTokens == ["token-1"])

        let shortLived = CapturingStravaService()
        shortLived.tokenLifetime = 30
        let other = await makeFixture(service: shortLived)
        try await other.manager.updateActivity(1, from: StravaFixture.session())
        try await other.manager.updateActivity(1, from: StravaFixture.session())
        #expect(shortLived.issuedTokens == ["token-1", "token-2"])
    }

    /// A 401 gets one fresh token and one retry.
    @Test("Test A Rejected Token Is Replaced Once And The Request Retried")
    func testARejectedTokenIsReplacedOnceAndTheRequestRetried() async throws {
        let service = CapturingStravaService()
        service.rejectedTokens = ["token-1"]
        let fixture = await makeFixture(service: service)

        try await fixture.manager.updateActivity(1, from: StravaFixture.session())

        #expect(service.issuedTokens == ["token-1", "token-2"])
        #expect(service.updates.count == 1)
        #expect(fixture.manager.isConnected)
    }

    /// Strava refusing a fresh token too means the athlete revoked Compound.
    @Test("Test A Token Refused Twice Disconnects")
    func testATokenRefusedTwiceDisconnects() async {
        let service = CapturingStravaService()
        service.rejectedTokens = ["token-1", "token-2"]
        let fixture = await makeFixture(service: service)

        await #expect(throws: StravaError.notConnected) {
            try await fixture.manager.updateActivity(1, from: StravaFixture.session())
        }

        #expect(!fixture.manager.isConnected)
    }

    @Test("Test An Edit Sends The Name And Description")
    func testAnEditSendsTheNameAndDescription() async throws {
        let fixture = await makeFixture()

        try await fixture.manager.updateActivity(42, from: StravaFixture.session(name: "Pull Day", notes: "Felt strong"))

        #expect(fixture.service.updates.first?.id == 42)
        #expect(fixture.service.updates.first?.name == "Pull Day")
        #expect(fixture.service.updates.first?.description?.hasPrefix("Felt strong\n\n") == true)
    }

    // MARK: - Sending one workout

    /// The external id is what makes a second upload of the same session a duplicate rather than
    /// a second activity.
    @Test("Test A Workout Is Sent With Its Name Description And Session Id")
    func testAWorkoutIsSentWithItsNameDescriptionAndSessionId() async throws {
        let fixture = await makeFixture()

        let outcome = try await fixture.manager.upload(StravaFixture.session(name: "Upper Body A", notes: "Felt strong"))

        let upload = try #require(fixture.service.uploaded.first)
        #expect(upload.name == "Upper Body A")
        #expect(upload.description?.hasPrefix("Felt strong") == true)
        #expect(upload.externalId == "compound-session-1")
        #expect(outcome == .linked(activityId: 42))
    }

    @Test("Test A Workout With No Completed Set Has Nothing To Send")
    func testAWorkoutWithNoCompletedSetHasNothingToSend() async throws {
        let fixture = await makeFixture()
        let workout = StravaFixture.session(exercises: [StravaFixture.exercise(sets: [StravaFixture.row("a", completed: false)])])

        #expect(try await fixture.manager.upload(workout) == .nothingToSend)
        #expect(fixture.service.uploaded.isEmpty)
    }

    @Test("Test A Processing Upload Is Polled Until Its Activity Exists")
    func testAProcessingUploadIsPolledUntilItsActivityExists() async throws {
        let service = CapturingStravaService()
        service.statuses = [
            StravaUploadStatus(id: 7, error: nil, activityId: nil),
            StravaUploadStatus(id: 7, error: nil, activityId: nil),
            StravaUploadStatus(id: 7, error: nil, activityId: 99)
        ]
        let fixture = await makeFixture(service: service)

        #expect(try await fixture.manager.upload(StravaFixture.session()) == .linked(activityId: 99))
        #expect(service.polledIds == [7, 7])
    }

    /// The second upload of a session is refused as a duplicate of the first, which is the
    /// activity it already became.
    @Test("Test A Duplicate Upload Answers The Existing Activity")
    func testADuplicateUploadAnswersTheExistingActivity() async throws {
        let service = CapturingStravaService()
        service.statuses = [StravaUploadStatus(id: 7, error: "compound-session-1 duplicate of activity 21234316", activityId: nil)]
        let fixture = await makeFixture(service: service)

        #expect(try await fixture.manager.upload(StravaFixture.session()) == .linked(activityId: 21_234_316))
    }

    @Test("Test A Processing Error Is Thrown With Stravas Reason")
    func testAProcessingErrorIsThrownWithStravasReason() async {
        let service = CapturingStravaService()
        service.statuses = [StravaUploadStatus(id: 7, error: "Unrecognized exercise", activityId: nil)]
        let fixture = await makeFixture(service: service)

        await #expect(throws: StravaError.processingFailed("Unrecognized exercise")) {
            _ = try await fixture.manager.upload(StravaFixture.session())
        }
    }

    @Test("Test An Upload Still Processing After The Wait Is Processing")
    func testAnUploadStillProcessingAfterTheWaitIsProcessing() async throws {
        let service = CapturingStravaService()
        service.statuses = [StravaUploadStatus(id: 7, error: nil, activityId: nil)]
        let fixture = await makeFixture(service: service, pollAttempts: 3)

        #expect(try await fixture.manager.upload(StravaFixture.session()) == .processing)
        #expect(service.polledIds.count == 3)
    }

    // MARK: - The queue

    /// A finished workout goes up and its session is stamped with the activity.
    @Test("Test A Queued Workout Is Sent And Linked")
    func testAQueuedWorkoutIsSentAndLinked() async {
        let workout = StravaFixture.session()
        let fixture = await makeFixture(sessions: [workout])

        await fixture.manager.queueUpload(workout)

        #expect(fixture.manager.pendingSessionIds.isEmpty)
        #expect(await TestManagers.eventually { fixture.sessions.workoutSessions.first?.stravaActivityId == 42 })
    }

    /// Offline at the gym: the workout stays queued, across launches, and goes at the next sign-in.
    @Test("Test A Failed Upload Stays Queued Across Launches")
    func testAFailedUploadStaysQueuedAcrossLaunches() async {
        let workout = StravaFixture.session()
        let offline = CapturingStravaService()
        offline.uploadErrors = [URLError(.notConnectedToInternet)]
        let defaults = TestManagers.scratchDefaults("strava")
        let first = await makeFixture(sessions: [workout], service: offline, defaults: defaults)

        await first.manager.queueUpload(workout)
        #expect(first.manager.pendingSessionIds == ["session-1"])

        let relaunch = await makeFixture(sessions: [workout], defaults: defaults)

        #expect(relaunch.service.uploaded.map(\.externalId) == ["compound-session-1"])
        #expect(relaunch.manager.pendingSessionIds.isEmpty)
    }

    /// Over Strava's limit, every later upload would fail too: the queue stops and keeps them all.
    @Test("Test Hitting Stravas Limit Stops The Queue And Keeps It")
    func testHittingStravasLimitStopsTheQueueAndKeepsIt() async {
        let sessions = [StravaFixture.session(id: "a"), StravaFixture.session(id: "b")]
        let service = CapturingStravaService()
        service.uploadErrors = [StravaError.rateLimited]
        let fixture = await makeFixture(sessions: sessions, service: service)
        fixture.manager.pendingSessionIds = ["a", "b"]

        await fixture.manager.syncPendingUploads()

        #expect(fixture.manager.pendingSessionIds == ["a", "b"])
        #expect(service.uploaded.isEmpty)
    }

    /// A workout Strava will never take is dropped rather than retried forever, and the rest go on.
    @Test("Test A Workout Strava Refuses Is Dropped And The Rest Sent")
    func testAWorkoutStravaRefusesIsDroppedAndTheRestSent() async {
        let sessions = [StravaFixture.session(id: "a"), StravaFixture.session(id: "b")]
        let service = CapturingStravaService()
        service.uploadErrors = [StravaError.uploadFailed(status: 400)]
        let fixture = await makeFixture(sessions: sessions, service: service)
        fixture.manager.pendingSessionIds = ["a", "b"]

        await fixture.manager.syncPendingUploads()

        #expect(fixture.manager.pendingSessionIds.isEmpty)
        #expect(service.uploaded.map(\.externalId) == ["compound-b"])
    }

    /// Still processing: kept, because sending again answers the activity as a duplicate.
    @Test("Test A Workout Still Processing Stays Queued")
    func testAWorkoutStillProcessingStaysQueued() async {
        let workout = StravaFixture.session()
        let service = CapturingStravaService()
        service.statuses = [StravaUploadStatus(id: 7, error: nil, activityId: nil)]
        let fixture = await makeFixture(sessions: [workout], service: service, pollAttempts: 1)

        await fixture.manager.queueUpload(workout)

        #expect(fixture.manager.pendingSessionIds == ["session-1"])
    }

    @Test("Test Nothing Is Queued Without A Connection")
    func testNothingIsQueuedWithoutAConnection() async {
        let service = CapturingStravaService()
        service.athlete = nil
        let fixture = await makeFixture(service: service)

        await fixture.manager.queueUpload(StravaFixture.session())

        #expect(fixture.manager.pendingSessionIds.isEmpty)
        #expect(service.uploaded.isEmpty)
    }

    // MARK: - Past workouts

    /// Finished, own, not rest days, not deleted, not already on Strava, with something to send —
    /// oldest first so Strava's feed fills in order.
    @Test("Test Past Workouts To Upload Are The Ones Strava Could Take")
    func testPastWorkoutsToUploadAreTheOnesStravaCouldTake() async {
        var linked = StravaFixture.session(id: "linked", dateCreated: StravaFixture.start)
        linked.stravaActivityId = 1
        var deleted = StravaFixture.session(id: "deleted")
        deleted.deletedAt = StravaFixture.start
        let fixture = await makeFixture(sessions: [
            StravaFixture.session(id: "newer", dateCreated: StravaFixture.start.addingTimeInterval(86_400)),
            StravaFixture.session(id: "older", dateCreated: StravaFixture.start),
            linked,
            deleted,
            StravaFixture.session(id: "rest", isRestDay: true),
            StravaFixture.session(id: "running", endedAt: .some(nil)),
            StravaFixture.session(id: "friend", authorId: "someone-else"),
            StravaFixture.session(id: "empty", exercises: [StravaFixture.exercise(sets: [StravaFixture.row("a", completed: false)])])
        ])

        #expect(fixture.manager.backfillCandidates.map(\.id) == ["older", "newer"])
        #expect(fixture.manager.queueBackfill() == 2)
        #expect(fixture.manager.pendingSessionIds == ["older", "newer"])
        #expect(fixture.manager.queueBackfill() == 0)
    }

    // MARK: - The redirect

    @Test("Test The Redirect Yields The Code When Upload Permission Was Granted")
    func testTheRedirectYieldsTheCodeWhenUploadPermissionWasGranted() throws {
        let url = try #require(URL(string: "compoundstrava://localhost/exchange_token?state=&code=abc&scope=read,activity:write"))
        #expect(try StravaManager.authorizationCode(from: url) == "abc")
    }

    /// Strava documents the granted scopes as comma- or space-delimited. Split on commas alone, a
    /// space-delimited grant read as missing the upload permission and refused every connection.
    @Test("Test A Space Delimited Grant Is Read")
    func testASpaceDelimitedGrantIsRead() throws {
        let url = try #require(URL(string: "compoundstrava://localhost/exchange_token?state=&code=abc&scope=read%20activity:write"))
        #expect(try StravaManager.authorizationCode(from: url) == "abc")
    }

    /// Strava's consent page lets the athlete untick the upload permission and still redirects with
    /// a code. Connecting on that would leave every upload refused.
    @Test("Test The Redirect Is Refused Without Upload Permission")
    func testTheRedirectIsRefusedWithoutUploadPermission() throws {
        let url = try #require(URL(string: "compoundstrava://localhost/exchange_token?state=&code=abc&scope=read"))
        #expect(throws: StravaError.missingUploadPermission) { try StravaManager.authorizationCode(from: url) }
        let noCode = try #require(URL(string: "compoundstrava://localhost/exchange_token?error=access_denied"))
        #expect(throws: StravaError.missingAuthCode) { try StravaManager.authorizationCode(from: noCode) }
    }

    // MARK: - Errors

    /// These strings are shown in the alert the connect flow puts up, and are the only explanation
    /// anyone gets when Strava refuses.
    @Test("Test Every Strava Error Explains Itself")
    func testEveryStravaErrorExplainsItself() {
        #expect(StravaError.invalidURL.errorDescription == "Invalid Strava authorization URL.")
        #expect(StravaError.missingAuthCode.errorDescription == "No authorization code was returned from Strava.")
        #expect(StravaError.notConnected.errorDescription == "Not connected to Strava.")
        #expect(StravaError.missingUploadPermission.errorDescription == "Allow Compound to upload your activities to connect Strava.")
        #expect(StravaError.uploadFailed(status: 500).errorDescription == "Strava did not accept the upload (500).")
        #expect(StravaError.processingFailed("x").errorDescription == "Strava could not process the workout.")
        #expect(StravaError.rateLimited.errorDescription == "Strava is busy. Your workouts will upload later.")
    }

    @Test("Test A Strava Error Is Readable Through Localized Description")
    func testAStravaErrorIsReadableThroughLocalizedDescription() {
        // `LocalizedError` only reaches `localizedDescription` through the bridge, which is how
        // the alert's message is actually read.
        #expect(StravaError.notConnected.localizedDescription == "Not connected to Strava.")
    }
}
