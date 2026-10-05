import SwiftUI

@Observable
@MainActor
class EditDeloadPresenter {

    var selected: DeloadType
    private let onSave: (DeloadType) -> Void
    private let interactor: EditDeloadInteractor
    private let router: EditDeloadRouter

    init(selected: DeloadType, onSave: @escaping (DeloadType) -> Void, interactor: EditDeloadInteractor, router: EditDeloadRouter) {
        self.selected = selected
        self.onSave = onSave
        self.interactor = interactor
        self.router = router
    }

    var allCases: [DeloadType] { DeloadType.allCases }

    func onSelect(_ type: DeloadType) {
        selected = type
    }

    func onSavePressed() {
        onSave(selected)
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
            case .onAppear:     return "EditDeloadView_Appear"
            case .onDisappear:  return "EditDeloadView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
