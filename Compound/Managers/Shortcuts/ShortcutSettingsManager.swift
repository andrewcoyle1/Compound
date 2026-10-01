//
//  ShortcutSettingsManager.swift
//  Compound
//

import Foundation

@Observable
@MainActor
class ShortcutSettingsManager {

    private let settingsSyncEngine: DocumentSyncEngine<ShortcutSettings>
    private var userId: String?

    var shortcutSettings: ShortcutSettings {
        settingsSyncEngine.currentDocument ?? ShortcutSettings(authorId: userId ?? "")
    }

    init(settingsSyncEngine: DocumentSyncEngine<ShortcutSettings>) {
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
            try await settingsSyncEngine.saveDocument(ShortcutSettings(authorId: userId))
        }
        try await settingsSyncEngine.startListening(documentId: "shortcut_settings")
    }

    func signOut() {
        settingsSyncEngine.stopListening()
    }

    func saveSettings(_ settings: ShortcutSettings) async throws {
        try await settingsSyncEngine.saveDocument(settings)
    }
}

extension CoreInteractor {
    // MARK: ShortcutSettingsManager

    var shortcutSettings: ShortcutSettings {
        shortcutSettingsManager.shortcutSettings
    }

    func saveShortcutSettings(_ settings: ShortcutSettings) async throws {
        try await shortcutSettingsManager.saveSettings(settings)
    }
}
