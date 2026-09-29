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
                ListRowButton(
                    title: String(localized: "Info"),
                    subtitle: delegate.exercise.description ?? String(localized: "View instructions, exercise details, and history"),
                    systemImage: Symbol.info
                ) {
                    presenter.onInfoPressed()
                }
                Picker(selection: Binding(get: { presenter.unitPreference.weightUnit }, set: { presenter.onSelectWeightUnit($0) })) {
                    ForEach(ExerciseWeightUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                } label: {
                    Label("Weight Unit", systemImage: Symbol.weight)
                }
                .pickerStyle(.menu)
                Picker(selection: Binding(get: { presenter.unitPreference.distanceUnit }, set: { presenter.onSelectDistanceUnit($0) })) {
                    ForEach(ExerciseDistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                } label: {
                    Label("Distance Unit", systemImage: Symbol.cardio)
                }
                .pickerStyle(.menu)
                editRow(title: String(localized: "Rest Timer"), subtitle: presenter.restSubtitle, systemImage: Symbol.rest) {
                    presenter.onRestTimerPressed()
                }
                // Shown for exercises worked one limb at a time, which is read off the metrics
                // the exercise is tracked by. It used to be gated on `laterality`, which nearly
                // every exercise leaves empty, so the row almost never appeared.
                if presenter.isPerSide {
                    editRow(
                        title: String(localized: "Rest Between Left/Right Sets"),
                        subtitle: presenter.sideSetRestSubtitle,
                        systemImage: "arrow.trianglehead.branch"
                    ) {
                        presenter.onSideSetRestPressed()
                    }
                }
                editRow(title: String(localized: "Exercise Note"), subtitle: presenter.noteSubtitle, systemImage: Symbol.note) {
                    presenter.onNotePressed()
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

    /// The whole row opens the editor. Only a 20 pt "Edit" chip at its end used to.
    private func editRow(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        ListRowButton(title: title, subtitle: subtitle, systemImage: systemImage, action: action)
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
