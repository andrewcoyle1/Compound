import SwiftUI

@Observable
@MainActor
class WeeklyGoalPresenter {

    private let interactor: WeeklyGoalInteractor
    private let router: WeeklyGoalRouter

    /// Starts at the saved goal, or the default 3 the strip already shows.
    var goal: Int
    private(set) var isSaving = false

    /// The segment shown as chosen: nil until a goal has been saved. A segment that is already
    /// selected does not fire when tapped, so pre-selecting the default 3 would leave no way to
    /// pick it.
    private(set) var selectedGoal: Int?
    private let savedGoal: Int?

    init(interactor: WeeklyGoalInteractor, router: WeeklyGoalRouter) {
        self.interactor = interactor
        self.router = router
        let goal = interactor.currentUser.map(CircleWeek.goal(for:)) ?? CircleWeek.defaultGoal
        let savedGoal = interactor.currentUser?.weeklySessionGoal == nil ? nil : goal
        self.goal = goal
        self.savedGoal = savedGoal
        self.selectedGoal = savedGoal
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onCancelPressed() {
        router.dismissScreen()
    }

    /// Picking a segment is the whole interaction: it saves and closes the sheet.
    func onGoalSelected(_ goal: Int) {
        guard !isSaving else { return }
        self.goal = goal
        selectedGoal = goal
        onSavePressed()
    }

    func onSavePressed() {
        guard !isSaving else { return }
        let goal = min(max(goal, CircleWeek.goalRange.lowerBound), CircleWeek.goalRange.upperBound)
        interactor.trackEvent(event: Event.savePressed(goal: goal))
        isSaving = true
        interactor.trackEvent(event: Event.saveStart)
        Task {
            defer { isSaving = false }
            do {
                try await interactor.updateWeeklySessionGoal(goal)
                interactor.trackEvent(event: Event.saveSuccess(goal: goal))
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                selectedGoal = savedGoal
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Save Goal"), subtitle: String(localized: "Please try again."))
            }
        }
    }
}

extension WeeklyGoalPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case savePressed(goal: Int)
        case saveStart
        case saveSuccess(goal: Int)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:     return "WeeklyGoalView_Appear"
            case .onDisappear:  return "WeeklyGoalView_Disappear"
            case .savePressed:  return "WeeklyGoalView_Save_Pressed"
            case .saveStart:    return "WeeklyGoalView_Save_Start"
            case .saveSuccess:  return "WeeklyGoalView_Save_Success"
            case .saveFail:     return "WeeklyGoalView_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .savePressed(goal: let goal), .saveSuccess(goal: let goal): return ["weekly_session_goal": goal]
            case .saveFail(error: let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default: return .analytic
            }
        }
    }
}
