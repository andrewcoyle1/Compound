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
    /// The rest set by hand on this set, as the tracker keeps it.
    var customRestSeconds: Int?
    /// What the set's circle shows in place of its number, in the superset tint: "B1·1", "B2·1"
    /// on a superset's card. `nil` shows the number.
    var badgeLabel: String?
}

struct SetTrackerRowView: View {
    
    @State var presenter: SetTrackerRowPresenter
    let delegate: SetTrackerRowDelegate
    
    /// The in-app keyboard all of this row's fields share.
    @State private var keyboardHost = SetKeyboardInputHost()

    @ScaledMetric(relativeTo: .body) var cellHeight = SetTable.cellHeight

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.showsBodyweightLoad) var showsBodyweightLoad

    /// At accessibility sizes five fixed columns truncated every value to "4…", so the row stacks
    /// into two lines and the text keeps growing. Below them the table is as it always was.
    var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    /// A logged working set is greyed; logged warm-ups are hidden altogether.
    private var isDone: Bool { delegate.rowState == .done }

    var body: some View {
        let units = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        VStack(alignment: .leading) {
            if isStacked {
                // Line one: the set, what it was last time, and Done. Line two: the inputs.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        setBadge
                        previousValues(units: units)
                        Spacer(minLength: 0)
                        completeButton
                    }
                    inputFields(units: units)
                }
            } else {
                HStack {
                    setBadge
                    Spacer()
                    previousValues(units: units)
                    Spacer()
                    inputFields(units: units)
                    Spacer()
                    completeButton
                }
            }
        }
        // A drop or mini-set sits under its set, one step in.
        .padding(.leading, delegate.set.wrappedValue.isSubSet ? Spacing.l : 0)
        .padding(.vertical, Spacing.xs)
        // One container per set, read on the way in as "Set 2, next to log, 100 kilograms,
        // 8 reps", so the Containers rotor moves set by set (a11y.md M4).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rowAccessibilityLabel(units: units))
        .reducedMotionAnimation(.standard, value: isDone)
        .listRowBackground(Color.surface)
        // No full swipe: a set, logged or not, went with one long swipe and no undo.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteSetButton
        }
        // The rest timer's only way in. Rests run only on the live tracker, not in a finished
        // workout's editor. VoiceOver lists it among the row's actions.
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if delegate.onLogSet != nil {
                restTimerButton
            }
        }
        // The long press offers what the trailing swipe does.
        .contextMenu {
            deleteSetButton
        }
        .moveDisabled(true)
    }

    /// "Set 2", "Set A1", "Warm-up set": what VoiceOver calls this row, and the start of each of
    /// its controls' names, so Voice Control can tell "Set 2 weight" from "Set 3 weight" (S5).
    /// A drop or mini-set is named after its set: "Set 2, drop set 1".
    var rowName: String {
        let set = delegate.set.wrappedValue
        guard !set.isWarmup else { return String(localized: "Warm-up set") }
        let sets = delegate.exercise.wrappedValue.sets
        // On a superset's card the badge names the set: "B1, set 2".
        let setName = { (set: WorkoutSetModel) in
            delegate.badgeLabel.map(ActiveWorkout.spokenBadge) ?? String(localized: "Set \(setLabel(for: set))")
        }
        if let parent = sets.first(where: { $0.id == set.parentSetId }), let subSetName = ActiveWorkout.subSetName(of: set, in: sets) {
            return "\(setName(parent)), \(subSetName)"
        }
        return setName(set)
    }

    private func rowAccessibilityLabel(units: ExerciseUnitPreference) -> String {
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

    private var deleteSetButton: some View {
        let set = delegate.set.wrappedValue
        let title: LocalizedStringKey = switch (set.subSetKind, set.kind) {
        case (.drop, _): "Delete Drop Set"
        case (.mini, .partials): "Delete Partials"
        case (.mini, .stretch): "Delete Stretch"
        case (.mini, .hold): "Delete Hold"
        case (.mini, _): "Delete Mini-Set"
        case (nil, _): "Delete Set"
        }
        return Button(role: .destructive) {
            presenter.onDeleteSetPressed(setId: set.id, setName: rowName, exercise: delegate.exercise)
        } label: {
            Label(title, systemImage: Symbol.delete)
        }
    }

    private var restTimerButton: some View {
        Button {
            presenter.onRestPickerRequested(
                exercise: delegate.exercise.wrappedValue,
                setId: delegate.set.wrappedValue.id,
                customRestSeconds: delegate.customRestSeconds,
                onChange: delegate.onCustomRestChanged
            )
        } label: {
            Label("Rest Timer…", systemImage: Symbol.rest)
        }
    }

    /// The set's circle. On a set of its own it opens the set-type menu, with Add Another Drop or
    /// Mini-Set under the types where the set takes them; a drop or mini-set is part of its set and
    /// its circle only shows where it hangs from.
    var setNumber: some View {
        let set = delegate.set.wrappedValue
        return Group {
            if ActiveWorkout.offersSetTypes(set) {
                Menu {
                    setTypeItems
                } label: {
                    setCircle
                        .accessibilityHint("Set type")
                }
                .buttonStyle(.plain)
            } else {
                setCircle
            }
        }
        // A minimum, not a fixed width: the circle outgrows the column at the larger standard sizes.
        .frame(minWidth: SetTable.setColumnWidth)
    }

    private var setCircle: some View {
        let set = delegate.set.wrappedValue
        return SetCircle(
            text: set.isSubSet ? nil : setLabel(for: set),
            tint: set.isWarmup ? .warmup : delegate.badgeLabel == nil ? .secondary : .superset,
            isEmphasised: set.isWarmup,
            isMuted: isDone,
            accessibilityLabel: rowName
        )
    }

    /// What the circle beside a set shows. Both halves of a left/right pair carry the same number
    /// with an L or R after it, because they are one set — numbering them 1 and 2 would tell a
    /// user doing three sets a side that they were on their fourth.
    private func setLabel(for set: WorkoutSetModel) -> String {
        if let badge = delegate.badgeLabel { return badge }
        guard !set.isWarmup else { return String(localized: "W", comment: "A warm-up set's circle, in place of its number") }
        let number = delegate.exercise.wrappedValue.workingSetNumber(for: set)
        return "\(number)\(set.side?.initial ?? "")"
    }

    // MARK: - Inputs

    /// The set's fields (`SetKeyboardField.fields(for:trackingMode:)`), each opening the set keyboard.
    func inputFields(units: ExerciseUnitPreference) -> some View {
        let fields = SetKeyboardField.fields(for: delegate.set.wrappedValue, trackingMode: delegate.exercise.wrappedValue.trackingMode)
        return HStack(spacing: Spacing.s) {
            ForEach(fields, id: \.self) { field in
                inputField(field, in: fields, units: units)
                    .setColumn(width: field.columnWidth(in: fields), height: cellHeight, stretches: isStacked)
            }
        }
    }

    /// A time still to do gets a stopwatch, its bar filling towards the plan's seconds for a
    /// stretch or hold, else last session's time. A logged one is corrected by typing.
    @ViewBuilder
    private func inputField(_ field: SetKeyboardField, in fields: [SetKeyboardField], units: ExerciseUnitPreference) -> some View {
        let set = delegate.set.wrappedValue
        if field.usesStopwatch(in: fields), set.completedAt == nil {
            SetStopwatch(set: delegate.set, targetSeconds: set.isTimedPiece ? set.durationSec : delegate.lastSet?.durationSec) {
                keyboardField(field, units: units)
            }
        } else {
            keyboardField(field, units: units)
        }
    }

    /// A field that opens the in-app keyboard, highlighted while it is being edited. A logged set
    /// stays editable, so a typo is corrected in place rather than by un-logging, which would
    /// restart the rest.
    private func keyboardField(_ field: SetKeyboardField, units: ExerciseUnitPreference) -> some View {
        let set = delegate.set
        let keyboard = presenter.keyboard
        let isActive = keyboard.activeField == field
        return SetKeyboardTextField(
            field: field,
            text: keyboard.displayText(for: field, set: set.wrappedValue, unit: units.weightUnit, distanceUnit: units.distanceUnit),
            isActive: isActive,
            // "Set 2, Weight, kilograms": the set first, so each row's fields have names of their own.
            accessibilityLabel: "\(rowName), \(field.accessibilityName(units: units))",
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
        // UI tests: `STARTSCREEN_SET_KEYBOARD` opens the first open weight field's keyboard.
        .task {
            presenter.onFieldAppeared(field, delegate: delegate)
        }
    }

    // MARK: - Done

    var completeButton: some View {
        let exercise = delegate.exercise.wrappedValue
        return DoneButton(state: presenter.completionState(exercise: exercise, set: delegate.set.wrappedValue), setName: rowName) {
            presenter.onSetComplete(exercise, delegate.set, onLogSet: delegate.onLogSet, customRestSeconds: delegate.customRestSeconds)
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

extension CoreBuilder {

    func setTrackerRowView(
        router: AnyRouter,
        delegate: SetTrackerRowDelegate
    ) -> some View {
        let presenter = SetTrackerRowPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        return SetTrackerRowView(presenter: presenter, delegate: delegate)
    }

}
