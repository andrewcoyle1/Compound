//
//  StravaManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Pushing a finished session to Strava.
///
/// Two parts of this manager are out of a unit test's reach and are left to manual testing rather
/// than faked here:
///
/// - `authenticate()` drives an `ASWebAuthenticationSession`, which needs a foreground window
///   scene and a real browser redirect. Nothing about the code exchange runs without it.
/// - Token state lives in the real Keychain through `KeychainHelper`, not behind an injectable
///   store, so `isConnected`, `disconnect()` and the refresh inside `validAccessToken()` can only
///   be exercised by writing to the test host's keychain. The tests below that do so write the
///   three `strava_*` keys and delete them again in a `defer`, and `testHostHasKeychainAccess`
///   fails loudly if the write did not land — a silently unavailable keychain would otherwise
///   turn those tests into no-ops. They clear any Strava tokens the test host's keychain already
///   held, which matters only if the same simulator was used to connect a real account.
///
/// What is left — the workout-to-activity mapping, the payload shape Strava decodes, and the
/// token response it returns — is what these cover.
@MainActor
struct StravaManagerTests {

    private static let accessKey = "strava_access_token"
    private static let refreshKey = "strava_refresh_token"
    private static let expiresKey = "strava_expires_at"

    /// Captures the activity uploaded and the refresh it was asked for.
    private final class CapturingStravaService: StravaService {
        private(set) var uploaded: [StravaActivity] = []
        private(set) var refreshTokensUsed: [String] = []
        private(set) var codesExchanged: [String] = []
        var refreshResponse = StravaTokenResponse(
            accessToken: "refreshed_access",
            refreshToken: "refreshed_refresh",
            expiresAt: Int(Date().timeIntervalSince1970) + 21_600
        )

        func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
            codesExchanged.append(code)
            return refreshResponse
        }

        func refreshToken(refreshToken: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
            refreshTokensUsed.append(refreshToken)
            return refreshResponse
        }

