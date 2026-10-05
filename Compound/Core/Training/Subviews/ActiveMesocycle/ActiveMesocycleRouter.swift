import SwiftUI

@MainActor
protocol ActiveMesocycleRouter: GlobalRouter, AskCoachRouter {
    func showEditMesocycleView(delegate: EditMesocycleDelegate)
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
    func showWorkoutTrackerView()
}

extension CoreRouter: ActiveMesocycleRouter { }
