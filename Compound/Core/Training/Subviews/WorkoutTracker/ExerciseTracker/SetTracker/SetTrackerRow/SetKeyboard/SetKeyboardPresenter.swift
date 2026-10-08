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

    /// The fields a row of this tracking mode shows, in the order Next and Prev walk them.
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
    /// The row's fields, in order. Next and Prev walk them.
    var fields: [SetKeyboardField] = [.weight, .reps]
    /// `WorkoutSettings.rirTracking`, shown to the user as "Effort (RPE)".
    var showsEffort: Bool = false
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

    /// The field before the active one, if any.
    var previousField: SetKeyboardField? {
        guard let field = activeField, let index = context.fields.firstIndex(of: field) else { return nil }
        return index > 0 ? context.fields[index - 1] : nil
    }

    func next() {
        guard let field = nextField else { return }
        activate(field)
    }

    func previous() {
        guard let field = previousField else { return }
        activate(field)
    }

    /// Done only closes. The log button, always above the keypad, is the one way to log, so Done
    /// never logs a set that was only being prepared (decision T1, `docs/reviews/hig-decisions.md`).
    func done() {
        close()
    }

    /// Closes the keypad: Done, or the field lost focus to something else.
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
            set.wrappedValue.weightKg = Double.typed(text, locale: locale).map { UnitConversion.convertWeightToKg($0, from: context.unit) }
        case .reps:
            set.wrappedValue.reps = Int(text)
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

    /// Picks an RPE, or clears it when the same chip is tapped again.
    func toggleRPE(_ rpe: Double) {
        guard let set = editingSet else { return }
        set.wrappedValue.rpe = set.wrappedValue.rpe == rpe ? nil : rpe
    }

    var selectedRPE: Double? { editingSet?.wrappedValue.rpe }

    /// The RPE chips, on a set already logged: effort is an outcome, recorded after the set in the
    /// correction row, so the keypad offers them only to correct a logged one.
    var showsEffortChips: Bool {
        context.showsEffort && editingSet?.wrappedValue.completedAt != nil
    }

    var weightChips: [SetKeyboardChip] {
        chips([
            (String(localized: "Last set"), context.lastSetWeightKg),
            (String(localized: "Last time"), context.previousSessionWeightKg),
            (String(localized: "Target"), context.targetWeightKg)
        ]) { UnitConversion.convertWeight($0, to: context.unit) }
    }

    var repsChips: [SetKeyboardChip] {
        chips([
            (String(localized: "Last set"), context.lastSetReps.map(Double.init)),
            (String(localized: "Min"), context.targetMinReps.map(Double.init)),
            (String(localized: "Max"), context.targetMaxReps.map(Double.init))
        ]) { $0 }
    }

    private func chips(_ values: [(String, Double?)], convert: (Double) -> Double) -> [SetKeyboardChip] {
        values.compactMap { title, value in
            guard let value else { return nil }
            let display = (convert(value) * 100).rounded() / 100
            return SetKeyboardChip(title: "\(title) \(WeightStepper.format(display))", value: display)
        }
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
    var showsLoadingBar: Bool {
        activeField == .weight && context.step.isPlateLoaded
    }

    /// The plates on one sleeve and the sum they make, for a weight the bar can carry; the bare
    /// bar before a weight is entered. `nil` when the weight cannot be loaded (see `plateLoad`).
    var plateLoading: PlateLoading? {
        guard context.step.isPlateLoaded, let base = context.step.baseWeight else { return nil }
        switch plateLoad {
        case .loadable(let perSide)?:
            return PlateLoading(perSide: perSide, base: base, sleeves: context.step.sleeves, unit: context.unit)
        case .notLoadable?:
            return nil
        case nil:
            return PlateLoading(perSide: [], base: base, sleeves: context.step.sleeves, unit: context.unit)
        }
    }

    /// The per-sleeve breakdown of the current weight, for plate-loaded equipment.
    var plateLoad: PlateCalculator.Result? {
        guard context.step.isPlateLoaded, let bar = context.step.baseWeight,
              let weightKg = editingSet?.wrappedValue.weightKg else { return nil }
        let total = (UnitConversion.convertWeight(weightKg, to: context.unit) * 1000).rounded() / 1000
        return PlateCalculator.load(total: total, bar: bar, plates: context.step.plates, sleeves: context.step.sleeves)
    }

    /// "Pin 14 + 2 kg" for the current weight on a stack with add-ons; nil otherwise.
    var stackSummary: String? {
        guard context.step.stack != nil, let weightKg = editingSet?.wrappedValue.weightKg else { return nil }
        let total = (UnitConversion.convertWeight(weightKg, to: context.unit) * 1000).rounded() / 1000
        return context.step.stackText(total: total, unit: context.unit)
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
        return Format.load(set.weightKg.map { ActiveWorkout.spokenWeight(kg: $0, unit: context.unit, locale: locale) }, bands: set.bands)
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
            return set.weightKg.map { WeightStepper.format(UnitConversion.convertWeight($0, to: unit), locale: locale) } ?? ""
        case .reps:
            return set.reps.map(String.init) ?? ""
        case .distance:
            return set.distanceMeters.map { WeightStepper.format(UnitConversion.convertDistance($0, to: distanceUnit), locale: locale) } ?? ""
        case .duration:
            return set.durationSec.map(digits(fromSeconds:)) ?? ""
        }
    }
}
