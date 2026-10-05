//
//  TodayRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol TodayRouter: GlobalRouter {
    #if DEV || MOCK
    func showDevSettingsView()
    #endif
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showWorkoutTrackerView()
    func showMesocycleLibraryView()
    func showAddMealView(delegate: AddMealDelegate)
    func showLogWeightView()
    func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?)
    func showCheckInView(delegate: CheckInDelegate)
    func showWeeklyReviewView()
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
    func showStepsView(delegate: StepsDelegate, themeColor: Color?)
    func showIntegrationsView(delegate: IntegrationsDelegate)
}

extension CoreRouter: TodayRouter { }
