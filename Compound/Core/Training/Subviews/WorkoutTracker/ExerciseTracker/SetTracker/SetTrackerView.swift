//
//  WorkoutTrackerView+SetUI.swift
//  Compound
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
    /// The live tracker's card: rows drawn done, current or upcoming, the exercise's actions in an
    /// overflow menu that `header` places, and the rest timer among the rows.
    var card: SetTrackerCard?
}

/// What the live tracker adds to the set table.
struct SetTrackerCard {
    /// The card's title row, handed the actions menu to place in it.
    var header: (AnyView) -> AnyView
    /// This session's note on the exercise, written from the actions menu.
    var hasNote = false
    var onNotePressed: @MainActor () -> Void = { }
    /// Moves the exercise to the end of the workout; `nil` when there is nothing to put it behind.
    var onDoLater: (@MainActor () -> Void)?
    /// Why smart progression changed today's numbers, as a row above the sets until it is tapped.
    var progressionNote: String?
    var onProgressionNoteAcknowledged: @MainActor () -> Void = { }
    var restTimer: InlineRestTimer?
    /// See `SetTrackerRowDelegate.onLogSet` and `onCustomRestChanged`.
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?
}

struct SetTrackerView<SetTrackerRow: View>: View {

    @State var presenter: SetTrackerPresenter
    let delegate: SetTrackerDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The rows stack into two lines at accessibility sizes; the headers follow them.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // The title row keeps the list's insets; the table runs to the card's edge.
        if let card = delegate.card {
            card.header(AnyView(actionsMenu))
                .listRowSeparator(.hidden)
                .listRowInsets(.bottom, 0)
        }
        if let card = delegate.card, let note = card.progressionNote {
            ProgressionNote(text: note, onAcknowledge: card.onProgressionNoteAcknowledged)
                .listRowSeparator(.hidden)
        }
        Group {
            VStack {
                if delegate.card == nil {
                    equipmentButton
                }
                columnHeaders
            }
            if delegate.card?.restTimer?.anchor == .top {
                restRow
            }
            ForEach(delegate.exercise.sets.filter { $0.wrappedValue.completedAt == nil || !$0.wrappedValue.isWarmup }) { set in
                // Matched on the side as well as the number: a left set inheriting the right
                // arm's last weight sends the user chasing the other arm's numbers.
                let lastSet = delegate.lastExercise?.matchingSet(for: set.wrappedValue, in: delegate.exercise.wrappedValue)
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
                        rowState: delegate.card == nil ? nil : ActiveWorkout.rowState(of: set.wrappedValue, in: delegate.exercise.wrappedValue),
                        onSetCompleted: delegate.onSetCompleted,
                        onLogSet: delegate.card?.onLogSet,
                        onCustomRestChanged: delegate.card?.onCustomRestChanged
                    )
                )
                .listRowSeparator(.visible)
                if delegate.card?.restTimer?.anchor == .below(setId: set.wrappedValue.id) {
                    restRow
                }
            }
            addSetButton
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.vertical, 0)
        .listRowInsets(.leading, 0)
        .listSectionMargins(.top, 0)
    }

    @ViewBuilder
    private var restRow: some View {
        if let timer = delegate.card?.restTimer {
            InlineRestTimerRow(timer: timer)
        }
    }

    // MARK: - Actions

    /// The chips over the table where the exercise has no card header, as when a finished
    /// workout is being corrected.
    private var equipmentButton: some View {
        ScrollView(.horizontal) {
            HStack {
                Group {
                    actionButtons
                    Menu {
                        moreButtons
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

    /// The same actions as one overflow menu, for the card's title row.
    private var actionsMenu: some View {
        Menu {
            if let card = delegate.card {
                Button {
                    card.onNotePressed()
                } label: {
                    Label(card.hasNote ? "Edit Note" : "Add Note", systemImage: Symbol.note)
                }
                if let onDoLater = card.onDoLater {
                    Button {
                        onDoLater()
                    } label: {
                        Label("Do Later", systemImage: Symbol.doLater)
                    }
                }
                Divider()
            }
            actionButtons
            Divider()
            moreButtons
        } label: {
            // A real 44 pt frame: the accessibility audit measures the frame, not the hit area
            // `tapTarget()` pads out behind it.
            Image(systemName: Symbol.more)
                .imageScale(.large)
                .frame(width: ControlSize.row, height: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Exercise options")
    }

    @ViewBuilder
    private var actionButtons: some View {
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

        if delegate.exercise.wrappedValue.isPerSide {
            let isSplit = delegate.exercise.wrappedValue.isSplit
            Button {
                presenter.onSplitSidesPressed(delegate.exercise)
            } label: {
                Label("Split L/R", systemImage: Symbol.splitSides)
                    .tapTarget()
            }
            .tint(isSplit ? .accentColor : .secondary)
            .accessibilityLabel("Split left and right")
            .accessibilityHint("Logs each side as its own set")
            .accessibilityAddTraits(isSplit ? .isSelected : [])
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
            Label("Swap", systemImage: Symbol.swap)
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
    }

    @ViewBuilder
    private var moreButtons: some View {
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
            // A chip inside a real 44 pt frame, so the column stays narrow and the tap target full.
            Group {
                if presenter.showAutoRanges {
                    Label("Auto", systemImage: Symbol.smartProgression)
                } else {
                    Label("Last", systemImage: Symbol.history)
                }
            }
            .chipStyle(tint: .secondary, filled: false)
            .frame(minHeight: ControlSize.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between last session and smart progression")
        .frame(width: isStacked ? nil : SetTrackerRowView.previousColumnWidth, alignment: .center)
    }
    
    private var addSetButton: some View {
        Button {
            presenter.addSet(exercise: delegate.exercise)
        } label: {
            Label("Add Set", systemImage: Symbol.add)
                .font(.rowTitle)
                .frame(maxWidth: .infinity, minHeight: ControlSize.row)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        // The table runs to the card's edge; the button keeps the card's margins on both sides.
        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l))
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
                            Image(systemName: Symbol.selected)
                        }
                    }
                }
            }
        } label: {
            Text(unitPreference.weightUnit.abbreviation.capitalized)
                .accessibilityLabel("Weight unit, \(unitPreference.weightUnit.displayName)")
                .chipStyle(tint: .secondary, filled: false)
                .frame(minHeight: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func distanceUnitMenu(exercise: Binding<WorkoutExerciseModel>, unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)) -> some View {
        Menu {
            ForEach(ExerciseDistanceUnit.allCases, id: \.self) { unit in
                Button {
                    presenter.promptDistanceUnitChange(unit, for: exercise)
                } label: {
                    if unit == unitPreference.distanceUnit {
                        Label(unit.displayName, systemImage: Symbol.selected)
                    } else {
                        Text(unit.displayName)
                    }
                }
            }
        } label: {
            Text(unitPreference.distanceUnit.abbreviation.capitalized)
                .accessibilityLabel("Distance unit, \(unitPreference.distanceUnit.displayName)")
                .chipStyle(tint: .secondary, filled: false)
                .frame(minHeight: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
