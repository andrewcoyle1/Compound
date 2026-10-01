import Foundation

@Observable
@MainActor
class FoodLogSettingsManager {

    private let foodLogSettingsSyncEngine: DocumentSyncEngine<FoodLogSettings>
    private var userId: String?

    var foodLogSettings: FoodLogSettings {
        foodLogSettingsSyncEngine.currentDocument ?? FoodLogSettings(authorId: userId ?? "")
    }

    init(foodLogSettingsSyncEngine: DocumentSyncEngine<FoodLogSettings>) {
        self.foodLogSettingsSyncEngine = foodLogSettingsSyncEngine
    }

    // MARK: - Public Methods

    /// `isNewUser` — not a fetch-and-check — is what decides whether a default document gets
    /// created, matching `UserManager.signIn(auth:isNewUser:)`.
    ///
    /// `startListening` does not wait for its listener's first emission (it spawns a `Task` and
    /// returns), so `currentDocument` is not a reliable answer to "does this user already have a
    /// document" immediately after it returns — reading it there races the listener and can
    /// overwrite an existing document (favourites included) with a blank one before the listener
    /// ever delivers the real one. Fetching first to decide does not fix this either:
    /// `RemoteDocumentService.getDocument(id:)` is documented to throw for "not found *or* fetch
    /// fails" — Mock and Firebase both collapse those into one error, so there is no reliable way
    /// to catch only "not found" here. `isNewUser` is a fact already known from auth, not
    /// something this manager has to infer.
    func signIn(userId: String, isNewUser: Bool) async throws {
        self.userId = userId
        if isNewUser {
            try await foodLogSettingsSyncEngine.saveDocument(FoodLogSettings(authorId: userId))
        }
        try await foodLogSettingsSyncEngine.startListening(documentId: "food_log_settings")
    }

    func signOut() {
        foodLogSettingsSyncEngine.stopListening()
    }

    func saveSettings(_ settings: FoodLogSettings) async throws {
        try await foodLogSettingsSyncEngine.saveDocument(settings)
    }
}

extension CoreInteractor {
    // MARK: FoodLogSettingsManager

    var foodLogSettings: FoodLogSettings {
        foodLogSettingsManager.foodLogSettings
    }

    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws {
        try await foodLogSettingsManager.saveSettings(settings)
    }

    // MARK: Favourites

    func isFavouriteFood(id: String) -> Bool {
        foodLogSettings.favouriteFoodIds.contains(id)
    }

    func isFavouriteRecipe(id: String) -> Bool {
        foodLogSettings.favouriteRecipeIds.contains(id)
    }

    func setFavouriteFood(id: String, isFavourite: Bool) async throws {
        var settings = foodLogSettings
        settings.favouriteFoodIds = Self.updating(settings.favouriteFoodIds, id: id, isMember: isFavourite)
        try await foodLogSettingsManager.saveSettings(settings)
    }

    func setFavouriteRecipe(id: String, isFavourite: Bool) async throws {
        var settings = foodLogSettings
        settings.favouriteRecipeIds = Self.updating(settings.favouriteRecipeIds, id: id, isMember: isFavourite)
        try await foodLogSettingsManager.saveSettings(settings)
    }

    /// An array rather than a Set, because the settings document is Codable and a Set would change
    /// how it serialises. Duplicates are still avoided.
    private static func updating(_ ids: [String], id: String, isMember: Bool) -> [String] {
        guard isMember else { return ids.filter { $0 != id } }
        return ids.contains(id) ? ids : ids + [id]
    }
}
