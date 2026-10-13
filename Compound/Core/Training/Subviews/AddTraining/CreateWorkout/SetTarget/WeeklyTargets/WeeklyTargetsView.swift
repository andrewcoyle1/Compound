import SwiftUI

struct WeeklyTargetsDelegate {
    /// The exercise as the editor holds it when the screen opens. The screen is the only editor of
    /// its variations while it is open, so it keeps its own copy and hands each change back rather
    /// than reading a binding.
    let exercise: WorkoutTemplateExercise
    let onChange: @MainActor ([MicrocycleSetTargets]) -> Void
}

struct WeeklyTargetsView: View {

    @State var presenter: WeeklyTargetsPresenter

    var body: some View {
        List {
            Section {
                Text(presenter.summary)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Each week's targets apply from that week until the next one listed.")
            }

            ForEach(presenter.variations) { variation in
                Section {
                    weekStepper(variation)
                        .rowActions { deleteButton(variation) }
                    ListRowButton(title: String(localized: "Targets"), subtitle: presenter.setsTitle(variation)) {
                        presenter.onVariationPressed(variation)
                    }
                    .rowActions { deleteButton(variation) }
                }
            }

            Section {
                Button {
                    presenter.onAddVariationPressed()
                } label: {
                    Label("Add Week", systemImage: Symbol.add)
                }
                .disabled(!presenter.canAddVariation)
                .accessibilityIdentifier("WeeklyTargets.add")
            }
        }
        .navigationTitle("Weekly Targets")
        .navigationSubtitle(presenter.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
    }

    /// A step onto a week another variation starts on is disabled rather than refused with an alert:
    /// a nil action greys out that half of the stepper.
    private func weekStepper(_ variation: WeeklyTargetsPresenter.Variation) -> some View {
        Stepper(
            label: { Text(presenter.weekTitle(variation)) },
            onIncrement: stepAction(variation, by: 1),
            onDecrement: stepAction(variation, by: -1)
        )
    }

    private func stepAction(_ variation: WeeklyTargetsPresenter.Variation, by delta: Int) -> (() -> Void)? {
        guard presenter.canStep(variation, by: delta) else { return nil }
        return { presenter.onStep(variation, by: delta) }
    }

    private func deleteButton(_ variation: WeeklyTargetsPresenter.Variation) -> some View {
        Button(role: .destructive) {
            presenter.onDeletePressed(variation)
        } label: {
            Label("Delete", systemImage: Symbol.delete)
        }
    }
}

extension CoreBuilder {

    func weeklyTargetsView(router: AnyRouter, delegate: WeeklyTargetsDelegate) -> some View {
        WeeklyTargetsView(
            presenter: WeeklyTargetsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {

    func showWeeklyTargetsView(delegate: WeeklyTargetsDelegate) {
        router.showScreen(.push) { router in
            builder.weeklyTargetsView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    var exercise = WorkoutTemplateExercise.mock
    exercise.setTargetsByMicrocycle = [
        MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [SetTarget(setNumber: 1), SetTarget(setNumber: 2)]),
        MicrocycleSetTargets(fromMicrocycle: 9, setTargets: [SetTarget(setNumber: 1), SetTarget(setNumber: 2), SetTarget(setNumber: 3)])
    ]
    let delegate = WeeklyTargetsDelegate(exercise: exercise, onChange: { _ in })

    return RouterView { router in
        builder.weeklyTargetsView(router: router, delegate: delegate)
    }
}
