//
//  WorkoutTrackerPresenter+Events.swift
//  Compound
//
//  The analytics events and error type were declared inside the class body, counting against
//  its 500-line type-body limit. Every other presenter declares its `Event` enum in an
//  extension, so these now follow suit.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - Screen events

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// Why a finish ended without the workout saved. The shared finish path reports only an
    /// outcome, not the error, so the reason stands in for it.
    enum FinishFailReason: String {
        case permanent
        case retriesExhausted = "retries_exhausted"
        case signedOut = "signed_out"
        case cancelled
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadGymProfileFail(error: Error)
        case healthKitAuthorisationFail(error: Error)
        case discardWorkoutStart
        case discardWorkoutSuccess
        case discardWorkoutFail(error: Error)
        case saveProgressFail(error: Error)
        case finishWorkoutStart
        case finishWorkoutSuccess
        case finishWorkoutFail(reason: FinishFailReason)
        case startRestTimerCalled(inputDuration: Int, resolvedDuration: Int)
        case startRestTimerAfterCall(restEndTime: Date?)
        case progressionAdjusted(exerciseId: String, setsChanged: Int)
        case restExtended(seconds: Int)
        case restSkipped
        case workoutPaused
        case workoutResumed

        var eventName: String {
            switch self {
            case .onAppear:                 return "WorkoutTrackerView_Appear"
            case .onDisappear:              return "WorkoutTrackerView_Disappear"
            case .loadGymProfileFail:       return "WorkoutTrackerView_LoadGymProfile_Fail"
            case .healthKitAuthorisationFail: return "WorkoutTrackerView_HealthKitAuthorisation_Fail"
            case .discardWorkoutStart:      return "WorkoutTrackerView_DiscardWorkout_Start"
            case .discardWorkoutSuccess:    return "WorkoutTrackerView_DiscardWorkout_Success"
            case .discardWorkoutFail:       return "WorkoutTrackerView_DiscardWorkout_Fail"
            case .saveProgressFail:         return "WorkoutTrackerView_SaveProgress_Fail"
            case .finishWorkoutStart:       return "WorkoutTrackerView_FinishWorkout_Start"
            case .finishWorkoutSuccess:     return "WorkoutTrackerView_FinishWorkout_Success"
            case .finishWorkoutFail:        return "WorkoutTrackerView_FinishWorkout_Fail"
            case .startRestTimerCalled:     return "WorkoutTracker_StartRestTimer_Called"
            case .startRestTimerAfterCall:  return "WorkoutTracker_StartRestTimer_AfterCall"
            case .progressionAdjusted:      return "WorkoutTracker_Progression_Adjusted"
            case .restExtended:             return "WorkoutTracker_Rest_Extended"
            case .restSkipped:              return "WorkoutTracker_Rest_Skipped"
            case .workoutPaused:            return "WorkoutTracker_Workout_Paused"
            case .workoutResumed:           return "WorkoutTracker_Workout_Resumed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadGymProfileFail(let error), .healthKitAuthorisationFail(let error), .discardWorkoutFail(let error), .saveProgressFail(let error):
                return error.eventParameters
            case .finishWorkoutFail(let reason):
                return ["reason": reason.rawValue]
            case .onAppear, .onDisappear, .discardWorkoutStart, .discardWorkoutSuccess, .finishWorkoutStart, .finishWorkoutSuccess:
                return nil
            case .startRestTimerCalled(let inputDuration, let resolvedDuration):
                return [
                    "input_duration": inputDuration,
                    "resolved_duration": resolvedDuration
                ]
            case .startRestTimerAfterCall(let restEndTime):
                return [
                    "rest_end_time": restEndTime?.timeIntervalSince1970 as Any,
                    "rest_end_time_is_nil": restEndTime == nil
                ]
            case .progressionAdjusted(let exerciseId, let setsChanged):
                return [
                    "exercise_id": exerciseId,
                    "sets_changed": setsChanged
                ]
            case .restExtended(let seconds):
                return ["seconds": seconds]
            case .restSkipped, .workoutPaused, .workoutResumed:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveProgressFail, .finishWorkoutFail:
                return .severe
            case .loadGymProfileFail, .healthKitAuthorisationFail, .discardWorkoutFail:
                return .warning
            case .startRestTimerAfterCall(let restEndTime) where restEndTime == nil:
                return .warning
            default:
                return .analytic
            }
        }
    }

    enum WorkoutTrackerError: LocalizedError {
        case noLocalActiveWorkout
        case noActiveWorkout

        var errorDescription: String? {
            switch self {
            case .noLocalActiveWorkout:
                return String(localized: "No local active workout available")
            case .noActiveWorkout:
                return String(localized: "No active workout available")
            }
        }
    }
}
