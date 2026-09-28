import Foundation
import SwiftUI

struct SetTargetDelegate {
    var exercise: Binding<WorkoutTemplateExercise>
}

struct SetTargetView: View {
    
    @State var presenter: SetTargetPresenter
    
    /// The committed binding from the parent (only written to on save)
    private let committedExercise: Binding<WorkoutTemplateExercise>
    
    /// Local working copy that drives the UI
    @State private var workingExercise: WorkoutTemplateExercise
    
    init(presenter: SetTargetPresenter, delegate: SetTargetDelegate) {
        self.presenter = presenter
        self.committedExercise = delegate.exercise
        self._workingExercise = State(initialValue: delegate.exercise.wrappedValue)
    }
    
    @ScaledMetric(relativeTo: .body) private var numberColumnWidth: CGFloat = 44

    var body: some View {
        List {
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
                
                ForEach($workingExercise.setTargets) { $setTarget in
                    HStack {
                        numberBadge("\(setTarget.setNumber)")

                        TextField("Optional", text: intTextBinding($setTarget.minReps))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Optional", text: intTextBinding($setTarget.maxReps))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        
                        numberBadge(setTarget.rirTarget.map { "\($0)" } ?? Format.placeholder)

                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            removeSetTarget(setTarget)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }
                    }
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowInsets(.vertical, 0)
                }
                Button {
                    addSetTarget()
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
                    isOn: $workingExercise.setRestTimers
                )
            }
        }
        .navigationTitle("Targets")
        .navigationSubtitle(workingExercise.exercise.name)
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
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                saveAndDismiss()
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

    private func addSetTarget() {
        let count = workingExercise.setTargets.count
        workingExercise.setTargets.append(SetTarget(setNumber: count + 1))
    }
    
    private func removeSetTarget(_ setTarget: SetTarget) {
        workingExercise.setTargets.removeAll { $0.id == setTarget.id }
        // Renumber remaining sets
        for index in workingExercise.setTargets.indices {
            workingExercise.setTargets[index].setNumber = index + 1
        }
    }
    
    private func saveAndDismiss() {
        // Write the entire working copy back to trigger @Observable detection
        committedExercise.wrappedValue = workingExercise
        presenter.onDismissPressed()
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
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
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
