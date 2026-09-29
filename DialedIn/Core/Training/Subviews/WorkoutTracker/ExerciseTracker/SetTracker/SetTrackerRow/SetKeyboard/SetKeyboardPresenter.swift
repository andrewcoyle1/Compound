//
//  SetKeyboardPresenter.swift
//  DialedIn
//
//  The in-app weight and reps keyboards for one set row. Every key edits the set as it is
//  pressed, so the row behind the keyboard always shows what will be logged.
//

import SwiftUI

enum SetKeyboardField: Equatable {
    case weight
    case reps
}

/// What the keyboard needs to know about the exercise and set it is editing, resolved by the row
/// each time a field opens.
struct SetKeyboardContext {
    var unit: ExerciseWeightUnit = .kilograms
    var step: WeightStep = WeightStepper.fallback(.kilograms)
    /// False for reps-only exercises: the reps keyboard then has nothing to go back to.
    var tracksWeight: Bool = true
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

    /// Called by Done when the set now holds everything it needs to be logged.
    var onOfferCompletion: (() -> Void)?

    // MARK: - Opening and moving

    func open(_ field: SetKeyboardField, set: Binding<WorkoutSetModel>, context: SetKeyboardContext) {
        self.editingSet = set
        self.context = context
        guard activeField != field else { return }
        activate(field)
    }

    /// Weight → reps.
    func next() {
        guard activeField == .weight else { return }
        activate(.reps)
    }

    /// Reps → weight.
    func previous() {
        guard activeField == .reps, context.tracksWeight else { return }
        activate(.weight)
    }

    /// Closes the keyboard and, when the set is ready, offers to log it.
    func done() {
        close()
        guard let set = editingSet?.wrappedValue, set.completedAt == nil, let reps = set.reps, reps > 0 else { return }
        if let weight = set.weightKg, weight < 0 { return }
        onOfferCompletion?()
    }

    /// Closes without offering anything: the field lost focus to something else.
    func close() {
        activeField = nil
        showsPlates = false
    }

    private func activate(_ field: SetKeyboardField) {
        activeField = field
        text = currentText(for: field)
        replacesOnNextKey = true
        if field != .weight { showsPlates = false }
    }

    // MARK: - Keys

    /// A digit or ".", from the keypad or a hardware keyboard.
    func type(_ key: Character) {
        guard let field = activeField else { return }
        let base = replacesOnNextKey ? "" : text
        let candidate: String
        switch key {
        case ".", ",":
            guard field == .weight, !base.contains(".") else { return }
            candidate = (base.isEmpty ? "0" : base) + "."
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
        case .weight:
            let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
            return (parts.first?.count ?? 0) <= 4 && (parts.count < 2 || parts[1].count <= 2)
        }
    }

    /// Writes the typed text into the set.
    private func commit() {
        guard let set = editingSet, let field = activeField else { return }
        switch field {
        case .weight:
            bandIndex = nil
            set.wrappedValue.weightKg = Double(text).map { UnitConversion.convertWeightToKg($0, from: context.unit) }
        case .reps:
            set.wrappedValue.reps = Int(text)
        }
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
    func displayText(for field: SetKeyboardField, set: WorkoutSetModel, unit: ExerciseWeightUnit) -> String {
        if field == activeField, editingSet?.wrappedValue.id == set.id { return text }
        if field == .weight, let bandIndex, case .bands(let names) = context.step.kind, names.indices.contains(bandIndex) {
            return names[bandIndex]
        }
        return Self.text(for: field, set: set, unit: unit)
    }

    private func currentText(for field: SetKeyboardField) -> String {
        guard let set = editingSet?.wrappedValue else { return "" }
        return Self.text(for: field, set: set, unit: context.unit)
    }

    static func text(for field: SetKeyboardField, set: WorkoutSetModel, unit: ExerciseWeightUnit) -> String {
        switch field {
        case .weight:
            return set.weightKg.map { WeightStepper.format(UnitConversion.convertWeight($0, to: unit)) } ?? ""
        case .reps:
            return set.reps.map(String.init) ?? ""
        }
    }
}
