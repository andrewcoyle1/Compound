import SwiftUI

@Observable
@MainActor
class EditMesocycleColourIconPresenter {

    private let router: EditMesocycleColourIconRouter

    var selectedColour: Color
    var selectedIcon: String

    var colours: [Color] { MesocycleIconPresenter.defaultColours }
    var icons: [String] { MesocycleIconPresenter.defaultIcons }

    private let onSave: (String, String) -> Void

    init(colour: String, icon: String, onSave: @escaping (String, String) -> Void, router: EditMesocycleColourIconRouter) {
        self.selectedColour = Color(hex: colour)
        self.selectedIcon = icon
        self.onSave = onSave
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
}
