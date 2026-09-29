import SwiftUI

struct SetTrackerRowDelegate {
    var exercise: Binding<WorkoutExerciseModel>
    var set: Binding<WorkoutSetModel>
    let lastSet: WorkoutSetModel?
    /// What smart progression suggests for this row, if anything. Shown by the Auto column.
    var progressionSuggestion: SuggestedSet?
    var showAutoRanges: Bool = false
    /// Called with the set that was just logged, so the screen can re-suggest what is left.
    var onSetCompleted: @MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void = { _, _ in }
    var eventParameters: [String: Any]? {
        nil
    }
}

struct SetTrackerRowView: View {
    
    @State var presenter: SetTrackerRowPresenter
    let delegate: SetTrackerRowDelegate
    
    /// The in-app keyboard all of this row's fields share.
    @State private var keyboardHost = SetKeyboardInputHost()

    /// The row's cell height at the default text size. Scaled so a larger size never clips a value;
    /// the row's Dynamic Type cap (`maxDynamicTypeSize`) bounds how far it grows.
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 35
    
    var body: some View {
        HStack {
            setNumber(set: delegate.set)
            Spacer()
            previousValues(exercise: delegate.exercise, set: delegate.set)
            Spacer()
            inputFields(exercise: delegate.exercise.wrappedValue, set: delegate.set)
            Spacer()
            completeButton(exercise: delegate.exercise.wrappedValue, set: delegate.set)
        }
        // A five-column table of numbers: past this size the fixed columns truncated every
        // value to "4…". Capped here and on the headers, which share the column widths.
        .dynamicTypeSize(...SetTrackerRowView.maxDynamicTypeSize)
        .padding(.vertical, Spacing.xs)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteSetButton
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            restTimerButton
        }
        // `rowActions` does this for one edge; this row swipes both ways, so one menu carries both
        // actions for anyone who cannot swipe.
        .contextMenu {
            restTimerButton
            deleteSetButton
        }
        .moveDisabled(true)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    static let maxDynamicTypeSize = DynamicTypeSize.xxxLarge

    /// Column widths the headers share. The set number and Done are the 44 pt minimum hit area;
    /// Prev gave up the room they needed.
    static let setColumnWidth = ControlSize.row
    static let previousColumnWidth: CGFloat = 78
    static let doneColumnWidth = ControlSize.row

    private var deleteSetButton: some View {
        Button(role: .destructive) {
            presenter.deleteSet(setId: delegate.set.id, exercise: delegate.exercise)
        } label: {
            Label("Delete", systemImage: Symbol.delete)
        }
    }

    private var restTimerButton: some View {
        Button {
            presenter.onRestPickerRequested(
                exercise: delegate.exercise.wrappedValue,
                setId: delegate.set.wrappedValue.id
            )
        } label: {
            Label("Rest Timer", systemImage: Symbol.rest)
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
        } label: {
            Text(setLabel(for: set.wrappedValue))
                .font(.caption)
                .tapTarget()
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(set.wrappedValue.isWarmup ? Color.warmup : .secondary)
        .foregroundStyle(set.wrappedValue.isWarmup ? AnyShapeStyle(.warmup) : AnyShapeStyle(.secondary))
        .frame(width: SetTrackerRowView.setColumnWidth, alignment: .center)
        .accessibilityLabel(set.wrappedValue.isWarmup ? String(localized: "Warmup set") : String(localized: "Set \(setLabel(for: set.wrappedValue))"))
    }

    /// What the circle beside a set shows. Both halves of a left/right pair carry the same number
    /// with an L or R after it, because they are one set — numbering them 1 and 2 would tell a
    /// user doing three sets a side that they were on their fourth.
    private func setLabel(for set: WorkoutSetModel) -> String {
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
                    .frame(width: 70, height: cellHeight)
                keyboardField(.reps, set: set, label: String(localized: "Reps"))
                    .frame(width: 50, height: cellHeight)
            case .repsOnly:
                keyboardField(.reps, set: set, label: String(localized: "Reps"))
                    .frame(width: 50, height: cellHeight)
            case .timeOnly:
                keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                    .frame(width: 90, height: cellHeight)
            case .distanceTime:
                keyboardField(.distance, set: set, label: String(localized: "Distance, \(units.distanceUnit.displayName)"))
                    .frame(width: 70, height: cellHeight)
                keyboardField(.duration, set: set, label: String(localized: "Time, minutes and seconds"))
                    .frame(width: 70, height: cellHeight)
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
            accessibilityLabel: label,
            presenter: keyboard,
            inputHost: keyboardHost,
            onBegin: { presenter.onKeyboardFieldBegan(field, delegate: delegate) }
        )
        .background(isActive ? AnyShapeStyle(Color.tintedSurface(.accentColor)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: Radius.s, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .strokeBorder(.tint, lineWidth: isActive ? 2 : 0)
        }
        .disabled(delegate.set.wrappedValue.completedAt != nil)
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
        .frame(width: SetTrackerRowView.previousColumnWidth, alignment: .center)
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
            .foregroundStyle(.secondary)
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
        let state = presenter.completionState(trackingMode: exercise.trackingMode, set: set.wrappedValue)
        return Button {
            presenter.onSetComplete(exercise, set)
        } label: {
            Image(systemName: state.systemImage)
                .font(.title3)
                .foregroundStyle(state.tint)
                .tapTarget()
        }
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityValue(state.accessibilityValue)
        .buttonStyle(.plain)
        .frame(width: SetTrackerRowView.doneColumnWidth, alignment: .center)
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
            if let weight = prev.weightKg, let reps = prev.reps {
                columnText("\(Format.weight(kg: weight, unit: unitPreference.weightUnit)) × \(reps)")
                    .anyButton {
                        delegate.set.wrappedValue.weightKg = weight
                        delegate.set.wrappedValue.reps = reps
                    }
                    .accessibilityHint("Fills this set")
                    .disabled(delegate.set.wrappedValue.completedAt != nil)
            } else {
                emptyTargetLabel
            }
        case .repsOnly:
            columnText(prev.reps.map(String.init) ?? Format.placeholder)
        case .timeOnly:
            columnText(prev.durationSec.map { Format.duration(TimeInterval($0)) } ?? Format.placeholder)
        case .distanceTime:
            if let distance = prev.distanceMeters, let duration = prev.durationSec {
                let displayDistance = Format.distance(meters: distance, exerciseUnit: unitPreference.distanceUnit)
                columnText("\(displayDistance) \(Format.duration(TimeInterval(duration)))", font: .caption2)
                    .lineLimit(2)
            } else {
                emptyTargetLabel
            }
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
        delegate: SetTrackerRowDelegate,
        onStartRest: ((Int) -> Void)? = nil
    ) -> some View {
        let presenter = SetTrackerRowPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        presenter.onStartRest = onStartRest
        presenter.onSetCompleted = delegate.onSetCompleted
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
