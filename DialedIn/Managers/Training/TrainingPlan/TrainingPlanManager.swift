//
//  TrainingPlanManager.swift
//  DialedIn
//
//  The user's plans, synced at `users/{uid}/training_plans`. Holds which block the user is on,
//  when it started and what they skipped; `ProgramSchedule` works out the rest from sessions.
//

import Foundation

@Observable
@MainActor
class TrainingPlanManager {

    private let trainingPlanSyncEngine: CollectionSyncEngine<TrainingPlan>
    private let logManager: LogManager

    /// A literal rather than an entry in the gitignored `Keys.swift`, so adding it cannot break a
    /// checkout whose local `Keys.swift` predates it.
    static let managerKey = "training_plan"

    var trainingPlans: [TrainingPlan] {
        trainingPlanSyncEngine.currentCollection
    }

    /// The plan being followed, or just finished and waiting on a repeat. Newest wins should two
    /// devices ever both start one.
    var currentPlan: TrainingPlan? {
        trainingPlans
            .filter { $0.status != .ended }
            .max { $0.dateModified < $1.dateModified }
    }

    init(trainingPlanSyncEngine: CollectionSyncEngine<TrainingPlan>, logManager: LogManager) {
        self.trainingPlanSyncEngine = trainingPlanSyncEngine
        self.logManager = logManager
    }

    func signIn() async {
        await trainingPlanSyncEngine.startListening()
    }

    func signOut() {
        trainingPlanSyncEngine.stopListening()
    }

    /// The block to schedule from. With no plan yet (an account from before plans, or the mock
    /// build) the program is followed from its creation, which counts the same history as before.
    func run(for program: TrainingProgram?) -> ProgramSchedule.Run? {
        guard let program else { return nil }
        if let plan = currentPlan, plan.currentProgramId == program.id {
            return ProgramSchedule.Run(program: program, startedAt: plan.blockStartedAt, skips: plan.currentSkips)
        }
        return ProgramSchedule.Run(program: program, startedAt: program.dateCreated)
    }

    /// Starts `programIds` as a plan and ends whatever plan was current.
    @discardableResult
    func startPlan(authorId: String, name: String, programIds: [String], startedAt: Date = Date()) async throws -> TrainingPlan {
        for plan in trainingPlans where plan.status != .ended {
            var ended = plan
            ended.status = .ended
            ended.dateModified = startedAt
            try await save(ended)
        }
        let plan = TrainingPlan(authorId: authorId, name: name, programIds: programIds, blockStartedAt: startedAt, dateCreated: startedAt, dateModified: startedAt)
        try await save(plan)
        logManager.trackEvent(event: Event.startPlan(plan: plan))
        return plan
    }

