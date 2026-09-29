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
                            Label("Equipment", systemImage: "scalemass")
                        }
                    }

                    Button {
                        presenter.onWarmupSetsPressed(delegate.exercise)
                    } label: {
                        Label("Warmup", systemImage: "target")
                    }

                    Button {
                        presenter.onTargetsPressed(delegate.exercise)
                    } label: {
                        Label("Targets", systemImage: "scope")
                    }

                    Button {
                        presenter.onSwapPressed(delegate.exercise)
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }

                    Button {
                        presenter.onSupersetPressed(
                            exercise: delegate.exercise,
                            allWorkoutExercises: delegate.allWorkoutExercises,
                            onSetSupersetGroup: delegate.onSetSupersetGroup
                        )
                    } label: {
                        let groupLabel: String = {
                            guard let groupId = delegate.exercise.wrappedValue.supersetGroupId else { return "Superset" }
                            let count = delegate.allWorkoutExercises.filter { $0.supersetGroupId == groupId }.count
                            return count > 2 ? String(localized: "Remove Circuit") : String(localized: "Remove Superset")
                        }()
                        Label(groupLabel, systemImage: "arrow.2.circlepath")
                    }
                    Menu {
                        Button {
                            presenter.onExerciseSettingsPressed(exercise: delegate.exercise.wrappedValue)
                        } label: {
                            Label("Exercise Settings", systemImage: "slider.horizontal.3")
                        }
                        
                        Button(role: .destructive) {
                            presenter.deleteExercise(delegate.exercise, onDelete: delegate.onDeleteExercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.secondary)
                .buttonBorderShape(.capsule)
            }
        }
    }

    private var columnHeaders: some View {
        let unitPreference = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        return HStack(alignment: .firstTextBaseline) {
            Text("Set")
                .frame(width: 34, alignment: .center)
            Spacer()
            prevAutoHeader(exercise: delegate.exercise)
            Spacer()
            HStack(spacing: 8) {
                unitMenu(exercise: delegate.exercise, unitPreference: unitPreference)
                    .frame(width: 70)
                Text("Reps")
                    .frame(width: 50)
            }
            Spacer()
            Text("Done")
                .frame(width: 32, alignment: .center)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .dynamicTypeSize(...SetTrackerRowView.maxDynamicTypeSize)
        .padding(.top, 4)
    }
    
    private func prevAutoHeader(exercise: Binding<WorkoutExerciseModel>) -> some View {
        Button {
            presenter.showAutoRanges.toggle()
        } label: {
            if presenter.showAutoRanges {
                Label("Auto", systemImage: "wand.and.stars")
            } else {
                Label("Prev", systemImage: "arrow.left")
            }
        }
        .buttonStyle(.bordered)
        .font(.caption2)
        .foregroundColor(.secondary)
        .frame(width: 90, alignment: .center)
    }
    
    private var addSetButton: some View {
        HStack {
            Button {
                presenter.addSet(exercise: delegate.exercise)
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .accessibilityLabel("Add set")
            .tint(.secondary)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .frame(width: 34, alignment: .center)
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
                .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
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
