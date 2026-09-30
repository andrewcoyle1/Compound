//
//  MacrocycleManager.swift
//  DialedIn
//
//  The user's plans, synced at `users/{uid}/training_plans`. Holds which block the user is on,
//  when it started and what they skipped; `MesocycleSchedule` works out the rest from sessions.
//

import Foundation

@Observable
@MainActor
class MacrocycleManager {

    private let macrocycleSyncEngine: CollectionSyncEngine<Macrocycle>
    private let logManager: LogManager

    /// A literal rather than an entry in the gitignored `Keys.swift`, so adding it cannot break a
    /// checkout whose local `Keys.swift` predates it.
    static let managerKey = "training_plan"

    var macrocycles: [Macrocycle] {
        macrocycleSyncEngine.currentCollection
    }

    /// The plan being followed, or just finished and waiting on a repeat. Newest wins should two
    /// devices ever both start one.
    var currentMacrocycle: Macrocycle? {
        macrocycles
            .filter { $0.status != .ended }
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

    /// The block to schedule from. With no plan yet (an account from before plans, or the mock
    /// build) the mesocycle is followed the way the old schedule followed it.
    func run(for mesocycle: Mesocycle?, sessions: [WorkoutSessionModel]) -> MesocycleSchedule.Run? {
        guard let mesocycle else { return nil }
        if let plan = currentMacrocycle, plan.currentMesocycleId == mesocycle.id {
            return MesocycleSchedule.Run(mesocycle: mesocycle, startedAt: plan.mesocycleStartedAt, skips: plan.currentSkips)
        }
        return MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: sessions)
    }

    /// Starts `mesocycleIds` as a plan and ends whatever plan was current.
    @discardableResult
    func startMacrocycle(authorId: String, name: String, mesocycleIds: [String], startedAt: Date = Date()) async throws -> Macrocycle {
        for plan in macrocycles where plan.status != .ended {
            var ended = plan
            ended.status = .ended
            ended.dateModified = startedAt
            try await save(ended)
        }
        let plan = Macrocycle(authorId: authorId, name: name, mesocycleIds: mesocycleIds, mesocycleStartedAt: startedAt, dateCreated: startedAt, dateModified: startedAt)
        try await save(plan)
        logManager.trackEvent(event: Event.startMacrocycle(plan: plan))
        return plan
    }

    func skip(_ slot: MesocycleSchedule.Slot, in plan: Macrocycle, now: Date = Date()) async throws -> Macrocycle {
        var updated = plan
        updated.skips.append(CycleSkip(
            mesocycleIndex: plan.mesocycleIndex,
            cycleIndex: slot.cycleIndex,
            position: slot.position,
            templateId: slot.dayPlan.id,
            date: now
        ))
        updated.dateModified = now
        try await save(updated)
        logManager.trackEvent(event: Event.skip(plan: updated))
        return updated
    }

    /// Moves on when the current block has nothing left open. Returns the plan when it changed.
    func advanceIfBlockComplete(_ plan: Macrocycle, progress: MesocycleSchedule.Progress, now: Date = Date()) async throws -> Macrocycle? {
        guard plan.status == .active, progress.isMesocycleComplete else { return nil }
        let advanced = plan.advanced(now: now)
        try await save(advanced)
        logManager.trackEvent(event: advanced.status == .completed ? Event.completeMacrocycle(plan: advanced) : Event.advanceMesocycle(plan: advanced))
        return advanced
    }

    func repeatMacrocycle(_ plan: Macrocycle, now: Date = Date()) async throws -> Macrocycle {
        let repeated = plan.repeated(now: now)
        try await save(repeated)
        logManager.trackEvent(event: Event.repeatMacrocycle(plan: repeated))
        return repeated
    }

    private func save(_ plan: Macrocycle) async throws {
        do {
            try await macrocycleSyncEngine.saveDocument(plan)
        } catch {
            logManager.trackEvent(event: Event.saveFail(planId: plan.id, error: error))
            throw error
        }
    }
}

extension MacrocycleManager {
    enum Event: LoggableEvent {
        case startMacrocycle(plan: Macrocycle)
        case skip(plan: Macrocycle)
        case advanceMesocycle(plan: Macrocycle)
        case completeMacrocycle(plan: Macrocycle)
        case repeatMacrocycle(plan: Macrocycle)
        case saveFail(planId: String, error: Error)

