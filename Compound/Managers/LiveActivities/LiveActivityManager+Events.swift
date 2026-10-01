//
//  LiveActivityManager+Events.swift
//  Compound
//
//  Split out of LiveActivityManager.swift, which had reached the file-length limit.
//

import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

enum LiveActivityError: LocalizedError {
    case noUpdatableActivity

    var errorDescription: String? {
        switch self {
        case .noUpdatableActivity:
            return "No active or stale Live Activity to update"
        }
    }
}

// MARK: Events
extension LiveActivityManager {
    enum Event: LoggableEvent {
        case startLiveActivityStart
        case startLiveActivitySuccess
        case startLiveActivityFail(error: Error)
        case liveActivitiesNotEnabled
        case updateLiveActivityStart
        case updateLiveActivitySuccess
        case updateLiveActivityFail(error: Error)
        case endLiveActivityStart
        case endLiveActivitySuccess
        case endLiveActivityFail(error: Error)

        var eventName: String {
            switch self {
            case .startLiveActivityStart:       return "LiveActivityMan_StartLiveActivity_Start"
            case .startLiveActivitySuccess:     return "LiveActivityMan_StartLiveActivity_Success"
            case .startLiveActivityFail:        return "LiveActivityMan_StartLiveActivity_Fail"
            case .liveActivitiesNotEnabled:     return "LiveActivityMan_LiveActivitiesNotEnabled"
            case .updateLiveActivityStart:      return "LiveActivityMan_UpdateLiveActivity_Start"
            case .updateLiveActivitySuccess:    return "LiveActivityMan_UpdateLiveActivity_Success"
            case .updateLiveActivityFail:       return "LiveActivityMan_UpdateLiveActivity_Fail"
            case .endLiveActivityStart:         return "LiveActivityMan_EndLiveActivity_Start"
            case .endLiveActivitySuccess:       return "LiveActivityMan_EndLiveActivity_Success"
            case .endLiveActivityFail:          return "LiveActivityMan_EndLiveActivity_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .startLiveActivityFail(error: let error), .updateLiveActivityFail(error: let error),
                 .endLiveActivityFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .startLiveActivityFail, .updateLiveActivityFail, .endLiveActivityFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}

#endif