        func uploadActivity(_ activity: StravaActivity, accessToken: String) async throws {
            uploaded.append(activity)
        }
    }

    private func makeManager(service: StravaService) -> StravaManager {
        StravaManager(service: service, clientId: "client-id", clientSecret: "client-secret")
    }

    /// Writes the three token keys the manager reads, and removes them again afterwards.
    private func withStravaTokens(
        accessToken: String = "stored_access",
        refreshToken: String = "stored_refresh",
        expiresAt: Int,
        _ body: () async throws -> Void
    ) async rethrows {
        defer {
            KeychainHelper.delete(forKey: Self.accessKey)
            KeychainHelper.delete(forKey: Self.refreshKey)
            KeychainHelper.delete(forKey: Self.expiresKey)
        }
        KeychainHelper.save(accessToken, forKey: Self.accessKey, synchronizable: true)
        KeychainHelper.save(refreshToken, forKey: Self.refreshKey, synchronizable: true)
        KeychainHelper.save(String(expiresAt), forKey: Self.expiresKey, synchronizable: true)
        try await body()
    }

    private func session(
        name: String = "Push Day",
        dateCreated: Date,
        endedAt: Date?,
        notes: String? = nil
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            authorId: "author-1",
            name: name,
            dateCreated: dateCreated,
            endedAt: endedAt,
            notes: notes,
            exercises: []
        )
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - The keychain these tests depend on

    /// The tests that write tokens are only meaningful if the write lands. The unit-test bundle is
    /// hosted in the app, so it shares the app's keychain access — if that ever stops being true
    /// this fails rather than letting the upload tests quietly pass on an unreachable path.
    @Test("Test The Test Host Has Keychain Access")
    func testHostHasKeychainAccess() async {
        await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            #expect(KeychainHelper.read(forKey: Self.accessKey, synchronizable: true) == "stored_access")
        }

        #expect(KeychainHelper.read(forKey: Self.accessKey, synchronizable: true) == nil)
    }

    // MARK: - Mapping a workout to an activity

    /// The activity is all Strava ever sees of the session, so every field it carries comes from
    /// somewhere in the workout: the name shown in the feed, the sport that decides which stats
    /// Strava keeps, and an elapsed time measured from the session's own two timestamps rather
    /// than from when the upload happened.
    @Test("Test Uploading A Workout Maps Its Name Sport And Duration")
    func testUploadingAWorkoutMapsItsNameSportAndDuration() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let workout = session(
            name: "Upper Body A",
            dateCreated: start,
            endedAt: start.addingTimeInterval(3_600),
            notes: "Felt strong"
        )

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            try await manager.uploadWorkout(workout)
        }

        let activity = try #require(service.uploaded.first)
        #expect(activity.name == "Upper Body A")
        #expect(activity.sportType == "WeightTraining")
        #expect(activity.elapsedTime == 3_600)
        #expect(activity.startDateLocal == iso(start))
        #expect(activity.description == "Felt strong")
    }

    /// The elapsed time is truncated to whole seconds, and a session's timestamps rarely land on
    /// one — the `Int` conversion has to round down rather than trap on a fractional interval.
    @Test("Test Elapsed Time Truncates A Fractional Duration")
    func testElapsedTimeTruncatesAFractionalDuration() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let workout = session(dateCreated: start, endedAt: start.addingTimeInterval(1_805.9))

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            try await manager.uploadWorkout(workout)
        }

        #expect(service.uploaded.first?.elapsedTime == 1_805)
    }

    /// An in-progress session has no end, so there is no duration to send — uploading one would
    /// put a zero-length activity on the athlete's feed.
    @Test("Test An Unfinished Workout Is Not Uploaded")
    func testAnUnfinishedWorkoutIsNotUploaded() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)

        try await manager.uploadWorkout(session(dateCreated: Date(), endedAt: nil))

        #expect(service.uploaded.isEmpty)
        // The end date is checked before the token is, so this path needs no keychain at all.
        #expect(!manager.isUploading)
    }

    @Test("Test A Workout Without Notes Sends No Description")
    func testAWorkoutWithoutNotesSendsNoDescription() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            try await manager.uploadWorkout(session(dateCreated: start, endedAt: start.addingTimeInterval(600)))
        }

        #expect(service.uploaded.first?.description == nil)
    }

    /// `isUploading` drives a spinner, so it has to come back down when the upload returns —
    /// including when it throws, which is what the `defer` in the manager is for.
    @Test("Test Uploading Clears Its Progress Flag")
    func testUploadingClearsItsProgressFlag() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            try await manager.uploadWorkout(session(dateCreated: start, endedAt: start.addingTimeInterval(600)))
        }

        #expect(!manager.isUploading)
    }

    // MARK: - Tokens

    /// With no stored tokens there is nothing to upload with, and the manager has to say so rather
    /// than send an unauthenticated request.
    @Test("Test Uploading Without Tokens Reports Not Connected")
    func testUploadingWithoutTokensReportsNotConnected() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        // Clears whatever this simulator's keychain held, so the test does not depend on it.
        manager.disconnect()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        // `notConnected` is the only `StravaError` `uploadWorkout` can reach — the other two come
        // from the auth session.
        await #expect(throws: StravaError.self) {
            try await manager.uploadWorkout(session(dateCreated: start, endedAt: start.addingTimeInterval(600)))
        }

        #expect(service.uploaded.isEmpty)
        #expect(!manager.isConnected)
    }

    /// Strava access tokens last six hours. The manager refreshes anything expiring within the next
    /// minute, so an upload that starts just before the deadline does not fail mid-flight.
    @Test("Test An Almost Expired Token Is Refreshed Before Uploading")
    func testAnAlmostExpiredTokenIsRefreshedBeforeUploading() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 30) {
            try await manager.uploadWorkout(session(dateCreated: start, endedAt: start.addingTimeInterval(600)))

            #expect(service.refreshTokensUsed == ["stored_refresh"])
            // The refreshed pair replaces what was stored, or the next upload refreshes again.
            #expect(KeychainHelper.read(forKey: Self.accessKey, synchronizable: true) == "refreshed_access")
            #expect(KeychainHelper.read(forKey: Self.refreshKey, synchronizable: true) == "refreshed_refresh")
        }

        #expect(service.uploaded.count == 1)
    }

    @Test("Test A Valid Token Is Used Without Refreshing")
    func testAValidTokenIsUsedWithoutRefreshing() async throws {
        let service = CapturingStravaService()
        let manager = makeManager(service: service)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            try await manager.uploadWorkout(session(dateCreated: start, endedAt: start.addingTimeInterval(600)))

            #expect(service.refreshTokensUsed.isEmpty)
            #expect(KeychainHelper.read(forKey: Self.accessKey, synchronizable: true) == "stored_access")
        }
    }

    /// `isConnected` is what the settings screen reads, and disconnecting has to clear all three
    /// keys — a leftover access token would leave the app claiming a connection it cannot refresh.
    @Test("Test Disconnecting Clears The Stored Tokens")
    func testDisconnectingClearsTheStoredTokens() async throws {
        let manager = makeManager(service: CapturingStravaService())

        await withStravaTokens(expiresAt: Int(Date().timeIntervalSince1970) + 3_600) {
            #expect(manager.isConnected)

            manager.disconnect()

            #expect(!manager.isConnected)
            #expect(KeychainHelper.read(forKey: Self.refreshKey, synchronizable: true) == nil)
            #expect(KeychainHelper.read(forKey: Self.expiresKey, synchronizable: true) == nil)
        }
    }

    // MARK: - The wire format

    /// Strava's API is snake_case and rejects anything else, and these keys are hand-written rather
    /// than derived from a strategy.
    @Test("Test An Activity Encodes With Stravas Keys")
    func testAnActivityEncodesWithStravasKeys() throws {
        let activity = StravaActivity(
            name: "Leg Day",
            sportType: "WeightTraining",
            startDateLocal: "2026-09-22T08:00:00Z",
            elapsedTime: 2_700,
            description: "Squats"
        )

        let encoded = try JSONEncoder().encode(activity)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let json = try #require(object as? [String: Any])

        #expect(json["name"] as? String == "Leg Day")
        #expect(json["sport_type"] as? String == "WeightTraining")
        #expect(json["start_date_local"] as? String == "2026-09-22T08:00:00Z")
        #expect(json["elapsed_time"] as? Int == 2_700)
        #expect(json["description"] as? String == "Squats")
    }

    @Test("Test An Activity With No Description Omits The Key")
    func testAnActivityWithNoDescriptionOmitsTheKey() throws {
        let activity = StravaActivity(
            name: "Leg Day",
            sportType: "WeightTraining",
            startDateLocal: "2026-09-22T08:00:00Z",
            elapsedTime: 2_700,
            description: nil
        )

        let encoded = try JSONEncoder().encode(activity)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let json = try #require(object as? [String: Any])

        #expect(json["description"] == nil)
        #expect(json.keys.count == 4)
    }

    /// The token response is decoded straight off Strava's JSON, and `expires_at` is a Unix
    /// timestamp rather than a duration — reading it as seconds-from-now would make every token
    /// look decades stale.
    @Test("Test A Token Response Decodes From Stravas JSON")
    func testATokenResponseDecodesFromStravasJSON() throws {
        let json = """
        {
          "token_type": "Bearer",
          "access_token": "a1b2c3",
          "refresh_token": "d4e5f6",
          "expires_at": 1893456000,
          "expires_in": 21600
        }
        """

        let response = try JSONDecoder().decode(StravaTokenResponse.self, from: Data(json.utf8))

        #expect(response.accessToken == "a1b2c3")
        #expect(response.refreshToken == "d4e5f6")
        #expect(response.expiresAt == 1_893_456_000)
    }

    // MARK: - Errors

    /// These strings are shown in the alert the connect flow puts up, and are the only explanation
    /// anyone gets when Strava refuses.
    @Test("Test Every Strava Error Explains Itself")
    func testEveryStravaErrorExplainsItself() {
        #expect(StravaError.invalidURL.errorDescription == "Invalid Strava authorization URL.")
        #expect(StravaError.missingAuthCode.errorDescription == "No authorization code was returned from Strava.")
        #expect(StravaError.notConnected.errorDescription == "Not connected to Strava.")
    }

    @Test("Test A Strava Error Is Readable Through Localized Description")
    func testAStravaErrorIsReadableThroughLocalizedDescription() {
        // `LocalizedError` only reaches `localizedDescription` through the bridge, which is how
        // the alert's message is actually read.
        #expect(StravaError.notConnected.localizedDescription == "Not connected to Strava.")
    }
}
