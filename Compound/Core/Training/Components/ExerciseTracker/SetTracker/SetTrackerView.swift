//
//  SetTrackerView.swift
//  Compound
//
//  One exercise's set table: column headings, the rows, Add Set and the notes. On the live
//  tracker it is the card's section, or one piece of a superset's card (`SetTrackerPiece`).
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
    /// The live tracker makes a swap itself, keeping the logged sets on the old exercise. `nil`
    /// swaps in place, as a finished workout's editor does. See `SetTrackerPresenter.onSwapPressed`.
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
    /// The live tracker's card: the exercise's actions in an overflow menu that `header` places,
    /// the rest timer among the rows, and logging through the tracker.
    var card: SetTrackerCard?
}

/// What the live tracker adds to the set table: the tracker's `ExerciseCard`, and what the
/// exercise card builds around it.
struct SetTrackerCard {
    /// The card's title row, handed the actions menu to place in it.
    var header: (AnyView) -> AnyView
    /// The exercise's notes, under the sets; the actions menu opens their sheet.
    var notes: AnyView?
    var onNotePressed: @MainActor () -> Void = { }
    /// Opens the plan's video link; `nil` when there is none to open.
    var onWatch: (@MainActor () -> Void)?
    var exerciseCard: ExerciseCard
}

/// A piece of one exercise's set table. See `SupersetBlockView`.
enum SetTrackerPiece: Equatable {
    /// The title row with the exercise's actions menu, for the section header.
    case header
    /// Smart progression's note, over the rows.
    case progressionNote
    case columnHeadings
    /// The logged warm-ups, folded into one line.
    case loggedWarmups
    /// A set's row with `badge` in its circle, and the rest under it when it follows that set. Only the row the log button logs next (`isNext`) is current.
    case row(setId: String, badge: String, isNext: Bool)
    /// The add-set button, then the exercise's notes.
    case addSet
}

struct SetTrackerView<SetTrackerRow: View>: View {

    @State var presenter: SetTrackerPresenter
    let delegate: SetTrackerDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    /// The sets' circle (`SetTrackerRowView.setCircleSide`).
    @ScaledMetric(relativeTo: .caption) private var addSetCircleSide: CGFloat = ControlSize.thumbnail - Spacing.xs

    /// Last or Auto, kept on the device. Read here rather than once per presenter, so a switch in
    /// one superset member's headings reaches every member's rows.
    @AppStorage(SetTrackerPresenter.showAutoRangesKey) private var showAutoRanges = false

    /// Whether the logged warm-ups are shown row by row rather than as one line.
    @State private var showsLoggedWarmups = false

