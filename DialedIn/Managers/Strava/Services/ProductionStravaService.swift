//
//  ProductionStravaService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation

struct ProductionStravaService: StravaService {

    // Safe: both are valid URL literals.
    private let tokenURL = URL(string: "https://www.strava.com/api/v3/oauth/token")!
    private let activitiesURL = URL(string: "https://www.strava.com/api/v3/activities")!

    func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    func refreshToken(refreshToken: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    func uploadActivity(_ activity: StravaActivity, accessToken: String) async throws {
        var request = URLRequest(url: activitiesURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(activity)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StravaUploadError.invalidResponse
        }
    }

    enum StravaUploadError: Error {
        case invalidResponse
    }
}
