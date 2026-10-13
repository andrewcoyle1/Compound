//
//  SetKeyboardPresenter.swift
//  Compound
//
//  The in-app keyboards for one set row: weight, reps, distance and duration. Every key edits the
//  set as it is pressed, so the row behind the keyboard always shows what will be logged.
//

import SwiftUI

enum SetKeyboardField: Equatable {
    case weight
    case reps
    /// In the exercise's distance unit, with a decimal point.
    case distance
    /// Typed like a microwave: digits fill from the right, so "130" is 1:30.
    case duration

    var takesDecimals: Bool { self == .weight || self == .distance }

    /// The fields a row of this tracking mode shows, in the order Next walks them.
    static func fields(for trackingMode: TrackingMode) -> [SetKeyboardField] {
        switch trackingMode {
        case .weightReps: return [.weight, .reps]
        case .repsOnly: return [.reps]
        case .timeOnly: return [.duration]
        case .distanceTime: return [.distance, .duration]
        }
    }

    /// The fields of `set`'s row: a stretch or hold after a set is timed, whatever the exercise
    /// tracks, and a hold keeps the set's weight.
    static func fields(for set: WorkoutSetModel, trackingMode: TrackingMode) -> [SetKeyboardField] {
        guard set.isTimedPiece else { return fields(for: trackingMode) }
        return set.kind == .hold && trackingMode == .weightReps ? [.weight, .duration] : [.duration]
    }
}

/// What the keyboard needs to know about the exercise and set it is editing, resolved by the row
/// each time a field opens.
struct SetKeyboardContext {
    var unit: ExerciseWeightUnit = .kilograms
    var step: WeightStep = WeightStepper.fallback(.kilograms)
    var distanceUnit: ExerciseDistanceUnit = .meters
    /// The row's fields, in order. Next walks them.
    var fields: [SetKeyboardField] = [.weight, .reps]
    /// `WorkoutSettings.rirTracking`, shown to the user as "Effort (RPE)".
    var showsEffort: Bool = false
    /// The reps in reserve the set's target aims for (`SetTarget.rirTarget`), which the set
    /// starts with; with one, the reps keypad always offers reps in reserve.
    var targetRIR: Int?
    var lastSetWeightKg: Double?
    var lastSetReps: Int?
    var previousSessionWeightKg: Double?
    var targetWeightKg: Double?
    var targetMinReps: Int?
    var targetMaxReps: Int?
}

struct SetKeyboardChip: Identifiable, Equatable {
    let title: String
    let value: Double
    var id: String { title }
}

@Observable
@MainActor
final class SetKeyboardPresenter {

    private(set) var activeField: SetKeyboardField?
    /// What the active field shows while it is being typed into.
    private(set) var text = ""
    /// The first key after a field opens replaces its value, as a selected text field would.
    private var replacesOnNextKey = false
    private(set) var context = SetKeyboardContext()
    /// Played when a band chip is toggled. The row sets it, as the keyboard has no interactor.
    var playSelectionHaptic: (@MainActor () -> Void)?
    /// Opens the plate calculator for the set being edited. The row sets it, as the keyboard has
    /// no router.
    var openPlateCalculator: (@MainActor () -> Void)?
    /// Logs the set being edited, as its Done column does. The row sets it; `false` keeps the
    /// keypad open because the set cannot be logged yet.
    var onComplete: (@MainActor () -> Bool)?
    /// The set being edited is already logged, so the last field's ✓ only closes.
    var isEditingLoggedSet: Bool { editingSet?.wrappedValue.completedAt != nil }

    private var editingSet: Binding<WorkoutSetModel>?

    /// Whose decimal separator the keypad shows and types. A test sets another region's.
    var locale: Locale = .current

    /// "," in most of Europe and South America, "." elsewhere: what the decimal key shows.
    var decimalSeparator: String { locale.decimalSeparator ?? "." }

    // MARK: - Opening and moving

    func open(_ field: SetKeyboardField, set: Binding<WorkoutSetModel>, context: SetKeyboardContext) {
        self.editingSet = set
        self.context = context
        guard activeField != field else { return }
        activate(field)
    }

