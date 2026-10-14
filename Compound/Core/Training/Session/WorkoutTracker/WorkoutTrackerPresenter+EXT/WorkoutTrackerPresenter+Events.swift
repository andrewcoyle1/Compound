//
//  WorkoutTrackerPresenter+Events.swift
//  Compound
//
//  The screen's analytics events.
//

import SwiftUI

extension WorkoutTrackerPresenter {

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
        case exerciseSelected
        case exerciseMoved(later: Bool)
        case exerciseReordered(fromBlock: Int, toBlock: Int)
        case progressionNoteAcknowledged
        /// Every set logged here, from a row or the log button, which `source` tells apart. Named
        /// as the row's event it replaced, so the series reads on.
        case setLogged(setId: String, exerciseId: String, useRestTimers: Bool, restDurationSeconds: Int, source: String)
        case correctionReps(delta: Int)
        case correctionRIR(Int)
        case correctionUndo
        case focusMoved(reason: FocusReason)
        case finishWorkoutDebug(session: WorkoutSessionModel)
        case finishWorkoutSaveError(error: Error)
        case minimized
        case finishPressed
        case discardPressed
        case workoutNotesSaved
        case exerciseNotesSaved
        case mesocycleNoteSaved
        case mesocycleNoteSaveFail(error: Error)
        case exercisesAdded(count: Int)
        case exerciseDeleted
        case exerciseSwapped(keptLoggedSets: Bool)
        case supersetChanged(joined: Bool)
        case roundAdded
        case workoutSettingsOpened
        case gymSettingsOpened

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
            case .exerciseSelected:         return "WorkoutTracker_Exercise_Selected"
            case .exerciseMoved:            return "WorkoutTracker_Exercise_Moved"
            case .exerciseReordered:        return "WorkoutTracker_Exercise_Reordered"
            case .progressionNoteAcknowledged: return "WorkoutTracker_ProgressionNote_Acknowledged"
            case .setLogged:                return "SetTrackerRow_SetCompleted"
            case .correctionReps:           return "WorkoutTracker_Correction_Reps"
            case .correctionRIR:            return "WorkoutTracker_Correction_RIR"
            case .correctionUndo:           return "WorkoutTracker_Correction_Undo"
            case .focusMoved:               return "WorkoutTracker_Focus_Moved"
            case .finishWorkoutDebug:       return "finish_workout_debug"
            case .finishWorkoutSaveError:   return "finish_workout_save_error"
            case .minimized:                return "WorkoutTracker_Minimized"
            case .finishPressed:            return "WorkoutTracker_Finish_Pressed"
            case .discardPressed:           return "WorkoutTracker_Discard_Pressed"
            case .workoutNotesSaved:        return "WorkoutTracker_WorkoutNotes_Saved"
            case .exerciseNotesSaved:       return "WorkoutTracker_ExerciseNotes_Saved"
            case .mesocycleNoteSaved:       return "WorkoutTracker_MesocycleNote_Saved"
            case .mesocycleNoteSaveFail:    return "WorkoutTracker_MesocycleNote_Fail"
            case .exercisesAdded:           return "WorkoutTracker_Exercises_Added"
            case .exerciseDeleted:          return "WorkoutTracker_Exercise_Deleted"
            case .exerciseSwapped:          return "WorkoutTracker_Exercise_Swapped"
            case .supersetChanged:          return "WorkoutTracker_Superset_Changed"
            case .roundAdded:               return "WorkoutTracker_Round_Added"
            case .workoutSettingsOpened:    return "WorkoutTracker_WorkoutSettings_Opened"
            case .gymSettingsOpened:        return "WorkoutTracker_GymSettings_Opened"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadGymProfileFail(let error), .healthKitAuthorisationFail(let error), .discardWorkoutFail(let error),
                 .saveProgressFail(let error), .mesocycleNoteSaveFail(let error):
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
            case .exerciseMoved(let later):
                return ["to": later ? "later" : "next"]
            case .exerciseReordered(let fromBlock, let toBlock):
                return ["from": fromBlock, "to": toBlock]
            case let .setLogged(setId, exerciseId, useRestTimers, restDurationSeconds, source):
                return [
                    "source": source,
                    "set_id": setId,
                    "exercise_id": exerciseId,
                    "use_rest_timers": useRestTimers,
                    "rest_duration_seconds": restDurationSeconds
                ]
            case .correctionReps(let delta):
                return ["delta": delta]
            case .correctionRIR(let rir):
                return ["rir": rir]
            case .focusMoved(let reason):
                return ["reason": reason.rawValue]
            case .finishWorkoutDebug(let session):
                return [
                    "session_id": session.id,
                    "template_id": session.workoutTemplateId ?? "nil",
                    "plan_id": session.mesocycleId ?? "nil"
                ]
            case .finishWorkoutSaveError(let error):
                return ["error": error.localizedDescription, "is_transient": error.isTransientWriteFailure]
            case .exercisesAdded(let count):
                return ["count": count]
            case .exerciseSwapped(let keptLoggedSets):
                return ["kept_logged_sets": keptLoggedSets]
            case .supersetChanged(let joined):
                return ["joined": joined]
            case .restSkipped, .workoutPaused, .workoutResumed, .exerciseSelected, .progressionNoteAcknowledged,
                 .correctionUndo, .minimized, .finishPressed, .discardPressed, .workoutNotesSaved, .exerciseNotesSaved,
                 .mesocycleNoteSaved, .exerciseDeleted, .roundAdded, .workoutSettingsOpened, .gymSettingsOpened:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveProgressFail, .finishWorkoutFail, .finishWorkoutSaveError:
                return .severe
            case .loadGymProfileFail, .healthKitAuthorisationFail, .discardWorkoutFail, .mesocycleNoteSaveFail:
                return .warning
            case .finishWorkoutDebug:
                return .info
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
