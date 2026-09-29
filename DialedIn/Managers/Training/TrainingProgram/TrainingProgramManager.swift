//
//  TrainingProgramManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/01/2026.
//

import Foundation

@Observable
@MainActor
class TrainingProgramManager {

    private let trainingProgramSyncEngine: CollectionSyncEngine<TrainingProgram>
    private let systemProgramPersistence: any LocalCollectionPersistence<TrainingProgram>
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

    var trainingPrograms: [TrainingProgram] {
        trainingProgramSyncEngine.currentCollection
    }

    var hasSeeded: Bool {
        userDefaults.bool(forKey: Self.hasSeededKey)
    }

    var seedingVersion: Int {
        userDefaults.integer(forKey: Self.seedingVersionKey)
    }

    /// The shipped program templates. Read-only: the user starts one by copying it.
    var prebuiltPrograms: [TrainingProgram] {
        (try? systemProgramPersistence.getCollection(managerKey: Self.systemManagerKey)) ?? []
    }

    init(
        trainingProgramSyncEngine: CollectionSyncEngine<TrainingProgram>,
        systemProgramPersistence: any LocalCollectionPersistence<TrainingProgram>,
        logManager: LogManager,
        userDefaults: UserDefaults = .standard
    ) {
        self.trainingProgramSyncEngine = trainingProgramSyncEngine
        self.systemProgramPersistence = systemProgramPersistence
        self.logManager = logManager
        self.userDefaults = userDefaults
    }

    func signIn(userId: String) async {
        logManager.trackEvent(event: Event.signIn(userId: userId))
        await trainingProgramSyncEngine.startListening()

        let loadedCount = trainingProgramSyncEngine.currentCollection.count
        if loadedCount == 0 {
            logManager.trackEvent(event: Event.bulkLoadEmpty(userId: userId))
        } else {
            logManager.trackEvent(event: Event.bulkLoadSuccess(userId: userId, count: loadedCount))
        }
    }

    func signOut() {
        trainingProgramSyncEngine.stopListening()
    }

    /// The program the user has chosen to follow, if it is one of theirs.
    func activeProgram(for user: UserModel?) -> TrainingProgram? {
        guard let activeId = user?.submittedActiveTrainingProgramId else { return nil }
        return trainingPrograms.first { $0.id == activeId }
    }

    func saveTrainingProgram(trainingProgram: TrainingProgram) async throws {
        do {
            try await trainingProgramSyncEngine.saveDocument(trainingProgram)
        } catch {
            logManager.trackEvent(event: Event.saveFail(programId: trainingProgram.id, error: error))
            throw error
        }
    }

    // MARK: DELETE

    func deleteTrainingProgram(programId: String) async throws {
        do {
            try await trainingProgramSyncEngine.deleteDocument(id: programId)
        } catch {
            logManager.trackEvent(event: Event.deleteFail(programId: programId, error: error))
            throw error
        }
    }
}

// MARK: - Prebuilt Programs

extension TrainingProgramManager {

    /// Seeds the program templates from `PrebuiltPrograms.json`. The programs name their days by
    /// system workout id, so this runs after workout templates are seeded and is handed them —
    /// the same ordering exercises → workouts already follows.
    func seedProgramsIfNeeded(workouts: [WorkoutTemplateModel]) throws {
        guard !hasSeeded || seedingVersion < Self.currentSeedingVersion else { return }
        // With no workouts every program drops; carrying on would delete the seeded programs,
        // seed nothing, and mark the library done with no retry.
        guard !workouts.isEmpty else { return }

        let programs = try loadPrebuiltPrograms(workouts: workouts)
        guard !programs.isEmpty else { return }

        for program in prebuiltPrograms {
            try systemProgramPersistence.deleteDocument(managerKey: Self.systemManagerKey, id: program.id)
        }
        for program in programs {
            try systemProgramPersistence.saveDocument(managerKey: Self.systemManagerKey, program)
        }
        userDefaults.set(true, forKey: Self.hasSeededKey)
        userDefaults.set(Self.currentSeedingVersion, forKey: Self.seedingVersionKey)
    }

