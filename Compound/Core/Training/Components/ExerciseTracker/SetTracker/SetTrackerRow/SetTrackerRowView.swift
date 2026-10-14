import SwiftUI

struct SetTrackerRowDelegate {
    var exercise: Binding<WorkoutExerciseModel>
    var set: Binding<WorkoutSetModel>
    let lastSet: WorkoutSetModel?
    /// What smart progression suggests for this row, if anything. Shown by the Auto column.
    var progressionSuggestion: SuggestedSet?
    var showAutoRanges: Bool = false
    /// Done, current or upcoming, on the live tracker: a done row is greyed, and the current one is
    /// "next to log" to VoiceOver. `nil` treats every row alike, as the warm-up sheet does.
    var rowState: SetRowState?
    /// The live tracker logs the set itself, with any rest set by hand on this row, so its log
    /// button and this row's Done are one path. `nil` where there is no tracker: the warm-up sheet
    /// and a finished workout's editor.
    var onLogSet: (@MainActor (_ setId: String, _ customRestSeconds: Int?) -> Void)?
    /// Hands a rest set by hand to the tracker, so its log button rests as long.
    var onCustomRestChanged: (@MainActor (_ setId: String, _ seconds: Int?) -> Void)?
    /// What the set's circle shows in place of its number, in the superset tint: "A1", "B2" on
    /// a superset's card. `nil` shows the number.
    var badgeLabel: String?
}

struct SetTrackerRowView: View {
    
    @State var presenter: SetTrackerRowPresenter
    let delegate: SetTrackerRowDelegate
    
    /// The in-app keyboard all of this row's fields share.
    @State private var keyboardHost = SetKeyboardInputHost()

    /// The row's cell height at the default text size. Scaled so a larger size never clips a value.
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 35

