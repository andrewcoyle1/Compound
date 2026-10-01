import Foundation
import SwiftUI

struct SetTargetDelegate {
    var exercise: Binding<WorkoutTemplateExercise>
}

struct SetTargetView: View {
    
    @State var presenter: SetTargetPresenter

    @ScaledMetric(relativeTo: .body) private var numberColumnWidth: CGFloat = 44

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Set")
                        .frame(width: numberColumnWidth)
                    Text("Reps Min")
                        .frame(maxWidth: .infinity)
                    Text("Reps Max")
                        .frame(maxWidth: .infinity)
                    Text("RIR")
                        .frame(width: numberColumnWidth)
                }
                .font(.label)
                .foregroundStyle(.secondary)
                // Each field names its own column and set, so the headings would only be read twice.
                .accessibilityHidden(true)

                ForEach($presenter.workingExercise.setTargets) { $setTarget in
                    HStack {
                        numberBadge("\(setTarget.setNumber)")
                            .accessibilityLabel("Set \(setTarget.setNumber)")

                        TextField("Optional", text: intTextBinding($setTarget.minReps))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Set \(setTarget.setNumber), minimum reps")

                        TextField("Optional", text: intTextBinding($setTarget.maxReps))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Set \(setTarget.setNumber), maximum reps")

                        numberBadge(setTarget.rirTarget.map { "\($0)" } ?? Format.placeholder)
                            .accessibilityLabel("Reps in reserve")
                            .accessibilityValue(setTarget.rirTarget.map { "\($0)" } ?? Format.placeholder)
                    }
                    .rowActions {
                        Button(role: .destructive) {
                            presenter.onDeleteSetPressed(setTarget)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }
                    }
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowInsets(.vertical, 0)
                }
                Button {
                    presenter.onAddSetPressed()
                } label: {
                    Label("Add Set", systemImage: Symbol.add)
                }
                .accessibilityLabel("Add set target")
            }
            
            Section {
                ListRowToggle(
                    title: String(localized: "Set Rest Timers"),
                    subtitle: String(localized: "This will override default exercise settings."),
                    systemImage: Symbol.rest,
                    isOn: $presenter.workingExercise.setRestTimers
                )
            }
        }
        .navigationTitle("Targets")
        .navigationSubtitle(presenter.workingExercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
        .interactiveDismissDisabled(presenter.hasUnsavedChanges)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onClosePressed()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed()
            }
        }
    }
    
    /// The set number and RIR columns, as a badge that grows with its text rather than a fixed
    /// circle the number overflowed at large sizes.
    private func numberBadge(_ text: String) -> some View {
        Text(text)
            .font(.rowDetail)
            .monospacedDigit()
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color.tintedSurface(.secondary), in: .capsule)
            .frame(width: numberColumnWidth)
    }

    private func intTextBinding(_ value: Binding<Int?>) -> Binding<String> {
        Binding(
            get: {
                guard let currentValue = value.wrappedValue else { return "" }
                return String(currentValue)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    value.wrappedValue = nil
                    return
                }
                value.wrappedValue = Int(trimmed)
            }
        )
    }
}

extension CoreBuilder {
    
    func setTargetView(router: AnyRouter, delegate: SetTargetDelegate) -> some View {
        SetTargetView(
            presenter: SetTargetPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
    
}

extension CoreRouter {
    
    func showSetTargetView(delegate: SetTargetDelegate) {
        router.showScreen(.sheet) { router in
            builder.setTargetView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var exercise: WorkoutTemplateExercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = SetTargetDelegate(exercise: $exercise)
    
    return RouterView { router in
        builder.setTargetView(router: router, delegate: delegate)
    }
    
}
