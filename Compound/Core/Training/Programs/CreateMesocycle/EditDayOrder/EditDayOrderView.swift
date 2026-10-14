import SwiftUI

struct EditDayOrderView: View {

    @State var presenter: EditDayOrderPresenter

    var body: some View {
        List {
            ForEach(presenter.dayPlans) { plan in
                ListRow(
                    title: plan.name,
                    subtitle: plan.exercises.isEmpty ? String(localized: "Rest") : String(localized: "Workout"),
                    systemImage: plan.exercises.isEmpty ? Symbol.restDay : Symbol.workout,
                    tint: .secondary
                )
            }
            .onMove { presenter.move(fromOffsets: $0, toOffset: $1) }
        }
        .environment(\.editMode, .constant(.active))
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .navigationTitle("Day Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { presenter.onCancelPressed() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { presenter.onSavePressed() }
            }
        }
    }
}

extension CoreBuilder {
    func editDayOrderView(router: AnyRouter, dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void) -> some View {
        let coreRouter = CoreRouter(router: router, builder: self)
        return EditDayOrderView(
            presenter: EditDayOrderPresenter(
                dayPlans: dayPlans,
                onSave: onSave,
                interactor: interactor,
                router: coreRouter
            )
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.editDayOrderView(
            router: router,
            dayPlans: WorkoutTemplateModel.mocks,
            onSave: { _ in }
        )
    }
}
