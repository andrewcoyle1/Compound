import SwiftUI

@Observable
@MainActor
class EditDayOrderPresenter {

    var dayPlans: [WorkoutTemplateModel]
    private let onSave: ([WorkoutTemplateModel]) -> Void
    private let router: EditDayOrderRouter

    init(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void, router: EditDayOrderRouter) {
        self.dayPlans = dayPlans
        self.onSave = onSave
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
}
