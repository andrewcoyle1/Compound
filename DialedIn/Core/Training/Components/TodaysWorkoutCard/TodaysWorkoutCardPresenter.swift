//
//  TodaysWorkoutCardPresenter.swift
//  DialedIn
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
        let programId = interactor.activeTrainingProgram?.id
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: template,
                trainingProgramId: programId,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                }
            )
        )
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
        skippableSlot != nil
    }

    func onSkipPressed() {
        guard let slot = skippableSlot else { return }
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

    private func skip(_ slot: ProgramSchedule.Slot) async {
        do {
            try await interactor.skipScheduledWorkout(slot)
            interactor.playHaptic(option: .success)
        } catch {
            interactor.trackEvent(event: Event.skipFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Skip Workout"), error: error)
        }
    }

    private var skippableSlot: ProgramSchedule.Slot? {
        guard let item = todaysScheduledItem, !item.isCompleted, !isTodayRestDay,
              let run = interactor.activeProgramRun,
              let next = ProgramSchedule.progress(of: run, sessions: interactor.workoutSessions).next,
              next.dayPlan.id == item.dayPlan.id else { return nil }
        return next
    }

    private var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        ProgramSchedule.todayItem(run: interactor.activeProgramRun, sessions: interactor.workoutSessions)
    }

}

extension TodaysWorkoutCardPresenter {
    enum Event: LoggableEvent {
        case skipPressed
        case skipFail(error: Error)

        var eventName: String {
            switch self {
            case .skipPressed: return "TodaysWorkoutCard_Skip_Pressed"
            case .skipFail:    return "TodaysWorkoutCard_Skip_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .skipFail(let error): return error.eventParameters
            default:                   return nil
            }
        }

        var type: LogType {
            switch self {
            case .skipFail: return .severe
            default:        return .analytic
            }
        }
    }
}
