//
//  TodayRouter.swift
//  DialedIn
//

import SwiftUI

@MainActor
protocol TodayRouter: GlobalRouter {
    #if DEV || MOCK
    func showDevSettingsView()
    #endif
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showWorkoutTrackerView()
    func showTrainingProgramLibraryView()
    func showAddMealView(delegate: AddMealDelegate)
    func showLogWeightView()
    func showCheckInView(delegate: CheckInDelegate)
    func showWeeklyReviewView()
}

extension CoreRouter: TodayRouter { }