    private func loadPrebuiltPrograms(workouts: [WorkoutTemplateModel]) throws -> [TrainingProgram] {
        guard let url = Bundle.main.url(forResource: "PrebuiltPrograms", withExtension: "json") else {
            throw SeedingError.bundleNotFound
        }
        let container = try JSONDecoder().decode(PrebuiltProgramsContainer.self, from: Data(contentsOf: url))
        return container.programs.compactMap { $0.toModel(workouts: workouts) }
    }

    /// The user's own copy of a template: new ids throughout and the user as author, so editing
    /// or deleting it never touches the shipped one. Same rules as accepting a shared program.
    static func copy(of program: TrainingProgram, authorId: String) -> TrainingProgram {
        let result = SharedItemCopier.copy(.program(program), recipientId: authorId, library: [])
        guard case .program(let copy) = result.payload else {
            preconditionFailure("Copying a program always yields a program")
        }
        return copy
    }
}

struct PrebuiltProgramsContainer: Codable {
    let programs: [PrebuiltProgramDTO]
}

struct PrebuiltProgramDTO: Codable {
    /// A day entry that is not a workout id.
    static let restDay = "rest"

    let programId: String
    let name: String
    let icon: String
    let colour: String
    let numMicrocycles: Int
    let deload: DeloadType
    let periodisation: Bool
    /// One entry per day of the microcycle: a system workout id, or `restDay`.
    let days: [String]

    /// Nil when any named workout is missing — a split with a day silently dropped is a
    /// different program, not a smaller one.
    func toModel(workouts: [WorkoutTemplateModel]) -> TrainingProgram? {
        var templates: [WorkoutTemplateModel] = []
        for (index, day) in days.enumerated() {
            if day == Self.restDay {
                templates.append(WorkoutTemplateModel(id: "\(programId)-rest-\(index)", authorId: "official", name: "Rest Day"))
            } else if let workout = workouts.first(where: { $0.id == day }) {
                templates.append(workout)
            } else {
                return nil
            }
        }
        guard templates.contains(where: { !$0.exercises.isEmpty }) else { return nil }
        return TrainingProgram(
            id: programId,
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

extension TrainingProgramManager {
    enum Event: LoggableEvent {
        case signIn(userId: String)
        case bulkLoadSuccess(userId: String, count: Int)
        case bulkLoadEmpty(userId: String)
        case saveFail(programId: String, error: Error)
        case deleteFail(programId: String, error: Error)

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
            case .saveFail(let programId, let error):
                return [
                    "program_id": programId,
                    "error_description": "\(error)",
                    "error_localized": error.localizedDescription
                ]
            case .deleteFail(let programId, let error):
                return [
                    "program_id": programId,
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
    // MARK: TrainingProgramManager

    var activeTrainingProgram: TrainingProgram? {
        trainingProgramManager.activeProgram(for: currentUser)
    }

    var trainingPrograms: [TrainingProgram] {
        trainingProgramManager.trainingPrograms
    }

    func saveTrainingProgram(trainingProgram: TrainingProgram) async throws {
        try await trainingProgramManager.saveTrainingProgram(trainingProgram: trainingProgram)
    }

    func deleteTrainingProgram(programId: String) async throws {
        try await trainingProgramManager.deleteTrainingProgram(programId: programId)
    }

    var prebuiltPrograms: [TrainingProgram] {
        trainingProgramManager.prebuiltPrograms
    }

    /// Copies a template under the current user and makes the copy their active program.
    @discardableResult
    func startPrebuiltProgram(_ program: TrainingProgram) async throws -> TrainingProgram {
        guard let userId else { throw CoreError.noCurrentUser }
        let copy = TrainingProgramManager.copy(of: program, authorId: userId)
        try await saveTrainingProgram(trainingProgram: copy)
        try await setActiveTrainingProgram(programId: copy.id)
        return copy
    }
}
