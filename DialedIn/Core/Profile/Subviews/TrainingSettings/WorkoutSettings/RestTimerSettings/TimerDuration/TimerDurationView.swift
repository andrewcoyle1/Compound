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
                    CustomLabelButtonView(
                        title: type.name,
                        subtitle: presenter.formattedDuration(for: type)) {
                            Text("Edit")
                                .padding(.horizontal, 8)
                                .padding(8)
                                .background(Color.secondary.opacity(0.2), in: .capsule)
                                .anyButton(.press) {
                                    presenter.onEditPressed(type: type)
                                }
                        }
                }
                CustomLabelButtonView(
                    title: String(localized: "Reset Defaults"),
                    subtitle: String(localized: "Reset timers to default settings")) {
                        Text("Reset")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.resetDefaults()
                            }
                    }
            } header: {
                Text("Default Timers")
            }

            Section {
                ForEach(presenter.exerciseOverrides) { override in
                    CustomLabelButtonView(
                        title: override.name,
                        subtitle: presenter.formattedDuration(seconds: override.seconds)) {
                            Text("Edit")
                                .padding(.horizontal, 8)
                                .padding(8)
                                .background(Color.secondary.opacity(0.2), in: .capsule)
                                .anyButton(.press) {
                                    presenter.onEditExerciseOverridePressed(override)
                                }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) {
                                presenter.removeExerciseOverride(override)
                            }
                        }
                }
                CustomLabelButtonView(
                    title: String(localized: "Add Exercise Timer"),
                    subtitle: String(localized: "Set timers for specific exercises")) {
                        Text("Add")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.onAddExerciseTimerPressed()
                            }
                    }
            } header: {
                Text("Exercise Timers")
            } footer: {
                Text("These take precident over default timers")
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
                    Text(exercise.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tappableBackground()
                        .anyButton(.highlight) {
                            presenter.onExercisePicked(exercise)
                        }
                }
            }
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presenter.isAddingExerciseTimer = false }
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
                    Button("Cancel") {
                        presenter.isEditingType = false
                        presenter.isEditingExercise = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
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
