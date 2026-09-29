import SwiftUI

struct ExerciseSettingsDelegate {
    var exercise: ExerciseModel
    var eventParameters: [String: Any]? {
        nil
    }
}

struct ExerciseSettingsView: View {

    @State var presenter: ExerciseSettingsPresenter
    let delegate: ExerciseSettingsDelegate

    var body: some View {
        List {
            Section {
                CustomLabelButtonView(
                    symbolName: "info.circle",
                    title: String(localized: "Info"),
                    subtitle: delegate.exercise.description ?? "View instructions, exercise details, and history"
                ) {
                    Button {
                        presenter.onInfoPressed()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Exercise info")
                }
                CustomLabelButtonView(
                    symbolName: "scalemass",
                    title: String(localized: "Weights"),
                    subtitle: presenter.weightsSubtitle
                ) {
                    Button {
                        presenter.onWeightsPressed()
                    } label: {
                        Text("Edit")
                    }
                    .buttonStyle(.bordered)
                }
                CustomLabelButtonView(
                    symbolName: "timer",
                    title: String(localized: "Rest Timer"),
                    subtitle: presenter.restSubtitle
                ) {
                    Button {
                        presenter.onRestTimerPressed()
                    } label: {
                        Text("Edit")
                    }
                    .buttonStyle(.bordered)
                }
                // Shown for exercises worked one limb at a time, which is read off the metrics
                // the exercise is tracked by. It used to be gated on `laterality`, which nearly
                // every exercise leaves empty, so the row almost never appeared.
                if presenter.isPerSide {
                    CustomLabelButtonView(
                        symbolName: "arrow.trianglehead.branch",
                        title: String(localized: "Rest Between Left/Right Sets"),
                        subtitle: presenter.sideSetRestSubtitle
                    ) {
                        Button {
                            presenter.onSideSetRestPressed()
                        } label: {
                            Text("Edit")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                CustomLabelButtonView(
                    symbolName: "text.page",
                    title: String(localized: "Exercise Note"),
                    subtitle: presenter.noteSubtitle
                ) {
                    Button {
                        presenter.onNotePressed()
                    } label: {
                        Text("Edit")
                    }
                    .buttonStyle(.bordered)
                }
                // Two rows removed rather than left inert:
                // - "Do Not Recommend" was a disabled toggle bound to .constant(false), and there
                //   is no program-suggestion engine for it to exclude an exercise from.
                // - "Edit Duplicate" needs CreateExercise to accept a prefill; showCreateExerciseView
                //   takes no delegate today, so routing there would open an empty form, not a copy.
            } header: {
                Text(delegate.exercise.name)
            }
            .listSectionMargins(.top, 0)
        }
        .navigationTitle("Exercise Settings")
        .navigationBarTitleDisplayMode(.inline)
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
    let delegate = ExerciseSettingsDelegate(exercise: ExerciseModel.mock)
    
    return RouterView { router in
        builder.exerciseSettingsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func exerciseSettingsView(router: AnyRouter, delegate: ExerciseSettingsDelegate) -> some View {
        ExerciseSettingsView(
            presenter: ExerciseSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                exercise: delegate.exercise
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {
    
    func showExerciseSettingsView(delegate: ExerciseSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseSettingsView(router: router, delegate: delegate)
        }
    }
    
}
