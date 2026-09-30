//
//  MesocycleManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/01/2026.
//

import Foundation

@Observable
@MainActor
class MesocycleManager {

    private let mesocycleSyncEngine: CollectionSyncEngine<Mesocycle>
    private let systemMesocyclePersistence: any LocalCollectionPersistence<Mesocycle>
    private let logManager: LogManager

    /// Injectable only so a test can point the seeding flags at storage of its own; the app
    /// always uses `.standard`, which is where the developer menu reads and clears the same keys.
    private let userDefaults: UserDefaults
    static let hasSeededKey = "hasSeededPrebuiltPrograms"
    static let seedingVersionKey = "prebuiltProgramsSeedingVersion"
    /// A literal rather than an entry in the gitignored `Keys.swift`, so adding it cannot break a
    /// checkout whose local `Keys.swift` predates it.
    static let systemManagerKey = "system_training_program"
    private static let currentSeedingVersion = 1

    var mesocycles: [Mesocycle] {
        mesocycleSyncEngine.currentCollection
    }

    var hasSeeded: Bool {
        userDefaults.bool(forKey: Self.hasSeededKey)
    }

    var seedingVersion: Int {
        userDefaults.integer(forKey: Self.seedingVersionKey)
    }

    /// The shipped mesocycle templates. Read-only: the user starts one by copying it.
    var prebuiltMesocycles: [Mesocycle] {
        (try? systemMesocyclePersistence.getCollection(managerKey: Self.systemManagerKey)) ?? []
    }

    init(
        mesocycleSyncEngine: CollectionSyncEngine<Mesocycle>,
        systemMesocyclePersistence: any LocalCollectionPersistence<Mesocycle>,
        logManager: LogManager,
        userDefaults: UserDefaults = .standard
    ) {
        self.mesocycleSyncEngine = mesocycleSyncEngine
        self.systemMesocyclePersistence = systemMesocyclePersistence
        self.logManager = logManager
        self.userDefaults = userDefaults
    }

    func signIn(userId: String) async {
        logManager.trackEvent(event: Event.signIn(userId: userId))
        await mesocycleSyncEngine.startListening()

        let loadedCount = mesocycleSyncEngine.currentCollection.count
        if loadedCount == 0 {
            logManager.trackEvent(event: Event.bulkLoadEmpty(userId: userId))
        } else {
            logManager.trackEvent(event: Event.bulkLoadSuccess(userId: userId, count: loadedCount))
        }
    }

    func signOut() {
        mesocycleSyncEngine.stopListening()
    }

    /// The mesocycle the user has chosen to follow, if it is one of theirs.
    func activeMesocycle(for user: UserModel?) -> Mesocycle? {
        guard let activeId = user?.submittedActiveMesocycleId else { return nil }
        return mesocycles.first { $0.id == activeId }
    }

    func saveMesocycle(mesocycle: Mesocycle) async throws {
        do {
            try await mesocycleSyncEngine.saveDocument(mesocycle)
        } catch {
            logManager.trackEvent(event: Event.saveFail(mesocycleId: mesocycle.id, error: error))
            throw error
        }
    }

    // MARK: DELETE

    func deleteMesocycle(mesocycleId: String) async throws {
        do {
            try await mesocycleSyncEngine.deleteDocument(id: mesocycleId)
        } catch {
            logManager.trackEvent(event: Event.deleteFail(mesocycleId: mesocycleId, error: error))
            throw error
        }
    }
}

// MARK: - Prebuilt Mesocycles

extension MesocycleManager {

    /// Seeds the mesocycle templates from `PrebuiltMesocycles.json`. The mesocycles name their days by
    /// system workout id, so this runs after workout templates are seeded and is handed them —
    /// the same ordering exercises → workouts already follows.
    func seedMesocyclesIfNeeded(workouts: [WorkoutTemplateModel]) throws {
        guard !hasSeeded || seedingVersion < Self.currentSeedingVersion else { return }
        // With no workouts every mesocycle drops; carrying on would delete the seeded mesocycles,
        // seed nothing, and mark the library done with no retry.
        guard !workouts.isEmpty else { return }

        let mesocycles = try loadPrebuiltMesocycles(workouts: workouts)
        guard !mesocycles.isEmpty else { return }

        for mesocycle in prebuiltMesocycles {
            try systemMesocyclePersistence.deleteDocument(managerKey: Self.systemManagerKey, id: mesocycle.id)
        }
        for mesocycle in mesocycles {
            try systemMesocyclePersistence.saveDocument(managerKey: Self.systemManagerKey, mesocycle)
        }
        userDefaults.set(true, forKey: Self.hasSeededKey)
        userDefaults.set(Self.currentSeedingVersion, forKey: Self.seedingVersionKey)
    }

