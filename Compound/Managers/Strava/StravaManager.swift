//
//  StravaManager.swift
//  Compound
//
//  The connection to Strava. Its tokens live on the server (`strava_connections/{uid}`, behind
//  the `strava*` callables), so the connection belongs to the Compound account rather than the
//  device: signing out keeps it, and signing in on another phone finds it. The app holds only a
//  short-lived access token, in memory.
//
//  Uploads are in `StravaManager+Uploads.swift`.
//

import AuthenticationServices
import UIKit

@Observable
@MainActor
class StravaManager {

    let service: StravaService
    let sessions: WorkoutSessionManager
    let exercises: ExerciseModelManager
    let users: UserManager
    let logger: LogManager
    let defaults: UserDefaults
    let pollInterval: Duration
    let pollAttempts: Int
    private let clientId: String
    private let activitySyncEngine: CollectionSyncEngine<StravaImportedActivity>
    private let contextProvider = StravaContextProvider()
    private var authSession: ASWebAuthenticationSession?
    private var cachedToken: StravaAccessToken?

    /// The local-persistence name of the imported activities. Here rather than in `Keys` because
    /// it is not a secret, and must stay stable like the others.
    static let importedActivitiesManagerKey = "strava_imported_activities"

    /// The Strava account this Compound account is connected to, `nil` when it is not. Kept per
    /// account so the app knows at launch, and refreshed from the server at sign-in and whenever
    /// Integrations opens.
    private(set) var athlete: StravaAthlete?
    var isConnected: Bool { athlete != nil }
    private(set) var userId: String?

    /// Sessions waiting to go to Strava, oldest first: kept per account across launches and sent
    /// at sign-in and after each finished workout, like a sync engine's pending writes.
    var pendingSessionIds: [String] = []
    var isSyncingUploads = false

    /// Runs and rides from Strava, for this account's own screens only.
    var importedActivities: [StravaImportedActivity] { activitySyncEngine.currentCollection }

    init(
        service: StravaService,
        clientId: String,
        activitySyncEngine: CollectionSyncEngine<StravaImportedActivity>,
        sessions: WorkoutSessionManager,
        exercises: ExerciseModelManager,
        users: UserManager,
        logger: LogManager,
        defaults: UserDefaults = .standard,
        pollInterval: Duration = .seconds(1),
        pollAttempts: Int = 10
    ) {
        self.service = service
        self.clientId = clientId
        self.activitySyncEngine = activitySyncEngine
        self.sessions = sessions
        self.exercises = exercises
        self.users = users
        self.logger = logger
        self.defaults = defaults
        self.pollInterval = pollInterval
        self.pollAttempts = pollAttempts
    }

    // MARK: - Lifecycle

    /// Call once the account's sessions are loaded: the queue is sent from them.
    func signIn(userId: String) async {
        self.userId = userId
        athlete = (defaults.data(forKey: Self.athleteKey(userId))).flatMap { try? JSONDecoder().decode(StravaAthlete.self, from: $0) }
        pendingSessionIds = defaults.stringArray(forKey: Self.pendingKey(userId)) ?? []
        await activitySyncEngine.startListening()
        await migrateDeviceTokensIfNeeded()
        try? await refreshConnection()
        await syncPendingUploads()
    }

    /// Forgets this account's state on the device. The connection itself stays with the account.
    func signOut() {
        activitySyncEngine.stopListening()
        userId = nil
        athlete = nil
        cachedToken = nil
        pendingSessionIds = []
    }

    func refreshConnection() async throws {
        setAthlete(try await service.connection())
    }

    // MARK: - Auth

    func authenticate() async throws {
        let encodedClientId = clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId
        // Reading activities is asked for but not required: the athlete may untick it, and then
        // nothing is imported.
        let urlString = "https://www.strava.com/oauth/mobile/authorize?client_id=\(encodedClientId)&redirect_uri=compoundstrava://localhost/exchange_token&response_type=code&approval_prompt=auto&scope=activity:write,activity:read_all"
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
        let result = try await service.connect(code: code, refreshToken: nil, clientId: clientId)
        cachedToken = result.token
        setAthlete(result.athlete)
    }

