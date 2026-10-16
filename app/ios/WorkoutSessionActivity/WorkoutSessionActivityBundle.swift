//
//  WorkoutSessionActivityBundle.swift
//  WorkoutSessionActivity
//  Copied unchanged in substance from the Swift app's `WorkoutSessionActivity/WorkoutSessionActivityBundle.swift`.
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
