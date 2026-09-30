//
//  MacrocycleManager.swift
//  DialedIn
//
//  The user's macrocycles, synced at `users/{uid}/macrocycles`. Holds which mesocycle the user is
//  on, when it started, where they joined it and what they skipped; `MesocycleSchedule` works out
//  the rest from sessions.
//

import Foundation

@Observable
@MainActor
class MacrocycleManager {

    private let macrocycleSyncEngine: CollectionSyncEngine<Macrocycle>
    private let logManager: LogManager

    /// A literal rather than an entry in the gitignored `Keys.swift`, so adding it cannot break a
    /// checkout whose local `Keys.swift` predates it. The local cache's name, not Firestore's.
    static let managerKey = "training_plan"

    var macrocycles: [Macrocycle] {
        macrocycleSyncEngine.currentCollection
    }

    /// The macrocycle being followed, or just finished and waiting on a repeat. Newest wins should
    /// two devices ever both start one.
    var currentMacrocycle: Macrocycle? {
        macrocycles
            .filter { $0.status == .active || $0.status == .completed }
            .max { $0.dateModified < $1.dateModified }
    }

    init(macrocycleSyncEngine: CollectionSyncEngine<Macrocycle>, logManager: LogManager) {
        self.macrocycleSyncEngine = macrocycleSyncEngine
        self.logManager = logManager
    }

    func signIn() async {
        await macrocycleSyncEngine.startListening()
    }

    func signOut() {
        macrocycleSyncEngine.stopListening()
    }

    /// The mesocycle to schedule from. With no macrocycle yet (an account from before them, or the
    /// mock build) the mesocycle is followed the way the old schedule followed it.
    func run(for mesocycle: Mesocycle?, sessions: [WorkoutSessionModel]) -> MesocycleSchedule.Run? {
        guard let mesocycle else { return nil }
        if let macrocycle = currentMacrocycle, macrocycle.currentMesocycleId == mesocycle.id {
            return MesocycleSchedule.Run(
                mesocycle: mesocycle,
                startedAt: macrocycle.mesocycleStartedAt,
                skips: macrocycle.currentSkips,
                firstMicrocycleIndex: macrocycle.startMicrocycleIndex ?? 0
            )
        }
        return MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: sessions)
    }

    /// Starts a new macrocycle of `mesocycleIds` from the beginning.
    @discardableResult
    func startMacrocycle(authorId: String, name: String, mesocycleIds: [String], startedAt: Date = Date()) async throws -> Macrocycle {
        let macrocycle = Macrocycle(
            authorId: authorId, name: name, mesocycleIds: mesocycleIds, status: .notStarted,
            dateCreated: startedAt, dateModified: startedAt
        )
        return try await start(macrocycle, now: startedAt)
    }

    /// Follows `macrocycle` from the given mesocycle and microcycle (0-based) and ends whichever one
    /// was being followed.
    @discardableResult
    func start(_ macrocycle: Macrocycle, atMesocycle mesocycleIndex: Int = 0, microcycle microcycleIndex: Int = 0, now: Date = Date()) async throws -> Macrocycle {
        for other in macrocycles where other.id != macrocycle.id && (other.status == .active || other.status == .completed) {
            var ended = other
            ended.status = .ended
            ended.dateModified = now
            try await save(ended)
        }
        let started = macrocycle.started(atMesocycle: mesocycleIndex, microcycle: microcycleIndex, now: now)
        try await save(started)
        logManager.trackEvent(event: Event.start(macrocycle: started))
        return started
    }

    func skip(_ slot: MesocycleSchedule.Slot, in macrocycle: Macrocycle, now: Date = Date()) async throws -> Macrocycle {
        var updated = macrocycle
        updated.skips.append(CycleSkip(
            mesocycleIndex: macrocycle.mesocycleIndex,
            cycleIndex: slot.cycleIndex,
            position: slot.position,
            templateId: slot.dayPlan.id,
            date: now
        ))
        updated.dateModified = now
        try await save(updated)
        logManager.trackEvent(event: Event.skip(macrocycle: updated))
        return updated
    }

    /// Moves on when the current mesocycle has nothing left open. Returns the macrocycle when it
    /// changed.
    func advanceIfMesocycleComplete(_ macrocycle: Macrocycle, progress: MesocycleSchedule.Progress, now: Date = Date()) async throws -> Macrocycle? {
        guard macrocycle.status == .active, progress.isMesocycleComplete else { return nil }
        let advanced = macrocycle.advanced(now: now)
        try await save(advanced)
        logManager.trackEvent(event: advanced.status == .completed ? Event.complete(macrocycle: advanced) : Event.advanceMesocycle(macrocycle: advanced))
        return advanced
    }

    func repeatMacrocycle(_ macrocycle: Macrocycle, now: Date = Date()) async throws -> Macrocycle {
        let repeated = macrocycle.repeated(now: now)
        try await save(repeated)
        logManager.trackEvent(event: Event.repeatMacrocycle(macrocycle: repeated))
        return repeated
    }

    func save(_ macrocycle: Macrocycle) async throws {
        do {
            try await macrocycleSyncEngine.saveDocument(macrocycle)
        } catch {
            logManager.trackEvent(event: Event.saveFail(macrocycleId: macrocycle.id, error: error))
            throw error
        }
    }

    func delete(_ macrocycle: Macrocycle) async throws {
        do {
            try await macrocycleSyncEngine.deleteDocument(id: macrocycle.id)
        } catch {
            logManager.trackEvent(event: Event.deleteFail(macrocycleId: macrocycle.id, error: error))
            throw error
        }
    }
}

