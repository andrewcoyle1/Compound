//
//  MockStravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation

final class MockStravaService: StravaService {
    private var athlete: StravaAthlete?

    init(athlete: StravaAthlete? = nil) {
        self.athlete = athlete
    }

    func connect(code: String?, refreshToken: String?, clientId: String) async throws -> StravaConnectResult {
        try await Task.sleep(for: .milliseconds(500))
        let athlete = StravaAthlete(id: 1, firstname: "Alex", lastname: "Runner", profile: nil)
        self.athlete = athlete
        return StravaConnectResult(accessToken: "mock_access", expiresAt: Int(Date().timeIntervalSince1970) + 21_600, athlete: athlete)
    }

    func connection() async throws -> StravaAthlete? { athlete }

    func accessToken() async throws -> StravaAccessToken {
        guard athlete != nil else { throw StravaError.notConnected }
        return StravaAccessToken(accessToken: "mock_access", expiresAt: Int(Date().timeIntervalSince1970) + 21_600)
    }

    func disconnect() async throws { athlete = nil }

    func upload(_ upload: StravaUpload, accessToken: String) async throws -> StravaUploadStatus {
        try await Task.sleep(for: .milliseconds(300))
        return StravaUploadStatus(id: 1, error: nil, activityId: 1)
    }

    func uploadStatus(id: Int, accessToken: String) async throws -> StravaUploadStatus {
        StravaUploadStatus(id: id, error: nil, activityId: 1)
    }

    func updateActivity(id: Int, name: String, description: String?, accessToken: String) async throws { }
}
