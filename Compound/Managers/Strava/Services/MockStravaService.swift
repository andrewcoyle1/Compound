//
//  MockStravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation

struct MockStravaService: StravaService {
    func exchangeCodeForToken(code: String, clientId: String) async throws -> StravaTokenResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        return StravaTokenResponse(accessToken: "mock_access", refreshToken: "mock_refresh", expiresAt: Int(Date().timeIntervalSince1970) + 21600)
    }

    func refreshToken(refreshToken: String, clientId: String) async throws -> StravaTokenResponse {
        try await Task.sleep(nanoseconds: 200_000_000)
        return StravaTokenResponse(accessToken: "mock_access", refreshToken: refreshToken, expiresAt: Int(Date().timeIntervalSince1970) + 21600)
    }

    func uploadActivity(_ activity: StravaActivity, accessToken: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    func deauthorize(accessToken: String) async throws { }
}