extension MacrocycleManager {
    enum Event: LoggableEvent {
        case start(macrocycle: Macrocycle)
        case skip(macrocycle: Macrocycle)
        case advanceMesocycle(macrocycle: Macrocycle)
        case complete(macrocycle: Macrocycle)
        case repeatMacrocycle(macrocycle: Macrocycle)
        case saveFail(macrocycleId: String, error: Error)
        case deleteFail(macrocycleId: String, error: Error)

        var eventName: String {
            switch self {
            case .start:            return "MacrocycleMan_Start"
            case .skip:             return "MacrocycleMan_Skip"
            case .advanceMesocycle: return "MacrocycleMan_AdvanceMesocycle"
            case .complete:         return "MacrocycleMan_Complete"
            case .repeatMacrocycle: return "MacrocycleMan_Repeat"
            case .saveFail:         return "MacrocycleMan_Save_Fail"
            case .deleteFail:       return "MacrocycleMan_Delete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .start(let macrocycle), .skip(let macrocycle), .advanceMesocycle(let macrocycle),
                 .complete(let macrocycle), .repeatMacrocycle(let macrocycle):
                return macrocycle.eventParameters
            case .saveFail(let macrocycleId, let error), .deleteFail(let macrocycleId, let error):
                return error.eventParameters.merging(["macrocycle_id": macrocycleId]) { $1 }
            }
        }

        var type: LogType {
            switch self {
            case .saveFail, .deleteFail: return .severe
            default:                     return .analytic
            }
        }
    }
}

/// Moves the current macrocycle on when its mesocycle has nothing left open, and points the
/// profile's active mesocycle at the next one so everything reading `activeMesocycle` follows.
/// Shared by finishing a workout (tracker and Live Activity) and skipping one.
@MainActor
func advanceMacrocycleIfMesocycleComplete(
    macrocycles: MacrocycleManager,
    mesocycles: MesocycleManager,
    users: UserManager,
    sessions: [WorkoutSessionModel]
) async throws {
    guard let macrocycle = macrocycles.currentMacrocycle,
          let run = macrocycles.run(for: mesocycles.activeMesocycle(for: users.currentUser), sessions: sessions) else { return }
    let progress = MesocycleSchedule.progress(of: run, sessions: sessions)
    guard let advanced = try await macrocycles.advanceIfMesocycleComplete(macrocycle, progress: progress),
          advanced.status == .active, let mesocycleId = advanced.currentMesocycleId else { return }
    try await users.updateActiveMesocycleId(mesocycleId: mesocycleId)
}

extension CoreInteractor {
    // MARK: MacrocycleManager

    var macrocycles: [Macrocycle] {
        macrocycleManager.macrocycles
    }

    var currentMacrocycle: Macrocycle? {
        macrocycleManager.currentMacrocycle
    }

    var activeMesocycleRun: MesocycleSchedule.Run? {
        macrocycleManager.run(for: activeMesocycle, sessions: workoutSessions)
    }