    /// The code from Strava's redirect. Strava lets the athlete untick the upload permission on its
    /// consent page and still redirects with a code; connecting then would leave every upload
    /// refused, so that is turned away here.
    static func authorizationCode(from callbackURL: URL) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw StravaError.missingAuthCode
        }
        // Comma- or space-delimited: Strava documents both.
        let scopes = items.first { $0.name == "scope" }?.value?.split { $0 == "," || $0 == " " } ?? []
        guard scopes.contains("activity:write") else {
            throw StravaError.missingUploadPermission
        }
        return code
    }

    /// Revokes Compound at Strava and deletes the connection and the imported activities on the
    /// server. Nothing changes here unless that worked, so a failure leaves the account connected
    /// rather than claiming otherwise.
    func disconnect() async throws {
        try await service.disconnect()
        setAthlete(nil)
        pendingSessionIds = []
        savePendingUploads()
    }

    // MARK: - Tokens

    /// A 401 gets one fresh token and one retry. If Strava still refuses, or the server has no
    /// connection, the account is not connected and Integrations says so.
    func withAccessToken<T>(_ body: (String) async throws -> T) async throws -> T {
        do {
            do {
                return try await body(try await validAccessToken())
            } catch StravaError.authorizationRevoked {
                cachedToken = nil
                return try await body(try await validAccessToken())
            }
        } catch StravaError.authorizationRevoked, StravaError.notConnected {
            setAthlete(nil)
            throw StravaError.notConnected
        }
    }

    private func validAccessToken() async throws -> String {
        if let cachedToken, cachedToken.expiresAt > Int(Date().timeIntervalSince1970) + 60 {
            return cachedToken.accessToken
        }
        let token = try await service.accessToken()
        cachedToken = token
        return token.accessToken
    }

    /// Builds before the server held the tokens kept them in the iCloud Keychain. The first
    /// sign-in after updating hands the refresh token to the server and forgets it here.
    private func migrateDeviceTokensIfNeeded() async {
        guard let refreshToken = KeychainHelper.read(forKey: Self.legacyRefreshTokenKey, synchronizable: true) else { return }
        do {
            let result = try await service.connect(code: nil, refreshToken: refreshToken, clientId: clientId)
            cachedToken = result.token
            setAthlete(result.athlete)
            clearDeviceTokens()
        } catch StravaError.authorizationRevoked {
            clearDeviceTokens()
        } catch {
            // Offline, most likely: the next sign-in tries again.
        }
    }

    private func clearDeviceTokens() {
        for key in ["strava_access_token", Self.legacyRefreshTokenKey, "strava_expires_at"] {
            KeychainHelper.delete(forKey: key)
        }
    }

    // MARK: - Persistence

    static let legacyRefreshTokenKey = "strava_refresh_token"
    static func athleteKey(_ userId: String) -> String { "strava_athlete_\(userId)" }
    static func pendingKey(_ userId: String) -> String { "strava_pending_uploads_\(userId)" }

    private func setAthlete(_ athlete: StravaAthlete?) {
        self.athlete = athlete
        if athlete == nil { cachedToken = nil }
        guard let userId else { return }
        if let athlete, let data = try? JSONEncoder().encode(athlete) {
            defaults.set(data, forKey: Self.athleteKey(userId))
        } else {
            defaults.removeObject(forKey: Self.athleteKey(userId))
        }
    }

    func savePendingUploads() {
        guard let userId else { return }
        defaults.set(pendingSessionIds, forKey: Self.pendingKey(userId))
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
    /// Over Strava's request limit (200 every 15 minutes, 2,000 a day by default).
    case rateLimited
    /// Strava took the upload and then could not make an activity of it, with its reason.
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Invalid Strava authorization URL.")
        case .missingAuthCode: return String(localized: "No authorization code was returned from Strava.")
        case .missingUploadPermission: return String(localized: "Allow Compound to upload your activities to connect Strava.")
        case .notConnected, .authorizationRevoked: return String(localized: "Not connected to Strava.")
        case .uploadFailed(let status): return String(localized: "Strava did not accept the upload (\(status)).")
        case .processingFailed: return String(localized: "Strava could not process the workout.")
        case .rateLimited: return String(localized: "Strava is busy. Your workouts will upload later.")
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
