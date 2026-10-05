import SwiftUI

@Observable
@MainActor
class RenameWorkoutTemplateModelPresenter {
    private let interactor: RenameWorkoutTemplateModelInteractor
    private let router: RenameWorkoutTemplateModelRouter

    var nameText: String

    var canSave: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        interactor: RenameWorkoutTemplateModelInteractor,
        router: RenameWorkoutTemplateModelRouter,
        initialName: String
    ) {
        self.interactor = interactor
        self.router = router
        self.nameText = initialName
    }

    func onCancelPressed() {
        router.dismissScreen()
    }

    func onSavePressed(onSave: (String) -> Void) {
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
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
            case .onAppear:     return "RenameWorkoutTemplateModelView_Appear"
            case .onDisappear:  return "RenameWorkoutTemplateModelView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