    func skip(_ slot: ProgramSchedule.Slot, in plan: TrainingPlan, now: Date = Date()) async throws -> TrainingPlan {
        var updated = plan
        updated.skips.append(PlanSkip(
            blockIndex: plan.blockIndex,
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
    func advanceIfBlockComplete(_ plan: TrainingPlan, progress: ProgramSchedule.Progress, now: Date = Date()) async throws -> TrainingPlan? {
        guard plan.status == .active, progress.isBlockComplete else { return nil }
        let advanced = plan.advanced(now: now)
        try await save(advanced)
        logManager.trackEvent(event: advanced.status == .completed ? Event.completePlan(plan: advanced) : Event.advanceBlock(plan: advanced))
        return advanced
    }

    func repeatPlan(_ plan: TrainingPlan, now: Date = Date()) async throws -> TrainingPlan {
        let repeated = plan.repeated(now: now)
        try await save(repeated)
        logManager.trackEvent(event: Event.repeatPlan(plan: repeated))
        return repeated
    }

    private func save(_ plan: TrainingPlan) async throws {
        do {
            try await trainingPlanSyncEngine.saveDocument(plan)
        } catch {
            logManager.trackEvent(event: Event.saveFail(planId: plan.id, error: error))
            throw error
        }
    }
}

extension TrainingPlanManager {
    enum Event: LoggableEvent {
        case startPlan(plan: TrainingPlan)
        case skip(plan: TrainingPlan)
        case advanceBlock(plan: TrainingPlan)
        case completePlan(plan: TrainingPlan)
        case repeatPlan(plan: TrainingPlan)
        case saveFail(planId: String, error: Error)

        var eventName: String {
            switch self {
            case .startPlan:    return "TrainingPlanMan_StartPlan"
            case .skip:         return "TrainingPlanMan_Skip"
            case .advanceBlock: return "TrainingPlanMan_AdvanceBlock"
            case .completePlan: return "TrainingPlanMan_CompletePlan"
            case .repeatPlan:   return "TrainingPlanMan_RepeatPlan"
            case .saveFail:     return "TrainingPlanMan_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .startPlan(let plan), .skip(let plan), .advanceBlock(let plan), .completePlan(let plan), .repeatPlan(let plan):
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
/// active program at the new block so everything reading `activeTrainingProgram` follows. Shared by
/// finishing a workout (tracker and Live Activity) and skipping one.
@MainActor
func advancePlanIfBlockComplete(
    plans: TrainingPlanManager,
    programs: TrainingProgramManager,
    users: UserManager,
    sessions: [WorkoutSessionModel]
) async throws {
    guard let plan = plans.currentPlan,
          let run = plans.run(for: programs.activeProgram(for: users.currentUser)) else { return }
    let progress = ProgramSchedule.progress(of: run, sessions: sessions)
    guard let advanced = try await plans.advanceIfBlockComplete(plan, progress: progress),
          advanced.status == .active, let programId = advanced.currentProgramId else { return }
    try await users.updateActiveTrainingProgramId(programId: programId)
}

extension CoreInteractor {
    // MARK: TrainingPlanManager

    var currentTrainingPlan: TrainingPlan? {
        trainingPlanManager.currentPlan
    }

    var activeProgramRun: ProgramSchedule.Run? {
        trainingPlanManager.run(for: activeTrainingProgram)
    }

    var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        ProgramSchedule.todayItem(run: activeProgramRun, sessions: workoutSessions)
    }

    /// Follows one program as a plan of one block. Re-activating the block already under way
    /// keeps its progress rather than starting it over.
    func setActiveTrainingProgram(programId: String) async throws {
        if let plan = currentTrainingPlan, plan.status == .active, plan.currentProgramId == programId {
            try await userManager.updateActiveTrainingProgramId(programId: programId)
            return
        }
        let name = trainingPrograms.first { $0.id == programId }?.name ?? ""
        try await startTrainingPlan(name: name, programIds: [programId])
    }

    func startTrainingPlan(name: String, programIds: [String]) async throws {
        guard let userId, let first = programIds.first else { throw CoreError.noCurrentUser }
        try await trainingPlanManager.startPlan(authorId: userId, name: name, programIds: programIds)
        try await userManager.updateActiveTrainingProgramId(programId: first)
    }

    func skipScheduledWorkout(_ slot: ProgramSchedule.Slot) async throws {
        let plan = try await currentTrainingPlanCreatingIfNeeded()
        _ = try await trainingPlanManager.skip(slot, in: plan)
        try await advancePlanIfBlockComplete(
            plans: trainingPlanManager,
            programs: trainingProgramManager,
            users: userManager,
            sessions: workoutSessions
        )
        refreshWidgetSnapshot()
    }

    func repeatCurrentTrainingPlan() async throws {
        guard let plan = currentTrainingPlan, let first = plan.programIds.first else { return }
        _ = try await trainingPlanManager.repeatPlan(plan)
        try await userManager.updateActiveTrainingProgramId(programId: first)
        refreshWidgetSnapshot()
    }

    /// Accounts from before plans follow a program with no plan behind it. Wraps it in a plan of
    /// one block dated from the program's creation, so the progress shown does not change.
    func migrateActiveProgramToPlanIfNeeded() async {
        guard trainingPlanManager.currentPlan == nil, activeTrainingProgram != nil else { return }
        _ = try? await currentTrainingPlanCreatingIfNeeded()
    }

    private func currentTrainingPlanCreatingIfNeeded() async throws -> TrainingPlan {
        if let plan = currentTrainingPlan { return plan }
        guard let userId, let program = activeTrainingProgram else { throw CoreError.noCurrentUser }
        return try await trainingPlanManager.startPlan(
            authorId: userId,
            name: program.name,
            programIds: [program.id],
            startedAt: program.dateCreated
        )
    }
}
