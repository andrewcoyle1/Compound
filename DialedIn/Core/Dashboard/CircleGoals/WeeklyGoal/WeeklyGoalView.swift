import SwiftUI

/// A stepper sheet for the weekly session goal, opened from the user's own profile and from the
/// Dashboard strip while no goal is set.
struct WeeklyGoalView: View {

    @State var presenter: WeeklyGoalPresenter

    var body: some View {
        List {
            Section {
                Stepper(value: $presenter.goal, in: CircleWeek.goalRange) {
                    Text("\(presenter.goal) \(presenter.goal == 1 ? String(localized: "session") : String(localized: "sessions")) a week")
                        .font(.headline)
                }
            } footer: {
                Text("Your circle sees your progress towards this as a ring round your face.")
            }
        }
        .navigationTitle("Weekly Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onCancelPressed()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    presenter.onSavePressed()
                }
                .disabled(presenter.isSaving)
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.weeklyGoalView(router: router)
    }
}

extension CoreBuilder {

    func weeklyGoalView(router: AnyRouter) -> some View {
        WeeklyGoalView(
            presenter: WeeklyGoalPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }

}

extension CoreRouter {

    func showWeeklyGoalView() {
        router.showScreen(.sheetConfig(config: ResizableSheetConfig(detents: [.medium]))) { router in
            builder.weeklyGoalView(router: router)
        }
    }

}
