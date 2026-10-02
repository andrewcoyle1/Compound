//
//  CoreInteractor+LiveActivity.swift
//  Compound
//
//  The Live Activity surface `CoreInteractor` exposes to the screens.
//
//  Split out of `LiveActivityManager.swift`, which had grown past the 750-line file limit.
//

import Foundation

#if !targetEnvironment(macCatalyst)
extension CoreInteractor {
    // MARK: LiveActivityManager
    
    /// Ensure a Workout Live Activity using data from the given session
    /// - Parameters:
    ///   - session: The workout session used to seed immutable attributes
    ///   - isActive: Whether the workout timer is running
    ///   - currentExerciseIndex: Index of the currently focused exercise in the session
    ///   - restEndsAt: Optional rest countdown end time
    func ensureLiveActivity(
        session: WorkoutSessionModel,
        isActive: Bool = true,
        currentExerciseIndex: Int = 0,
        restEndsAt: Date? = nil
    ) {
        // "Show on Lock Screen" in Workout Settings. Off, no activity is started, and the rest-over
        // alert falls back to the notification.
        guard workoutSettingsManager.workoutSettings.showsOnLockScreen else { return }
        liveActivityManager.ensureLiveActivity(session: session, isActive: isActive, currentExerciseIndex: currentExerciseIndex, restEndsAt: restEndsAt)
    }
    
    /// Push the session's current state to the Live Activity.
    func updateLiveActivity(params: LiveActivityUpdateParams) {
        liveActivityManager.updateLiveActivity(params: params)
    }
    
    /// End the session's Live Activity, with the summary when the workout completed.
    func endLiveActivity(
        session: WorkoutSessionModel,
        isCompleted: Bool = true
    ) {
        liveActivityManager.endLiveActivity(session: session, isCompleted: isCompleted)
    }
}
#endif
