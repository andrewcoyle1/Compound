import SwiftUI

struct SetTrackerRowDelegate {
    var exercise: Binding<WorkoutExerciseModel>
    var set: Binding<WorkoutSetModel>
    let lastSet: WorkoutSetModel?
    /// What smart progression suggests for this row, if anything. Shown by the Auto column.
    var progressionSuggestion: SuggestedSet?
    var showAutoRanges: Bool = false
    /// Done, current or upcoming, on the live tracker. `nil` draws every row alike, as the
    /// warm-up sheet does.
    var rowState: SetRowState?
    /// Called with the set that was just logged, so the screen can re-suggest what is left.
    var onSetCompleted: @MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void = { _, _ in }
    /// The live tracker logs the set itself, with any rest set by hand on this row, so its log
    /// button and this row's Done are one path. `nil` where there is no tracker: the warm-up sheet
    /// and a finished workout's editor.
    var onLogSet: (@MainActor (_ setId: String, _ customRestSeconds: Int?) -> Void)?
    /// Hands a rest set by hand to the tracker, so its log button rests as long.
    var onCustomRestChanged: (@MainActor (_ setId: String, _ seconds: Int?) -> Void)?
    /// What the set's circle shows in place of its number, in the superset tint: "A1", "B2" on
    /// a superset's card. `nil` shows the number.
    var badgeLabel: String?
    var eventParameters: [String: Any]? {
        nil
    }
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

