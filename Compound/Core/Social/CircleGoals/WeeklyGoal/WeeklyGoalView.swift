import SwiftUI

/// A one-tap sheet for the weekly session goal, opened from the user's own profile and from the
/// Dashboard strip while no goal is set.
struct WeeklyGoalView: View {

    @State var presenter: WeeklyGoalPresenter

    var body: some View {
        Form {
            Section {
                if let goal = presenter.selectedGoal {
                    Text("^[\(goal) session](inflect: true) a week")
                        .font(.sectionTitle)
                } else {
                    Text("Set your weekly session goal")
                        .font(.sectionTitle)
                }
                Picker(String(localized: "Weekly Goal"), selection: goalSelection) {
                    ForEach(CircleWeek.goalRange, id: \.self) { goal in
                        Text(goal, format: .number).tag(Optional(goal))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(presenter.isSaving)
            } header: {
                MethodInfoHeader(title: "Weekly Goal", info: .weeklySessionGoal)
            } footer: {
                Text("Your circle sees your progress towards this as a ring round your face.")
            }
        }
        .navigationTitle("Weekly Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onCancelPressed()
                }
            }
            if presenter.isSaving {
                ToolbarItem(placement: .confirmationAction) {
                    ProgressView()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private var goalSelection: Binding<Int?> {
        Binding(
            get: { presenter.selectedGoal },
            set: { goal in
                if let goal { presenter.onGoalSelected(goal) }
            }
        )
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
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.weeklyGoalView(router: router)
        }
    }

}