    private func loadPrebuiltMesocycles(workouts: [WorkoutTemplateModel]) throws -> [Mesocycle] {
        guard let url = Bundle.main.url(forResource: "PrebuiltMesocycles", withExtension: "json") else {
            throw SeedingError.bundleNotFound
        }
        let container = try JSONDecoder().decode(PrebuiltMesocyclesContainer.self, from: Data(contentsOf: url))
        return container.mesocycles.compactMap { $0.toModel(workouts: workouts) }
    }

    /// The user's own copy of a template: new ids throughout and the user as author, so editing
    /// or deleting it never touches the shipped one. Same rules as accepting a shared mesocycle.
    static func copy(of mesocycle: Mesocycle, authorId: String) -> Mesocycle {
        let result = SharedItemCopier.copy(.mesocycle(mesocycle), recipientId: authorId, library: [])
        guard case .mesocycle(let copy) = result.payload else {
            preconditionFailure("Copying a program always yields a program")
        }
        return copy
    }
}

struct PrebuiltMesocyclesContainer: Codable {
    let mesocycles: [PrebuiltMesocycleDTO]
}

struct PrebuiltMesocycleDTO: Codable {
    /// A day entry that is not a workout id.
    static let restDay = "rest"

    let mesocycleId: String
    let name: String
    let icon: String
    let colour: String
    let numMicrocycles: Int
    let deload: DeloadType
    let periodisation: Bool
    /// One entry per day of the microcycle: a system workout id, or `restDay`.
    let days: [String]

    /// Nil when any named workout is missing — a split with a day silently dropped is a
    /// different mesocycle, not a smaller one.
    func toModel(workouts: [WorkoutTemplateModel]) -> Mesocycle? {
        var templates: [WorkoutTemplateModel] = []
        for (index, day) in days.enumerated() {
            if day == Self.restDay {
                templates.append(WorkoutTemplateModel(id: "\(mesocycleId)-rest-\(index)", authorId: "official", name: "Rest Day"))
            } else if let workout = workouts.first(where: { $0.id == day }) {
                templates.append(workout)
            } else {
                return nil
            }
        }
        guard templates.contains(where: { !$0.exercises.isEmpty }) else { return nil }
        return Mesocycle(
            id: mesocycleId,
            authorId: "official",
            name: name,
            icon: icon,
            colour: colour,
            numMicrocycles: numMicrocycles,
            deload: deload,
            periodisation: periodisation,
            workoutTemplates: templates
        )
    }
}

extension MesocycleManager {
    enum Event: LoggableEvent {
        case signIn(userId: String)
        case bulkLoadSuccess(userId: String, count: Int)
        case bulkLoadEmpty(userId: String)
        case saveFail(mesocycleId: String, error: Error)
        case deleteFail(mesocycleId: String, error: Error)

        var eventName: String {
            switch self {
            case .signIn:           return "training_program_signIn"
            case .bulkLoadSuccess:  return "training_program_bulkLoad_success"
            case .bulkLoadEmpty:    return "training_program_bulkLoad_empty"
            case .saveFail:         return "training_program_save_fail"
            case .deleteFail:       return "training_program_delete_fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .signIn(let userId):
                return ["user_id": userId]
            case .bulkLoadSuccess(let userId, let count):
                return ["user_id": userId, "count": count]
            case .bulkLoadEmpty(let userId):
                return ["user_id": userId]
            case .saveFail(let mesocycleId, let error):
                return [
                    "program_id": mesocycleId,
                    "error_description": "\(error)",
                    "error_localized": error.localizedDescription
                ]
            case .deleteFail(let mesocycleId, let error):
                return [
                    "program_id": mesocycleId,
                    "error_description": "\(error)",
                    "error_localized": error.localizedDescription
                ]
            }
        }

        var type: LogType {
            switch self {
            case .saveFail, .deleteFail:    return .severe
            case .bulkLoadEmpty:            return .severe
            default:                        return .analytic
            }
        }
    }
}

extension CoreInteractor {
    // MARK: MesocycleManager

    var activeMesocycle: Mesocycle? {
        mesocycleManager.activeMesocycle(for: currentUser)
    }

    var mesocycles: [Mesocycle] {
        mesocycleManager.mesocycles
    }

    func saveMesocycle(mesocycle: Mesocycle) async throws {
        try await mesocycleManager.saveMesocycle(mesocycle: mesocycle)
    }

    func deleteMesocycle(mesocycleId: String) async throws {
        try await mesocycleManager.deleteMesocycle(mesocycleId: mesocycleId)
    }

    var prebuiltMesocycles: [Mesocycle] {
        mesocycleManager.prebuiltMesocycles
    }

    /// Copies a template under the current user and makes the copy their active mesocycle.
    @discardableResult
    func startPrebuiltMesocycle(_ mesocycle: Mesocycle) async throws -> Mesocycle {
        guard let userId else { throw CoreError.noCurrentUser }
        let copy = MesocycleManager.copy(of: mesocycle, authorId: userId)
        try await saveMesocycle(mesocycle: copy)
        try await setActiveMesocycle(mesocycleId: copy.id)
        return copy
    }
}
