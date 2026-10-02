//
//  ProductionStravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation
import FirebaseFunctions

struct ProductionStravaService: StravaService {

    private let functions = Functions.functions(region: "us-central1")
    // Safe: both are valid URL literals.
    private let activitiesURL = URL(string: "https://www.strava.com/api/v3/activities")!
    private let deauthorizeURL = URL(string: "https://www.strava.com/oauth/deauthorize")!

    func exchangeCodeForToken(code: String, clientId: String) async throws -> StravaTokenResponse {
        try await token(["clientId": clientId, "code": code])
    }

    func refreshToken(refreshToken: String, clientId: String) async throws -> StravaTokenResponse {
        try await token(["clientId": clientId, "refreshToken": refreshToken])
    }

    /// Through the `stravaToken` callable, which adds the client secret. It answers
    /// permission-denied when Strava refuses the grant.
    private func token(_ payload: [String: String]) async throws -> StravaTokenResponse {
        let result: HTTPSCallableResult
        do {
            result = try await functions.httpsCallable("stravaToken").call(payload)
        } catch let error as NSError
                    where error.domain == FunctionsErrorDomain && error.code == FunctionsErrorCode.permissionDenied.rawValue {
            throw StravaError.authorizationRevoked
        }
        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    func uploadActivity(_ activity: StravaActivity, accessToken: String) async throws {
        var request = URLRequest(url: activitiesURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(activity)
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299: return
        case 401: throw StravaError.authorizationRevoked
        default: throw StravaError.uploadFailed(status: status)
        }
    }

    func deauthorize(accessToken: String) async throws {
        var request = URLRequest(url: deauthorizeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }
}
