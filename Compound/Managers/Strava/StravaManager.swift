//
//  StravaManager.swift
//  Compound
//

import AuthenticationServices
import UIKit

@Observable
@MainActor
class StravaManager {

    private let service: StravaService
    private let clientId: String
    private let contextProvider = StravaContextProvider()

    private var authSession: ASWebAuthenticationSession?

    var isConnected: Bool { KeychainHelper.read(forKey: "strava_access_token", synchronizable: true) != nil }

    /// The client secret is not here: the code exchange and refreshes go through the `stravaToken`
    /// Cloud Function, which holds it.
    init(service: StravaService, clientId: String) {
        self.service = service
        self.clientId = clientId
    }

    // MARK: - Auth

    func authenticate() async throws {
        let encodedClientId = clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId
        let urlString = "https://www.strava.com/oauth/mobile/authorize?client_id=\(encodedClientId)&redirect_uri=compoundstrava://localhost/exchange_token&response_type=code&approval_prompt=auto&scope=activity:write"
        guard let authURL = URL(string: urlString) else {
            throw StravaError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "compoundstrava"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: StravaError.missingAuthCode)
                }
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }

        let code = try Self.authorizationCode(from: callbackURL)
        let tokenResponse = try await service.exchangeCodeForToken(code: code, clientId: clientId)
        storeTokens(tokenResponse)
    }

    /// The code from Strava's redirect. Strava lets the athlete untick the upload permission on its
    /// consent page and still redirects with a code; connecting then would leave every upload
    /// refused, so that is turned away here.
    static func authorizationCode(from callbackURL: URL) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw StravaError.missingAuthCode
        }
        let scopes = items.first { $0.name == "scope" }?.value?.split(separator: ",") ?? []
        guard scopes.contains("activity:write") else {
            throw StravaError.missingUploadPermission
        }
        return code
    }

    /// Forgets the tokens and asks Strava to revoke them, so Compound also leaves the athlete's
    /// authorized apps. The revoke is best-effort: the tokens are gone from here either way.
    func disconnect() {
        let accessToken = KeychainHelper.read(forKey: "strava_access_token", synchronizable: true)
        clearTokens()
        guard let accessToken else { return }
        Task { try? await service.deauthorize(accessToken: accessToken) }
    }

    // MARK: - Upload

    func uploadWorkout(_ session: WorkoutSessionModel) async throws {
        guard let duration = session.activeDuration else { return }
        try await upload(StravaActivity(
            name: session.name,
            sportType: "WeightTraining",
            startDateLocal: Self.localDateString(session.dateCreated),
            elapsedTime: Int(duration),
            description: session.notes
        ))
    }

    func uploadTestActivity() async throws {
        try await upload(StravaActivity(
            name: "Compound Test Upload",
            sportType: "WeightTraining",
            startDateLocal: Self.localDateString(Date().addingTimeInterval(-1800)),
            elapsedTime: 1800,
            description: "Test upload from Compound — safe to delete."
        ))
    }

    /// Strava reads `start_date_local` as wall-clock time where the athlete is, whatever zone
    /// designator it carries, so it is written in the device's zone with none.
    static func localDateString(_ date: Date, in timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    // MARK: - Private Helpers

    /// A 401 on a token believed valid gets one forced refresh and one retry. If Strava still
    /// refuses — access revoked, or the upload permission withdrawn — the connection is useless, so
    /// it is dropped and Integrations stops claiming it.
    private func upload(_ activity: StravaActivity) async throws {
        do {
            do {
                try await service.uploadActivity(activity, accessToken: try await validAccessToken())
            } catch StravaError.authorizationRevoked {
                try await service.uploadActivity(activity, accessToken: try await validAccessToken(forceRefresh: true))
            }
        } catch StravaError.authorizationRevoked {
            clearTokens()
            throw StravaError.notConnected
        }
    }

    private func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        guard let expiresAtString = KeychainHelper.read(forKey: "strava_expires_at", synchronizable: true),
              let expiresAt = Int(expiresAtString),
              let refreshToken = KeychainHelper.read(forKey: "strava_refresh_token", synchronizable: true) else {
            throw StravaError.notConnected
        }

        let now = Int(Date().timeIntervalSince1970)
        if forceRefresh || now + 60 >= expiresAt {
            let tokenResponse = try await service.refreshToken(refreshToken: refreshToken, clientId: clientId)
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

    private func clearTokens() {
        KeychainHelper.delete(forKey: "strava_access_token")
        KeychainHelper.delete(forKey: "strava_refresh_token")
        KeychainHelper.delete(forKey: "strava_expires_at")
    }
}

// MARK: - Errors

enum StravaError: LocalizedError, Equatable {
    case invalidURL
    case missingAuthCode
    case missingUploadPermission
    case notConnected
    /// Strava refused the token: the athlete revoked access or withdrew the upload permission.
    case authorizationRevoked
    case uploadFailed(status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Invalid Strava authorization URL.")
        case .missingAuthCode: return String(localized: "No authorization code was returned from Strava.")
        case .missingUploadPermission: return String(localized: "Allow Compound to upload your activities to connect Strava.")
        case .notConnected, .authorizationRevoked: return String(localized: "Not connected to Strava.")
        case .uploadFailed(let status): return String(localized: "Strava did not accept the upload (\(status)).")
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