    private var isCurrent: Bool { delegate.rowState == .current }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if isStacked {
                stackedRow
            } else {
                HStack {
                    setNumber(set: delegate.set)
                    Spacer()
                    previousValues(exercise: delegate.exercise, set: delegate.set)
                    Spacer()
                    inputFields(exercise: delegate.exercise.wrappedValue, set: delegate.set)
                    Spacer()
                    completeButton(exercise: delegate.exercise.wrappedValue, set: delegate.set)
                }
            }
            if isCurrent, let plates = presenter.plateSummary(exercise: delegate.exercise.wrappedValue, set: delegate.set.wrappedValue) {
                Group {
                    if let nearestKg = plates.nearestKg {
                        Button {
                            delegate.set.wrappedValue.weightKg = nearestKg
                        } label: {
                            // The warning colour on the icon only: orange text on the current row's
                            // highlight is under 4.5:1.
                            plateLine(plates.text, symbol: Symbol.warning, tint: .warning)
                                .frame(minHeight: ControlSize.row)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityHint("Changes the weight to one your plates can make")
                    } else {
                        plateLine(plates.text, symbol: Symbol.equipment, tint: .secondary)
                    }
                }
                .padding(.leading, isStacked ? 0 : SetTrackerRowView.setColumnWidth + Spacing.s)
            }
        }
        .padding(.vertical, Spacing.xs)
        // One container per set, read on the way in as "Set 2, next to log, 100 kilograms,
        // 8 reps", so the Containers rotor moves set by set (a11y.md M4).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rowAccessibilityLabel)
        // The outlines, muted text and plates line follow the highlight in step with it.
        .reducedMotionAnimation(.standard, value: isCurrent)
        // Always the same view with the tint faded in or out, so the highlight moves between sets
        // rather than jumping: a nil background cannot be animated to.
        .listRowBackground(
            Color.tintedSurface(.accentColor)
                // The 15 % tint alone is well under 3:1 against the surface; the outline in the
                // accent is what marks the row (S4), heavier with Increase Contrast on.
                .overlay {
                    Rectangle()
                        .strokeBorder(.tint, lineWidth: colorSchemeContrast == .increased ? 2.5 : 1.5)
                }
                .opacity(isCurrent ? 1 : 0)
                .reducedMotionAnimation(.standard, value: isCurrent)
                .background(Color.surface)
        )
        // No full swipe: a set, logged or not, went with one long swipe and no undo.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteSetButton
        }
        // No rest runs when a finished workout is being corrected, which is the one place these
        // rows are built without a rest handler.
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if presenter.onStartRest != nil {
                restTimerButton
            }
        }
        // Shortcuts to the set number's menu, which is the visible route to both actions.
        .contextMenu {
            if presenter.onStartRest != nil {
                restTimerButton
            }
            deleteSetButton
        }
        .moveDisabled(true)
    }
    
    /// The plates line under the current row: the colour on the icon only, since coloured or
    /// secondary text on the row's tint is under 4.5:1 (S4). The text wraps within the row's width
    /// by itself: wrapped as a whole `Label`, it clipped mid-word at AX5 ("Not loadabl").
    private func plateLine(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.label)
    }

    /// "Set 2", "Set A1", "Warmup set": what VoiceOver calls this row, and the start of each of
    /// its controls' names, so Voice Control can tell "Set 2 weight" from "Set 3 weight" (S5).
    private var rowName: String {
        let set = delegate.set.wrappedValue
        return set.isWarmup ? String(localized: "Warmup set") : String(localized: "Set \(setLabel(for: set))")
    }

    private var rowAccessibilityLabel: String {
        let units = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        let figures = ActiveWorkout.spokenFigures(
            of: delegate.set.wrappedValue,
            trackingMode: delegate.exercise.wrappedValue.trackingMode,
            unit: units.weightUnit,
            distanceUnit: units.distanceUnit
        )
        return ActiveWorkout.rowSpokenLabel(name: rowName, state: delegate.rowState, figures: figures)
    }

    /// Line one: the set, what it was last time, and Done. Line two: the inputs, sharing the width.
    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                setNumber(set: delegate.set)
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

    private var deleteSetButton: some View {
        Button(role: .destructive) {
            presenter.deleteSet(setId: delegate.set.id, exercise: delegate.exercise)
        } label: {
            Label("Delete Set", systemImage: Symbol.delete)
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

    func setNumber(set: Binding<WorkoutSetModel>) -> some View {
        Menu {
            // A menu toggle draws its own checkmark; the old label asked for a symbol named "".
            Toggle("Warmup Set", isOn: set.isWarmup)
            
            Button {
                presenter.onWarmupSetHelpPressed()
            } label: {
                Label("What's a warmup set?", systemImage: Symbol.info)
            }

            // The visible route to what the swipes and the long press also offer.
            if presenter.onStartRest != nil {
                restTimerButton
            }
            Divider()
            deleteSetButton
        } label: {
            // Drawn here rather than by `.bordered`, which sizes the control to its text (19 × 28 pt
            // for "1") whatever frame the label is given. A 44 pt frame is what a thumb needs and
            // what the accessibility audit measures.
            // The text stays the label's root so the menu's accessibility element is built from
            // it; a shape on top made the audit see the number as text no element owns.
            let tint: Color = set.wrappedValue.isWarmup ? .warmup : delegate.badgeLabel == nil ? .secondary : .superset
            // The label colour on the tinted circle: orange "W" on its own 15 % fill was about
            // 2:1 in light mode. The tint stays on the circle, and the letter says what it is (S4).
            Text(setLabel(for: set.wrappedValue))
                .font(set.wrappedValue.isWarmup ? .caption.weight(.semibold) : .caption)
                .foregroundStyle(.primary)
                // On the text, not the menu: the menu's inner button takes its accessibility from
                // its label view, and left unlabeled it reads as text no element owns.
                // Where the set stands is the row's to say, on the way into it.
                .accessibilityLabel(rowName)
                .accessibilityHint("Set options")
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
        .buttonStyle(.plain)
        // A minimum, not a fixed width: the circle outgrows the column at the larger standard sizes.
        .frame(minWidth: SetTrackerRowView.setColumnWidth)
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
            switch exercise.trackingMode {
            case .weightReps:
                keyboardField(.weight, set: set, label: String(localized: "Weight, \(units.weightUnit.displayName)"))
                    .setColumn(width: 70, height: cellHeight, stretches: isStacked)
                keyboardField(.reps, set: set, label: String(localized: "Reps"))
                    .setColumn(width: 50, height: cellHeight, stretches: isStacked)
            case .repsOnly:
                keyboardField(.reps, set: set, label: String(localized: "Reps"))
                    .setColumn(width: 50, height: cellHeight, stretches: isStacked)
            case .timeOnly:
                // A set still to do gets a stopwatch; a logged one is corrected by typing.
                if set.wrappedValue.completedAt == nil {
                    SetStopwatch(set: set, targetSeconds: delegate.lastSet?.durationSec) {
                        keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                    }
                    .setColumn(width: 90, height: cellHeight, stretches: isStacked)
                } else {
                    keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                        .setColumn(width: 90, height: cellHeight, stretches: isStacked)
                }
            case .distanceTime:
                keyboardField(.distance, set: set, label: String(localized: "Distance, \(units.distanceUnit.displayName)"))
                    .setColumn(width: 70, height: cellHeight, stretches: isStacked)
                keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                    .setColumn(width: 70, height: cellHeight, stretches: isStacked)
            }
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
            isMuted: delegate.rowState == .upcoming,
            placeholder: keyboard.placeholder(for: field, previous: delegate.lastSet, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            presenter: keyboard,
            inputHost: keyboardHost,
            onBegin: { presenter.onKeyboardFieldBegan(field, delegate: delegate) }
        )
        .background(isActive ? AnyShapeStyle(Color.tintedSurface(.accentColor)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: Radius.s, style: .continuous))
        .overlay {
            // The row being logged is outlined, so its fields read as the ones to fill in.
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .strokeBorder(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isActive ? 2 : (isCurrent ? 1 : 0))
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
        if set.isWarmup {
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
                        fill(delegate.set, from: suggestion)
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
            // On the current row's tint secondary grey was about 2.4:1 (S4); elsewhere it is muted.
            .foregroundStyle(isCurrent ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.secondary))
            .frame(minHeight: cellHeight)
    }

    /// Writes a suggestion into the row, leaving alone every metric it says nothing about.
    private func fill(_ set: Binding<WorkoutSetModel>, from suggestion: SuggestedSet) {
        if let weightKg = suggestion.weightKg { set.wrappedValue.weightKg = weightKg }
        if let reps = suggestion.reps { set.wrappedValue.reps = reps }
        if let durationSec = suggestion.durationSec { set.wrappedValue.durationSec = durationSec }
        if let distanceMeters = suggestion.distanceMeters { set.wrappedValue.distanceMeters = distanceMeters }
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
            if let reps = prev.reps,
               let figures = ActiveWorkout.figures(
                   of: prev,
                   trackingMode: .weightReps,
                   unit: unitPreference.weightUnit,
                   distanceUnit: unitPreference.distanceUnit,
                   showsBodyweight: showsBodyweightLoad
               ) {
                fillFromPrevious(withEffort(columnText(figures), rpe: prev.rpe)) {
                    if let weight = prev.weightKg { $0.weightKg = weight }
                    $0.reps = reps
                }
            } else {
                emptyTargetLabel
            }
        case .repsOnly:
            if let reps = prev.reps {
                fillFromPrevious(withEffort(columnText(String(reps)), rpe: prev.rpe)) { $0.reps = reps }
            } else {
                emptyTargetLabel
            }
        case .timeOnly:
            if let duration = prev.durationSec {
                fillFromPrevious(columnText(Format.duration(TimeInterval(duration)))) { $0.durationSec = duration }
            } else {
                emptyTargetLabel
            }
        case .distanceTime:
            if let distance = prev.distanceMeters, let duration = prev.durationSec {
                let displayDistance = Format.distance(meters: distance, exerciseUnit: unitPreference.distanceUnit)
                fillFromPrevious(
                    columnText("\(displayDistance) \(Format.duration(TimeInterval(duration)))", font: .caption2)
                        .lineLimit(2)
                ) {
                    $0.distanceMeters = distance
                    $0.durationSec = duration
                }
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
                    .foregroundStyle(isCurrent ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.secondary))
            }
        }
    }

    /// A Prev value that fills this set when tapped, for every tracking mode. Not on a logged set,
    /// where a stray tap would overwrite what was recorded.
    private func fillFromPrevious(_ label: some View, fill: @escaping (inout WorkoutSetModel) -> Void) -> some View {
        label
            .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
            .contentShape(.rect)
            .anyButton {
                fill(&delegate.set.wrappedValue)
            }
            .accessibilityHint("Fills this set")
            .disabled(delegate.set.wrappedValue.completedAt != nil)
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
        delegate: SetTrackerRowDelegate,
        onStartRest: ((Int) -> Void)? = nil
    ) -> some View {
        let presenter = SetTrackerRowPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        presenter.onStartRest = onStartRest
        presenter.onSetCompleted = delegate.onSetCompleted
        presenter.onLogSet = delegate.onLogSet
        presenter.onCustomRestChanged = delegate.onCustomRestChanged
        return SetTrackerRowView(presenter: presenter, delegate: delegate)
    }

}

extension CoreRouter {
    
    func showSetTrackerRowView(delegate: SetTrackerRowDelegate) {
        router.showScreen(.push) { router in
            builder.setTrackerRowView(router: router, delegate: delegate)
        }
    }
    
}
