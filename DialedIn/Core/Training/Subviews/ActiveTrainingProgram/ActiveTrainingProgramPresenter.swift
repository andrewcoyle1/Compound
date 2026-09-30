import SwiftUI

struct MicrocycleItem: Identifiable {
    /// Where the row's microcycle sits against the one the user is on.
    enum Timing {
        case past, current, future
    }

    let id: String
    let workoutTemplate: WorkoutTemplateModel
    let completedSessionId: String?
    let trainingProgramId: String
    var isSkipped: Bool = false
    /// The day plan the schedule puts on today — the same answer Today's workout card gives.
    var isToday: Bool = false
    var timing: Timing = .current
    /// The schedule's slot behind the row, for skipping it.
    var slot: ProgramSchedule.Slot?

    var isCompleted: Bool {
        completedSessionId != nil
    }

    /// Only an open workout in the microcycle under way can be skipped.
    var canSkip: Bool {
        timing == .current && !isCompleted && !isSkipped && !workoutTemplate.exercises.isEmpty && slot != nil
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

    /// The microcycle being looked at, 0-based; nil follows the one the user is on.
    private(set) var viewedCycleIndex: Int?
    private(set) var displayedCycleIndex: Int = 0
    private(set) var cycleCount: Int = 1

    /// Read from the request, not only the last render, so two taps before a redraw both count.
    private var shownCycleIndex: Int { viewedCycleIndex ?? displayedCycleIndex }
    var canShowPreviousCycle: Bool { shownCycleIndex > 0 }
    var canShowNextCycle: Bool { shownCycleIndex < cycleCount - 1 }

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

    func onPreviousCyclePressed() {
        guard canShowPreviousCycle else { return }
        viewedCycleIndex = shownCycleIndex - 1
    }

    func onNextCyclePressed() {
        guard canShowNextCycle else { return }
        viewedCycleIndex = shownCycleIndex + 1
    }

    /// `cycleIndex` is 1-based, as the header shows it.
    func isCurrentCycleDeload(cycleIndex: Int, program: TrainingProgram) -> Bool {
        switch program.deload {
        case .none:  return false
        case .start: return cycleIndex == 1
        case .end:   return cycleIndex == program.numMicrocycles
        }
    }

    /// `cycleIndex` is 1-based, as the header shows it.
    func currentPeriodisationPhase(cycleIndex: Int, program: TrainingProgram) -> PeriodisationPhase? {
        guard program.periodisation else { return nil }
        let number = max(program.numMicrocycles, 1)
        let third = max(number / 3, 1)
        if cycleIndex <= third { return .hypertrophy }
        if cycleIndex <= third * 2 { return .strength }
        return .power
    }

    /// The days of the microcycle being looked at, from `ProgramSchedule` — the same answer the
    /// Today card reads. Also sets the header, deload and phase for that microcycle.
    func microcycleItems(program: TrainingProgram) -> [MicrocycleItem] {
        guard !program.workoutTemplates.isEmpty else {
            microcycleHeaderText = String(localized: "Current Microcycle")
            return []
        }

        let run = run(for: program)
        let progress = ProgramSchedule.progress(of: run, sessions: workoutSessions)
        let currentCycle = progress.currentCycleIndex
        let shown = min(viewedCycleIndex ?? currentCycle, progress.cycles.count - 1)
        cycleCount = progress.cycles.count
        displayedCycleIndex = shown

        let cycleNumber = shown + 1
        isDeloadCycle = isCurrentCycleDeload(cycleIndex: cycleNumber, program: program)
        periodisationPhase = currentPeriodisationPhase(cycleIndex: cycleNumber, program: program)
        let microcycleText = String(localized: "Microcycle \(String(describing: cycleNumber)) of \(String(describing: cycleCount))")
        if let plan = interactor.currentTrainingPlan, plan.programIds.count > 1, plan.currentProgramId == program.id {
            let blockNumber = plan.blockIndex + 1
            let blockCount = plan.programIds.count
            microcycleHeaderText = String(localized: "Block \(String(describing: blockNumber)) of \(String(describing: blockCount)) · \(microcycleText)")
        } else {
            microcycleHeaderText = microcycleText
        }

        let today = ProgramSchedule.todayItem(run: run, sessions: workoutSessions)
        let nextSlotId = progress.next?.id
        return progress.cycles[shown].map { slot in
            let isToday: Bool
            if let sessionId = today?.completedSessionId, slot.completedSessionId != nil {
                isToday = slot.completedSessionId == sessionId
            } else {
                isToday = today?.completedSessionId == nil && slot.id == nextSlotId
            }
            return MicrocycleItem(
                id: slot.id,
                workoutTemplate: slot.dayPlan,
                completedSessionId: slot.completedSessionId,
                trainingProgramId: program.id,
                isSkipped: slot.state == .skipped,
                isToday: isToday,
                timing: shown < currentCycle ? .past : (shown == currentCycle ? .current : .future),
                slot: slot
            )
        }
    }

    /// The plan's block when it is this program, otherwise the program as the old schedule saw it.
    private func run(for program: TrainingProgram) -> ProgramSchedule.Run {
        if let run = interactor.activeProgramRun, run.program.id == program.id {
            return ProgramSchedule.Run(program: program, startedAt: run.startedAt, skips: run.skips)
        }
        return ProgramSchedule.legacyRun(program: program, sessions: workoutSessions)
    }

    func onItemPressed(_ item: MicrocycleItem) {
        if let sessionId = item.completedSessionId {
            openCompletedSession(sessionId: sessionId)
        } else if item.timing == .current && !item.isSkipped {
            startWorkoutTemplateModelWorkout(item.workoutTemplate, in: item.trainingProgramId)
        } else {
            router.showWorkoutTemplateDetailView(
                delegate: WorkoutTemplateDetailDelegate(
                    workoutTemplate: item.workoutTemplate,
                    trainingProgramId: item.trainingProgramId,
                    onStartWorkoutPressed: nil,
                    isDeloadCycle: isDeloadCycle,
                    periodisationPhase: periodisationPhase,
                    allowsStart: false
                )
            )
        }
    }

    func onSkipPressed(_ item: MicrocycleItem) {
        guard item.canSkip, let slot = item.slot else { return }
        interactor.trackEvent(event: Event.skipStart)
        Task {
            do {
                try await interactor.skipScheduledWorkout(slot)
                interactor.playHaptic(option: .success)
                interactor.trackEvent(event: Event.skipSuccess)
            } catch {
                interactor.playHaptic(option: .error)
                interactor.trackEvent(event: Event.skipFail(error: error))
                router.showAlert(title: String(localized: "Unable to Skip Workout"), error: error)
            }
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

    /// The shared prompt, so both start buttons ask the same question with the same answers.
    private func checkForActiveWorkout(onResumeWorkout: @escaping @Sendable () -> Void, onStartNewWorkout: @escaping @Sendable () -> Void) -> Bool {
        guard activeSession != nil else {
            return true
        }

        router.showActiveWorkoutAlert(
            onResume: onResumeWorkout,
            onReplace: { [weak self] in
                Task { @MainActor in
                    try? self?.interactor.deleteActiveSession()
                    onStartNewWorkout()
                }
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
        case skipStart
        case skipSuccess
        case skipFail(error: Error)

        var eventName: String {
            switch self {
            case .deleteProgramFail: return "ActiveTrainingProgramView_DeleteProgram_Fail"
            case .skipStart:                     return "ActiveTrainingProgramView_Skip_Start"
            case .skipSuccess:                   return "ActiveTrainingProgramView_Skip_Success"
            case .skipFail:                      return "ActiveTrainingProgramView_Skip_Fail"
            case .onAppear:                      return "ActiveTrainingProgramView_Appear"
            case .onDisappear:                   return "ActiveTrainingProgramView_Disappear"
            case .openCompletedSessionStart:     return "ActiveTrainingProgramView_OpenCompletedSession_Start"
            case .openCompletedSessionSuccess:   return "ActiveTrainingProgramView_OpenCompletedSession_Success"
            case .openCompletedSessionFail:      return "ActiveTrainingProgramView_OpenCompletedSession_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteProgramFail(error: let error), .skipFail(error: let error): return error.eventParameters
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
            case .deleteProgramFail, .skipFail: return .severe
            case .openCompletedSessionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
