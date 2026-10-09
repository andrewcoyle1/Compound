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
    /// The live tracker makes a swap itself, keeping the logged sets on the old exercise. `nil`
    /// swaps in place, as a finished workout's editor does. See `SetTrackerPresenter.onSwapPressed`.
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
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
    /// Opens the plan's video link; `nil` when there is none to open.
    var onWatch: (@MainActor () -> Void)?
    /// Why smart progression changed today's numbers, as a row above the sets until it is tapped.
    var progressionNote: String?
    var onProgressionNoteAcknowledged: @MainActor () -> Void = { }
    var restTimer: InlineRestTimer?
    /// See `SetTrackerRowDelegate.onLogSet` and `onCustomRestChanged`.
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?
    /// The row under the set just logged, with the rest when one follows it there.
    var correction: SetCorrection?
    var onCorrection: (@MainActor (String, SetCorrectionAction) -> Void)?
    /// Handed the window's undo manager while the card is on screen, and `nil` once it has gone.
    var onUndoManager: (@MainActor (UndoManager?) -> Void)?
    /// One piece of the table rather than all of it, for a superset's card to place among its
    /// partners' rows. `nil` draws the whole table.
    var piece: SetTrackerPiece?
    /// Last or Auto, when a superset's card holds the choice for every member's rows: each piece
    /// has its own presenter, so one piece's switch would not reach the others' rows.
    var showAutoRanges: Bool?
}

/// A piece of one exercise's set table. See `SupersetBlockView`.
enum SetTrackerPiece: Equatable {
    /// The title row with the exercise's actions menu, and smart progression's note under it.
    case header
    case columnHeadings
    /// The logged warm-ups, folded into one line.
    case loggedWarmups
    /// A set's row with `badge` in its circle, and the correction row or rest under it when
    /// they follow that set. Only the row the log button logs next (`isNext`) is current.
    case row(setId: String, badge: String, isNext: Bool)
    case addSet
}

struct SetTrackerView<SetTrackerRow: View>: View {

