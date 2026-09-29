import SwiftUI

@Observable
@MainActor
class WeeklyGoalPresenter {

    private let interactor: WeeklyGoalInteractor
    private let router: WeeklyGoalRouter

    /// Starts at the saved goal, or the default 3 the strip already shows.
    var goal: Int
    private(set) var isSaving = false

    init(interactor: WeeklyGoalInteractor, router: WeeklyGoalRouter) {
        self.interactor = interactor
        self.router = router
        self.goal = interactor.currentUser.map(CircleWeek.goal(for:)) ?? CircleWeek.defaultGoal
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onCancelPressed() {
        router.dismissScreen()
    }

    func onSavePressed() {
        guard !isSaving else { return }
        let goal = min(max(goal, CircleWeek.goalRange.lowerBound), CircleWeek.goalRange.upperBound)
        interactor.trackEvent(event: Event.savePressed(goal: goal))
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await interactor.updateWeeklySessionGoal(goal)
                router.dismissScreen()
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to save your goal"), subtitle: String(localized: "Please try again."))
            }
        }
    }
}

extension WeeklyGoalPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case savePressed(goal: Int)

        var eventName: String {
            switch self {
            case .onAppear:     return "WeeklyGoalView_Appear"
            case .savePressed:  return "WeeklyGoalView_Save_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear: return nil
            case .savePressed(goal: let goal): return ["weekly_session_goal": goal]
            }
        }

        var type: LogType { .analytic }
    }
}
