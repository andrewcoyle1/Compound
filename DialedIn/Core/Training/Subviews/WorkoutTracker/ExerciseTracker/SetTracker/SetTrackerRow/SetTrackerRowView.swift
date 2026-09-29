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
    
    /// The in-app keyboard both of this row's fields share.
    @State private var keyboardHost = SetKeyboardInputHost()
    
    var body: some View {
        HStack {
            setNumber(set: delegate.set)
            Spacer()
            previousValues(exercise: delegate.exercise, set: delegate.set)
            Spacer()
            inputFields(exercise: delegate.exercise, set: delegate.set)
            Spacer()
            completeButton(exercise: delegate.exercise.wrappedValue, set: delegate.set)
        }
        // A five-column table of numbers: past this size the fixed columns truncated every
        // value to "4…". Capped here and on the headers, which share the column widths.
        .dynamicTypeSize(...SetTrackerRowView.maxDynamicTypeSize)
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                presenter.deleteSet(setId: delegate.set.id, exercise: delegate.exercise)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                presenter.onRestPickerRequested(
                    exercise: delegate.exercise.wrappedValue,
                    setId: delegate.set.wrappedValue.id
                )
            } label: {
                Label("Rest Timer", systemImage: "timer")
            }
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

    func setNumber(set: Binding<WorkoutSetModel>) -> some View {
        Menu {
            Button {
                set.wrappedValue.isWarmup.toggle()
            } label: {
                Label("Warmup Set", systemImage: set.wrappedValue.isWarmup ? "checkmark" : "")
            }
            
            Button {
                presenter.onWarmupSetHelpPressed()
            } label: {
                Label("What's a warmup set?", systemImage: "info.circle")
            }
        } label: {
            Text(setLabel(for: set.wrappedValue))
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(set.wrappedValue.isWarmup ? Color.orange : .secondary)
        .foregroundColor(.secondary)
        .frame(width: 34, alignment: .center)
    }

    /// What the circle beside a set shows. Both halves of a left/right pair carry the same number
    /// with an L or R after it, because they are one set — numbering them 1 and 2 would tell a
    /// user doing three sets a side that they were on their fourth.
    private func setLabel(for set: WorkoutSetModel) -> String {
        guard !set.isWarmup else { return "W" }
        let number = delegate.exercise.wrappedValue.workingSetNumber(for: set)
        return "\(number)\(set.side?.initial ?? "")"
    }

    func weightRepsFields(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        let unitPreference = presenter.getUnitPreference(for: exercise.wrappedValue)
        return HStack(spacing: 8) {
            weightTextField(exercise: exercise, set: set, unitPreference: unitPreference)
            repsField(exercise: exercise.wrappedValue, set: set)
        }
    }

    private func weightTextField(
        exercise: Binding<WorkoutExerciseModel>,
        set: Binding<WorkoutSetModel>,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        keyboardField(.weight, set: set, unit: unitPreference.weightUnit, label: "Weight, \(unitPreference.weightUnit.displayName)")
            .frame(width: 70, height: 35)
    }

    private func repsField(exercise: WorkoutExerciseModel, set: Binding<WorkoutSetModel>) -> some View {
        keyboardField(.reps, set: set, unit: .kilograms, label: "Reps")
            .frame(width: 50, height: 35)
    }

    /// A field that opens the in-app weight or reps keyboard, highlighted while it is being edited.
    private func keyboardField(_ field: SetKeyboardField, set: Binding<WorkoutSetModel>, unit: ExerciseWeightUnit, label: String) -> some View {
        let keyboard = presenter.keyboard
        let isActive = keyboard.activeField == field
        return SetKeyboardTextField(
            field: field,
            text: keyboard.displayText(for: field, set: set.wrappedValue, unit: unit),
            isActive: isActive,
            accessibilityLabel: label,
            presenter: keyboard,
            inputHost: keyboardHost,
            onBegin: { presenter.onKeyboardFieldBegan(field, delegate: delegate) }
        )
        .background(isActive ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
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

    func previousValues(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        let unitPreference = presenter.getUnitPreference(for: exercise.wrappedValue)
        return Group {
            if delegate.showAutoRanges {
                autoTargetContent(exercise: exercise.wrappedValue, set: set.wrappedValue)
            } else if let prev = delegate.lastSet {
                previousValueContent(trackingMode: exercise.wrappedValue.trackingMode, prev: prev, unitPreference: unitPreference)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            }
        }
        .frame(width: 90, alignment: .center)
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
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
                    .anyButton {
                        fill(delegate.set, from: suggestion)
                    }
                    .disabled(delegate.set.wrappedValue.completedAt != nil)
            } else if let target {
                autoRangeLabel(target: target)
            } else {
                emptyTargetLabel
            }
        }
    }

    private var emptyTargetLabel: some View {
        Text("\u{2014}")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 35)
    }

    /// Writes a suggestion into the row, leaving alone every metric it says nothing about.
    private func fill(_ set: Binding<WorkoutSetModel>, from suggestion: SuggestedSet) {
        if let weightKg = suggestion.weightKg { set.wrappedValue.weightKg = weightKg }
        if let reps = suggestion.reps { set.wrappedValue.reps = reps }
        if let durationSec = suggestion.durationSec { set.wrappedValue.durationSec = durationSec }
        if let distanceMeters = suggestion.distanceMeters { set.wrappedValue.distanceMeters = distanceMeters }
    }

    @ViewBuilder
    private func autoRangeLabel(target: SetTarget) -> some View {
        let label: String = {
            switch (target.minReps, target.maxReps) {
            case (let min?, let max?): return "\(min)–\(max)"
            case (let min?, nil):      return "\(min)+"
            default:                   return "—"
            }
        }()
        Text(label)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 35)
    }

    @ViewBuilder
    func inputFields(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        switch exercise.wrappedValue.trackingMode {
        case .weightReps:
            weightRepsFields(exercise: exercise, set: set)
        case .repsOnly:
            repsField(exercise: exercise.wrappedValue, set: set)
        case .timeOnly:
            timeOnlyFields(exercise: exercise.wrappedValue, set: set)
        case .distanceTime:
            distanceTimeFields(exercise: exercise, set: set)
        }
    }

    func timeOnlyFields(exercise: WorkoutExerciseModel, set: Binding<WorkoutSetModel>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                TextField("0", value: Binding(
                    get: { set.wrappedValue.durationSec.map { $0 / 60 } },
                    set: { newMinutes in
                        if let minutes = newMinutes {
                            let seconds = (set.wrappedValue.durationSec ?? 0) % 60
                            let newDuration = minutes * 60 + seconds
                            set.wrappedValue.durationSec = newDuration
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 40)

                Text(":")
                    .font(.caption)

                TextField("00", value: Binding(
                    get: { set.wrappedValue.durationSec.map { $0 % 60 } },
                    set: { newSeconds in
                        if let seconds = newSeconds {
                            let minutes = (set.wrappedValue.durationSec ?? 0) / 60
                            let newDuration = minutes * 60 + seconds
                            set.wrappedValue.durationSec = newDuration
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 40)
            }
            .frame(width: 90)
            .frame(height: 35)
        }
    }
    
    func buttonColor(set: WorkoutSetModel, canComplete: Bool) -> Color {
        if set.completedAt != nil {
            return .green
        } else if canComplete {
            return .secondary
        } else {
            return .red.opacity(0.6)
        }
    }

    func completeButton(exercise: WorkoutExerciseModel, set: Binding<WorkoutSetModel>) -> some View {
        Button {
            presenter.onSetComplete(exercise, set)
        } label: {
            Image(systemName: set.wrappedValue.completedAt != nil ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(
                    presenter.buttonColor(
                        set: set.wrappedValue,
                        canComplete: presenter.canComplete(
                            trackingMode: exercise.trackingMode,
                            set: set.wrappedValue
                        )
                    )
                )
                .frame(height: 35)
        }
        .accessibilityLabel(set.wrappedValue.completedAt != nil ? String(localized: "Set completed") : String(localized: "Complete set"))
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, alignment: .center)
        .disabled(!presenter.canComplete(trackingMode: exercise.trackingMode, set: set.wrappedValue))
    }

    @ViewBuilder
    func previousValueContent(
        trackingMode: TrackingMode,
        prev: WorkoutSetModel,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        switch trackingMode {
        case .weightReps:
            previousValueWeightReps(prev: prev, unitPreference: unitPreference)
        case .repsOnly:
            previousValueRepsOnly(prev: prev)
        case .timeOnly:
            previousValueTimeOnly(prev: prev)
        case .distanceTime:
            previousValueDistanceTime(prev: prev, unitPreference: unitPreference)
        }
    }

    func previousValueWeightReps(
        prev: WorkoutSetModel,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        Group {
            if let weight = prev.weightKg, let reps = prev.reps {
                let displayWeight = UnitConversion.formatWeight(weight, unit: unitPreference.weightUnit)
                Text("\(displayWeight) × \(reps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
                    .anyButton {
                        delegate.set.wrappedValue.weightKg = weight
                        delegate.set.wrappedValue.reps = reps
                    }
                    .disabled(delegate.set.wrappedValue.completedAt != nil)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            }
        }
    }

    func previousValueRepsOnly(prev: WorkoutSetModel) -> some View {
        Group {
            if let reps = prev.reps {
                Text("\(reps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            }
        }
    }

    func previousValueTimeOnly(prev: WorkoutSetModel) -> some View {
        Group {
            if let duration = prev.durationSec {
                let minutes = duration / 60
                let seconds = duration % 60
                Text("\(minutes):\(String(format: "%02d", seconds))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
            }
        }
    }

    func distanceTimeFields(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        let unitPreference = presenter.getUnitPreference(for: exercise.wrappedValue)
        return HStack(spacing: 8) {
            distanceTimeDistanceField(exercise: exercise, set: set, unitPreference: unitPreference)
            distanceTimeTimeField(exercise: exercise, set: set)
        }
    }

    func distanceTimeDistanceField(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>, unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)) -> some View {
        VStack(alignment: .center, spacing: 2) {
            TextField("0", value: Binding(
                get: {
                    guard let meters = set.wrappedValue.distanceMeters else { return nil }
                    return UnitConversion.convertDistance(meters, to: unitPreference.distanceUnit)
                },
                set: { newValue in
                    guard let value = newValue else {
                        set.wrappedValue.distanceMeters = nil
                        return
                    }
                    let meters = UnitConversion.convertDistanceToMeters(value, from: unitPreference.distanceUnit)
                    set.wrappedValue.distanceMeters = meters
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            .frame(height: 35)
        }
        .frame(width: 70)
    }

    func distanceTimeTimeField(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                TextField("0", value: Binding(
                    get: { set.wrappedValue.durationSec.map { $0 / 60 } },
                    set: { newMinutes in
                        if let minutes = newMinutes {
                            let seconds = (set.wrappedValue.durationSec ?? 0) % 60
                            let newDuration = minutes * 60 + seconds
                            set.wrappedValue.durationSec = newDuration
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 35)
                Text(":")
                    .font(.caption2)
                TextField("00", value: Binding(
                    get: { set.wrappedValue.durationSec.map { $0 % 60 } },
                    set: { newSeconds in
                        if let seconds = newSeconds {
                            let minutes = (set.wrappedValue.durationSec ?? 0) / 60
                            let newDuration = minutes * 60 + seconds
                            set.wrappedValue.durationSec = newDuration
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 35)
            }
            .frame(height: 35)
        }
        .frame(width: 80)
    }

    func previousValueDistanceTime(
        prev: WorkoutSetModel,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        Group {
            if let distance = prev.distanceMeters, let duration = prev.durationSec {
                let displayDistance = UnitConversion.formatDistance(distance, unit: unitPreference.distanceUnit)
                let minutes = duration / 60
                let seconds = duration % 60
                Text("\(displayDistance) \(minutes):\(String(format: "%02d", seconds))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
                    .lineLimit(2)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 35)
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