        var eventName: String {
            switch self {
            case .startMacrocycle:    return "TrainingPlanMan_StartPlan"
            case .skip:         return "TrainingPlanMan_Skip"
            case .advanceMesocycle: return "TrainingPlanMan_AdvanceBlock"
            case .completeMacrocycle: return "TrainingPlanMan_CompletePlan"
            case .repeatMacrocycle:   return "TrainingPlanMan_RepeatPlan"
            case .saveFail:     return "TrainingPlanMan_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .startMacrocycle(let plan), .skip(let plan), .advanceMesocycle(let plan), .completeMacrocycle(let plan), .repeatMacrocycle(let plan):
                return plan.eventParameters
            case .saveFail(let planId, let error):
                return error.eventParameters.merging(["plan_id": planId]) { $1 }
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default:        return .analytic
            }
        }
    }
}

/// Moves the current plan on when its block has nothing left open, and points the profile's
/// active mesocycle at the new block so everything reading `activeMesocycle` follows. Shared by
/// finishing a workout (tracker and Live Activity) and skipping one.
@MainActor
func advanceMacrocycleIfMesocycleComplete(
    plans: MacrocycleManager,
    mesocycles: MesocycleManager,
    users: UserManager,
    sessions: [WorkoutSessionModel]
) async throws {
    guard let plan = plans.currentMacrocycle,
          let run = plans.run(for: mesocycles.activeMesocycle(for: users.currentUser), sessions: sessions) else { return }
    let progress = MesocycleSchedule.progress(of: run, sessions: sessions)
    guard let advanced = try await plans.advanceIfBlockComplete(plan, progress: progress),
          advanced.status == .active, let mesocycleId = advanced.currentMesocycleId else { return }
    try await users.updateActiveMesocycleId(mesocycleId: mesocycleId)
}

extension CoreInteractor {
    // MARK: MacrocycleManager

    var currentMacrocycle: Macrocycle? {
        macrocycleManager.currentMacrocycle
    }

    var activeMesocycleRun: MesocycleSchedule.Run? {
        macrocycleManager.run(for: activeMesocycle, sessions: workoutSessions)
    }

    var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        MesocycleSchedule.todayItem(run: activeMesocycleRun, sessions: workoutSessions)
    }

    /// Follows one mesocycle as a plan of one block. Re-activating the block already under way
    /// keeps its progress rather than starting it over.
    func setActiveMesocycle(mesocycleId: String) async throws {
        if let plan = currentMacrocycle, plan.status == .active, plan.currentMesocycleId == mesocycleId {
            try await userManager.updateActiveMesocycleId(mesocycleId: mesocycleId)
            return
        }
        let name = mesocycles.first { $0.id == mesocycleId }?.name ?? ""
        try await startMacrocycle(name: name, mesocycleIds: [mesocycleId])
    }

    func startMacrocycle(name: String, mesocycleIds: [String]) async throws {
        guard let userId, let first = mesocycleIds.first else { throw CoreError.noCurrentUser }
        try await macrocycleManager.startMacrocycle(authorId: userId, name: name, mesocycleIds: mesocycleIds)
        try await userManager.updateActiveMesocycleId(mesocycleId: first)
    }

    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws {
        let plan = try await currentMacrocycleCreatingIfNeeded()
        _ = try await macrocycleManager.skip(slot, in: plan)
        try await advanceMacrocycleIfMesocycleComplete(
            plans: macrocycleManager,
            mesocycles: mesocycleManager,
            users: userManager,
            sessions: workoutSessions
        )
        refreshWidgetSnapshot()
    }

    func repeatCurrentMacrocycle() async throws {
        guard let plan = currentMacrocycle, let first = plan.mesocycleIds.first else { return }
        _ = try await macrocycleManager.repeatMacrocycle(plan)
        try await userManager.updateActiveMesocycleId(mesocycleId: first)
        refreshWidgetSnapshot()
    }

    /// Accounts from before plans follow a mesocycle with no plan behind it. Wraps it in a plan of
    /// one block starting where the old schedule had them, so the progress shown does not change.
    /// Then moves on any block finished elsewhere, so a completed block is never left with
    /// nothing scheduled until the next workout.
    func migrateActiveMesocycleToMacrocycleIfNeeded() async {
        if macrocycleManager.currentMacrocycle == nil, activeMesocycle != nil {
            _ = try? await currentMacrocycleCreatingIfNeeded()
        }
        try? await advanceMacrocycleIfMesocycleComplete(
            plans: macrocycleManager,
            mesocycles: mesocycleManager,
            users: userManager,
            sessions: workoutSessions
        )
    }

    private func currentMacrocycleCreatingIfNeeded() async throws -> Macrocycle {
        if let plan = currentMacrocycle { return plan }
        guard let userId, let mesocycle = activeMesocycle else { throw CoreError.noCurrentUser }
        return try await macrocycleManager.startMacrocycle(
            authorId: userId,
            name: mesocycle.name,
            mesocycleIds: [mesocycle.id],
            startedAt: MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: workoutSessions).startedAt
        )
    }
}
