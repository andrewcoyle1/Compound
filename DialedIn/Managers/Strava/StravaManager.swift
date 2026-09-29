//
//  StravaManager.swift
//  DialedIn
//

import AuthenticationServices
import UIKit

@Observable
@MainActor
class StravaManager {

    private let service: StravaService
    private let clientId: String
    private let clientSecret: String
    private let contextProvider = StravaContextProvider()

    private var authSession: ASWebAuthenticationSession?

    var isConnected: Bool { KeychainHelper.read(forKey: "strava_access_token", synchronizable: true) != nil }
    var isUploading: Bool = false

    init(service: StravaService, clientId: String, clientSecret: String) {
        self.service = service
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    // MARK: - Auth

    func authenticate() async throws {
        let encodedClientId = clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId
        let urlString = "https://www.strava.com/oauth/mobile/authorize?client_id=\(encodedClientId)&redirect_uri=dialedinostrava://localhost/exchange_token&response_type=code&approval_prompt=auto&scope=activity:write"
        guard let authURL = URL(string: urlString) else {
            throw StravaError.invalidURL
        }

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "dialedinostrava"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: StravaError.missingAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }

        let tokenResponse = try await service.exchangeCodeForToken(code: code, clientId: clientId, clientSecret: clientSecret)
        storeTokens(tokenResponse)
    }

    func disconnect() {
        KeychainHelper.delete(forKey: "strava_access_token")
        KeychainHelper.delete(forKey: "strava_refresh_token")
        KeychainHelper.delete(forKey: "strava_expires_at")
    }

    // MARK: - Upload

    func uploadWorkout(_ session: WorkoutSessionModel) async throws {
        guard let endedAt = session.endedAt else { return }

        let accessToken = try await validAccessToken()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let activity = StravaActivity(
            name: session.name,
            sportType: "WeightTraining",
            startDateLocal: formatter.string(from: session.dateCreated),
            elapsedTime: Int(endedAt.timeIntervalSince(session.dateCreated)),
            description: session.notes
        )

        isUploading = true
        defer { isUploading = false }
        try await service.uploadActivity(activity, accessToken: accessToken)
    }

    func uploadTestActivity() async throws {
        let accessToken = try await validAccessToken()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = Date().addingTimeInterval(-1800)
        let activity = StravaActivity(
            name: "DialedIn Test Upload",
            sportType: "WeightTraining",
            startDateLocal: formatter.string(from: start),
            elapsedTime: 1800,
            description: "Test upload from DialedIn — safe to delete."
        )
        isUploading = true
        defer { isUploading = false }
        try await service.uploadActivity(activity, accessToken: accessToken)
    }

    // MARK: - Private Helpers

    private func validAccessToken() async throws -> String {
        guard let expiresAtString = KeychainHelper.read(forKey: "strava_expires_at", synchronizable: true),
              let expiresAt = Int(expiresAtString),
              let refreshToken = KeychainHelper.read(forKey: "strava_refresh_token", synchronizable: true) else {
            throw StravaError.notConnected
        }

        let now = Int(Date().timeIntervalSince1970)
        if now + 60 >= expiresAt {
            let tokenResponse = try await service.refreshToken(refreshToken: refreshToken, clientId: clientId, clientSecret: clientSecret)
            storeTokens(tokenResponse)
        }

        guard let accessToken = KeychainHelper.read(forKey: "strava_access_token", synchronizable: true) else {
            throw StravaError.notConnected
        }
        return accessToken
    }

    private func storeTokens(_ response: StravaTokenResponse) {
        KeychainHelper.save(response.accessToken, forKey: "strava_access_token", synchronizable: true)
        KeychainHelper.save(response.refreshToken, forKey: "strava_refresh_token", synchronizable: true)
        KeychainHelper.save(String(response.expiresAt), forKey: "strava_expires_at", synchronizable: true)
    }
}

// MARK: - Errors

enum StravaError: LocalizedError {
    case invalidURL
    case missingAuthCode
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Invalid Strava authorization URL.")
        case .missingAuthCode: return String(localized: "No authorization code was returned from Strava.")
        case .notConnected: return String(localized: "Not connected to Strava.")
        }
    }
}

private class StravaContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {

    /// The attribute is here only to scope an unavoidable deprecation, not because callers
    /// should stop using this: with no window scene at all there is nothing to present over,
    /// but the return type is non-optional and *every* spelling of a scene-less `UIWindow`
    /// (`init()`, `init(frame:)`, `ASPresentationAnchor()`) is deprecated as of iOS 26. Swift
    /// has no per-call suppression, so the warning is confined to this method — which only
    /// ASWebAuthenticationSession calls, never our own code. The branch is unreachable while
    /// the app has a foreground scene, which is the only state web auth can start from.
    @available(iOS, deprecated: 26.0, message: "Scopes the scene-less UIWindow fallback below.")
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first

        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            return window
        }
        if let scene {
            return UIWindow(windowScene: scene)
        }
        return UIWindow(frame: .zero)
    }
}
