import SwiftUI

struct WarmupSetsDelegate {
    let exercise: Binding<WorkoutExerciseModel>
    var eventParameters: [String: Any]? {
        nil
    }
}

struct WarmupSetsView<TrackerRow: View>: View {

    @State var presenter: WarmupSetsPresenter
    let delegate: WarmupSetsDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> TrackerRow

    // Binding backed by presenter.exercise (which is @Observable) so the ForEach
    // re-renders when a set is toggled. Writes also propagate to the parent binding
    // to keep WorkoutTrackerPresenter.workoutSession in sync.
    private var exerciseBinding: Binding<WorkoutExerciseModel> {
        Binding(
            get: { presenter.exercise },
            set: {
                presenter.exercise = $0
                delegate.exercise.wrappedValue = $0
            }
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(exerciseBinding.sets.filter { $0.wrappedValue.completedAt != nil && $0.wrappedValue.isWarmup }) { set in
                    setTrackerRow(
                        SetTrackerRowDelegate(
                            exercise: exerciseBinding,
                            set: set,
                            lastSet: nil
                        )
                    )
                    .listRowSeparator(.visible)
                }
                .listRowSeparator(.hidden)
            }
            .listSectionMargins(.top, 0)
            .listSectionSeparator(.hidden)
        }
        .navigationTitle("Warmup Sets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WarmupSetsDelegate(exercise: Binding.constant(WorkoutExerciseModel.mock))

    return RouterView { router in
        builder.warmupSetsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func warmupSetsView(router: AnyRouter, delegate: WarmupSetsDelegate) -> some View {
        WarmupSetsView(
            presenter: WarmupSetsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                exercise: delegate.exercise.wrappedValue
            ),
            delegate: delegate,
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate)
            }
        )
    }

}

extension CoreRouter {

    func showWarmupSetsView(delegate: WarmupSetsDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.warmupSetsView(router: router, delegate: delegate)
        }
    }

}
