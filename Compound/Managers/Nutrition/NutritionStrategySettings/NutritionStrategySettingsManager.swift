//
//  NutritionStrategySettingsManager.swift
//  Compound
//

import Foundation

@Observable
@MainActor
class NutritionStrategySettingsManager {

    private let settingsSyncEngine: DocumentSyncEngine<NutritionStrategySettings>
    private var userId: String?

    var nutritionStrategySettings: NutritionStrategySettings {
        settingsSyncEngine.currentDocument ?? NutritionStrategySettings(authorId: userId ?? "")
    }

    init(settingsSyncEngine: DocumentSyncEngine<NutritionStrategySettings>) {
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
            try await settingsSyncEngine.saveDocument(NutritionStrategySettings(authorId: userId))
        }
        try await settingsSyncEngine.startListening(documentId: "nutrition_strategy_settings")
    }

    func signOut() {
        settingsSyncEngine.stopListening()
    }

    func saveSettings(_ settings: NutritionStrategySettings) async throws {
        try await settingsSyncEngine.saveDocument(settings)
    }
}

extension CoreInteractor {
    // MARK: NutritionStrategySettingsManager

    var nutritionStrategySettings: NutritionStrategySettings {
        nutritionStrategySettingsManager.nutritionStrategySettings
    }

    func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws {
        try await nutritionStrategySettingsManager.saveSettings(settings)
    }
}
