import SwiftUI

struct MicrocycleItem: Identifiable {
    /// Where the row's microcycle sits against the one the user is on.
    enum Timing {
        case past, current, future
    }

    let id: String
    let workoutTemplate: WorkoutTemplateModel
    let completedSessionId: String?
    let mesocycleId: String
    var isSkipped: Bool = false
    /// The day plan the schedule puts on today — the same answer Today's workout card gives.
    var isToday: Bool = false
    var timing: Timing = .current
    /// The schedule's slot behind the row, for skipping it.
    var slot: MesocycleSchedule.Slot?

    var isCompleted: Bool {
        completedSessionId != nil
    }

    /// Only an open workout in the microcycle under way can be skipped.
    var canSkip: Bool {
        timing == .current && !isCompleted && !isSkipped && !workoutTemplate.exercises.isEmpty && slot != nil
    }

    static var mock: Self {
        Self(id: UUID().uuidString, workoutTemplate: .mock, completedSessionId: nil, mesocycleId: Mesocycle.mock.id)
    }
}

@Observable
@MainActor
class ActiveMesocyclePresenter {

    private let interactor: ActiveMesocycleInteractor
    private let router: ActiveMesocycleRouter

    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?
    var microcycleHeaderText: String = "Current Microcycle"
    var activeMesocycleIsExpanded: Bool = true

