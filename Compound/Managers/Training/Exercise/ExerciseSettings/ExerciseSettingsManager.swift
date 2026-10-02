import Foundation

@Observable
@MainActor
class ExerciseSettingsManager {

    private let syncEngine: CollectionSyncEngine<ExerciseSettingsModel>
    private var userId: String?

    var allExerciseSettings: [ExerciseSettingsModel] {
        syncEngine.currentCollection
    }

    init(syncEngine: CollectionSyncEngine<ExerciseSettingsModel>) {
        self.syncEngine = syncEngine
    }

    func signIn(userId: String) async {
        self.userId = userId
        await syncEngine.startListening()
    }

    func signOut() {
        syncEngine.stopListening()
    }

    func settings(for exerciseId: String) -> ExerciseSettingsModel? {
        allExerciseSettings.first(where: { $0.id == exerciseId })
    }

    func note(for exerciseId: String) -> String? {
        let note = settings(for: exerciseId)?.note
        return note?.isEmpty == true ? nil : note
    }

    func setNote(_ note: String?, for exerciseId: String) async throws {
        var doc = settings(for: exerciseId) ?? ExerciseSettingsModel(id: exerciseId, authorId: userId ?? "")
        doc.note = (note?.isEmpty == true) ? nil : note
        try await syncEngine.saveDocument(doc)
    }

    func restOverride(for exerciseId: String) -> Int? {
        settings(for: exerciseId)?.restDurationOverride
    }

    func setRestOverride(_ seconds: Int?, for exerciseId: String) async throws {
        var doc = settings(for: exerciseId) ?? ExerciseSettingsModel(id: exerciseId, authorId: userId ?? "")
        doc.restDurationOverride = seconds
        try await syncEngine.saveDocument(doc)
    }
}

extension CoreInteractor {

    // MARK: ExerciseSettingsManager

    var allExerciseSettings: [ExerciseSettingsModel] {
        exerciseSettingsManager.allExerciseSettings
    }

    func exerciseNote(for exerciseId: String) -> String? {
        exerciseSettingsManager.note(for: exerciseId)
    }

    func setExerciseNote(_ note: String?, for exerciseId: String) async throws {
        try await exerciseSettingsManager.setNote(note, for: exerciseId)
    }

    func exerciseRestOverride(for exerciseId: String) -> Int? {
        exerciseSettingsManager.restOverride(for: exerciseId)
    }

    func setExerciseRestOverride(_ seconds: Int?, for exerciseId: String) async throws {
        try await exerciseSettingsManager.setRestOverride(seconds, for: exerciseId)
    }
}
