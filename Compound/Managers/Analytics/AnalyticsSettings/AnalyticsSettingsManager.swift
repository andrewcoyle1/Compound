//
//  AnalyticsSettingsManager.swift
//  Compound
//

import Foundation

@Observable
@MainActor
class AnalyticsSettingsManager {

    private let settingsSyncEngine: DocumentSyncEngine<AnalyticsSettings>
    private var userId: String?

    var analyticsSettings: AnalyticsSettings {
        settingsSyncEngine.currentDocument ?? AnalyticsSettings(authorId: userId ?? "")
    }

    init(settingsSyncEngine: DocumentSyncEngine<AnalyticsSettings>) {
        self.settingsSyncEngine = settingsSyncEngine
    }

    // MARK: - Public Methods

    /// `isNewUser` — not a fetch-and-check — is what decides whether a default document gets
    /// created, matching `UserManager.signIn(auth:isNewUser:)`. See `FoodLogSettingsManager.signIn`
    /// for why: `startListening` does not wait for its listener's first emission, so reading
    /// `currentDocument` right after it returns races the listener, and `RemoteDocumentService`
    /// gives no way to catch "not found" separately from any other fetch failure.
    func signIn(userId: String, isNewUser: Bool) async throws {
        self.userId = userId
        if isNewUser {
            try await settingsSyncEngine.saveDocument(AnalyticsSettings(authorId: userId))
        }
        try await settingsSyncEngine.startListening(documentId: "analytics_settings")
    }

    func signOut() {
        settingsSyncEngine.stopListening()
    }

    func saveSettings(_ settings: AnalyticsSettings) async throws {
        try await settingsSyncEngine.saveDocument(settings)
    }
}

extension CoreInteractor {
    // MARK: AnalyticsSettingsManager

    var analyticsSettings: AnalyticsSettings {
        analyticsSettingsManager.analyticsSettings
    }

    func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws {
        try await analyticsSettingsManager.saveSettings(settings)
    }
}
