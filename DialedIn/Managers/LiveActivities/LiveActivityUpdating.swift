//
//  LiveActivityUpdating.swift
//  DialedIn
//
//  Created by Andrew Coyle on 30/09/2025.
//

import Foundation

@MainActor
protocol LiveActivityUpdating: AnyObject {
    func ensureLiveActivity(
        session: WorkoutSessionModel,
        isActive: Bool,
        currentExerciseIndex: Int,
        restEndsAt: Date?
    )
    
    func updateLiveActivity(params: LiveActivityUpdateParams)
    
    func updateRestAndActive(
        isActive: Bool,
        restEndsAt: Date?
    )
    
    func endLiveActivity(
        session: WorkoutSessionModel,
        isCompleted: Bool
    )

    /// True while an activity is on screen to carry the rest-over alert.
    var isShowingLiveActivity: Bool { get }

    /// What the rest-over alert says about the set after this rest, "Next: Bench Press, 60 kg × 8",
    /// or nil when nothing is left.
    func restOverMessage(session: WorkoutSessionModel, currentExerciseIndex: Int) -> String?

    /// Clears the rest, as `updateRestAndActive` does, and alerts: the activity lights the screen,
    /// plays the alert sound and shows what is next.
    func announceRestOver(isActive: Bool)
}