    var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        MesocycleSchedule.todayItem(run: activeMesocycleRun, sessions: workoutSessions)
    }

    /// Follows one mesocycle as a macrocycle of one. Re-activating the mesocycle already under way
    /// keeps its progress rather than starting it over.
    func setActiveMesocycle(mesocycleId: String) async throws {
        if let macrocycle = currentMacrocycle, macrocycle.status == .active, macrocycle.currentMesocycleId == mesocycleId {
            try await userManager.updateActiveMesocycleId(mesocycleId: mesocycleId)
            return
        }
        guard let userId else { throw CoreError.noCurrentUser }
        let name = mesocycles.first { $0.id == mesocycleId }?.name ?? ""
        try await macrocycleManager.startMacrocycle(authorId: userId, name: name, mesocycleIds: [mesocycleId])
        try await userManager.updateActiveMesocycleId(mesocycleId: mesocycleId)
    }

    /// Follows `macrocycle` from the given mesocycle and microcycle, both 0-based.
    func startMacrocycle(_ macrocycle: Macrocycle, atMesocycle mesocycleIndex: Int, microcycle microcycleIndex: Int) async throws {
        let started = try await macrocycleManager.start(macrocycle, atMesocycle: mesocycleIndex, microcycle: microcycleIndex)
        if let mesocycleId = started.currentMesocycleId {
            try await userManager.updateActiveMesocycleId(mesocycleId: mesocycleId)
        }
        refreshWidgetSnapshot()
    }

    /// Saves edits. When the macrocycle being followed has its mesocycles reordered, it stays on
    /// the mesocycle the user is doing; when that one is removed, it stays at the same position.
    func saveMacrocycle(_ macrocycle: Macrocycle) async throws {
        var updated = macrocycle
        updated.dateModified = Date()
        let previous = macrocycles.first { $0.id == macrocycle.id }
        if updated.status == .active, let followedId = previous?.currentMesocycleId {
            if let index = updated.mesocycleIds.firstIndex(of: followedId) {
                updated.mesocycleIndex = index
            } else {
                updated.mesocycleIndex = min(updated.mesocycleIndex, max(updated.mesocycleIds.count - 1, 0))
                updated.mesocycleStartedAt = updated.dateModified
                updated.startMicrocycleIndex = nil
            }
        }
        try await macrocycleManager.save(updated)
        if updated.status == .active, let mesocycleId = updated.currentMesocycleId,
           mesocycleId != currentUser?.submittedActiveMesocycleId {
            try await userManager.updateActiveMesocycleId(mesocycleId: mesocycleId)
        }
    }

    func deleteMacrocycle(_ macrocycle: Macrocycle) async throws {
        try await macrocycleManager.delete(macrocycle)
    }

    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws {
        let macrocycle = try await currentMacrocycleCreatingIfNeeded()
        _ = try await macrocycleManager.skip(slot, in: macrocycle)
        try await advanceMacrocycleIfMesocycleComplete(
            macrocycles: macrocycleManager,
            mesocycles: mesocycleManager,
            users: userManager,
            sessions: workoutSessions
        )
        refreshWidgetSnapshot()
    }

    func repeatCurrentMacrocycle() async throws {
        guard let macrocycle = currentMacrocycle, let first = macrocycle.mesocycleIds.first else { return }
        _ = try await macrocycleManager.repeatMacrocycle(macrocycle)
        try await userManager.updateActiveMesocycleId(mesocycleId: first)
        refreshWidgetSnapshot()
    }

    /// Accounts from before macrocycles follow a mesocycle with nothing behind it. Wraps it in a
    /// macrocycle of one starting where the old schedule had them, so the progress shown does not
    /// change. Then moves on any mesocycle finished elsewhere, so a finished one is never left
    /// with nothing scheduled until the next workout.
    func migrateActiveMesocycleToMacrocycleIfNeeded() async {
        if macrocycleManager.currentMacrocycle == nil, activeMesocycle != nil {
            _ = try? await currentMacrocycleCreatingIfNeeded()
        }
        try? await advanceMacrocycleIfMesocycleComplete(
            macrocycles: macrocycleManager,
            mesocycles: mesocycleManager,
            users: userManager,
            sessions: workoutSessions
        )
    }

    private func currentMacrocycleCreatingIfNeeded() async throws -> Macrocycle {
        if let macrocycle = currentMacrocycle { return macrocycle }
        guard let userId, let mesocycle = activeMesocycle else { throw CoreError.noCurrentUser }
        return try await macrocycleManager.startMacrocycle(
            authorId: userId,
            name: mesocycle.name,
            mesocycleIds: [mesocycle.id],
            startedAt: MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: workoutSessions).startedAt
        )
    }
}