    /// The field after the active one, if any: weight → reps, distance → duration.
    var nextField: SetKeyboardField? {
        guard let field = activeField, let index = context.fields.firstIndex(of: field) else { return nil }
        return context.fields.indices.contains(index + 1) ? context.fields[index + 1] : nil
    }

    func next() {
        guard let field = nextField else { return }
        activate(field)
    }

    /// The ✓ on the row's last field: logs the set, as its Done column does, and closes. A logged
    /// set only closes; one that cannot be logged yet stays open (decision T1, amended 13 Oct
    /// 2026, `docs/reviews/hig-decisions.md`). The keypad only moves forward; an earlier field is
    /// a tap away.
    func done() {
        guard onComplete?() ?? true else { return }
        close()
    }

    /// Closes the keypad: the hide key, Done, or the field lost focus to something else.
    ///
    /// Lets go of the set too. The binding reads its set by index, so one kept after an earlier set
    /// is deleted would read past the end of the array.
    func close() {
        activeField = nil
        editingSet = nil
    }

    private func activate(_ field: SetKeyboardField) {
        activeField = field
        text = currentText(for: field)
        replacesOnNextKey = true
    }

    /// The gym changed under an open keyboard (a bar or plates chosen in the plate calculator):
    /// step and load on the new equipment without touching what is typed.
    func refresh(context: SetKeyboardContext) {
        self.context = context
    }

    // MARK: - Keys

    /// A digit or a decimal separator, from the keypad or a hardware keyboard. Either "." or ","
    /// types the region's separator, so a hardware keyboard works whichever the user reaches for.
    func type(_ key: Character) {
        guard let field = activeField else { return }
        // Assistance stays assistance: typing over "−30" types another negative weight.
        let base = replacesOnNextKey ? (showsSignKey && text.hasPrefix("-") ? "-" : "") : text
        let candidate: String
        switch key {
        case ".", ",":
            guard field.takesDecimals, !base.contains(decimalSeparator) else { return }
            candidate = (base.isEmpty || base == "-" ? base + "0" : base) + decimalSeparator
        case "0"..."9":
            candidate = base + String(key)
        case "-" where showsSignKey:
            toggleSign()
            return
        default:
            return
        }
        guard isValid(candidate, for: field) else { return }
        replacesOnNextKey = false
        text = candidate
        commit()
    }

    func backspace() {
        guard activeField != nil else { return }
        text = replacesOnNextKey ? "" : String(text.dropLast())
        replacesOnNextKey = false
        commit()
    }

    private func isValid(_ candidate: String, for field: SetKeyboardField) -> Bool {
        switch field {
        case .reps:
            return candidate.count <= 3
        case .duration:
            // mmss: up to 99:99, which is read as 100:39.
            return candidate.count <= 4
        case .weight, .distance:
            let parts = candidate.components(separatedBy: decimalSeparator)
            let wholeDigits = field == .distance ? 5 : 4
            return (parts.first?.filter(\.isNumber).count ?? 0) <= wholeDigits && (parts.count < 2 || parts[1].count <= 2)
        }
    }

    /// Writes the typed text into the set.
    private func commit() {
        guard let set = editingSet, let field = activeField else { return }
        switch field {
        case .weight:
            // Typed as the load: a machine base kept out of it goes back on (`machineBaseKg`).
            let base = set.wrappedValue.machineBaseKg ?? 0
            set.wrappedValue.weightKg = Double.typed(text, locale: locale).map { UnitConversion.convertWeightToKg($0, from: context.unit) + base }
        case .reps:
            // A logged set keeps at least one rep: cleared, it would read as a single everywhere.
            let typed = Int(text)
            guard set.wrappedValue.completedAt == nil || (typed ?? 0) >= 1 else { return }
            set.wrappedValue.reps = typed
        case .distance:
            set.wrappedValue.distanceMeters = Double.typed(text, locale: locale).map { UnitConversion.convertDistanceToMeters($0, from: context.distanceUnit) }
        case .duration:
            set.wrappedValue.durationSec = Self.seconds(fromDigits: text)
        }
    }

    /// "130" → 90, "45" → 45, "" → nil. The last two digits are seconds, the rest minutes.
    static func seconds(fromDigits digits: String) -> Int? {
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        return (value / 100) * 60 + value % 100
    }

