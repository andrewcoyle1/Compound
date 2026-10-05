//
//  TodaysWorkoutCardPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

@Observable
@MainActor
class TodaysWorkoutCardPresenter {
    private let interactor: TodaysWorkoutCardInteractor
    private let router: TodaysWorkoutCardRouter
    
    init(interactor: TodaysWorkoutCardInteractor, router: TodaysWorkoutCardRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onTodaysWorkoutPressed() {
        guard let template = todaysWorkoutTemplate, !isTodayRestDay else { return }
        let mesocycleId = interactor.activeMesocycle?.id
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                mesocycleId: mesocycleId,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                },
                isDeloadCycle: isTodayDeload
            )
        )
    }

    /// Today's workout is the next open one, so it can be started straight from the card.
    var canStart: Bool {
        todaysOpenSlot != nil
    }

    /// Start on the card: straight into the tracker, skipping the preview the card itself opens.
    func onStartPressed() {
        guard let slot = todaysOpenSlot else { return }
        interactor.trackEvent(event: Event.startPressed)
        let mesocycleId = interactor.activeMesocycle?.id
        let isDeload = isTodayDeload
        if interactor.activeSession != nil {
            router.showActiveWorkoutAlert(
                onResume: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                onReplace: { [weak self] in
                    Task { @MainActor in
                        do {
                            try self?.interactor.deleteActiveSession()
                        } catch {
                            self?.interactor.trackEvent(event: Event.deleteActiveSessionFail(error: error))
                        }
                        await self?.start(slot.dayPlan, in: mesocycleId, isDeloadCycle: isDeload)
                    }
                }
            )
        } else {
            Task { await start(slot.dayPlan, in: mesocycleId, isDeloadCycle: isDeload) }
        }
    }

    private func start(_ template: WorkoutTemplateModel, in mesocycleId: String?, isDeloadCycle: Bool) async {
        interactor.trackEvent(event: Event.startStart)
        do {
            try await interactor.startWorkout(for: template, in: mesocycleId, isDeloadCycle: isDeloadCycle)
            interactor.trackEvent(event: Event.startSuccess)
            router.showWorkoutTrackerView()
        } catch {
            interactor.trackEvent(event: Event.startFail(error: error))
            router.showSimpleAlert(title: String(localized: "Could Not Start Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    /// Whether today's workout falls in the mesocycle's deload microcycle.
    var isTodayDeload: Bool {
        guard let slot = todaysOpenSlot, let run = interactor.activeMesocycleRun else { return false }
        return MesocycleSchedule.isDeload(cycleIndex: slot.cycleIndex + 1, of: run.mesocycle)
    }
    
    var todaysWorkoutTemplate: WorkoutTemplateModel? {
        todaysScheduledItem?.dayPlan
    }

    var isTodayRestDay: Bool {
        todaysWorkoutTemplate?.exercises.isEmpty == true
    }

    var isTodayCompleted: Bool {
        todaysScheduledItem?.completedSessionId != nil
    }

    /// Only today's own workout can be skipped from the card, not a rest day or one already done.
    var canSkip: Bool {
        todaysOpenSlot != nil
    }

    func onSkipPressed() {
        guard let slot = todaysOpenSlot else { return }
        interactor.trackEvent(event: Event.skipPressed)
        router.showAlert(
            title: String(localized: "Skip \(slot.dayPlan.name)?"),
            subtitle: String(localized: "It will count as done for this microcycle, and the next workout moves up to today."),
            buttons: {
                AnyView(
                    Group {
                        Button("Skip", role: .destructive) {
                            Task { await self.skip(slot) }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func skip(_ slot: MesocycleSchedule.Slot) async {
        interactor.trackEvent(event: Event.skipStart)
        do {
            try await interactor.skipScheduledWorkout(slot)
            interactor.trackEvent(event: Event.skipSuccess)
            interactor.playHaptic(option: .success)
        } catch {
            interactor.trackEvent(event: Event.skipFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Skip Workout"), error: error)
        }
    }

    /// Today's workout when it is the next open slot: not a rest day and not already done.
    private var todaysOpenSlot: MesocycleSchedule.Slot? {
        guard let item = todaysScheduledItem, !item.isCompleted, !isTodayRestDay,
              let run = interactor.activeMesocycleRun,
              let next = MesocycleSchedule.progress(of: run, sessions: interactor.workoutSessions).next,
              next.dayPlan.id == item.dayPlan.id else { return nil }
        return next
    }

    private var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        MesocycleSchedule.todayItem(run: interactor.activeMesocycleRun, sessions: interactor.workoutSessions)
    }

}

extension TodaysWorkoutCardPresenter {
    enum Event: LoggableEvent {
        case skipPressed
        case skipStart
        case skipSuccess
        case skipFail(error: Error)
        case startPressed
        case startStart
        case startSuccess
        case startFail(error: Error)
        case deleteActiveSessionFail(error: Error)

        var eventName: String {
            switch self {
            case .skipPressed:  return "TodaysWorkoutCard_Skip_Pressed"
            case .skipStart:    return "TodaysWorkoutCard_Skip_Start"
            case .skipSuccess:  return "TodaysWorkoutCard_Skip_Success"
            case .skipFail:     return "TodaysWorkoutCard_Skip_Fail"
            case .startPressed: return "TodaysWorkoutCard_Start_Pressed"
            case .startStart:   return "TodaysWorkoutCard_Start_Start"
            case .startSuccess: return "TodaysWorkoutCard_Start_Success"
            case .startFail:    return "TodaysWorkoutCard_Start_Fail"
            case .deleteActiveSessionFail: return "TodaysWorkoutCard_DeleteActiveSession_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .skipFail(let error), .startFail(let error), .deleteActiveSessionFail(let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .skipFail, .startFail: return .severe
            case .deleteActiveSessionFail: return .warning
            default: return .analytic
            }
        }
    }
}