    /// The set number's circle, scaled with its text so "12L" never clips at a larger size.
    @ScaledMetric(relativeTo: .caption) private var setCircleSide: CGFloat = ControlSize.thumbnail - Spacing.xs

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.showsBodyweightLoad) private var showsBodyweightLoad
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// At accessibility sizes five fixed columns truncated every value to "4…", so the row stacks
    /// into two lines and the text keeps growing. Below them the table is as it always was.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    /// A logged working set is greyed; logged warm-ups are hidden altogether.
    private var isDone: Bool { delegate.rowState == .done }

    var body: some View {
        VStack(alignment: .leading) {
            if isStacked {
                stackedRow
            } else {
                HStack {
                    setBadge(set: delegate.set)
                    Spacer()
                    previousValues(exercise: delegate.exercise, set: delegate.set)
                    Spacer()
                    inputFields(exercise: delegate.exercise.wrappedValue, set: delegate.set)
                    Spacer()
                    completeButton(exercise: delegate.exercise.wrappedValue, set: delegate.set)
                }
            }
        }
        // A drop or mini-set sits under its set, one step in.
        .padding(.leading, delegate.set.wrappedValue.isSubSet ? Spacing.l : 0)
        .padding(.vertical, Spacing.xs)
        // One container per set, read on the way in as "Set 2, next to log, 100 kilograms,
        // 8 reps", so the Containers rotor moves set by set (a11y.md M4).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rowAccessibilityLabel)
        .reducedMotionAnimation(.standard, value: isDone)
        .listRowBackground(Color.surface)
        // No full swipe: a set, logged or not, went with one long swipe and no undo.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteSetButton
        }
        // The rest timer's only way in. Rests run only on the live tracker, not in a finished
        // workout's editor. VoiceOver lists it among the row's actions.
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if presenter.onLogSet != nil {
                restTimerButton
            }
        }
        // The long press offers what the trailing swipe does.
        .contextMenu {
            deleteSetButton
        }
        .moveDisabled(true)
    }

    /// "Set 2", "Set A1", "Warmup set": what VoiceOver calls this row, and the start of each of
    /// its controls' names, so Voice Control can tell "Set 2 weight" from "Set 3 weight" (S5).
    /// A drop or mini-set is named after its set: "Set 2, drop set 1".
    private var rowName: String {
        let set = delegate.set.wrappedValue
        guard !set.isWarmup else { return String(localized: "Warmup set") }
        let sets = delegate.exercise.wrappedValue.sets
        if let parent = sets.first(where: { $0.id == set.parentSetId }), let subSetName = ActiveWorkout.subSetName(of: set, in: sets) {
            return "\(String(localized: "Set \(setLabel(for: parent))")), \(subSetName)"
        }
        return String(localized: "Set \(setLabel(for: set))")
    }

    private var rowAccessibilityLabel: String {
        let units = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        let figures = ActiveWorkout.spokenFigures(
            of: delegate.set.wrappedValue,
            trackingMode: delegate.exercise.wrappedValue.trackingMode,
            unit: units.weightUnit,
            distanceUnit: units.distanceUnit
        )
        // The kind's chip is hidden from VoiceOver; the row says it: "Set 3, AMRAP", "Set 4, AMRAP 8+".
        let set = delegate.set.wrappedValue
        let kind = set.isWarmup || set.isSubSet || set.kind == .standard ? nil : Self.kindName(of: set)
        let name = [rowName, kind].compactMap { $0 }.joined(separator: ", ")
        return ActiveWorkout.rowSpokenLabel(name: name, state: delegate.rowState, figures: figures)
    }

    /// Line one: the set, what it was last time, and Done. Line two: the inputs, sharing the width.
    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                setBadge(set: delegate.set)
                previousValues(exercise: delegate.exercise, set: delegate.set)
                Spacer(minLength: 0)
                completeButton(exercise: delegate.exercise.wrappedValue, set: delegate.set)
            }
            inputFields(exercise: delegate.exercise.wrappedValue, set: delegate.set)
        }
    }

    /// Column widths the headers share. The set number and Done are the 44 pt minimum hit area;
    /// Prev gave up the room they needed.
    static let setColumnWidth = ControlSize.row
    static let previousColumnWidth: CGFloat = 78
    static let doneColumnWidth = ControlSize.row
    /// A weight or distance, and the time beside a distance.
    static let fieldColumnWidth: CGFloat = 70
    static let repsColumnWidth: CGFloat = 50
    /// A timed set's own time, with room for its stopwatch.
    static let timeColumnWidth: CGFloat = 90

    private var deleteSetButton: some View {
        Button(role: .destructive) {
            presenter.onDeleteSetPressed(setId: delegate.set.id, setName: rowName, exercise: delegate.exercise)
        } label: {
            switch delegate.set.wrappedValue.subSetKind {
            case .drop: Label("Delete Drop Set", systemImage: Symbol.delete)
            case .mini:
                switch delegate.set.wrappedValue.kind {
                case .partials: Label("Delete Partials", systemImage: Symbol.delete)
                case .stretch: Label("Delete Stretch", systemImage: Symbol.delete)
                case .hold: Label("Delete Hold", systemImage: Symbol.delete)
                default: Label("Delete Mini-Set", systemImage: Symbol.delete)
                }
            case nil: Label("Delete Set", systemImage: Symbol.delete)
            }
        }
    }

    private var restTimerButton: some View {
        Button {
            presenter.onRestPickerRequested(
                exercise: delegate.exercise.wrappedValue,
                setId: delegate.set.wrappedValue.id
            )
        } label: {
            Label("Rest Timer…", systemImage: Symbol.rest)
        }
    }

    /// The set's circle. On a set of its own it opens the set-type menu, with Add Another Drop or
    /// Mini-Set under the types where the set takes them; a drop or mini-set is part of its set and
    /// its circle only shows where it hangs from.
    @ViewBuilder
    func setNumber(set: Binding<WorkoutSetModel>) -> some View {
        Group {
            if ActiveWorkout.offersSetTypes(set.wrappedValue) {
                Menu {
                    setTypeItems(set: set)
                } label: {
                    setCircle(set: set.wrappedValue)
                        .accessibilityHint("Set type")
                }
                .buttonStyle(.plain)
            } else {
                setCircle(set: set.wrappedValue)
            }
        }
        // A minimum, not a fixed width: the circle outgrows the column at the larger standard sizes.
        .frame(minWidth: SetTrackerRowView.setColumnWidth)
    }

    /// Drawn here rather than by `.bordered`, which sizes the control to its text (19 × 28 pt for
    /// "1") whatever frame the label is given. A 44 pt frame is what a thumb needs and what the
    /// accessibility audit measures. The text stays the label's root so the menu's accessibility
    /// element is built from it; a shape on top made the audit see the number as text no element
    /// owns.
    private func setCircle(set: WorkoutSetModel) -> some View {
        let tint: Color = set.isWarmup ? .warmup : delegate.badgeLabel == nil ? .secondary : .superset
        // The label colour on the tinted circle: orange "W" on its own 15 % fill was about 2:1 in
        // light mode. The tint stays on the circle, and the letter says what it is (S4). A drop or
        // mini-set has no number of its own, so its circle shows where it hangs from.
        return Group {
            if set.isSubSet {
                Image(systemName: Symbol.subSet)
            } else {
                Text(setLabel(for: set))
            }
        }
        .font(set.isWarmup ? .caption.weight(.semibold) : .caption)
        .foregroundStyle(isDone ? .secondary : .primary)
        // On the text, not the menu: the menu's inner button takes its accessibility from its
        // label view, and left unlabeled it reads as text no element owns. Where the set stands is
        // the row's to say, on the way into it.
        .accessibilityLabel(rowName)
        .frame(width: setCircleSide, height: setCircleSide)
        .background(Color.tintedSurface(tint), in: .circle)
        // Increase Contrast: the circle's edge in its full colour, where the fill alone is faint.
        .overlay {
            if colorSchemeContrast == .increased {
                Circle().strokeBorder(tint, lineWidth: 1)
            }
        }
        .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
        .contentShape(.circle)
    }

    /// What the circle beside a set shows. Both halves of a left/right pair carry the same number
    /// with an L or R after it, because they are one set — numbering them 1 and 2 would tell a
    /// user doing three sets a side that they were on their fourth.
    private func setLabel(for set: WorkoutSetModel) -> String {
        if let badge = delegate.badgeLabel { return badge }
        guard !set.isWarmup else { return "W" }
        let number = delegate.exercise.wrappedValue.workingSetNumber(for: set)
        return "\(number)\(set.side?.initial ?? "")"
    }

    // MARK: - Inputs

    /// Every tracking mode enters its figures the same way: a field that opens the set keyboard.
    @ViewBuilder
    func inputFields(exercise: WorkoutExerciseModel, set: Binding<WorkoutSetModel>) -> some View {
        let units = presenter.getUnitPreference(for: exercise)
        HStack(spacing: Spacing.s) {
            if set.wrappedValue.isTimedPiece {
                // A stretch or hold after the set is timed towards the plan's seconds, whatever the
                // exercise tracks; a hold keeps the set's weight.
                if SetKeyboardField.fields(for: set.wrappedValue, trackingMode: exercise.trackingMode).contains(.weight) {
                    keyboardField(.weight, set: set, label: String(localized: "Weight, \(units.weightUnit.displayName)"))
                        .setColumn(width: Self.fieldColumnWidth, height: cellHeight, stretches: isStacked)
                }
                timeField(set: set, targetSeconds: set.wrappedValue.durationSec)
            } else {
                trackingModeFields(exercise: exercise, set: set, units: units)
            }
        }
    }

    @ViewBuilder
    private func trackingModeFields(
        exercise: WorkoutExerciseModel,
        set: Binding<WorkoutSetModel>,
        units: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        switch exercise.trackingMode {
        case .weightReps:
            keyboardField(.weight, set: set, label: String(localized: "Weight, \(units.weightUnit.displayName)"))
                .setColumn(width: Self.fieldColumnWidth, height: cellHeight, stretches: isStacked)
            keyboardField(.reps, set: set, label: String(localized: "Reps"))
                .setColumn(width: Self.repsColumnWidth, height: cellHeight, stretches: isStacked)
        case .repsOnly:
            keyboardField(.reps, set: set, label: String(localized: "Reps"))
                .setColumn(width: Self.repsColumnWidth, height: cellHeight, stretches: isStacked)
        case .timeOnly:
            timeField(set: set, targetSeconds: delegate.lastSet?.durationSec)
        case .distanceTime:
            keyboardField(.distance, set: set, label: String(localized: "Distance, \(units.distanceUnit.displayName)"))
                .setColumn(width: Self.fieldColumnWidth, height: cellHeight, stretches: isStacked)
            keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                .setColumn(width: Self.fieldColumnWidth, height: cellHeight, stretches: isStacked)
        }
    }

    /// A set still to do gets a stopwatch, its bar filling towards `targetSeconds`; a logged one is
    /// corrected by typing.
    @ViewBuilder
    private func timeField(set: Binding<WorkoutSetModel>, targetSeconds: Int?) -> some View {
        if set.wrappedValue.completedAt == nil {
            SetStopwatch(set: set, targetSeconds: targetSeconds) {
                keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
            }
            .setColumn(width: Self.timeColumnWidth, height: cellHeight, stretches: isStacked)
        } else {
            keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                .setColumn(width: Self.timeColumnWidth, height: cellHeight, stretches: isStacked)
        }
    }

    /// A field that opens the in-app keyboard, highlighted while it is being edited.
    private func keyboardField(_ field: SetKeyboardField, set: Binding<WorkoutSetModel>, label: String) -> some View {
        let keyboard = presenter.keyboard
        let isActive = keyboard.activeField == field
        let units = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        return SetKeyboardTextField(
            field: field,
            text: keyboard.displayText(for: field, set: set.wrappedValue, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            isActive: isActive,
            // "Set 2, Weight, kilograms": the set first, so each row's fields have names of their own.
            accessibilityLabel: "\(rowName), \(label)",
            isMuted: isDone,
            placeholder: Self.targetPlaceholder(for: field, set: set.wrappedValue)
                ?? keyboard.placeholder(for: field, previous: delegate.lastSet, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            presenter: keyboard,
            inputHost: keyboardHost,
            onBegin: { presenter.onKeyboardFieldBegan(field, delegate: delegate) }
        )
        .background(isActive ? AnyShapeStyle(Color.tintedSurface(.accentColor)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: Radius.s, style: .continuous))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(.tint, lineWidth: 2)
            }
        }
        // A logged set stays editable, so a typo is corrected in place rather than by un-logging,
        // which would restart the rest timer. The edit is not copied to other sets.
        .task {
            // `STARTSCREEN_SET_KEYBOARD`: the first open weight field opens its keyboard.
            guard field == .weight, set.wrappedValue.completedAt == nil, SetKeyboardLaunch.isPending else { return }
            SetKeyboardLaunch.isPending = false
            presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        }
    }

    // MARK: - Previous and Auto

    func previousValues(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        let unitPreference = presenter.getUnitPreference(for: exercise.wrappedValue)
        return Group {
            if delegate.showAutoRanges {
                autoTargetContent(exercise: exercise.wrappedValue, set: set.wrappedValue)
            } else if let prev = delegate.lastSet {
                previousValueContent(trackingMode: exercise.wrappedValue.trackingMode, prev: prev, unitPreference: unitPreference)
            } else {
                emptyTargetLabel
            }
        }
        .setColumn(width: SetTrackerRowView.previousColumnWidth, stretches: isStacked, alignment: .leading)
    }

    @ViewBuilder
    private func autoTargetContent(exercise: WorkoutExerciseModel, set: WorkoutSetModel) -> some View {
        // A drop or mini-set has no target of its own; its set's would read as the drop's.
        if set.isWarmup || set.isSubSet {
            emptyTargetLabel
        } else {
            // The same number the row is labelled with, so a pair shares one target: a target
            // describes a set, and a left and a right are the one set.
            let workingIndex = exercise.workingSetNumber(for: set)
            let target = exercise.setTargets.first { $0.setNumber == workingIndex }
            let unitPreference = presenter.getUnitPreference(for: exercise)
            let suggestion = delegate.progressionSuggestion
            let label = suggestion?.label(
                trackingMode: exercise.trackingMode,
                weightUnit: unitPreference.weightUnit,
                distanceUnit: unitPreference.distanceUnit
            )

            if let suggestion, let label {
                columnText(label)
                    .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                    .contentShape(.rect)
                    .anyButton {
                        presenter.onFillFromSuggestion(suggestion, set: delegate.set)
                    }
                    .accessibilityHint("Fills this set")
                    .disabled(delegate.set.wrappedValue.completedAt != nil)
            } else if let target {
                autoRangeLabel(target: target)
            } else {
                emptyTargetLabel
            }
        }
    }

    private var emptyTargetLabel: some View {
        columnText(Format.placeholder)
    }

    /// One value in the Prev or Auto column.
    private func columnText(_ text: String, font: Font = .caption) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(.secondary)
            .frame(minHeight: cellHeight)
    }

    private func autoRangeLabel(target: SetTarget) -> some View {
        let label: String = {
            switch (target.minReps, target.maxReps) {
            case (let min?, let max?): return Format.repRange(min, max)
            case (let min?, nil):      return "\(min)+"
            default:                   return Format.placeholder
            }
        }()
        return columnText(label)
    }

    // MARK: - Done

    func completeButton(exercise: WorkoutExerciseModel, set: Binding<WorkoutSetModel>) -> some View {
        let state = presenter.completionState(trackingMode: exercise.trackingMode, set: set.wrappedValue, isAssisted: presenter.isAssisted(exercise))
        return Button {
            presenter.onSetComplete(exercise, set)
        } label: {
            Image(systemName: state.systemImage)
                .font(.title3)
                .foregroundStyle(state.tint)
                .frame(width: ControlSize.row, height: ControlSize.row)
                .contentShape(.rect)
        }
        // "Complete Set 2", not "Complete set" on every row, which Voice Control could only
        // number (a11y.md S5).
        .accessibilityLabel(state == .completed ? String(localized: "\(rowName) completed") : String(localized: "Complete \(rowName)"))
        .accessibilityValue(state.accessibilityValue)
        .buttonStyle(.plain)
        .frame(width: isStacked ? nil : SetTrackerRowView.doneColumnWidth, alignment: .center)
        .frame(minWidth: SetTrackerRowView.doneColumnWidth)
        .disabled(state == .notReady)
    }

    @ViewBuilder
    func previousValueContent(
        trackingMode: TrackingMode,
        prev: WorkoutSetModel,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        switch trackingMode {
        case .weightReps:
            // A set with no weight, as on a bodyweight lift, reads "8 reps" rather than nothing, or
            // "BW × 8" while the bodyweight contribution is shown.
            if prev.reps != nil,
               let figures = ActiveWorkout.figures(
                   of: prev,
                   trackingMode: .weightReps,
                   unit: unitPreference.weightUnit,
                   distanceUnit: unitPreference.distanceUnit,
                   showsBodyweight: showsBodyweightLoad
               ) {
                fillFromPrevious(withEffort(columnText(figures), rpe: prev.rpe), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .repsOnly:
            if let reps = prev.reps {
                fillFromPrevious(withEffort(columnText(String(reps)), rpe: prev.rpe), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .timeOnly:
            if let duration = prev.durationSec {
                fillFromPrevious(columnText(Format.duration(TimeInterval(duration))), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .distanceTime:
            if let distance = prev.distanceMeters, let duration = prev.durationSec {
                let displayDistance = Format.distance(meters: distance, exerciseUnit: unitPreference.distanceUnit)
                fillFromPrevious(
                    columnText("\(displayDistance) \(Format.duration(TimeInterval(duration)))", font: .caption2)
                        .lineLimit(2),
                    prev: prev,
                    trackingMode: trackingMode
                )
            } else {
                emptyTargetLabel
            }
        }
    }

    /// Last time's figures with the reps left in reserve under them, when they were logged.
    private func withEffort(_ figures: some View, rpe: Double?) -> some View {
        VStack(spacing: 0) {
            figures
            if let rpe {
                Text("RIR \(WeightStepper.format(EffortScale.rir(fromRPE: rpe)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A Prev value that fills this set when tapped, for every tracking mode. Not on a logged set,
    /// where a stray tap would overwrite what was recorded.
    private func fillFromPrevious(_ label: some View, prev: WorkoutSetModel, trackingMode: TrackingMode) -> some View {
        label
            .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
            .contentShape(.rect)
            .anyButton {
                presenter.onFillFromPrevious(prev, trackingMode: trackingMode, set: delegate.set)
            }
            .accessibilityHint("Fills this set")
            .disabled(delegate.set.wrappedValue.completedAt != nil)
    }

}

// MARK: - Set kinds

extension SetTrackerRowView {

    /// The set's circle, with its kind's chip under it: "Failure", or "Drop", "Mini", "Partials",
    /// "Stretch" or "Hold" on a sub-row.
    /// Under rather than beside, so the columns keep the headers' widths.
    func setBadge(set: Binding<WorkoutSetModel>) -> some View {
        VStack(spacing: Spacing.xxs) {
            setNumber(set: set)
            kindChip(for: set.wrappedValue)
        }
    }

    /// The chip's text in the primary colour on its tint, as the circle's is: orange on its own
    /// 15 % fill is about 2:1 in light mode (S4). Hidden from VoiceOver, which hears the kind in
    /// the row's name.
    @ViewBuilder
    private func kindChip(for set: WorkoutSetModel) -> some View {
        if let chip = Self.chip(for: set) {
            Text(chip.text)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .fixedSize()
                .chipStyle(tint: chip.tint, filled: false)
                .accessibilityHidden(true)
        }
    }

    private static func chip(for set: WorkoutSetModel) -> (text: String, tint: Color)? {
        switch (set.subSetKind, set.kind) {
        case (.drop, _): (String(localized: "Drop"), .warmup)
        case let (.mini, kind): (kind.pieceName ?? String(localized: "Mini"), .warmup)
        case (nil, .amrap) where !set.isWarmup: (set.targetReps.map { String(localized: "Failure \($0)+") } ?? String(localized: "Failure"), .secondary)
        default: nil
        }
    }

    /// "AMRAP 8+" for an AMRAP set the plan gave a target, else the kind's name.
    static func kindName(of set: WorkoutSetModel) -> String {
        guard set.kind == .amrap, let target = set.targetReps else { return set.kind.displayName }
        return String(localized: "Failure \(target)+")
    }

    /// An AMRAP set's reps, while they are open, hint at the plan's target, greyed as any
    /// placeholder is: "8+".
    static func targetPlaceholder(for field: SetKeyboardField, set: WorkoutSetModel) -> String? {
        guard field == .reps, set.kind == .amrap, !set.isSubSet, !set.isWarmup, set.reps == nil,
              let target = set.targetReps else { return nil }
        return "\(target)+"
    }

    /// The types, the set's own ticked, then another drop or mini-set where the set takes one.
    @ViewBuilder
    private func setTypeItems(set: Binding<WorkoutSetModel>) -> some View {
        Picker("Set Type", selection: Binding(
            get: { set.wrappedValue.typeChoice },
            set: { presenter.onSetTypeSelected($0, setId: set.wrappedValue.id, setName: rowName, exercise: delegate.exercise) }
        )) {
            ForEach(ActiveWorkout.setTypeOptions(for: set.wrappedValue), id: \.self) { choice in
                Text(choice.displayName).tag(choice)
            }
        }
        .pickerStyle(.inline)
        if ActiveWorkout.offersDrop(set.wrappedValue) {
            Button {
                presenter.addSubSet(.drop, to: set.wrappedValue.id, exercise: delegate.exercise)
            } label: {
                Label("Add Another Drop", systemImage: Symbol.add)
            }
            .accessibilityLabel(String(localized: "Add another drop to \(rowName)"))
        }
        if ActiveWorkout.offersMiniSet(set.wrappedValue) {
            Button {
                presenter.addSubSet(.mini, to: set.wrappedValue.id, exercise: delegate.exercise)
            } label: {
                Label("Add Another Mini-Set", systemImage: Symbol.add)
            }
            .accessibilityLabel(String(localized: "Add another mini-set to \(rowName)"))
        }
    }
}

#Preview {
    @Previewable @State var set: WorkoutSetModel = .mock
    @Previewable @State var exercise: WorkoutExerciseModel = .mock
    let lastSet: WorkoutSetModel? = .mock
    
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SetTrackerRowDelegate(exercise: $exercise, set: $set, lastSet: lastSet)
    
    return RouterView { router in
        List {
            builder.setTrackerRowView(router: router, delegate: delegate)
        }
    }
}

extension View {
    /// A column of the set table: its fixed width, or on the stacked row at accessibility sizes a
    /// share of the line that grows with the text. The headers use the same widths.
    @ViewBuilder
    func setColumn(width: CGFloat, height: CGFloat? = nil, stretches: Bool, alignment: Alignment = .center) -> some View {
        if stretches {
            frame(maxWidth: .infinity, minHeight: height, alignment: alignment)
        } else {
            frame(width: width, height: height, alignment: .center)
        }
    }
}

extension CoreBuilder {

    func setTrackerRowView(
        router: AnyRouter,
        delegate: SetTrackerRowDelegate
    ) -> some View {
        let presenter = SetTrackerRowPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        presenter.onLogSet = delegate.onLogSet
        presenter.onCustomRestChanged = delegate.onCustomRestChanged
        return SetTrackerRowView(presenter: presenter, delegate: delegate)
    }

}
