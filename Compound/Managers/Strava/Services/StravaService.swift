//
//  StravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

/// The connection and its tokens live on the server, behind the `strava*` callables; the app only
/// ever holds a short-lived access token, which it uses to talk to Strava directly.
@MainActor
protocol StravaService {
    /// Exchanges an authorization code, or migrates a refresh token an older build kept on the
    /// device. Exactly one of the two is given.
    func connect(code: String?, refreshToken: String?, clientId: String) async throws -> StravaConnectResult
    /// `nil` when this account is not connected.
    func connection() async throws -> StravaAthlete?
    func accessToken() async throws -> StravaAccessToken
    func disconnect() async throws

    /// Starts an upload. A refusal Strava explains, such as a duplicate, comes back as a status
    /// carrying the `error` rather than thrown.
    func upload(_ upload: StravaUpload, accessToken: String) async throws -> StravaUploadStatus
    func uploadStatus(id: Int, accessToken: String) async throws -> StravaUploadStatus
    func updateActivity(id: Int, name: String, description: String?, accessToken: String) async throws
}

/// The form fields sent with the file. `externalId` is what Strava deduplicates on.
struct StravaUpload: Equatable {
    let name: String
    let description: String?
    let externalId: String
    let file: StravaStrengthFile
}