    /// The rows stack into two lines at accessibility sizes; the headers follow them.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        if let piece = delegate.card?.exerciseCard.piece {
            pieceView(piece)
        } else {
            table
        }
    }

    /// On the live tracker the card is its own section, headed by the title and actions menu.
    @ViewBuilder
    private var table: some View {
        if let card = delegate.card {
            Section {
                tableBody
            } header: {
                sectionHeader(card)
            }
            .listSectionMargins(.top, Spacing.s)
        } else {
            tableBody
        }
    }

    /// The title row over the card, in the primary colour a header would otherwise grey.
    private func sectionHeader(_ card: SetTrackerCard) -> some View {
        card.header(AnyView(actionsMenu))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    @ViewBuilder
    private var tableBody: some View {
        // The table runs to the card's edge.
        progressionNoteRow
        Group {
            VStack {
                if delegate.card == nil {
                    equipmentButton
                }
                columnHeaders
            }
            if let timer = delegate.card?.exerciseCard.restTimer, timer.anchor == .top {
                InlineRestTimerRow(timer: timer)
            }
            loggedWarmupsGroup
            ForEach(delegate.exercise.wrappedValue.sets.filter { !$0.isWarmup || $0.completedAt == nil }) { set in
                row(for: set)
                restRow(below: set)
            }
            addSetButton
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.vertical, 0)
        .listRowInsets(.leading, 0)
        .listSectionMargins(.top, 0)
        noteCards
    }

    /// Why smart progression changed today's numbers, above the sets until it is tapped.
    @ViewBuilder
    private var progressionNoteRow: some View {
        if let card = delegate.card, let note = card.exerciseCard.progressionNote {
            ProgressionNote(text: note, onAcknowledge: card.exerciseCard.onProgressionNoteAcknowledged)
                .listRowSeparator(.hidden)
        }
    }

    /// The notes under the add-set button, with the list's own insets like the title row.
    @ViewBuilder
    private var noteCards: some View {
        if let notes = delegate.card?.notes {
            notes
                .listRowSeparator(.hidden)
        }
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
                showAutoRanges: showAutoRanges,
                rowState: delegate.card == nil ? nil : isNext.map { ActiveWorkout.blockRowState(of: set, in: exercise, isNext: $0) }
                    ?? ActiveWorkout.rowState(of: set, in: exercise),
                onLogSet: delegate.card?.exerciseCard.onLogSet,
                onCustomRestChanged: delegate.card?.exerciseCard.onCustomRestChanged,
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

    /// Under the set just logged: the rest it started. Correcting the set is the bar over the
    /// log button (`WorkoutTrackerPresenter.restCorrection`).
    @ViewBuilder
    private func restRow(below set: WorkoutSetModel) -> some View {
        if let timer = delegate.card?.exerciseCard.restTimer, timer.anchor == .below(setId: set.id) {
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
                    Label("Notes", systemImage: Symbol.note)
                }
                if let onDoLater = card.exerciseCard.onDoLater {
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
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
                Text("Reps")
                    .setColumn(width: SetTrackerRowView.repsColumnWidth, stretches: isStacked)
            case .repsOnly:
                Text("Reps")
                    .setColumn(width: SetTrackerRowView.repsColumnWidth, stretches: isStacked)
            case .timeOnly:
                Text("Time")
                    .setColumn(width: SetTrackerRowView.timeColumnWidth, stretches: isStacked)
            case .distanceTime:
                distanceUnitMenu(exercise: delegate.exercise, unitPreference: unitPreference)
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
                Text("Time")
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
            }
        }
    }
    
    private func prevAutoHeader(exercise: Binding<WorkoutExerciseModel>) -> some View {
        Button {
            showAutoRanges.toggle()
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
                Image(systemName: showAutoRanges ? Symbol.smartProgression : Symbol.history)
                    .accessibilityHidden(true)
            }
            if showAutoRanges {
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
            // A circle in the Set column, as the sets' own are.
            Image(systemName: Symbol.add)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: addSetCircleSide, height: addSetCircleSide)
                .background(Color.tintedSurface(.secondary), in: .circle)
                .overlay {
                    if colorSchemeContrast == .increased {
                        Circle().strokeBorder(.secondary, lineWidth: 1)
                    }
                }
                .frame(minWidth: SetTrackerRowView.setColumnWidth, minHeight: ControlSize.row)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        // On a superset's card each member has its own, so each says whose it is.
        .accessibilityLabel(delegate.card?.exerciseCard.piece == nil ? String(localized: "Add Set") : String(localized: "Add Set to \(delegate.exercise.wrappedValue.name)"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .listRowInsets(.bottom, Spacing.s)
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
            Text(presenter.weightColumnTitle(for: exercise.wrappedValue, unit: unitPreference.weightUnit))
                .accessibilityLabel(presenter.weightColumnLabel(for: exercise.wrappedValue, unit: unitPreference.weightUnit))
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

    /// One piece of the table, laid out as the whole table lays it out.
    @ViewBuilder
    func pieceView(_ piece: SetTrackerPiece) -> some View {
        switch piece {
        case .header:
            if let card = delegate.card {
                sectionHeader(card)
            }
        case .progressionNote:
            progressionNoteRow
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
                    restRow(below: set)
                }
            }
        case .addSet:
            tableRows { addSetButton }
            noteCards
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
        delegate: SetTrackerDelegate
    ) -> some View {
        let presenter = SetTrackerPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        return SetTrackerView(
            presenter: presenter,
            delegate: delegate,
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate)
            }
        )
    }
}
