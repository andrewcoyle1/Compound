//
//  CheckInPresenter+Events.swift
//  Compound
//

import Foundation

extension CheckInPresenter {

    /// Every event carries the step it happened on, so the funnel can be read as a funnel:
    /// which step people leave from is the only question worth asking of a six-screen flow.
    enum Event: LoggableEvent {
        case onAppear(weekStart: Date, steps: [CheckInStep])
        case onDisappear(step: CheckInStep?, completed: Bool)
        case stepShown(step: CheckInStep)
        case stepCompleted(step: CheckInStep, outcome: String)
        case proposalAccepted(proposal: TargetProposal)
        case completed(weekStart: Date)
        case dismissed(step: CheckInStep?)
        case completeFail(error: Error)
        case completeSuccess
        case logWeightStart
        case logWeightSuccess
        case logWeightFail(error: Error)
        case saveAnswerStart(action: String)
        case saveAnswerSuccess(action: String)
        case saveAnswerFail(action: String, error: Error)
        case loadMealsFail(error: Error)

        var eventName: String {
            switch self {
            case .completeFail: return "CheckInView_Complete_Fail"
            case .completeSuccess:   return "CheckInView_Complete_Success"
            case .logWeightStart:    return "CheckInView_LogWeight_Start"
            case .logWeightSuccess:  return "CheckInView_LogWeight_Success"
            case .logWeightFail:     return "CheckInView_LogWeight_Fail"
            case .saveAnswerStart:   return "CheckInView_SaveAnswer_Start"
            case .saveAnswerSuccess: return "CheckInView_SaveAnswer_Success"
            case .saveAnswerFail:    return "CheckInView_SaveAnswer_Fail"
            case .loadMealsFail:     return "CheckInView_LoadMeals_Fail"
            case .onAppear:         return "CheckInView_Appear"
            case .onDisappear:      return "CheckInView_Disappear"
            case .stepShown:        return "CheckInView_Step_Shown"
            case .stepCompleted:    return "CheckInView_Step_Completed"
            case .proposalAccepted: return "CheckInView_Proposal_Accept"
            case .completed:        return "CheckInView_Completed"
            case .dismissed:        return "CheckInView_Dismissed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .completeFail(error: let error), .logWeightFail(error: let error), .loadMealsFail(error: let error):
                return error.eventParameters
            case .completeSuccess, .logWeightStart, .logWeightSuccess:
                return nil
            case .saveAnswerStart(let action), .saveAnswerSuccess(let action):
                return ["action": action]
            case .saveAnswerFail(let action, let error):
                return error.eventParameters.merging(["action": action]) { _, new in new }
            case .onAppear(let weekStart, let steps):
                return [
                    "check_in_week_start": weekStart,
                    "check_in_steps": steps.map(\.eventName).joined(separator: ","),
                    "check_in_step_count": steps.count
                ]
            case .onDisappear(let step, let completed):
                return ["step": step?.eventName ?? "none", "check_in_completed": completed]
            case .stepShown(let step):
                return ["step": step.eventName]
            case .stepCompleted(let step, let outcome):
                return ["step": step.eventName, "check_in_step_outcome": outcome]
            case .proposalAccepted(let proposal):
                return [
                    "step": CheckInStep.programUpdate.eventName,
                    "proposal_current_kcal": proposal.currentTargetKcal,
                    "proposal_proposed_kcal": proposal.proposedTargetKcal,
                    "proposal_expenditure_kcal": proposal.expenditureKcal,
                    "proposal_reason": proposal.reason.rawValue
                ]
            case .completed(let weekStart):
                return ["check_in_week_start": weekStart]
            case .dismissed(let step):
                return ["step": step?.eventName ?? "none"]
            }
        }

        var type: LogType {
            switch self {
            case .completeFail, .logWeightFail, .saveAnswerFail: return .severe
            case .loadMealsFail: return .warning
            default: return .analytic
            }
        }
    }
}
