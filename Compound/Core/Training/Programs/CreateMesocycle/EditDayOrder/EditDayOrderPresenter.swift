import SwiftUI

@Observable
@MainActor
class EditDayOrderPresenter {

    var dayPlans: [WorkoutTemplateModel]
    private let onSave: ([WorkoutTemplateModel]) -> Void
    private let interactor: EditDayOrderInteractor
    private let router: EditDayOrderRouter

    init(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void, interactor: EditDayOrderInteractor, router: EditDayOrderRouter) {
        self.dayPlans = dayPlans
        self.onSave = onSave
        self.interactor = interactor
        self.router = router
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        dayPlans.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func onSavePressed() {
        onSave(dayPlans)
        router.dismissScreen()
    }

    func onCancelPressed() {
        router.dismissScreen()
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "EditDayOrderView_Appear"
            case .onDisappear:  return "EditDayOrderView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
