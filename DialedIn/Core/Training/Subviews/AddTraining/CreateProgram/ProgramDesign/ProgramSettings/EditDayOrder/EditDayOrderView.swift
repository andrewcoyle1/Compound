import SwiftUI

struct EditDayOrderView: View {

    @State var presenter: EditDayOrderPresenter

    var body: some View {
        List {
            ForEach(presenter.dayPlans) { plan in
                HStack(spacing: 12) {
                    Image(systemName: plan.exercises.isEmpty ? "bed.double" : "dumbbell")
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.subheadline)
                        Text(plan.exercises.isEmpty ? String(localized: "Rest") : String(localized: "Workout"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onMove { presenter.move(fromOffsets: $0, toOffset: $1) }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Day Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presenter.onCancelPressed() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { presenter.onSavePressed() }
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
