//
//  WorkoutSessionActivityBundle.swift
//  WorkoutSessionActivity
//
//  Created by Andrew Coyle on 30/09/2025.
//

import WidgetKit
import SwiftUI

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
@main
struct WorkoutSessionActivityBundle: WidgetBundle {
    var body: some Widget {
        WorkoutSessionActivity()
        TodaysWorkoutWidget()
        StreakWidget()
        WeeklyRingWidget()
    }
}
#endif
