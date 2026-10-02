//
//  StravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol StravaService {
    func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse
    func refreshToken(refreshToken: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse
    func uploadActivity(_ activity: StravaActivity, accessToken: String) async throws
}
