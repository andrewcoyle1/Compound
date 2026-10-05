//
//  StravaAthlete.swift
//  Compound
//
//  The Strava account a Compound account is connected to, as the server stored it at connect.
//

import Foundation

struct StravaAthlete: Codable, Equatable {
    let id: Int
    let firstname: String?
    let lastname: String?
    /// The avatar's URL.
    let profile: String?

    /// The server stores a missing name as "".
    var name: String {
        [firstname, lastname].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// A short-lived access token the server hands out; the refresh token never leaves it.
struct StravaAccessToken: Codable, Equatable {
    let accessToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresAt = "expires_at"
    }
}

/// What `stravaConnect` answers.
struct StravaConnectResult: Decodable, Equatable {
    let accessToken: String
    let expiresAt: Int
    let athlete: StravaAthlete

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresAt = "expires_at"
        case athlete
    }

    var token: StravaAccessToken { StravaAccessToken(accessToken: accessToken, expiresAt: expiresAt) }
}
