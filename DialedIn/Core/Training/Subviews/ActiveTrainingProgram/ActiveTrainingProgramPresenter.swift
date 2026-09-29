import SwiftUI

struct MicrocycleItem: Identifiable {
    let id: String
    let workoutTemplate: WorkoutTemplateModel
    let completedSessionId: String?
    let trainingProgramId: String

    var isCompleted: Bool {
        completedSessionId != nil
    }
    
    static var mock: Self {
        Self(id: UUID().uuidString, workoutTemplate: .mock, completedSessionId: nil, trainingProgramId: TrainingProgram.mock.id)
    }
}

@Observable
@MainActor
class ActiveTrainingProgramPresenter {

    private let interactor: ActiveTrainingProgramInteractor
    private let router: ActiveTrainingProgramRouter

    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?
    var microcycleHeaderText: String = "Current Microcycle"
    var activeProgramIsExpanded: Bool = true

    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }

    init(interactor: ActiveTrainingProgramInteractor, router: ActiveTrainingProgramRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: ActiveTrainingProgramDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: ActiveTrainingProgramDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onProgramPressed(program: TrainingProgram) {
        router.showEditTrainingProgramView(delegate: EditTrainingProgramDelegate(program: program))
    }

    func isCurrentCycleDeload(cycleIndex: Int, program: TrainingProgram) -> Bool {
        switch program.deload {
        case .none:  return false
        case .start: return cycleIndex == 1
        case .end:   return cycleIndex == program.numMicrocycles
        }
    }

    func currentPeriodisationPhase(cycleIndex: Int, program: TrainingProgram) -> PeriodisationPhase? {
        guard program.periodisation else { return nil }
        let number = max(program.numMicrocycles, 1)
        let third = max(number / 3, 1)
        if cycleIndex <= third { return .hypertrophy }
        if cycleIndex <= third * 2 { return .strength }
        return .power
    }

    func currentMicrocycleItems(program: TrainingProgram) -> [MicrocycleItem] {
        guard !program.workoutTemplates.isEmpty else {
            microcycleHeaderText = String(localized: "Current Microcycle")
            return []
        }

        let dayPlans = program.workoutTemplates
        let dayPlanNames = Set(dayPlans.map { $0.name })
        let dayPlanById = Dictionary(uniqueKeysWithValues: dayPlans.map { ($0.id, $0) })
        let workoutWorkoutTemplateModelIds = Set(dayPlans.filter { !$0.exercises.isEmpty }.map { $0.id })

        let completedSessions = workoutSessions
            .compactMap { session -> (WorkoutSessionModel, WorkoutTemplateModel)? in
                let shouldInclude = session.trainingProgramId == program.id
                    || (session.trainingProgramId == nil && session.workoutTemplateId == nil && dayPlanNames.contains(session.name))
                guard shouldInclude else { return nil }
                if let dayPlanId = session.workoutTemplateId, let plan = dayPlanById[dayPlanId] {
                    return (session, plan)
                }
                if let plan = dayPlans.first(where: { $0.name == session.name }) {
                    return (session, plan)
                }
                return nil
            }
            .sorted { ($0.0.endedAt ?? .distantPast) < ($1.0.endedAt ?? .distantPast) }

        let cyclesTotal = max(program.numMicrocycles, 1)
        var completedCycles = 0
        var completedInCurrentCycle = Set<String>()
        var sessionByPlanId: [String: String] = [:]
        for (session, dayPlan) in completedSessions {
            guard workoutWorkoutTemplateModelIds.contains(dayPlan.id) else { continue }
            if !completedInCurrentCycle.contains(dayPlan.id) {
                completedInCurrentCycle.insert(dayPlan.id)
                sessionByPlanId[dayPlan.id] = session.id
            }
            if completedInCurrentCycle == workoutWorkoutTemplateModelIds && !workoutWorkoutTemplateModelIds.isEmpty {
                completedCycles += 1
                completedInCurrentCycle.removeAll()
                sessionByPlanId.removeAll()
            }
        }
        let cycleIndex = (completedCycles % cyclesTotal) + 1
        isDeloadCycle = isCurrentCycleDeload(cycleIndex: cycleIndex, program: program)
        periodisationPhase = currentPeriodisationPhase(cycleIndex: cycleIndex, program: program)
        microcycleHeaderText = String(localized: "Microcycle \(String(describing: cycleIndex)) of \(String(describing: cyclesTotal))")

        return dayPlans.map { plan in
            MicrocycleItem(
                id: plan.id,
                workoutTemplate: plan,
                completedSessionId: sessionByPlanId[plan.id],
                trainingProgramId: program.id
            )
        }
    }

    func openCompletedSession(sessionId: String) {
        interactor.trackEvent(event: Event.openCompletedSessionStart)
        guard let session = workoutSessions.first(where: { $0.id == sessionId }) else {
            // Same blind spot as the Training tab: a silent return left a Start with no terminal
            // event, so a session vanishing mid-tap was indistinguishable from an unopened screen.
            interactor.trackEvent(event: Event.openCompletedSessionFail(error: TrainingError.sessionNotFound))
            return
        }
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
        interactor.trackEvent(event: Event.openCompletedSessionSuccess)
    }

    func startWorkoutTemplateModelWorkout(_ workoutTemplate: WorkoutTemplateModel, in trainingProgram: String?) {
        let shouldProceed = checkForActiveWorkout(
            onResumeWorkout: { [weak self] in
                Task {
                    await self?.resumeActiveWorkout()
                }
            },
            onStartNewWorkout: { [weak self] in
                Task {
                    await self?.performStartWorkoutTemplateModelWorkout(workoutTemplate, in: trainingProgram)
                }
            }
        )

        if shouldProceed {
            performStartWorkoutTemplateModelWorkout(workoutTemplate, in: trainingProgram)
        }
    }

    private func resumeActiveWorkout() {
        guard activeSession != nil else { return }
        router.showWorkoutTrackerView()
    }

    private func performStartWorkoutTemplateModelWorkout(_ template: WorkoutTemplateModel, in trainingProgramId: String?) {
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                trainingProgramId: trainingProgramId,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                },
                isDeloadCycle: isDeloadCycle,
                periodisationPhase: periodisationPhase
            )
        )
    }

    func onProgramDeletePressed(program: TrainingProgram) {
        router.showAlert(
            title: String(localized: "Delete Training Program"),
            subtitle: String(localized: "Are you sure you want to delete your active training program? This cannot be undone."),
            buttons: {
                AnyView(
                    HStack {
                        Button(role: .destructive) {
                            Task { await self.deleteTrainingProgram(programId: program.id) }
                        }
                        Button(role: .cancel) { }
                    }
                )
            }
        )
    }

    func deleteTrainingProgram(programId: String) async {
        do {
            try await interactor.deleteTrainingProgram(programId: programId)
        } catch {
            interactor.trackEvent(event: Event.deleteProgramFail(error: error))
            router.showSimpleAlert(title: String(localized: "Unable to Delete Program"), subtitle: String(localized: "Please try again."))
        }
    }

    // MARK: - Active Workout Safeguard

    private func checkForActiveWorkout(onResumeWorkout: @escaping @Sendable () -> Void, onStartNewWorkout: @escaping @Sendable () -> Void) -> Bool {
        guard let activeSession = activeSession else {
            return true
        }

        router.showAlert(
            title: String(localized: "Workout In Progress"),
            subtitle: String(localized: "You already have '\(activeSession.name)' in progress. What would you like to do?"),
            buttons: {
                AnyView(
                    VStack {
                        Button("Resume Current Workout") {
                            onResumeWorkout()
                        }
                        Button("Discard & Start New", role: .destructive) {
                            try? self.interactor.deleteActiveSession()
                            onStartNewWorkout()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )

        return false
    }

}

extension ActiveTrainingProgramPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: ActiveTrainingProgramDelegate)
        case onDisappear(delegate: ActiveTrainingProgramDelegate)
        case openCompletedSessionStart
        case openCompletedSessionSuccess
        case openCompletedSessionFail(error: Error)
        case deleteProgramFail(error: Error)

        var eventName: String {
            switch self {
            case .deleteProgramFail: return "ActiveTrainingProgramView_DeleteProgram_Fail"
            case .onAppear:                      return "ActiveTrainingProgramView_Appear"
            case .onDisappear:                   return "ActiveTrainingProgramView_Disappear"
            case .openCompletedSessionStart:     return "ActiveTrainingProgramView_OpenCompletedSession_Start"
            case .openCompletedSessionSuccess:   return "ActiveTrainingProgramView_OpenCompletedSession_Success"
            case .openCompletedSessionFail:      return "ActiveTrainingProgramView_OpenCompletedSession_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteProgramFail(error: let error): return error.eventParameters
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .openCompletedSessionFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteProgramFail: return .severe
            case .openCompletedSessionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
