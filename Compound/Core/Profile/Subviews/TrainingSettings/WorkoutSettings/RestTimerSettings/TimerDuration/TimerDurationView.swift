import SwiftUI

struct TimerDurationDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct TimerDurationView: View {

    @State var presenter: TimerDurationPresenter
    let delegate: TimerDurationDelegate

    var body: some View {
        List {
            Section {
                ForEach(ExerciseType.allCases, id: \.self) { type in
                    ListRowButton(
                        title: type.name,
                        subtitle: presenter.formattedDuration(for: type)
                    ) {
                        presenter.onEditPressed(type: type)
                    }
                }
            } header: {
                MethodInfoHeader(title: "Default Timers", info: .restIntervals)
            } footer: {
                Text("Until you set a time for a type, compound sets of 6 reps or fewer rest 3:00.")
            }

            // Its own section, styled as an action, and it asks first: it sat among the rows it
            // resets, looked like them, and reset at once.
            Section {
                Button("Reset Default Timers", role: .destructive) {
                    presenter.onResetDefaultsPressed()
                }
            }

            Section {
                ForEach(presenter.exerciseOverrides) { override in
                    ListRowButton(
                        title: override.name,
                        subtitle: presenter.formattedDuration(seconds: override.seconds)
                    ) {
                        presenter.onEditExerciseOverridePressed(override)
                    }
                    .rowActions {
                        Button("Remove", role: .destructive) {
                            presenter.removeExerciseOverride(override)
                        }
                    }
                }
                ListRowButton(
                    title: String(localized: "Add Exercise Timer"),
                    subtitle: String(localized: "Set timers for specific exercises")
                ) {
                    presenter.onAddExerciseTimerPressed()
                }
            } header: {
                Text("Exercise Timers")
            } footer: {
                Text("These take precedence over default timers")
            }
        }
        .navigationTitle("Timer Duration")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isEditingType) {
            if let type = presenter.editingType {
                durationPicker(title: type.name, onSave: { presenter.saveEdit() })
            }
        }
        .sheet(isPresented: $presenter.isEditingExercise) {
            durationPicker(
                title: presenter.editingExerciseName,
                onSave: { presenter.saveExerciseEdit() }
            )
        }
        .sheet(isPresented: $presenter.isAddingExerciseTimer) {
            exercisePicker
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Duration Picker Sheet

    private var exercisePicker: some View {
        NavigationStack {
            List {
                ForEach(presenter.exercisesWithoutOverride) { exercise in
                    ListRowButton(title: exercise.name, accessory: .none) {
                        presenter.onExercisePicked(exercise)
                    }
                }
            }
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { presenter.isAddingExerciseTimer = false }
                }
            }
        }
    }

    @ViewBuilder
    private func durationPicker(title: String, onSave: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Picker("Minutes", selection: $presenter.editMinutes) {
                        ForEach(0..<10, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Seconds", selection: $presenter.editSeconds) {
                        ForEach([0, 15, 30, 45], id: \.self) { sec in
                            Text("\(sec) sec").tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .padding(.horizontal)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.isEditingType = false
                        presenter.isEditingExercise = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { onSave() }
                }
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = TimerDurationDelegate()

    return RouterView { router in
        builder.timerDurationView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func timerDurationView(router: AnyRouter, delegate: TimerDurationDelegate) -> some View {
        TimerDurationView(
            presenter: TimerDurationPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showTimerDurationView(delegate: TimerDurationDelegate) {
        router.showScreen(.push) { router in
            builder.timerDurationView(router: router, delegate: delegate)
        }
    }

}
