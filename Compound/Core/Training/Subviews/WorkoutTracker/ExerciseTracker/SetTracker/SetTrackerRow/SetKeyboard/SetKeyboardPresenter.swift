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
    private(set) var bandIndex: Int?
    var showsPlates = false

    private var editingSet: Binding<WorkoutSetModel>?

    /// Whose decimal separator the keypad shows and types. A test sets another region's.
    var locale: Locale = .current

    /// "," in most of Europe and South America, "." elsewhere: what the decimal key shows.
    var decimalSeparator: String { locale.decimalSeparator ?? "." }

    /// Called by Done. The row offers to log the set if it is ready.
    var onOfferCompletion: (() -> Void)?

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

    /// Closes the keyboard and hands over to the row, which offers to log the set when it is ready.
    /// The row decides, because what "ready" means depends on the tracking mode.
    func done() {
        close()
        onOfferCompletion?()
    }

    /// Closes without offering anything: the field lost focus to something else.
    ///
    /// Lets go of the set too. The binding reads its set by index, so one kept after an earlier set
    /// is deleted would read past the end of the array.
    func close() {
        activeField = nil
        showsPlates = false
        editingSet = nil
    }

    private func activate(_ field: SetKeyboardField) {
        activeField = field
        text = currentText(for: field)
        replacesOnNextKey = true
        if field != .weight { showsPlates = false }
    }

    // MARK: - Keys

    /// A digit or a decimal separator, from the keypad or a hardware keyboard. Either "." or ","
    /// types the region's separator, so a hardware keyboard works whichever the user reaches for.
    func type(_ key: Character) {
        guard let field = activeField else { return }
        let base = replacesOnNextKey ? "" : text
        let candidate: String
        switch key {
        case ".", ",":
            guard field.takesDecimals, !base.contains(decimalSeparator) else { return }
            candidate = (base.isEmpty ? "0" : base) + decimalSeparator
        case "0"..."9":
            candidate = base + String(key)
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
            return (parts.first?.count ?? 0) <= wholeDigits && (parts.count < 2 || parts[1].count <= 2)
        }
    }

    /// Writes the typed text into the set.
    private func commit() {
        guard let set = editingSet, let field = activeField else { return }
        switch field {
        case .weight:
            bandIndex = nil
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

    // MARK: - Stepper and chips

    func stepUp() { step(forward: true) }

    func stepDown() { step(forward: false) }

    private func step(forward: Bool) {
        guard let set = editingSet else { return }
        if case .bands = context.step.kind {
            bandIndex = context.step.band(after: bandIndex, forward: forward)
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
        bandIndex = nil
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

    // MARK: - Plates

    /// The per-side breakdown of the current weight, for plate-loaded equipment.
    var plateLoad: PlateCalculator.Result? {
        guard context.step.isPlateLoaded, let bar = context.step.baseWeight,
              let weightKg = editingSet?.wrappedValue.weightKg else { return nil }
        let total = (UnitConversion.convertWeight(weightKg, to: context.unit) * 1000).rounded() / 1000
        return PlateCalculator.load(total: total, bar: bar, plates: context.step.plates)
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
            return field == .duration && !text.isEmpty ? Self.clock(fromDigits: text) : text
        }
        if field == .weight, let bandIndex, case .bands(let names) = context.step.kind, names.indices.contains(bandIndex) {
            return names[bandIndex]
        }
        if field == .duration { return set.durationSec.map { Format.duration(TimeInterval($0)) } ?? "" }
        return Self.text(for: field, set: set, unit: unit, distanceUnit: distanceUnit, locale: locale)
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
