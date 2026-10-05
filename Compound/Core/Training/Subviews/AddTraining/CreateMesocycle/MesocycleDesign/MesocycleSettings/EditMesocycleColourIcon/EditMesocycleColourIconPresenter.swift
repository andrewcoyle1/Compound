import SwiftUI

@Observable
@MainActor
class EditMesocycleColourIconPresenter {

    private let interactor: EditMesocycleColourIconInteractor
    private let router: EditMesocycleColourIconRouter

    var selectedColour: Color
    var selectedIcon: String

    var colours: [Color] { MesocycleIconPresenter.defaultColours }
    var icons: [String] { MesocycleIconPresenter.defaultIcons }

    private let onSave: (String, String) -> Void

    init(colour: String, icon: String, onSave: @escaping (String, String) -> Void, interactor: EditMesocycleColourIconInteractor, router: EditMesocycleColourIconRouter) {
        self.selectedColour = Color(hex: colour)
        self.selectedIcon = icon
        self.onSave = onSave
        self.interactor = interactor
        self.router = router
    }

    func onColourPressed(_ colour: Color) {
        selectedColour = colour
    }

    func onIconPressed(_ icon: String) {
        selectedIcon = icon
    }

    func onSavePressed() {
        onSave(selectedColour.asHex(), selectedIcon)
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
            case .onAppear:     return "EditMesocycleColourIconView_Appear"
            case .onDisappear:  return "EditMesocycleColourIconView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