    /// 90 → "130", the digits that type a duration back in.
    static func digits(fromSeconds seconds: Int) -> String {
        String((seconds / 60) * 100 + seconds % 60)
    }

    /// The typed digits as a clock: "1" → "0:01", "130" → "1:30".
    static func clock(fromDigits digits: String) -> String {
        let padded = String(repeating: "0", count: max(0, 3 - digits.count)) + digits
        return "\(padded.dropLast(2)):\(padded.suffix(2))"
    }

    // MARK: - Assistance

    /// The ± key, on an assisted exercise's weight only: assistance is stored as a negative weight.
    var showsSignKey: Bool { activeField == .weight && context.step.isAssisted }

    /// Flips the weight between load and assistance: 30 kg ↔ −30 kg. On an empty field it starts
    /// a negative number, so "± 3 0" types −30.
    func toggleSign() {
        guard showsSignKey, let set = editingSet else { return }
        if let weightKg = set.wrappedValue.weightKg, weightKg != 0 {
            applyWeight(displayValue: UnitConversion.convertWeight(-weightKg, to: context.unit))
            return
        }
        // Nothing to flip yet: start a negative number, or cancel one just started.
        text = text == "-" ? "" : "-"
        replacesOnNextKey = false
        set.wrappedValue.weightKg = nil
    }

    // MARK: - Stepper and chips

    func stepUp() { step(forward: true) }

    func stepDown() { step(forward: false) }

    /// Bands alone have no weight to step, so ± moves through them one at a time, as it always
    /// has, choosing just that band: from the last one chosen, or the lightest (heaviest going down).
    private func step(forward: Bool) {
        guard let set = editingSet else { return }
        if context.step.kind == .bands {
            let current = set.wrappedValue.bands?.last.flatMap { context.step.bands.firstIndex(of: $0) }
            let next = context.step.band(after: current, forward: forward)
            set.wrappedValue.bands = next.map { [context.step.bands[$0]] }
            set.wrappedValue.weightKg = nil
            text = ""
            replacesOnNextKey = true
            return
        }
        let current = set.wrappedValue.weightKg.map { UnitConversion.convertWeight($0, to: context.unit) }
        let value = forward ? context.step.next(after: current) : context.step.previous(before: current)
        applyWeight(displayValue: value)
    }

    /// Sets the weight from a value already in the display unit.
    func applyWeight(displayValue: Double?) {
        guard let set = editingSet else { return }
        set.wrappedValue.weightKg = displayValue.map { UnitConversion.convertWeightToKg($0, from: context.unit) }
        if activeField == .weight {
            text = currentText(for: .weight)
            replacesOnNextKey = true
        }
    }

    func applyReps(_ reps: Int) {
        editingSet?.wrappedValue.reps = reps
        if activeField == .reps {
            text = currentText(for: .reps)
            replacesOnNextKey = true
        }
    }

    /// Picks the reps left in reserve, or clears them when the same chip is tapped again. Stored
    /// as the RPE it is (`EffortScale`): 2 in reserve is RPE 8, 6+ is RPE 4.
    func toggleRIR(_ rir: Int) {
        guard let set = editingSet else { return }
        set.wrappedValue.rpe = selectedRIR == rir ? nil : EffortScale.rpe(fromRIR: rir)
    }

    var selectedRIR: Int? { editingSet?.wrappedValue.rpe.map(EffortScale.rirChoice(fromRPE:)) }

    /// The reps-in-reserve chips over the reps keypad, with effort tracking on or a target RIR
    /// on the set: the set starts at its target, and the chips record what was actually left.
    var showsEffortChips: Bool {
        context.showsEffort || context.targetRIR != nil
    }

    /// Each chip applies a total and reads as the load, like the field.
    var weightChips: [SetKeyboardChip] {
        chips([
            (String(localized: "Last set"), context.lastSetWeightKg),
            (String(localized: "Last time"), context.previousSessionWeightKg),
            (String(localized: "Target"), context.targetWeightKg)
        ], shownLess: baseInUnit) { UnitConversion.convertWeight($0, to: context.unit) }
    }