    /// The microcycle being looked at, 0-based; nil follows the one the user is on.
    private(set) var viewedCycleIndex: Int?
    private(set) var displayedCycleIndex: Int = 0
    private(set) var cycleCount: Int = 1
    /// The microcycle the user is on, 0-based, marked in the menu.
    private(set) var currentCycleIndex: Int = 0

    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }

    init(interactor: ActiveMesocycleInteractor, router: ActiveMesocycleRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: ActiveMesocycleDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: ActiveMesocycleDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onMesocyclePressed(mesocycle: Mesocycle) {
        router.showEditMesocycleView(delegate: EditMesocycleDelegate(mesocycle: mesocycle))
    }

    /// Picking the microcycle the user is on goes back to following it as the block moves on.
    func onCycleSelected(_ index: Int) {
        guard (0..<cycleCount).contains(index) else { return }
        viewedCycleIndex = index == currentCycleIndex ? nil : index
    }

    func cycleMenuTitle(_ index: Int) -> String {
        let number = index + 1
        return index == currentCycleIndex
            ? String(localized: "Microcycle \(number) (Current)")
            : String(localized: "Microcycle \(number)")
    }

    /// `cycleIndex` is 1-based, as the header shows it.
    func isCurrentCycleDeload(cycleIndex: Int, mesocycle: Mesocycle) -> Bool {
        switch mesocycle.deload {
        case .none:  return false
        case .start: return cycleIndex == 1
        case .end:   return cycleIndex == mesocycle.numMicrocycles
        }
    }

    /// `cycleIndex` is 1-based, as the header shows it.
    func currentPeriodisationPhase(cycleIndex: Int, mesocycle: Mesocycle) -> PeriodisationPhase? {
        guard mesocycle.periodisation else { return nil }
        let number = max(mesocycle.numMicrocycles, 1)
        let third = max(number / 3, 1)
        if cycleIndex <= third { return .hypertrophy }
        if cycleIndex <= third * 2 { return .strength }
        return .power
    }

    /// The days of the microcycle being looked at, from `MesocycleSchedule` — the same answer the
    /// Today card reads. Also sets the header, deload and phase for that microcycle.
    func microcycleItems(mesocycle: Mesocycle) -> [MicrocycleItem] {
        guard !mesocycle.workoutTemplates.isEmpty else {
            microcycleHeaderText = String(localized: "Current Microcycle")
            return []
        }

        let run = run(for: mesocycle)
        let progress = MesocycleSchedule.progress(of: run, sessions: workoutSessions)
        let currentCycle = progress.currentCycleIndex
        let shown = min(viewedCycleIndex ?? currentCycle, progress.cycles.count - 1)
        cycleCount = progress.cycles.count
        currentCycleIndex = currentCycle
        displayedCycleIndex = shown

        let cycleNumber = shown + 1
        isDeloadCycle = isCurrentCycleDeload(cycleIndex: cycleNumber, mesocycle: mesocycle)
        periodisationPhase = currentPeriodisationPhase(cycleIndex: cycleNumber, mesocycle: mesocycle)
        let microcycleText = String(localized: "Microcycle \(String(describing: cycleNumber)) of \(String(describing: cycleCount))")
        if let plan = interactor.currentMacrocycle, plan.mesocycleIds.count > 1, plan.currentMesocycleId == mesocycle.id {
            let blockNumber = plan.mesocycleIndex + 1
            let blockCount = plan.mesocycleIds.count
            microcycleHeaderText = String(localized: "Block \(String(describing: blockNumber)) of \(String(describing: blockCount)) · \(microcycleText)")
        } else {
            microcycleHeaderText = microcycleText
        }

        let today = MesocycleSchedule.todayItem(run: run, sessions: workoutSessions)
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
                mesocycleId: mesocycle.id,
                isSkipped: slot.state == .skipped,
                isToday: isToday,
                timing: shown < currentCycle ? .past : (shown == currentCycle ? .current : .future),
                slot: slot
            )
        }
    }

    /// The plan's block when it is this mesocycle, otherwise the mesocycle as the old schedule saw it.
    private func run(for mesocycle: Mesocycle) -> MesocycleSchedule.Run {
        if let run = interactor.activeMesocycleRun, run.mesocycle.id == mesocycle.id {
            return MesocycleSchedule.Run(mesocycle: mesocycle, startedAt: run.startedAt, skips: run.skips)
        }
        return MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: workoutSessions)
    }

    func onItemPressed(_ item: MicrocycleItem) {
        if let sessionId = item.completedSessionId {
            openCompletedSession(sessionId: sessionId)
        } else if item.timing == .current && !item.isSkipped {
            startWorkoutTemplateModelWorkout(item.workoutTemplate, in: item.mesocycleId)
        } else {
            router.showWorkoutTemplateDetailView(
                delegate: WorkoutTemplateDetailDelegate(
                    workoutTemplate: item.workoutTemplate,
                    mesocycleId: item.mesocycleId,
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

    func startWorkoutTemplateModelWorkout(_ workoutTemplate: WorkoutTemplateModel, in mesocycle: String?) {
        let shouldProceed = checkForActiveWorkout(
            onResumeWorkout: { [weak self] in
                Task {
                    await self?.resumeActiveWorkout()
                }
            },
            onStartNewWorkout: { [weak self] in
                Task {
                    await self?.performStartWorkoutTemplateModelWorkout(workoutTemplate, in: mesocycle)
                }
            }
        )

        if shouldProceed {
            performStartWorkoutTemplateModelWorkout(workoutTemplate, in: mesocycle)
        }
    }

    private func resumeActiveWorkout() {
        guard activeSession != nil else { return }
        router.showWorkoutTrackerView()
    }

    private func performStartWorkoutTemplateModelWorkout(_ template: WorkoutTemplateModel, in mesocycleId: String?) {
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                mesocycleId: mesocycleId,
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

    func onMesocycleDeletePressed(mesocycle: Mesocycle) {
        router.showAlert(
            title: String(localized: "Delete Training Program"),
            subtitle: String(localized: "Are you sure you want to delete your active training program? This cannot be undone."),
            buttons: {
                AnyView(
                    HStack {
                        Button(role: .destructive) {
                            Task { await self.deleteMesocycle(mesocycleId: mesocycle.id) }
                        }
                        Button(role: .cancel) { }
                    }
                )
            }
        )
    }

    func deleteMesocycle(mesocycleId: String) async {
        do {
            try await interactor.deleteMesocycle(mesocycleId: mesocycleId)
        } catch {
            interactor.trackEvent(event: Event.deleteMesocycleFail(error: error))
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

extension ActiveMesocyclePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: ActiveMesocycleDelegate)
        case onDisappear(delegate: ActiveMesocycleDelegate)
        case openCompletedSessionStart
        case openCompletedSessionSuccess
        case openCompletedSessionFail(error: Error)
        case deleteMesocycleFail(error: Error)
        case skipStart
        case skipSuccess
        case skipFail(error: Error)

        var eventName: String {
            switch self {
            case .deleteMesocycleFail: return "ActiveTrainingProgramView_DeleteProgram_Fail"
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
            case .deleteMesocycleFail(error: let error), .skipFail(error: let error): return error.eventParameters
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
            case .deleteMesocycleFail, .skipFail: return .severe
            case .openCompletedSessionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
