//
//  TabBarRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/01/2026.
//

@MainActor
protocol TabBarRouter: GlobalRouter {
    /// The Today's Workout widget's link, when a session is already under way.
    func showWorkoutTrackerView()
}

extension CoreRouter: TabBarRouter { }