    var repsChips: [SetKeyboardChip] {
        chips([
            (String(localized: "Last set"), context.lastSetReps.map(Double.init)),
            (String(localized: "Min"), context.targetMinReps.map(Double.init)),
            (String(localized: "Max"), context.targetMaxReps.map(Double.init))
        ]) { $0 }
    }

    private func chips(_ values: [(String, Double?)], shownLess offset: Double = 0, convert: (Double) -> Double) -> [SetKeyboardChip] {
        values.compactMap { title, value in
            guard let value else { return nil }
            let display = (convert(value) * 100).rounded() / 100
            let shown = ((display - offset) * 100).rounded() / 100
            return SetKeyboardChip(title: "\(title) \(WeightStepper.format(shown))", value: display)
        }
    }

    /// The machine base the set's weight is entered without, in the display unit; 0 for most.
    private var baseInUnit: Double {
        (editingSet?.wrappedValue.machineBaseKg).map { UnitConversion.convertWeight($0, to: context.unit) } ?? 0
    }

    /// A total in the display unit as the field would show it: without any machine base.
    func shownLoad(_ total: Double) -> String {
        WeightStepper.format(((total - baseInUnit) * 1000).rounded() / 1000, locale: locale)
    }

    // MARK: - Bands

    /// The bands on the set being edited, in the order they were chosen.
    var selectedBands: [String] { editingSet?.wrappedValue.bands ?? [] }

    /// Adds the band to the set, or takes it off; the last one off leaves no bands (`nil`). Beside
    /// any weight: on a bar with bands, ± steps the bar and these choose the bands.
    func toggleBand(_ name: String) {
        guard let set = editingSet else { return }
        var bands = set.wrappedValue.bands ?? []
        if let index = bands.firstIndex(of: name) {
            bands.remove(at: index)
        } else {
            bands.append(name)
        }
        set.wrappedValue.bands = bands.isEmpty ? nil : bands
        playSelectionHaptic?()
    }

    // MARK: - Plates

    /// The loading bar over the weight keypad: on a bar or plate-loaded machine, whatever the
    /// weight, so the bar and plates being loaded are always in view.
    /// Whatever the plates: with every plate switched off it still opens the plate calculator,
    /// the one place to switch them back on.
    var showsLoadingBar: Bool {
        activeField == .weight && context.step.baseWeight != nil
    }

    /// The plates on one sleeve and the sum they make, for a weight the bar can carry; the bare
    /// bar before a weight is entered. `nil` when the weight cannot be loaded (see `plateLoad`).
    var plateLoading: PlateLoading? {
        guard let base = context.step.baseWeight else { return nil }
        switch plateLoad {
        case .loadable(let perSide)?:
            return PlateLoading(perSide: perSide, base: base, sleeves: context.step.sleeves, unit: context.unit)
        case .notLoadable?:
            return nil
        case nil:
            return PlateLoading(perSide: [], base: base, sleeves: context.step.sleeves, unit: context.unit)
        }
    }

    /// The per-sleeve breakdown of the weight in the field, for plate-loaded equipment.
    var plateLoad: PlateCalculator.Result? {
        guard let bar = context.step.baseWeight, let total = shownWeight else { return nil }
        return PlateCalculator.load(total: total, bar: bar, plates: context.step.plates, sleeves: context.step.sleeves)
    }

    /// "Pin 14 + 2 kg" for the weight in the field on a stack with add-ons; nil otherwise.
    var stackSummary: String? {
        guard context.step.stack != nil, let total = shownWeight else { return nil }
        return context.step.stackText(total: total, unit: context.unit)
    }

    /// The weight the field shows, in the display unit, read from the field's own text while it
    /// is open. Every key, step and chip rewrites `text`, which this presenter observes; a weight
    /// read through the set's binding is not observed, so the loading bar stayed on the weight the
    /// keyboard opened with while + stepped the field.
    ///
    /// The field shows two decimals, so where it shows the stored weight the stored weight is read:
    /// + on a 44.092 lb bar makes 224.092 lb, which the field shows as "224.09", and the bar must
    /// not call that weight unloadable.
    private var shownWeight: Double? {
        let stored = editingSet?.wrappedValue.weightKg.map { (UnitConversion.convertWeight($0, to: context.unit) * 1000).rounded() / 1000 }
        guard activeField == .weight else { return stored }
        if let stored, shownLoad(stored) == text { return stored }
        return Double.typed(text, locale: locale).map { $0 + baseInUnit }
    }

