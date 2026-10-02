import SwiftUI

@Observable
@MainActor
class EditDeloadPresenter {

    var selected: DeloadType
    private let onSave: (DeloadType) -> Void
    private let router: EditDeloadRouter

    init(selected: DeloadType, onSave: @escaping (DeloadType) -> Void, router: EditDeloadRouter) {
        self.selected = selected
        self.onSave = onSave
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
}