    @State var presenter: SetTrackerPresenter
    let delegate: SetTrackerDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.undoManager) private var undoManager

    /// The card's rows on screen. The undo manager is let go only when none is: a single row
    /// scrolling away is not the card going.
    @State private var visibleRows = 0

    /// Whether the logged warm-ups are shown row by row rather than as one line.
    @State private var showsLoggedWarmups = false

    /// The rows stack into two lines at accessibility sizes; the headers follow them.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        if let piece = delegate.card?.piece {
            pieceView(piece)
        } else {
            table
        }
    }

    @ViewBuilder
    private var table: some View {
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
            if let timer = delegate.card?.restTimer, timer.anchor == .top {
                InlineRestTimerRow(timer: timer)
            }
            loggedWarmupsGroup
            ForEach(delegate.exercise.wrappedValue.sets.filter { !$0.isWarmup || $0.completedAt == nil }) { set in
                row(for: set)
                correctionRow(below: set)
            }
            addSetButton
        }
        .onAppear {
            visibleRows += 1
            delegate.card?.onUndoManager?(undoManager)
        }
        .onDisappear {
            visibleRows -= 1
            if visibleRows == 0 { delegate.card?.onUndoManager?(nil) }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.vertical, 0)
        .listRowInsets(.leading, 0)
        .listSectionMargins(.top, 0)
    }

    /// Done warm-ups fold into one line, so the table starts at the work, and open on a tap to be
    /// corrected.
    @ViewBuilder
    private var loggedWarmupsGroup: some View {
        let loggedWarmups = delegate.exercise.wrappedValue.sets.filter { $0.isWarmup && $0.completedAt != nil }
        if !loggedWarmups.isEmpty {
            DisclosureGroup(isExpanded: $showsLoggedWarmups) {
                ForEach(loggedWarmups) { set in
                    row(for: set)
                }
            } label: {
                Label {
                    Text("\(loggedWarmups.count) warm-ups")
                } icon: {
                    Image(systemName: Symbol.success)
                        .foregroundStyle(.success)
                }
                .font(.rowDetail)
                .frame(minHeight: ControlSize.row)
                .padding(.leading, Spacing.l)
            }
        }
    }

    private func row(for set: WorkoutSetModel, badge: String? = nil, isNext: Bool? = nil) -> some View {
        let exercise = delegate.exercise.wrappedValue
        // Matched on the side as well as the number: a left set inheriting the right arm's last
        // weight sends the user chasing the other arm's numbers. A drop is matched on its kind,
        // and has no suggestion of its own: its parent's would fill it with the heavier figures.
        return setTrackerRow(
            SetTrackerRowDelegate(
                exercise: delegate.exercise,
                set: setBinding(for: set),
                lastSet: ActiveWorkout.lastSet(for: set, in: exercise, last: delegate.lastExercise),
                progressionSuggestion: set.isSubSet ? nil : delegate.progressionSuggestion?.suggestedSet(for: set, in: exercise),
                showAutoRanges: delegate.card?.showAutoRanges ?? presenter.showAutoRanges,
                rowState: delegate.card == nil ? nil : isNext.map { ActiveWorkout.blockRowState(of: set, in: exercise, isNext: $0) }
                    ?? ActiveWorkout.rowState(of: set, in: exercise),
                onSetCompleted: delegate.onSetCompleted,
                onLogSet: delegate.card?.onLogSet,
                onCustomRestChanged: delegate.card?.onCustomRestChanged,
                badgeLabel: badge
            )
        )
        .listRowSeparator(.visible)
    }

    /// The set by id, not by position, as `WorkoutTrackerView.currentExerciseSection` binds the
    /// exercise. A binding by index read `sets[4]` of four sets when an earlier set was deleted
    /// with the keyboard open on the last, and trapped. Once the set is gone the getter hands back
    /// what it last held, and the setter has nothing to write.
    private func setBinding(for set: WorkoutSetModel) -> Binding<WorkoutSetModel> {
        let exercise = delegate.exercise
        let id = set.id
        return Binding(
            get: { exercise.wrappedValue.sets.first { $0.id == id } ?? set },
            set: { updated in
                guard let index = exercise.wrappedValue.sets.firstIndex(where: { $0.id == id }) else { return }
                exercise.wrappedValue.sets[index] = updated
            }
        )
    }

    /// Under the set just logged: what it was, to correct or undo, and the rest it started.
    @ViewBuilder
    private func correctionRow(below set: WorkoutSetModel) -> some View {
        if let card = delegate.card {
            let correction = card.correction?.setId == set.id ? card.correction : nil
            let timer = card.restTimer?.anchor == .below(setId: set.id) ? card.restTimer : nil
            if correction != nil || timer != nil {
                InlineRestTimerRow(timer: timer, correction: correction) { action in
                    card.onCorrection?(set.id, action)
                }
            }
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
                .toggleStyle(.button)
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
                if let onWatch = card.onWatch {
                    Button {
                        onWatch()
                    } label: {
                        Label("Watch", systemImage: Symbol.video)
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
                Label("Equipment…", systemImage: Symbol.equipment)
                    .tapTarget()
            }
        }

        Button {
            presenter.onWarmupSetsPressed(delegate.exercise)
        } label: {
            Label("Warmup Sets…", systemImage: Symbol.warmup)
                .tapTarget()
        }

        if delegate.exercise.wrappedValue.isPerSide {
            // A toggle, so the menu draws a checkmark beside it while the sides are split; a tint
            // is not drawn inside a menu.
            let exercise = delegate.exercise
            Toggle(isOn: Binding(
                get: { exercise.wrappedValue.isSplit },
                set: { _ in presenter.onSplitSidesPressed(exercise) }
            )) {
                Label("Split L/R", systemImage: Symbol.splitSides)
                    .tapTarget()
            }
            .accessibilityLabel("Split left and right")
            .accessibilityHint("Logs each side as its own set")
        }

        Button {
            presenter.onTargetsPressed(delegate.exercise)
        } label: {
            Label("Targets…", systemImage: Symbol.goal)
                .tapTarget()
        }

        Button {
            presenter.onSwapPressed(delegate.exercise, onSwap: delegate.onSwap)
        } label: {
            Label("Swap…", systemImage: Symbol.swap)
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
                guard let groupId = delegate.exercise.wrappedValue.supersetGroupId else { return String(localized: "Superset…") }
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
                // No line limit and no shrinking: Caption 2 is already the 11 pt floor, so a
                // heading too long for its column wraps instead.
                .multilineTextAlignment(.center)
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
            // A one-word heading cannot wrap and must not shrink below 11 pt, so where the column
            // is too narrow for the symbol as well, the chip drops it.
            ViewThatFits(in: .horizontal) {
                prevAutoChip(showsSymbol: true).fixedSize()
                prevAutoChip(showsSymbol: false).fixedSize()
            }
            .frame(minHeight: ControlSize.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between last session and smart progression")
        .frame(width: isStacked ? nil : SetTrackerRowView.previousColumnWidth, alignment: .center)
    }

    /// An `HStack` rather than a `Label`: in a list a label sets aside an icon column as wide as a
    /// row's, which left the word no room.
    private func prevAutoChip(showsSymbol: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            if showsSymbol {
                Image(systemName: presenter.showAutoRanges ? Symbol.smartProgression : Symbol.history)
                    .accessibilityHidden(true)
            }
            if presenter.showAutoRanges {
                Text("Auto")
            } else {
                Text("Last")
            }
        }
        .lineLimit(1)
        .chipStyle(tint: .secondary, filled: false)
    }

    private var addSetButton: some View {
        Button {
            presenter.addSet(exercise: delegate.exercise)
        } label: {
            // On a superset's card each member has its own, so each says whose it is.
            Label(
                delegate.card?.piece == nil ? String(localized: "Add Set") : String(localized: "Add Set to \(delegate.exercise.wrappedValue.name)"),
                systemImage: Symbol.add
            )
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

// MARK: - Pieces

extension SetTrackerView {

    /// One piece of the table, laid out as the whole table lays it out. The superset card keeps
    /// the window's undo manager itself, since it knows when the last of its rows has gone.
    @ViewBuilder
    func pieceView(_ piece: SetTrackerPiece) -> some View {
        switch piece {
        case .header:
            if let card = delegate.card {
                card.header(AnyView(actionsMenu))
                    .listRowSeparator(.hidden)
                    .listRowInsets(.bottom, 0)
                if let note = card.progressionNote {
                    ProgressionNote(text: note, onAcknowledge: card.onProgressionNoteAcknowledged)
                        .listRowSeparator(.hidden)
                }
            }
        case .columnHeadings:
            tableRows { columnHeaders }
        case .loggedWarmups:
            tableRows { loggedWarmupsGroup }
        case let .row(setId, badge, isNext):
            if let set = delegate.exercise.wrappedValue.sets.first(where: { $0.id == setId }) {
                tableRows {
                    // One VoiceOver container per row, named for its set and exercise, so the
                    // Containers rotor steps through the rounds: "A1, Bench Press", and a drop
                    // under it "A1 drop set 1, Bench Press".
                    let name = [badge, ActiveWorkout.subSetName(of: set, in: delegate.exercise.wrappedValue.sets)]
                        .compactMap { $0 }.joined(separator: " ")
                    row(for: set, badge: badge, isNext: isNext)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel([name, delegate.exercise.wrappedValue.name].joined(separator: ", "))
                    correctionRow(below: set)
                }
            }
        case .addSet:
            tableRows { addSetButton }
        }
    }

    /// The insets and separators the table gives its rows.
    private func tableRows(@ViewBuilder _ content: () -> some View) -> some View {
        Group(content: content)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
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
