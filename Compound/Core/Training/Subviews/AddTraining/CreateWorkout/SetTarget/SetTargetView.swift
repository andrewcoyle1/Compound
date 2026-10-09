import Foundation
import SwiftUI

/// What the set-target editor offers beside the targets.
enum SetTargetScope: Equatable {
    /// A logged session's targets, from the tracker, which keeps only the targets.
    case session
    /// A template exercise: its targets and its plan (warm-ups, rest, notes, link, substitutions,
    /// weekly variation).
    case template
    /// One week's variation of a template exercise: its targets only.
    case week(Int)
}

struct SetTargetDelegate {
    var exercise: Binding<WorkoutTemplateExercise>
    var scope: SetTargetScope = .session
}

struct SetTargetView: View {
    
    @State var presenter: SetTargetPresenter

    @ScaledMetric(relativeTo: .body) private var numberColumnWidth: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    VStack(alignment: .leading, spacing: 0) {
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
                        if presenter.plansSets {
                            planButton(setTarget)
                        }
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
            
            if presenter.showsPlan {
                ExercisePlanSection(presenter: presenter)
            }

            if presenter.showsRestTimers {
                Section {
                    ListRowToggle(
                        title: String(localized: "Set Rest Timers"),
                        subtitle: String(localized: "This will override default exercise settings."),
                        systemImage: Symbol.rest,
                        isOn: $presenter.workingExercise.setRestTimers
                    )
                }
            }
        }
        .navigationTitle(presenter.title)
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
            .accessibilityIdentifier("SetTarget.save")
        }
    }
    
    /// With the set plan on, the set's kind and its plan under its reps, opening that set's plan.
    /// A standard set names its kind without a chip, so it reads as nothing extra.
    private func planButton(_ setTarget: SetTarget) -> some View {
        Button {
            presenter.onSetPlanPressed(setTarget)
        } label: {
            HStack(spacing: Spacing.s) {
                AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.s) {
                    if let chip = presenter.planChip(for: setTarget) {
                        Chip(chip)
                    } else {
                        Text(presenter.planTitle(for: setTarget))
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                    if let summary = presenter.planSummary(for: setTarget) {
                        Text(summary)
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.rowDetail.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            // Under the reps fields, or the full width at the accessibility sizes, where the
            // number column is wide enough to break "Standard" over two lines.
            .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : numberColumnWidth + Spacing.s)
            .frame(minHeight: ControlSize.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presenter.planAccessibilityLabel(for: setTarget))
        .accessibilityValue(presenter.planSummary(for: setTarget) ?? "")
        .accessibilityAddTraits(.isButton)
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
    let delegate = SetTargetDelegate(exercise: $exercise, scope: .template)
    
    return RouterView { router in
        builder.setTargetView(router: router, delegate: delegate)
    }
    
}
