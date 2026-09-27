//
//  TodaysWorkoutCardPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation

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

    private var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        TodaysWorkoutSchedule.item(program: interactor.activeTrainingProgram, sessions: interactor.workoutSessions)
    }

}