    // MARK: - VoiceOver

    /// The active field's value as VoiceOver reads it after a key, a step or a chip: "102.5
    /// kilograms", "6 reps", "1 minute, 30 seconds". `nil` while the field is empty.
    var spokenValue: String? {
        guard let field = activeField, let set = editingSet?.wrappedValue else { return nil }
        switch field {
        case .weight:
            return spokenWeight
        case .reps:
            return set.reps.map { Format.reps($0, locale: locale) }
        case .distance:
            return set.distanceMeters.map {
                Measurement(value: UnitConversion.convertDistance($0, to: context.distanceUnit), unit: context.distanceUnit == .miles ? UnitLength.miles : UnitLength.meters)
                    .formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))).locale(locale))
            }
        case .duration:
            return set.durationSec.map { Duration.seconds($0).formatted(.units(allowed: [.minutes, .seconds], width: .wide).locale(locale)) }
        }
    }

    /// The weight and bands as the stepper row's VoiceOver value: "60 kilograms + Red", "Red + Blue".
    var spokenWeight: String? {
        guard let set = editingSet?.wrappedValue else { return nil }
        return Format.load(set.loadKg.map { ActiveWorkout.spokenWeight(kg: $0, unit: context.unit, locale: locale) }, bands: set.bands)
    }

    // MARK: - Display

    /// What a field shows: the live text while it is being typed into, the stored value otherwise.
    func displayText(
        for field: SetKeyboardField,
        set: WorkoutSetModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit = .meters
    ) -> String {
        if field == activeField, editingSet?.wrappedValue.id == set.id {
            if field == .weight { return Self.load(text, bands: set.bands) }
            return field == .duration && !text.isEmpty ? Self.clock(fromDigits: text) : text
        }
        if field == .weight { return Self.load(Self.text(for: .weight, set: set, unit: unit, locale: locale), bands: set.bands) }
        if field == .duration { return set.durationSec.map { Format.duration(TimeInterval($0)) } ?? "" }
        return Self.text(for: field, set: set, unit: unit, distanceUnit: distanceUnit, locale: locale)
    }

    /// The greyed hint an empty field shows: what the same set held last time, else "—". Only a
    /// hint: it is never written into the set, so it can never be logged as done.
    func placeholder(
        for field: SetKeyboardField,
        previous: WorkoutSetModel?,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit = .meters
    ) -> String {
        guard let previous else { return Format.placeholder }
        let hint = switch field {
        case .duration: previous.durationSec.map { Format.duration(TimeInterval($0)) } ?? ""
        case .weight: Self.load(Self.text(for: field, set: previous, unit: unit, locale: locale), bands: previous.bands)
        case .reps, .distance: Self.text(for: field, set: previous, unit: unit, distanceUnit: distanceUnit, locale: locale)
        }
        return hint.isEmpty ? Format.placeholder : hint
    }

    /// The weight cell: "60 + Red", "Red + Blue", or the weight alone. The column header gives the unit.
    private static func load(_ weight: String, bands: [String]?) -> String {
        Format.load(weight.isEmpty ? nil : weight, bands: bands) ?? ""
    }

    private func currentText(for field: SetKeyboardField) -> String {
        guard let set = editingSet?.wrappedValue else { return "" }
        return Self.text(for: field, set: set, unit: context.unit, distanceUnit: context.distanceUnit, locale: locale)
    }

    /// What typing starts from: the stored value as the keys would enter it.
    static func text(
        for field: SetKeyboardField,
        set: WorkoutSetModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit = .meters,
        locale: Locale = .current
    ) -> String {
        switch field {
        case .weight:
            return set.loadKg.map { WeightStepper.format(UnitConversion.convertWeight($0, to: unit), locale: locale) } ?? ""
        case .reps:
            return set.reps.map(String.init) ?? ""
        case .distance:
            return set.distanceMeters.map { WeightStepper.format(UnitConversion.convertDistance($0, to: distanceUnit), locale: locale) } ?? ""
        case .duration:
            return set.durationSec.map(digits(fromSeconds:)) ?? ""
        }
    }
}
