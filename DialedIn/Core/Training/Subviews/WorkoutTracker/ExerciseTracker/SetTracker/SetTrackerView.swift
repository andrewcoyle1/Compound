//
//  WorkoutTrackerView+SetUI.swift
//  DialedIn
//
//  Extracted for function_body_length.
//

import SwiftUI

struct SetTrackerDelegate {
    let exercise: Binding<WorkoutExerciseModel>
    let lastExercise: WorkoutExerciseModel?
    /// What smart progression suggests for this exercise, one entry per working set.
    var progressionSuggestion: ProgressionSuggestion?
    var allWorkoutExercises: [WorkoutExerciseModel] = []
    var onSetSupersetGroup: @MainActor (String, String?) -> Void = { _, _ in }
    var onDeleteExercise: @MainActor () -> Void = { }
    /// Called with the set that was just logged, so the screen can re-suggest what is left.
    var onSetCompleted: @MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void = { _, _ in }
}

struct SetTrackerView<SetTrackerRow: View>: View {

    @State var presenter: SetTrackerPresenter
    let delegate: SetTrackerDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The rows stack into two lines at accessibility sizes; the headers follow them.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }
    
    var body: some View {
        Group {
            VStack {
                equipmentButton
                columnHeaders
            }
            ForEach(delegate.exercise.sets.filter { $0.wrappedValue.completedAt == nil || !$0.wrappedValue.isWarmup }) { set in
                // Matched on the side as well as the number: a left set inheriting the right
                // arm's last weight sends the user chasing the other arm's numbers.
                let lastSet = delegate.lastExercise?.matchingSet(for: set.wrappedValue)
                let suggestedSet = delegate.progressionSuggestion?.suggestedSet(
                    for: set.wrappedValue,
                    in: delegate.exercise.wrappedValue
                )
                setTrackerRow(
                    SetTrackerRowDelegate(
                        exercise: delegate.exercise,
                        set: set,
                        lastSet: lastSet,
                        progressionSuggestion: suggestedSet,
                        showAutoRanges: presenter.showAutoRanges,
                        onSetCompleted: delegate.onSetCompleted
                    )
                )
                .listRowSeparator(.visible)
            }
            addSetButton
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.vertical, 0)
        .listRowInsets(.leading, 0)
        .listSectionMargins(.top, 0)
    }
    
    private var equipmentButton: some View {
        ScrollView(.horizontal) {
            HStack {
                Group {
                    if !delegate.exercise.wrappedValue.equipmentVariations.isEmpty {
                        Button {
                            presenter.onExerciseEquipmentPressed(delegate.exercise)
                        } label: {
                            Label("Equipment", systemImage: Symbol.equipment)
                                .tapTarget()
                        }
                    }

                    Button {
                        presenter.onWarmupSetsPressed(delegate.exercise)
                    } label: {
                        Label("Warmup", systemImage: Symbol.warmup)
                            .tapTarget()
                    }

                    Button {
                        presenter.onTargetsPressed(delegate.exercise)
                    } label: {
                        Label("Targets", systemImage: Symbol.goal)
                            .tapTarget()
                    }

                    Button {
                        presenter.onSwapPressed(delegate.exercise)
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                            .tapTarget()
                    }

                    Button {
                        presenter.onSupersetPressed(
                            exercise: delegate.exercise,
                            allWorkoutExercises: delegate.allWorkoutExercises,
                            onSetSupersetGroup: delegate.onSetSupersetGroup
                        )
                    } label: {
                        let groupLabel: String = {
                            guard let groupId = delegate.exercise.wrappedValue.supersetGroupId else { return String(localized: "Superset") }
                            let count = delegate.allWorkoutExercises.filter { $0.supersetGroupId == groupId }.count
                            return count > 2 ? String(localized: "Remove Circuit") : String(localized: "Remove Superset")
                        }()
                        Label(groupLabel, systemImage: Symbol.superset)
                            .tapTarget()
                    }
                    Menu {
                        Button {
                            presenter.onExerciseSettingsPressed(exercise: delegate.exercise.wrappedValue)
                        } label: {
                            Label("Exercise Settings", systemImage: Symbol.settings)
                        }
                        
                        Button(role: .destructive) {
                            presenter.deleteExercise(delegate.exercise, onDelete: delegate.onDeleteExercise)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }

                    } label: {
                        Label("More", systemImage: Symbol.more)
                            .tapTarget()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.secondary)
                .buttonBorderShape(.capsule)
            }
            // Room for each chip's 44 pt hit area, which the scroll view would otherwise clip.
            .frame(minHeight: ControlSize.row)
        }
    }

    private var columnHeaders: some View {
        let unitPreference = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        return Group {
            if isStacked {
                // Over the stacked rows: the Prev/Auto switch for line one, the input headers over
                // the inputs of line two. The set and Done controls need no heading.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    prevAutoHeader(exercise: delegate.exercise)
                    inputHeaders(unitPreference: unitPreference)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Set")
                        .frame(width: SetTrackerRowView.setColumnWidth, alignment: .center)
                    Spacer()
                    prevAutoHeader(exercise: delegate.exercise)
                    Spacer()
                    inputHeaders(unitPreference: unitPreference)
                    Spacer()
                    Text("Done")
                        .frame(width: SetTrackerRowView.doneColumnWidth, alignment: .center)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, Spacing.xs)
    }

    /// One header per input the rows show, at the rows' widths. The weight header stood over every
    /// exercise, so a run was headed with a kg menu and "Reps".
    @ViewBuilder
    private func inputHeaders(unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)) -> some View {
        HStack(spacing: Spacing.s) {
            switch delegate.exercise.wrappedValue.trackingMode {
            case .weightReps:
                unitMenu(exercise: delegate.exercise, unitPreference: unitPreference)
                    .setColumn(width: 70, stretches: isStacked)
                Text("Reps")
                    .setColumn(width: 50, stretches: isStacked)
            case .repsOnly:
                Text("Reps")
                    .setColumn(width: 50, stretches: isStacked)
            case .timeOnly:
                Text("Time")
                    .setColumn(width: 90, stretches: isStacked)
            case .distanceTime:
                distanceUnitMenu(exercise: delegate.exercise, unitPreference: unitPreference)
                    .setColumn(width: 70, stretches: isStacked)
                Text("Time")
                    .setColumn(width: 70, stretches: isStacked)
            }
        }
    }
    
    private func prevAutoHeader(exercise: Binding<WorkoutExerciseModel>) -> some View {
        Button {
            presenter.showAutoRanges.toggle()
        } label: {
            if presenter.showAutoRanges {
                Label("Auto", systemImage: "wand.and.stars")
                    .tapTarget()
            } else {
                Label("Prev", systemImage: Symbol.history)
                    .tapTarget()
            }
        }
        .buttonStyle(.bordered)
        // Small, so "Auto" and its icon fit the Prev column; the hit area is the label's.
        .controlSize(.small)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: isStacked ? nil : SetTrackerRowView.previousColumnWidth, alignment: .center)
    }
    
    private var addSetButton: some View {
        HStack {
            Button {
                presenter.addSet(exercise: delegate.exercise)
            } label: {
                Image(systemName: Symbol.add)
                    .font(.caption)
                    .tapTarget()
            }
            .accessibilityLabel("Add set")
            .tint(.secondary)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .frame(width: SetTrackerRowView.setColumnWidth, alignment: .center)
            Spacer()
        }
        
    }

    @ViewBuilder
    private func unitMenu(exercise: Binding<WorkoutExerciseModel>, unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)) -> some View {
        Menu {
            ForEach(ExerciseWeightUnit.allCases, id: \.self) { unit in
                Button {
                    presenter.promptWeightUnitChange(unit, for: exercise)
                } label: {
                    HStack {
                        Text(unit.displayName)
                        if unit == unitPreference.weightUnit {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(unitPreference.weightUnit.abbreviation.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.s)
                .tapTarget()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Weight unit, \(unitPreference.weightUnit.displayName)")
    }

    private func distanceUnitMenu(exercise: Binding<WorkoutExerciseModel>, unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)) -> some View {
        Menu {
            ForEach(ExerciseDistanceUnit.allCases, id: \.self) { unit in
                Button {
                    presenter.promptDistanceUnitChange(unit, for: exercise)
                } label: {
                    if unit == unitPreference.distanceUnit {
                        Label(unit.displayName, systemImage: "checkmark")
                    } else {
                        Text(unit.displayName)
                    }
                }
            }
        } label: {
            Text(unitPreference.distanceUnit.abbreviation.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.s)
                .tapTarget()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Distance unit, \(unitPreference.distanceUnit.displayName)")
    }
}

#Preview {
    @Previewable @State var exercise: WorkoutExerciseModel = .mock
    let lastExercise: WorkoutExerciseModel = .mock

    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SetTrackerDelegate(
        exercise: $exercise,
        lastExercise: lastExercise
    )

    RouterView { router in
        List {
            DisclosureGroup(isExpanded: .constant(true)) {
                builder.setTrackerView(router: router, delegate: delegate)
            } label: {
                Text("Disclosure Group")
            }
        }
    }
}

extension CoreBuilder {
    func setTrackerView(
        router: AnyRouter,
        delegate: SetTrackerDelegate,
        onStartRest: ((Int) -> Void)? = nil
    ) -> some View {
        let presenter = SetTrackerPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        return SetTrackerView(
            presenter: presenter,
            delegate: delegate,
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate, onStartRest: onStartRest)
            }
        )
    }
}
