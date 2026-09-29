//
//  WorkoutTrackerPresenter+Events.swift
//  DialedIn
//
//  The analytics events and error type were declared inside the class body, counting against
//  its 500-line type-body limit. Every other presenter declares its `Event` enum in an
//  extension, so these now follow suit.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    enum Event: LoggableEvent {
        case startRestTimerCalled(inputDuration: Int, resolvedDuration: Int)
        case startRestTimerAfterCall(restEndTime: Date?)
        case progressionAdjusted(exerciseId: String, setsChanged: Int)

        var eventName: String {
            switch self {
            case .startRestTimerCalled:     return "WorkoutTracker_StartRestTimer_Called"
            case .startRestTimerAfterCall:  return "WorkoutTracker_StartRestTimer_AfterCall"
            case .progressionAdjusted:      return "WorkoutTracker_Progression_Adjusted"
            }
        }

        var parameters: [String: Any]? {
            switch self {
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
            }
        }

        var type: LogType {
            switch self {
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
